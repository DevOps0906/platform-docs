# Slido_Project 기획 리뷰

대상: `구현해야 할 프로젝트/Slido_Project/` (CLAUDE.md 22줄, PRD.md 35줄, 그 외 파일 없음, 코드 없음)

## 1. 프로젝트 개요

- 한 줄 설명: 호스트가 투표방을 만들고 로그인 없는 참가자 수천 명이 QR/링크로 들어와 투표하면, 결과가 0.5초 이내에 실시간 차트로 스트리밍되는 웹 기반 실시간 투표 서비스(Slido의 Poll 기능에 해당).
- 기획 의도: 방송, 대규모 이벤트에서 순간 트래픽 급증을 견디는 초저지연 투표. OBS 송출용 결과 화면(전체화면/투명 배경) 제공 (PRD.md 2절, 4.1절).
- 대상 사용자: 호스트(행사 진행자, 방송인, 강연자) / 참가자(행사 청중, 방송 시청자, 모바일 웹뷰 사용자).

| 구분 | 제안된 기술 (PRD.md 5절, CLAUDE.md 1~2절) | 리뷰 의견 |
| --- | --- | --- |
| 프론트 | Next.js App Router, Tailwind CSS, Shadcn UI, Recharts | 워크스페이스 표준(Next 16.2.9 + Tailwind v4 + shadcn)과 일치 |
| 실시간 | Socket.io / FastAPI WebSocket / Supabase Realtime 중 택1 (미확정) | Supabase Realtime Broadcast로 확정 권장 |
| DB | PostgreSQL + Redis(카운팅/캐싱) | MVP는 Supabase Postgres 단독, Redis는 부하 테스트 후 결정 |
| 인프라 | Vercel/AWS 일반 클라우드 (CLAUDE.md 4절) | Vercel은 상주 WebSocket 서버 불가 -> Socket.io 선택지와 충돌 |
| AI | 없음 | - |

- 기획 완성도: 약 35%
  - 근거: 핵심 사용자 플로우(호스트/참가자)와 기능 범주(방 관리, 상태 제어, OBS 모드, 1인 1표, 실시간 브로드캐스트)는 정의되어 있다. 그러나 데이터 모델, 질문 유형(단일/복수 선택, 주관식 여부), 호스트 인증 방식, 동시 접속 목표치, 방 코드 규칙, 종료 후 결과 보존, 오류/재연결 시 UX, 기술 스택 확정이 모두 비어 있다. 화면 목록과 수용 기준(Acceptance Criteria)도 없다.

## 2. 기획 문서 분석

| 파일 | 역할 | 분량/특징 |
| --- | --- | --- |
| `PRD.md` | 제품 요구사항. 개요, 목표(지연 0.5초, 모바일, 확장성), 유저 플로우 2개, 기능 요구사항 3그룹(호스트/참가자/실시간 엔진), 기술 스택 후보 | 35줄. 요구사항이 기능 나열 수준이며 ID, 우선순위, 수용 기준 없음 |
| `CLAUDE.md` | AI 개발 지침. 역할 정의, GEO 최적화, 폴링 금지, 경량 렌더링, 훅/UI 분리, 중복 투표 검증 필수, 로컬 하드웨어 의존 금지, 재연결 로직 명시 | 22줄. 구현 원칙은 명확하나 PRD와 일부 충돌 |

요구사항 구조 요약:
- 호스트(Admin): 방 생성/삭제/관리, 투표 상태 3단계(대기/시작/종료), 결과 화면 OBS 모드 (PRD.md:17-20).
- 참가자(Client): 닉네임 또는 익명 입장, 호스트 상태 변경 시 무새로고침 전환, IP+LocalStorage/Cookie 기반 1인 1표 (PRD.md:23-25).
- 실시간 엔진: WebSocket/SSE 브로드캐스트, Redis 또는 인메모리 큐로 집계 부하 분산 "고려" (PRD.md:28-29).
- 비기능: 0.5초 이내 반영, 트래픽 스파이크 대응, 모바일 최적화 (PRD.md:7-9), 시맨틱 마크업/GEO, 재연결 로직 (CLAUDE.md:7, 21).

## 3. 기획상의 문제점

| # | 심각도 | 분류 | 위치(파일명:섹션) | 내용 |
| --- | --- | --- | --- | --- |
| 1 | 높음 | 기술리스크 | PRD.md:2절(7, 9줄), 4.3절 | "수천 명 + 0.5초 이내 반영"을 목표로 하면서 동시 접속 수치, 초당 투표 수, 측정 지점(제출->다른 클라이언트 차트 반영)이 없다. 투표 1건마다 전원에게 브로드캐스트하면 메시지 수가 투표수 x 구독자수로 폭증한다. 집계 스냅샷을 일정 간격(예: 250~500ms)으로 묶어 보내는 설계가 필수인데 언급이 없다 |
| 2 | 높음 | 모순 | PRD.md:5절(33줄) vs CLAUDE.md:4절(17줄) | 실시간 백엔드 후보로 Socket.io/FastAPI를 제시하지만 CLAUDE.md는 Vercel 배포를 전제한다. Vercel 서버리스는 상주 WebSocket 서버를 띄울 수 없어 별도 서버(Fly.io, AWS)가 필요해진다. 스택 3안이 확정되지 않아 이후 설계 전체가 흔들린다 |
| 3 | 높음 | 보안 | PRD.md:4.2절(25줄), CLAUDE.md:3절(14줄) | IP 기반 1인 1표는 행사장 Wi-Fi, 통신사 CGNAT에서 수백 명이 같은 IP를 공유해 정상 사용자를 차단한다. 반대로 LocalStorage/Cookie는 시크릿 창으로 즉시 우회된다. "로그인 불필요"와 "엄격한 1인 1표"는 동시에 만족할 수 없으므로 허용 가능한 중복 수준(소프트 제한)을 기획에서 정해야 한다 |
| 4 | 높음 | 보안 | CLAUDE.md:3절(14줄) | "암호화된 IP 해시"를 저장하면 개인정보(개인정보보호법상 IP는 개인정보) 처리가 된다. 솔트 관리, 보관 기간, 파기 정책, 처리방침 고지가 없다. IPv4 공간은 작아 솔트 없는 해시는 역산 가능하다 |
| 5 | 중간 | 누락 | PRD.md:4.1절 | 호스트 인증 수단(이메일/소셜), 방 소유권, 공동 호스트, 방 하나에 질문 여러 개(슬라이드식 진행) 여부, 질문 유형(단일/복수/주관식/평점), 투표 중 선택지 수정 허용 여부가 없다 |
| 6 | 중간 | 누락 | PRD.md:3절, 4.2절 | 방 입장 키(6자리 코드 vs UUID 링크), 비공개 방 비밀번호, 종료 후 참가자 화면(결과 공개 여부를 호스트가 제어하는지), 늦게 들어온 참가자의 상태 복구 규칙이 정의되지 않았다 |
| 7 | 중간 | 모호성 | PRD.md:4.3절(29줄), 5절(34줄) | Redis를 "고려"로 두면서 5절에서는 스택에 포함했다. MVP 필수인지 확장 단계인지 불명확하다. Supabase만으로 수천 명 규모는 Postgres 원자적 증분 + Broadcast로 처리 가능하므로 Redis는 2단계로 미루는 것이 합리적이다 |
| 8 | 중간 | 모호성 | PRD.md:4.1절(20줄) | "크로마키(투명 배경)"는 두 가지가 섞여 있다. OBS 브라우저 소스는 투명 배경을 직접 지원하므로 그린 배경(크로마키)과 투명 배경 중 무엇을 제공할지, 레이아웃/테마/폰트 크기를 URL 파라미터로 조절할지 정해야 한다 |
| 9 | 중간 | 누락 | CLAUDE.md:2절(8줄), 5절(21줄) | 폴링을 금지하면서 재연결 로직은 요구한다. 재연결 직후 놓친 이벤트를 메우는 "스냅샷 재조회" 규칙(1회성 fetch는 폴링이 아님)과 연결 상태 표시 UX가 명시되어야 한다 |
| 10 | 중간 | 보안 | PRD.md 전체 | 봇/스크립트 대량 투표, 방 코드 무차별 대입, 닉네임 욕설/XSS, 방 생성 남용에 대한 레이트 리밋/모더레이션 요구사항이 없다. 방송 이벤트에서는 실제로 공격 대상이 된다 |
| 11 | 낮음 | 범위과다 | CLAUDE.md:2절(7줄) | GEO(AI 검색 최적화)는 참가자 투표방처럼 일시적이고 비공개인 페이지에는 의미가 없다. 오히려 방 페이지는 `noindex` 해야 한다. GEO는 랜딩 페이지에만 적용하도록 범위를 줄인다 |
| 12 | 낮음 | 누락 | PRD.md 전체 | 성공 지표(KPI), 결과 내보내기(CSV), 데이터 보존 기간, 다국어, 접근성 요구가 없다. 프로젝트명 "Slido"는 상용 서비스 상표이므로 제품명으로 쓰지 않는 것이 안전하다 |

심각도 높음 상세:
- #1 성능 목표 미정량: "0.5초"는 측정 가능한 수치이지만 부하 조건이 없으면 검증할 수 없다. 1,000명이 10초 안에 모두 투표하는 시나리오에서 투표마다 브로드캐스트하면 약 100만 메시지가 생긴다. Supabase Realtime은 플랜별 동시 접속/초당 메시지 상한이 있으므로(플랜 문서 확인 필요), "집계 스냅샷 throttle 브로드캐스트 + 클라이언트 렌더 throttle"을 요구사항으로 명시하고 목표 동시 접속(예: 3,000)을 숫자로 적어야 한다.
- #2 스택 미확정: Socket.io를 고르면 Vercel 외 상주 서버, 수평 확장 시 Redis adapter, 별도 배포 파이프라인이 필요해 MVP 규모가 2배 이상 커진다. 워크스페이스의 기존 자산(Supabase 기반 6개 프로젝트)을 쓰려면 Supabase Realtime으로 확정하는 것이 가장 효율적이다.
- #3 중복 투표 정책 모순: 하드 IP 차단은 이벤트 현장에서 서비스 장애와 같다. Supabase 익명 로그인(`signInAnonymously`)으로 기기별 안정 ID를 발급하고 `unique(poll_id, voter_id)` 제약으로 1차 방지, IP 해시는 차단이 아닌 레이트 리밋 신호로만 쓰는 것을 권장한다.
- #4 IP 해시 개인정보: 해시를 저장한다면 서버 비밀 솔트(HMAC), 방 종료 후 N일 파기, 처리방침 고지를 요구사항에 포함해야 한다. 저장하지 않고 레이트 리밋 메모리(또는 Upstash)에서만 쓰는 방식이 가장 안전하다.

## 4. 효율적 구현 전략

### 권장 아키텍처
- 단일 Next.js 16 앱(Vercel) + Supabase(Postgres, Auth, Realtime). 별도 WebSocket 서버 없음.
- 호스트: Supabase Auth 이메일/OAuth 로그인. 참가자: Supabase 익명 로그인으로 `voter_id` 확보(쿠키 세션 유지).
- 데이터 모델: `rooms(id, code, host_id, title, status, created_at)`, `polls(id, room_id, question, type, status[draft/open/closed], order, show_results)`, `poll_options(id, poll_id, label, order)`, `votes(poll_id, option_id, voter_id, created_at, unique(poll_id, voter_id))`, `poll_counts(option_id, count)`.
- 투표 쓰기: Postgres 함수 `cast_vote(poll_id, option_id)`(security definer) 하나로 상태 검증 -> `votes` insert(중복 시 unique 위반으로 거절) -> `poll_counts` 원자적 증분을 한 트랜잭션에 처리.
- 실시간 전파: `room:{code}` Broadcast 채널. (a) 상태 변경(투표 시작/종료/다음 질문)은 호스트 서버 액션이 즉시 broadcast, (b) 집계는 `polls.last_broadcast_at` 기준 최소 간격(약 300ms)으로 묶어 `realtime.send()`로 전송, 종료 시 최종 스냅샷을 반드시 1회 전송. `postgres_changes`는 구독자마다 권한 검사가 일어나 대규모에 부적합하므로 쓰지 않는다.
- 클라이언트: `useRoomChannel` 훅 하나가 구독, 연결 상태(SUBSCRIBED/CHANNEL_ERROR/TIMED_OUT/CLOSED), 재연결 후 스냅샷 재조회, 렌더 throttle(requestAnimationFrame)을 담당. UI는 props만 받는다(CLAUDE.md 3절 준수).
- OBS 뷰: `/r/{code}/live?bg=transparent|green&theme=dark` 전용 라우트, 레이아웃 크롬 없음, `noindex`.
- 남용 방지: 투표/입장 Route에 IP+voter_id 레이트 리밋(Upstash Ratelimit 또는 Postgres 함수 내 카운트), 닉네임 길이/금칙어 검증.

### 재사용 가능한 기존 프로젝트/모듈

| 재사용 대상 | 출처 | 활용 방법 / 주의점 |
| --- | --- | --- |
| 프로젝트 골격 | `basic-master-module/` (Next 16.2.4 + Tailwind v4 빈 템플릿) | 복제 후 Next 16.2.9로 버전 정렬. 의존성이 없어 깨끗한 출발점 |
| Supabase SSR 클라이언트 3종 | `Nomad-BlogStudio/src/lib/supabase/{client,server,middleware}.ts` | 그대로 이식. Next 16 Proxy 규약은 `Hospital/src/proxy.ts` 구조를 참고(세션 갱신 + 보호 경로) |
| shadcn UI 컴포넌트 | `Nomad-BlogStudio/src/components/ui/` (button, card, dialog, input, tabs, switch, progress, sonner, skeleton 등 19종) + `components.json` | 복사만으로 호스트 대시보드/참가자 UI 80% 구성 가능 |
| 실시간 구독 훅 패턴 | `Hospital/src/hooks/use-realtime-queue.ts` | 구독/언마운트 정리 구조만 참고. Hospital 리뷰에서 지적된 문제를 반복하지 말 것: 이벤트마다 전체 재조회(17번), 같은 화면에서 훅 2회 호출로 채널 중복(8번), 연결 상태 콜백 없음, `as any` 캐스팅(14번). 이 프로젝트는 postgres_changes 대신 Broadcast + payload 직접 반영 |
| 실시간 피드/알림 UI | `School_Management_System/src/components/realtime/RealtimeFeed.tsx`, `ERP-Wesite/components/dashboard/DashboardClient.tsx` | 호스트 대시보드의 "참가자 입장/투표 수" 라이브 피드 UI 참고 |
| 마이그레이션 + RLS + Realtime publication 구성 | `sellingstudio/supabase/migrations/001_initial_schema.sql`, `ERP-Wesite/supabase/migrations/001_initial_schema.sql` | 파일 구조만 참고. ERP의 RLS 자기참조 재귀, sellingstudio의 `USING(true)` 업데이트 정책 같은 결함은 리뷰(`docs/reviews/ERP-Wesite.md`, `sellingstudio.md`)대로 피한다 |
| 차트 | `Hospital` dashboard 차트(recharts 3) | 결과 막대 차트. 애니메이션은 `isAnimationActive` + CSS transition으로 경량화 |
| 공통 교훈 | `docs/reviews/Hospital.md` #5 | 날짜는 KST/UTC 변환 유틸을 처음부터 둔다(방 만료, 통계) |

### MVP 범위 축소안
- 포함: 호스트 로그인, 방 생성(6자리 코드 + QR), 방당 여러 개의 단일 선택 투표, 대기/시작/종료 제어, 참가자 익명 입장(닉네임 선택), 1인 1표(익명 auth + unique), 실시간 막대 차트, OBS 전용 뷰(투명/그린), 재연결 + 스냅샷 복구.
- 제외(2단계 이후): 복수 선택/주관식/워드클라우드, Q&A, 공동 호스트, Redis/Upstash 집계, CSV 내보내기, 다국어, GEO(랜딩 외), 결제.
- 목표 수치 확정: 동시 3,000명, 투표 피크 300건/초, 제출->차트 반영 p95 500ms(throttle 300ms 포함).

### 단계별 로드맵
1. 설계 확정(1~2일): PRD 보완(비기능 수치, 질문 유형, 방 코드, 중복 정책, 개인정보), 스택 ADR, ERD/RLS 설계.
2. 골격 + 데이터 레이어(2~3일): 템플릿 복제, Supabase/shadcn 이식, 마이그레이션, `cast_vote` 함수, 익명 auth.
3. 핵심 플로우(4~5일): 호스트 대시보드, 참가자 페이지, `useRoomChannel`, 실시간 차트, OBS 뷰.
4. 안정화(2~3일): 레이트 리밋, 부하 테스트(k6 + realtime 클라이언트 시뮬레이터), throttle 튜닝, 필요 시 Redis 도입 판단.
5. 확장: 질문 유형 추가, Q&A, 내보내기, 랜딩/GEO.

## 5. 구현 작업 목록 및 권장 모델

| # | 작업 | 우선순위 | 규모 | 권장 모델 | 이유 |
| --- | --- | --- | --- | --- | --- |
| 1 | PRD 보완: 동시 접속/지연 목표 수치화, 질문 유형, 방 코드 규칙, 중복 투표 정책(소프트 제한), IP 해시 처리 정책, 스택 ADR(Supabase 확정) 작성 | P0 | M | Fable 5.1 | 기획안만 있는 프로젝트의 설계, 이후 모든 작업의 기준 |
| 2 | `basic-master-module` 복제, Next 16.2.9 정렬, Nomad-BlogStudio의 supabase 클라이언트 3종/shadcn ui/components.json 이식, Hospital 방식 `proxy.ts` 작성 | P0 | S | Sonnet 5.5 | 보일러플레이트 복사와 설정 정리 |
| 3 | 마이그레이션 `001`: rooms/polls/poll_options/votes/poll_counts, unique 제약, 인덱스, RLS(호스트 소유권, 익명 참가자 읽기 범위), 익명 로그인 활성화 | P0 | M | Fable 5.1 | 데이터 모델 + 권한 설계, 실수 시 보안 사고 |
| 4 | `cast_vote` Postgres 함수: 상태 검증, 중복 거절, 원자적 증분, 300ms throttle `realtime.send()` 브로드캐스트, 종료 시 최종 스냅샷 | P0 | M | Fable 5.1 | 서비스 핵심 정합성 + 성능 로직 |
| 5 | `useRoomChannel` 훅: Broadcast 구독, 연결 상태 노출, 지수 백오프 재연결, 재연결 시 스냅샷 재조회, rAF 렌더 throttle, 테스트 | P0 | M | Opus 5.5 | 명확히 정의된 중간 규모 상태관리 |
| 6 | 호스트 대시보드: 방 CRUD, 투표/선택지 편집, 대기/시작/종료/다음 질문 서버 액션(소유권 검사 + broadcast) | P0 | M | Opus 5.5 | API 연동 + 서버 액션, 2~5개 파일 |
| 7 | 참가자 페이지: `/join` 코드 입력, `/r/{code}` 닉네임/익명 입장, 상태별 화면 전환(대기/투표/제출 완료/결과), 중복 투표 오류 처리 | P0 | M | Opus 5.5 | 명확한 중간 규모 기능 |
| 8 | 결과 차트 컴포넌트(recharts) + OBS 전용 라우트(투명/그린 배경, 테마/폰트 파라미터, 전체화면, noindex) | P1 | S | Sonnet 5.5 | UI/스타일 중심 반복 작업 |
| 9 | QR 코드 생성/공유 패널, 참가자 수 라이브 카운터, 연결 상태 배지 | P1 | S | Sonnet 5.5 | 단순 UI 컴포넌트 |
| 10 | 레이트 리밋(IP HMAC + voter_id), 방 코드 대입 방지, 닉네임 길이/금칙어/이스케이프 | P1 | S | Opus 5.5 | 보안 성격이지만 범위가 명확한 중간 난이도 |
| 11 | 부하 테스트: 3,000 동시 구독 + 300 votes/s 시나리오 스크립트, p95 지연 측정, throttle/플랜 한도 진단, Redis 도입 여부 결론 | P1 | M | Fable 5.1 | 성능 병목 진단 |
| 12 | 랜딩 페이지 시맨틱 마크업/메타데이터(GEO), 방 페이지 noindex, 사용 가이드 문서 | P2 | S | Sonnet 5.5 | 문서화/마크업 |
| 13 | 종료된 투표 결과 보존 화면 + CSV 내보내기 | P2 | S | Sonnet 5.5 | 단순 조회/변환 기능 |

## 6. 종합 평가

- 실현 가능성: 높음(조건부). 기능 범위 자체는 작고 워크스페이스에 Supabase/shadcn/Realtime 자산이 있어 MVP는 약 2~3주 규모로 가능하다. 단, 스택을 Supabase로 확정하고 "수천 명/0.5초"를 throttle 브로드캐스트 기준의 측정 가능한 목표로 다시 정의하는 것이 전제다.
- 강점: (1) 사용자 플로우가 단순하고 명확하다. (2) 폴링 금지, 훅/UI 분리, 재연결 명시 등 개발 원칙이 구체적이다. (3) OBS 송출 모드라는 차별화 요구가 있다.
- 약점: (1) 기술 스택 3안 미확정과 Vercel 전제의 충돌. (2) 중복 투표 정책이 "로그인 불필요"와 모순되고 IP 해시의 개인정보 이슈가 있다. (3) 비기능 요구사항이 수치/부하 조건 없이 선언적이다.
- 모델별 비율 (13개 작업 기준): Fable 5.1 31% (4개) / Opus 5.5 31% (4개) / Sonnet 5.5 38% (5개).
- 권장 진행 순서: 1단계 설계 확정과 데이터/투표 엔진(#1, #3, #4, 동시에 #2) -> 2단계 실시간 훅과 핵심 화면(#5, #6, #7, #8, #9) -> 3단계 보안/부하 검증과 부가 기능(#10, #11, #12, #13).
- 주 담당 모델: Fable 5.1. 이 프로젝트는 코드가 없는 기획 단계이고, 가치의 전부가 "대규모 동시 투표의 정합성과 지연"이라는 설계 결정(스택 확정, 데이터 모델, RLS, 원자적 집계, throttle 브로드캐스트, 부하 진단)에 걸려 있다. 이 부분이 틀리면 나머지 UI를 다시 짜야 하므로 초기 설계와 골격은 Fable 5.1이 맡고, 설계가 고정된 뒤의 화면/훅 구현은 Opus 5.5, UI와 보일러플레이트는 Sonnet 5.5로 내려 비용을 절감한다.
