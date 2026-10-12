# 02 아키텍처: Live Poll

근거 약어는 01장과 같다. 조각 = `docs/products/_supabase-modular/migrations/1800_poll.sql`.

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 | Next.js App Router(Route Handler, RSC), Tailwind CSS v4, shadcn/ui | Next 16.2.9 | 리뷰:12 워크스페이스 표준, 원본 PRD:32 |
| 차트 | Recharts 3(진행자 콘솔), 발표 화면/오버레이/청중 결과 막대는 CSS width transition 직접 구현 | recharts 3.x | 원본 CLAUDE:9, 리뷰:76. 막대 몇 개에 차트 라이브러리를 싣지 않아 청중 번들을 줄인다(제안) |
| 인증 | Supabase Auth(진행자만). 청중은 서버 발급 참가자 토큰 | `@supabase/ssr` | `SHARED_MODULES.md` 2장, 05장 7절 |
| DB | Supabase Postgres 15, 모듈러 `poll` 스키마 | PG 15 | README 5장 |
| 실시간 | Supabase Realtime Broadcast, private 채널 | supabase-js 2.x | 분석:1259(Supabase Realtime 확정), 리뷰:40 |
| 브로드캐스터 | Node 워커 1개(`services/poll-broadcaster`), Railway | Node 22 LTS | 이 문서 4장 |
| 레이트 리밋 | `core.rate_limit_hit`(Postgres 고정 윈도우) | 코어 0004 | `SECURITY_BASELINE.md` 8장. Redis 없음(분석:1260) |
| 배포 | Vercel(웹, 서울 리전 icn1), Supabase(ap-northeast-2), Railway(워커) | - | 리뷰:61 |
| 테스트 | Vitest, Playwright(webapp-testing), k6 + Realtime 클라이언트 시뮬레이터 | - | 리뷰:94 |

쓰지 않는 것: Socket.io, FastAPI WebSocket, 상주 WebSocket 서버, Redis(분석:1259-1260), `postgres_changes` 구독(구독자마다 권한 검사가 일어나 대규모에 맞지 않는다, 리뷰:65).

## 2. 모듈 경계

| 모듈 | 디렉토리 | 책임 |
|---|---|---|
| 마케팅 | `apps/live-poll/src/app/(marketing)/` | 랜딩, 가격, 베타 가입 진입. 색인 허용 |
| 진행자 인증 | `apps/live-poll/src/app/(auth)/` | 로그인, 가입(`signup_app='poll'`), 베타 약관 동의 |
| 진행자 콘솔 | `apps/live-poll/src/app/(host)/` | 행사 목록, 행사 편집(문항/선택지), 진행 콘솔, Q&A 모더레이션, 결과/CSV, 설정(금칙어) |
| 발표 화면 | `apps/live-poll/src/app/present/[eventId]/` | 전체화면 결과, 코드/QR. 진행자 세션 필요 |
| 오버레이 | `apps/live-poll/src/app/overlay/[eventId]/` | OBS 브라우저 소스. 오버레이 키 |
| 청중 | `apps/live-poll/src/app/(participant)/join/`, `.../e/[code]/` | 입장, 대기, 투표, 결과, Q&A |
| 청중 API | `apps/live-poll/src/app/api/p/` | 입장, 투표, 질문, 추천, 스냅샷, 실시간 토큰. service_role RPC 호출 |
| 진행자 API | `apps/live-poll/src/app/api/host/` | CSV, 오버레이 키, 진행자 실시간 토큰 확인. 나머지 진행자 쓰기는 브라우저에서 RLS/RPC 직접 |
| 오버레이 API | `apps/live-poll/src/app/api/overlay/` | 오버레이 스냅샷, 오버레이 실시간 토큰 |
| 실시간 클라이언트 | `apps/live-poll/src/lib/realtime/` | `useEventChannel` 훅(구독, 상태, 재연결, seq, rAF 묶음) |
| 도메인 | `apps/live-poll/src/lib/poll/` | zod 스키마, 타입, 오류 코드 매핑, 참가자 토큰/IP HMAC 유틸 |
| UI 컴포넌트 | `apps/live-poll/src/components/` | 결과 막대, 문항 카드, 연결 배지, QR, 코드 입력 |
| 브로드캐스터 | `services/poll-broadcaster/` | `collect_broadcasts` 루프, Realtime 전송, 정리 스케줄 |
| DB | `apps/live-poll/supabase/` | 조각 사본, 변환 스크립트, RLS 스모크 테스트 |

UI 컴포넌트는 props만 받고, 실시간 로직은 훅에만 둔다(원본 CLAUDE:12).

## 3. 공용 모듈 사용

| 공용 모듈(`SHARED_MODULES.md`) | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth (2장) | 진행자 세션, `requireSession('poll')` | `(host)` 레이아웃, `api/host/*` | 청중에는 쓰지 않는다 |
| org (3장) | 개인 조직, Phase 2 공동 진행자 초대 | 설정 화면 | 1인 1워크스페이스 |
| toss (5장) | Phase 2 Pro/Business 구독 | `api/billing/*`(Phase 2) | 베타에는 비활성 |
| webhooks (6장) | Phase 2 Toss 웹훅 | `api/webhooks/toss` | 결제 보조 경로 |
| audit (15장) | 행사 생성/전이, 문항 열기/닫기, 모더레이션, 차단, 키 재발급, 삭제, CSV 내보내기 | 조각 RPC 내부 `core.write_audit`, CSV는 Route Handler service INSERT | |
| rate limit (`CORE_SPEC.md` 12장) | 01장 5절 수치 | 조각 RPC 내부 `core.rate_limit_hit` | 키 규약 `poll:<route>:<id>` |
| storage (14장) | 사용 안 함(MVP) | - | Phase 2 행사 로고 |
| credits, llm, fal, weasyprint, sns, automation, compliance, jobs, affiliate, oauth | 사용 안 함 | - | 금칙어는 compliance 모듈이 아니라 제품 테이블(`poll.banned_words`)로 DB 함수 안에서 검사한다. 청중 RPC 트랜잭션 안에서 판정해야 하기 때문 |

## 4. 잡과 워커

`core.jobs`를 쓰지 않는다. 비동기 작업은 상시 루프 하나와 스케줄 두 개다.

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| 해당 없음(core.jobs 미사용) | - | - | 없음 | - | - |

| 워커 작업 | 주기 | 호출 | 실패 처리 |
|---|---|---|---|
| 브로드캐스트 루프 | 250ms 틱(행사별 간격은 아래) | `poll.collect_broadcasts(200, 5)` → 행마다 Realtime Broadcast HTTP API 전송(private, event `state` 또는 `hb`) | 전송 실패는 3회 재시도 후 다음 틱. DB 오류는 지수 백오프(최대 5초)와 운영 알림. 워커가 죽어도 투표는 기록되고 클라이언트가 15초 무수신 후 스냅샷으로 복구 |
| 정리 | 매시간 | `poll.purge_expired_events()` | 실패 시 다음 시간 재실행(멱등) |
| 레이트 리밋 정리 | 매일 04:00 KST | `core.purge_rate_limit_buckets()` | 코어 스케줄과 같다 |

행사별 전송 간격: MVP(베타, 참가자 100명 한도)는 모든 행사 250ms 고정이다. 인원별 간격(300명 이하 250ms, 1,000명 이하 500ms, 그 이상 1,000ms, 제안)은 Phase 2에서 DB 쪽에 넣는다. 워커가 메모리에서 건너뛰면 `collect_broadcasts`가 이미 `broadcast_*` 값을 갱신해 변경이 유실되므로, 간격 판정은 반드시 `collect_broadcasts` 안에서 `broadcast_at`과 참가자 수로 해야 한다(LP-06-027 결과로 수치 확정 후 조각 1810 마이그레이션).

리더 선출: 워커 2대(기본 + 대기)를 띄우고 `pg_try_advisory_lock(hashtext('poll-broadcaster'))`를 잡은 쪽만 루프를 돈다. `collect_broadcasts`가 `for update skip locked`를 쓰므로 두 대가 동시에 돌아도 같은 행사를 두 번 보내지 않는다(조각:1328).

## 5. AI 라우팅

해당 없음. 이 제품은 LLM, 이미지, 음성 호출이 없다. 질문 요약/분류(Phase 3 후보)를 넣으면 `SHARED_MODULES.md` 8장 게이트웨이와 크레딧을 그때 정한다.

### 5-1. 실시간 구조 (기획 공백을 채운 설계)

```
청중 휴대폰 --POST /api/p/vote--> Vercel Route Handler --service_role rpc cast_vote--> Postgres(votes INSERT)
                                                                                        |
브로드캐스터 워커 --250ms rpc collect_broadcasts--> Postgres (변경 감지: max(votes.id), qna change_seq, 참가자 수, state_version)
       |
       +--Realtime Broadcast HTTP API (private 토픽 poll:<org>:<event>)--> 청중 / 발표 화면 / 오버레이 / 진행자 콘솔
```

| 결정 | 내용 | 이유 |
|---|---|---|
| 쓰기 경로 | 투표 1건 = `votes` INSERT 1행. 집계 카운터 행을 갱신하지 않는다 | 300건/초가 같은 카운터 행을 잠그는 핫 로우 경합을 없앤다. unique 위반으로 중복을 거절한다(조각:195) |
| 변경 감지 | 행사의 현재 문항 `max(votes.id)`, Q&A `max(change_seq)`, 참가자 수, `state_version`을 직전 전송 값과 비교 | 투표 경로가 events 행을 건드리지 않는다 |
| 집계 | 변경이 있을 때만 `build_public_state`가 `unnest(option_ids)` 집계(3,000행 인덱스 스캔) | 행사당 초당 최대 4회 |
| 순서 | 행사별 `broadcast_seq` 단조 증가. 상태와 hb 모두 seq를 올린다 | 클라이언트가 공백을 감지해 스냅샷 1회 조회 |
| 상태 변경 | 진행자 RPC가 `state_version`을 올리고, 다음 틱(250ms 이내)에 전송 | 전송 경로가 하나라 순서가 꼬이지 않는다 |
| 종료 | ended 전이 뒤 마지막 상태 1회 전송 후 hb 중단 | 리뷰:65 "종료 시 최종 스냅샷 1회" |
| 채널 권한 | private 채널. 진행자는 조직 멤버 정책, 청중/오버레이는 서버가 발급한 단기 JWT(role anon, `poll_topic`, `poll_aud`, 만료 6시간)의 토픽과 같을 때만 수신. 송신 정책 없음(service_role만) | 공개 채널은 토픽을 아는 누구나 가짜 결과를 보낼 수 있다(조각:1462-1488) |
| JWT 발급 | `/api/p/realtime-token`, `/api/overlay/realtime-token`이 Supabase JWT 비밀키로 HS256 서명 | 미확인: Supabase 새 JWT 서명 키(비대칭) 체계에서 사용자 정의 JWT를 Realtime이 받는 방식. 안 되면 대안: 공개 채널 + 워커가 Ed25519로 페이로드 서명, 클라이언트가 공개키로 검증(LP-06-011 착수 전 확인) |
| 클라이언트 | `useEventChannel`: 구독 → SUBSCRIBED 시 스냅샷 1회 → seq 증가분만 적용 → CHANNEL_ERROR/TIMED_OUT/CLOSED 시 백오프 재구독 → rAF 묶음 렌더 | 원본 CLAUDE:8, :21의 폴링 금지와 재연결 요구를 함께 만족. 1회성 조회는 폴링이 아니다(리뷰:47) |

## 6. 리뷰 "높음" 결함의 차단 설계

리뷰 3장 높음 4건 중 기술/구조 결함 2건은 여기, 보안/데이터 결함 2건(#3, #4)은 05장 7절에 있다. 합계 4건 = 차단 설계 4건.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/Slido_Project.md` 3장 #1 | `docs/reviews/Slido_Project.md:39`, `:53` | "수천 명 + 0.5초"에 부하 조건과 측정 지점이 없고, 투표마다 전원 브로드캐스트하면 메시지가 투표수 x 구독자수로 폭증한다 | (1) 측정 지점과 인원별 p95, 처리량을 01장 5절에 수치로 정의. (2) 투표는 INSERT만 하고 브로드캐스트는 워커가 행사별 250ms 묶음으로만 보낸다(5-1절, 조각:1328). 행사당 메시지는 초당 최대 4건이라 투표 수와 무관하다. (3) 클라이언트 rAF 렌더 묶음. (4) 3,000 구독 + 300건/초 부하 테스트로 Realtime 한도와 간격을 확정 | LP-06-010, LP-06-011, LP-06-027 |
| `docs/reviews/Slido_Project.md` 3장 #2 | `docs/reviews/Slido_Project.md:40`, `:54` | 실시간 스택 3안(Socket.io/FastAPI/Supabase)이 미확정이고 Vercel 전제와 상주 WebSocket 서버가 충돌한다 | Supabase Realtime Broadcast로 확정(분석:1259). 웹은 Vercel 서버리스 Route Handler만, 상주 연결은 Supabase가 맡는다. 상주 프로세스는 송신 전용 브로드캐스터 워커 1개(Railway)뿐이며 WebSocket 서버가 아니다. Socket.io/FastAPI는 07장 3절에 폐기로 기록 | 1장 표, LP-06-001, LP-06-010 |

## 7. 배포 토폴로지

| 구성 | 위치 | 네트워크 경계 |
|---|---|---|
| 웹(Next.js) | Vercel icn1 | 공개. `/api/p/*`는 쿠키(참가자 토큰)와 IP HMAC으로 service_role RPC 호출. service_role 키는 서버 번들에만 |
| DB, Auth, Realtime | Supabase ap-northeast-2(모듈러 통합 프로젝트) | 진행자 브라우저는 anon 키 + 세션으로 RLS 경로. 청중 브라우저는 Realtime 수신만(DB 권한 없음) |
| 브로드캐스터 | Railway 서울 인근 리전(미확인: Railway 리전 목록), 2대(리더 1) | 아웃바운드만: Supabase DB(pooler, service_role)와 Realtime HTTP API |
| 스케줄 | 브로드캐스터 프로세스 내부 크론 | `CRON_SECRET` 공개 라우트 방식 금지(`SECURITY_BASELINE.md` 13장) |

트래픽이 늘어 Realtime 부하가 다른 제품에 영향을 주면 모놀리스(`supabase/monolith/`)로 분리한다(README 5장).

## 8. 환경변수

| 변수 | 용도 | 공개 여부 | 누락 시 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase URL | 공개 | 기동 실패 |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 진행자 RLS 경로, 청중 Realtime 연결 | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 청중/오버레이 RPC, 워커 | 서버 전용 | 기동 실패 |
| `SUPABASE_JWT_SECRET` | 청중/오버레이 Realtime JWT 서명 | 서버 전용 | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | `core`(모듈러) / `public`(모놀리스) | 서버 | 기본 `core` |
| `POLL_DB_SCHEMA` | `poll`(모듈러) / `public`(모놀리스) | 서버 | 기본 `poll` |
| `POLL_IP_HMAC_SECRET` | IP HMAC 비밀(32바이트 이상) | 서버 전용 | 기동 실패 |
| `POLL_PARTICIPANT_COOKIE_DAYS` | 참가자 쿠키 유효기간(7) | 서버 | 기본 7 |
| `POLL_BROADCAST_TICK_MS` | 워커 틱(250) | 워커 | 기본 250 |
| `POLL_HEARTBEAT_SECONDS` | hb 간격(5) | 워커 | 기본 5 |
| `DATABASE_URL` | 워커 DB 연결(pooler) | 워커 전용 | 기동 실패 |
| `TOSS_CLIENT_KEY` / `TOSS_SECRET_KEY` | Phase 2 결제 | 클라이언트 키만 공개 | Phase 2부터 필수 |
