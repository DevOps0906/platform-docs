# 06 에이전트 작업 계획: Live Poll

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 작업마다 디렉토리(또는 파일)를 하나 이상 단독 소유한다. 다른 작업의 디렉토리는 읽기만 한다 |
| 루트 | 앱 `apps/live-poll/`, 워커 `services/poll-broadcaster/`. 아래 경로의 `src/`, `tests/`, `supabase/`는 `apps/live-poll/` 기준 |
| DB 정본 | 스키마 변경은 `docs/products/_supabase-modular/migrations/18xx_poll.sql`에서만(Fable). 앱의 `supabase/migrations/`는 정본 복사와 변환 스크립트 결과물이다 |
| 공유 파일 | `src/lib/poll/`(도메인 타입, 오류 코드)은 LP-06-004만 쓴다. 다른 작업은 필요하면 004 담당에게 요청한다 |
| 코어 | `_platform-core`, `packages/core-*`는 수정하지 않는다. 필요한 것은 6절 요청 |
| 스타일 토큰 | `src/styles/tokens.css`는 LP-06-023만 쓴다 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| LP-06-001 | 앱 골격과 스택 ADR: basic-master-module 복제, Next 16.2.9, Tailwind v4, shadcn, `packages/core-db` 연결, ADR(Supabase Realtime 확정, Socket.io/FastAPI/Redis 폐기) | `apps/live-poll/package.json`, `next.config.ts`, `tsconfig.json`, `components.json`, `src/app/layout.tsx`, `docs/adr/` | 없음 | P0 | S | Sonnet | `pnpm build`, `tsc --noEmit`, `lint` 통과. ADR 1개에 02장 6절 리뷰 #2 결정이 적혀 있다 | 리뷰 5장 #1, #2, 02장 1절 |
| LP-06-002 | DB 적용: 조각 1800 복사, 모놀리스 변환 스크립트(`@@modular-only` 제거 + 접두사 치환), `config.toml`에 `poll` 노출, 타입 생성 | `supabase/migrations/`, `supabase/scripts/`, `src/types/supabase.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공. 변환 결과가 저장소의 `0002_poll_domain.sql`과 바이트 단위 같다. 체커 mod/mono OK | 리뷰 5장 #3, #4, 05장 |
| LP-06-003 | 진행자 인증: `proxy.ts`(세션 갱신, 보호 경로), 로그인/가입(`signup_app='poll'`, 베타 약관), `requireSession('poll')`, 다른 제품 사용자 `bootstrap_app_for_org` | `src/proxy.ts`, `src/app/(auth)/` | LP-06-001 | P0 | S | Opus | 가입 직후 `/events`에서 entitled=true. 프로필 없는 세션은 로그아웃. 기본 역할 admin 코드 없음 | LP-F-001, `SECURITY_BASELINE.md` 11장 |
| LP-06-004 | 도메인 라이브러리: zod 스키마, 타입, PL 오류 → HTTP/문구 매핑, 참가자 토큰 생성(32바이트), 쿠키 유틸, IP HMAC(`POLL_IP_HMAC_SECRET` + 날짜) | `src/lib/poll/` | LP-06-001 | P0 | S | Opus | 단위 테스트: HMAC이 날짜마다 달라지고 원문 IP가 로그에 없다. 오류 코드 15개 전부 매핑 | 리뷰 5장 #10, 04장 1, 7절 |
| LP-06-005 | 청중 Route Handler: join, snapshot, vote, question, upvote(service_role RPC, 본문 4KB 상한, no-store, noindex) | `src/app/api/p/join/`, `.../snapshot/`, `.../vote/`, `.../question/`, `.../upvote/` | LP-06-002, LP-06-004 | P0 | M | Opus | 04장 2절 표의 입력/출력/오류 그대로. 쿠키 없는 vote는 401 PL009 | 리뷰 5장 #7, LP-F-007~014 |
| LP-06-006 | 청중 API 통합 테스트(로컬 Supabase): 입장/재입장/정원/잠금/비밀번호/중복 투표/다른 행사 문항/레이트 리밋 | `tests/api/participant/` | LP-06-005 | P0 | M | Opus | 01장 LP-F-007, 008, 013, 017, 018, 019 수용 기준을 각각 테스트 1개 이상으로 검증 | 01장 3절 |
| LP-06-007 | 진행자 행사 목록/생성/편집 화면(문항 카드, 선택지, 결과 공개 규칙, 행사 설정) | `src/app/(host)/events/page.tsx`, `src/app/(host)/events/new/`, `src/app/(host)/events/[id]/edit/` | LP-06-003, LP-06-015, LP-06-023 | P0 | M | Sonnet | 열린 문항은 편집 컨트롤이 비활성. 선택지 11개째 추가 버튼이 막힌다 | 리뷰 5장 #6, 03장 3.5 |
| LP-06-008 | 진행자 콘솔: 문항 진행(열기/닫기/다음, 단축키), 실시간 집계(`host_poll_results`), 입장 잠금, 비밀번호, 참가자 목록/차단, 행사 종료 | `src/app/(host)/events/[id]/live/page.tsx`, `src/app/(host)/events/[id]/live/_console/` | LP-06-007, LP-06-013 | P0 | L | Opus | 문항을 열면 1초 안에 청중 화면 전환(E2E). Space/화살표 단축키 동작 | 리뷰 5장 #6, LP-F-003, 005, 011 |
| LP-06-009 | 청중 화면: `/join`, `/e/[code]`(입장 시트, 고지, 대기, 투표, 제출, 결과, Q&A 탭), 오류 문구 | `src/app/(participant)/` | LP-06-005, LP-06-013, LP-06-015 | P0 | L | Opus | 375px에서 가로 스크롤 없음. PL005 수신 시 제출 완료 상태로 전환. 종료 행사는 제목만 | 리뷰 5장 #7, LP-F-007, 022 |
| LP-06-010 | 브로드캐스터 워커: 250ms 루프 `collect_broadcasts`, Realtime Broadcast HTTP 배치 전송(private), advisory lock 리더 선출, 진행자 토픽 pending 수, 정리 스케줄, 단위 테스트 | `services/poll-broadcaster/src/`, `services/poll-broadcaster/test/` | LP-06-002 | P0 | M | Opus | 투표 후 300ms 안에 state 메시지 발행(로컬). 워커 2대 동시 기동 시 중복 전송 0. 변경 없는 live 행사는 5초마다 hb | 리뷰 5장 #4, 02장 4, 5-1절 |
| LP-06-011 | Realtime 권한: 청중/오버레이 JWT 발급 라우트, `realtime.messages` 정책 실제 Supabase 검증, 미확인 사항(사용자 정의 JWT 수용) 확인과 대안(Ed25519 서명) 결정 | `src/app/api/p/realtime-token/`, `src/app/api/overlay/realtime-token/`, `src/lib/realtime-auth/` | LP-06-002 | P0 | M | Fable | 청중 JWT로 다른 행사 토픽 구독이 거부된다. 청중 JWT로 broadcast 송신이 거부된다. 결론을 ADR로 남긴다 | 02장 5-1절, 조각 17절 |
| LP-06-012 | 남용 방지 점검: 코드 대입(실패 31회째 PL429), 금칙어 우회(공백/구두점), 닉네임/질문 XSS 렌더 확인, 질문 레이트 리밋 | `tests/abuse/` | LP-06-005 | P1 | S | Opus | 4개 시나리오 자동 테스트 통과. React에서 `dangerouslySetInnerHTML` 사용 0건 | 리뷰 5장 #10, 리뷰 3장 #10 |
| LP-06-013 | `useEventChannel` 훅: 구독, 연결 상태 4종, 지수 백오프(1/2/4/8/15초, 지터), SUBSCRIBED 후 스냅샷, seq 공백 감지, 15초 무수신 재구독, rAF 묶음, 언마운트 정리 | `src/lib/realtime/` | LP-06-004 | P0 | M | Opus | 한 화면에서 훅을 두 번 써도 채널 1개(참조 카운트). `as any` 0건 | 리뷰 5장 #5, 리뷰:74 Hospital 교훈 |
| LP-06-014 | 훅 테스트: 가짜 Realtime 클라이언트로 끊김/재연결/seq 공백/중복 seq/hb 시나리오 | `tests/realtime/` | LP-06-013 | P0 | M | Opus | 10초 단절 후 3초 안에 스냅샷 반영. 오래된 seq 무시 | LP-F-010 |
| LP-06-015 | 공용 UI 컴포넌트: 결과 막대(CSS transition, 재정렬, reduced-motion), 연결 배지, QR, 6자리 코드 입력, 참가자 수 카운터 | `src/components/` | LP-06-023 | P0 | M | Sonnet | 컴포넌트는 props만 받는다(훅 import 0). 스토리/스냅샷 테스트 | 리뷰 5장 #8, #9 |
| LP-06-016 | 발표 화면: 전체화면, 대기 시 큰 코드+QR, 결과 막대 48px 숫자, 단축키 | `src/app/present/` | LP-06-013, LP-06-015 | P0 | S | Sonnet | 1920x1080 스크린샷에서 숫자 48px 이상. noindex | 리뷰 5장 #8, LP-F-011 |
| LP-06-017 | 오버레이 화면: `bg`, `theme`, `scale`, `position` 파라미터, 크롬 없음, 투명 배경 | `src/app/overlay/` | LP-06-015, LP-06-018 | P0 | S | Sonnet | `bg=transparent`에서 body 배경이 투명. 키 오류 시 빈 화면 | 리뷰 5장 #8, LP-F-012 |
| LP-06-018 | 오버레이/진행자 키 API: 오버레이 스냅샷, 오버레이 키 재발급 라우트 | `src/app/api/overlay/snapshot/`, `src/app/api/host/events/[id]/overlay-key/` | LP-06-002, LP-06-004 | P0 | S | Opus | 재발급 후 이전 키 스냅샷이 PL009 | LP-F-012 |
| LP-06-019 | Q&A 모더레이션 패널: 대기 큐, 승인/거절/답변 완료/숨김, 진행자 토픽 수신 시 목록 재조회 | `src/app/(host)/events/[id]/live/_qna/` | LP-06-008 | P1 | M | Sonnet | 승인 후 다음 브로드캐스트에 질문 표시. 차단 참가자 질문이 사라진다 | LP-F-013~015 |
| LP-06-020 | 결과 보존 화면 + CSV 내보내기(UTF-8 BOM, 참가자 식별자 없음, 감사 기록) | `src/app/(host)/events/[id]/results/`, `src/app/api/host/events/[id]/export.csv/` | LP-06-008 | P1 | M | Sonnet | 보존 기간 경과 행사도 집계가 같다. CSV를 엑셀에서 열면 한글이 깨지지 않는다 | 리뷰 5장 #13, LP-F-020 |
| LP-06-021 | 설정 화면: 조직 금칙어 추가/삭제(owner/admin) | `src/app/(host)/settings/` | LP-06-003 | P1 | S | Haiku | member 계정에는 편집 버튼이 없고, API도 0행 | LP-F-016 |
| LP-06-022 | 랜딩, 가격, robots/sitemap(랜딩만 색인), 행사 페이지 noindex 메타 | `src/app/(marketing)/`, `src/app/robots.ts`, `src/app/sitemap.ts` | LP-06-015, LP-06-023 | P1 | M | Sonnet | 03장 4절 안 A 구현. 01장 6절 금지 문구 0건. `/e/*` 응답 헤더 noindex | 리뷰 5장 #12, 분석:1261 |
| LP-06-023 | 디자인 시스템: UUPM 초안 → 03장 4.3 토큰으로 MASTER.md, 페이지 오버라이드(dashboard, overlay, landing), `tokens.css` | `design-system/live-poll/`, `src/styles/tokens.css` | 없음 | P0 | S | Sonnet | MASTER.md에 UUPM 대비 변경점 표. 하드코딩 hex 0건(린트 규칙) | `DESIGN_PRINCIPLES.md` 3~5단계 |
| LP-06-024 | 문구 사전: 청중/진행자 오류 문구, 고지 문구, 빈 상태(03장 5절) | `src/messages/ko.json` | LP-06-004 | P1 | S | Haiku | 오류 코드 15개 전부 문구 있음. 사과 표현 0건 | `DESIGN_PRINCIPLES.md` 카피 규칙 |
| LP-06-025 | E2E(Playwright): 가입 → 행사 생성 → 시작 → 청중 2명(다른 브라우저 컨텍스트) 입장 → 투표 → 발표 화면 반영 → Q&A → 종료 | `tests/e2e/` | LP-06-008, LP-06-009, LP-06-010, LP-06-016, LP-06-017 | P0 | M | Opus | 전 흐름 통과. 청중 화면에서 결과 반영 1초 이내 단언 | 03장 2절 |
| LP-06-026 | RLS/권한 회귀 테스트: 기획 단계 스모크(79항목, 05장 9절)를 저장소로 이식, 모듈러/모놀리스 둘 다, CI 연결 | `supabase/tests/` | LP-06-002 | P0 | M | Fable | B가 A 행사 데이터 0행, 역할/플랜/크레딧 변경 42501, anon 전부 42501, 종료 행사 스냅샷 poll/qna null. CI 실패 시 머지 차단 | `SECURITY_BASELINE.md` 15장 |
| LP-06-027 | 부하 테스트: 3,000 구독 + 300 votes/s(k6 + Realtime 클라이언트 시뮬레이터), p95 측정, Realtime 플랜 한도 확인, 인원별 간격과 Redis 필요 여부 결론 | `tests/load/` | LP-06-010, LP-06-005 | P1 | L | Fable | 01장 5절 표의 인원별 p95를 측정해 보고서로 남긴다. 미달이면 원인과 1810 마이그레이션 제안 | 리뷰 5장 #11, 리뷰 3장 #1 |
| LP-06-028 | 결제 E2E(Toss 테스트 키): Pro 구독 결제 → 엔타이틀먼트 pro → `max_participants` 1,000 반영, 금액 위조 PM001 시 Toss 취소 호출 | `tests/e2e-billing/` | LP-06-029 | P2 | M | Opus | 테스트 키로 전 흐름 통과. PM001에서 `fail_payment_order` 호출 후 취소 API 호출 | 확정 결정 4, `CORE_SPEC.md` 5장 |
| LP-06-029 | Phase 2 결제 라우트: checkout, confirm, Toss 웹훅(서명 필수), seed 플랜 활성화 요청 | `src/app/api/billing/`, `src/app/api/webhooks/toss/` | LP-06-003 | P2 | M | Fable | 클라이언트 금액 무시, 주문 선저장, 웹훅 서명 실패 401 | `SHARED_MODULES.md` 5, 6장 |
| LP-06-030 | 접근성/반응형 체크(375/768/1024/1440, 포커스, reduced-motion, 대비, aria-live 요약) | `tests/a11y/` | LP-06-009, LP-06-016, LP-06-022 | P1 | S | Haiku | `DESIGN_PRINCIPLES.md` 7단계 12항목 통과 기록 | 03장 6절 |
| LP-06-031 | 배포 설정: Vercel(icn1), Railway 워커 2대, env 기동 검증(누락 시 실패), 스케줄 | `src/env.ts`, `vercel.json`, `services/poll-broadcaster/deploy/` | LP-06-010 | P1 | S | Sonnet | 필수 env 하나라도 없으면 기동 실패. 워커 헬스체크 엔드포인트 | 02장 7, 8절 |
| LP-06-032 | 진행자 가이드와 FAQ(소프트 1인 1표 설명, OBS 연결 방법, 개인정보 고지) | `docs/guide/` | LP-06-017 | P2 | S | Haiku | 01장 6절 고지와 문구가 일치. 금지 문구 0건 | 리뷰 5장 #12 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | LP-06-001, 002, 023 | 3 | 없음 | 앱 골격, DB 적용과 타입, 디자인 토큰 |
| W1 | LP-06-003, 004, 010, 011, 026 | 5 | W0 완료 | 진행자 인증, 도메인 라이브러리, 브로드캐스터, Realtime 권한, RLS 회귀 |
| W2 | LP-06-005, 013, 015, 018, 021, 024 | 6 | W1 완료 | 청중 API, 실시간 훅, 공용 컴포넌트, 오버레이 API, 설정, 문구 |
| W3 | LP-06-006, 007, 012, 014, 016, 017, 022 | 7 | W2 완료 | API 테스트, 편집 화면, 남용 테스트, 훅 테스트, 발표/오버레이, 랜딩 |
| W4 | LP-06-008, 009, 027, 031 | 4 | W3 완료 | 콘솔, 청중 화면, 부하 테스트, 배포 |
| W5 | LP-06-019, 020, 025, 030, 032 | 5 | W4 완료 | Q&A 패널, 결과/CSV, E2E, 접근성, 가이드 → 베타 공개 |
| W6(Phase 2) | LP-06-029, 028 | 2(순차) | 베타 8주 후 가격 결정(01장 D4) | 유료 플랜 |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 5 (002, 011, 026, 027, 029) | 15.6% | 11/54 = 20.4% |
| Opus | 13 (003, 004, 005, 006, 008, 009, 010, 012, 013, 014, 018, 025, 028) | 40.6% | 24/54 = 44.4% |
| Sonnet | 10 (001, 007, 015, 016, 017, 019, 020, 022, 023, 031) | 31.3% | 15/54 = 27.8% |
| Haiku | 4 (021, 024, 030, 032) | 12.5% | 4/54 = 7.4% |
| 합계 | 32 | 100% | 54 |

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

## 6. 공용 모듈 요청

| 요청 | 대상 | 이유 | 우선순위 |
|---|---|---|---|
| `handle_new_user`가 `auth.users.is_anonymous = true`인 사용자에 대해 프로필/조직을 만들지 않게 | `_platform-core` 0001, `MONOLITH_CORE_LITE.sql` SECTION 1 | 익명 로그인을 쓰는 제품이 생기면 조직이 폭증한다. 해결 전까지 live-poll은 참가자 토큰을 쓴다(05장 7절) | P2 |
| `core.rate_limit_peek(key, limit, window)`(히트 없이 조회) | 0004 | `join_event`가 사전 차단을 위해 `core.rate_limit_buckets`를 직접 읽는다(읽기만). 함수로 감싸면 코어 내부 구조와의 결합이 사라진다 | P2 |
| 모듈러 seed의 `poll` free 플랜 features 보강과 pro/business 행 추가 | `_supabase-modular/seed.sql` | 01장 4절 키(현재는 조각의 기본값으로 동작). 금액은 D4 결정 뒤. 해결(2026-10-13 코어 반영 완료): 모듈러 seed가 모놀리스 seed와 일치 | P1 |
| `confirm_payment_order` 금액 불일치 시 failed 상태 보존 | 0003 | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가. live-poll은 PM001 시 별도 호출(05장 8절) | 완료 |

## 7. 완료 정의

| 항목 | 기준 |
|---|---|
| 빌드 | `pnpm build`(앱), 워커 `pnpm build` 성공 |
| 타입/린트 | `tsc --noEmit`, `eslint` 0 오류, `as any` 0건 |
| SQL | `docs/products/_tools-sqlcheck` mod/mono OK |
| RLS | LP-06-026 전 항목 통과(모듈러, 모놀리스) |
| E2E | LP-06-025 통과. Phase 2는 LP-06-028(결제 E2E) 통과 |
| 성능 | LP-06-027 보고서에서 300명 이하 p95 500ms 이내 |
| 06장 | 32개 작업 완료(Phase 2 작업은 Phase 2 완료 정의) |
| 명령 | `pnpm test`, `pnpm test:e2e`, `pnpm test:rls`, `node check.mjs mod ...`, `node check.mjs mono ...` |
