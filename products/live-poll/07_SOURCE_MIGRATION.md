# 07 원본 이식과 폐기: Live Poll

## 1. 원본별 자산 분류

원본 `구현해야 할 프로젝트/Slido_Project/`에는 코드가 없고 문서 2개뿐이다(`docs/reviews/Slido_Project.md:3`).

AI 관련 원본 자산(2026-10-13 점검): 없다. 리뷰 1장 표가 AI 항목을 "없음"으로 적었고(`docs/reviews/Slido_Project.md:17`), 원본 PRD와 CLAUDE에는 LLM·음성·요약 기능이 없다. 원본 CLAUDE:7의 "GEO(Generative Engine Optimization)"는 AI 검색 엔진용 마크업 원칙이지 AI 기능이 아니다. 그래서 AI 계층(행사 자료 RAG, `poll.qna_assist`, 행사 위키, 어시스턴트, 음성)은 이식이 아니라 **전부 신규**이고 설계 정본은 `_platform-core`의 AI·음성 문서다. 아래 표는 AI 도입과 닿는 원본 자산만 적는다.

| 자산(파일/디렉토리) | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `PRD.md` 3절 유저 플로우(호스트/참가자) | 기획만 | 이식(디벨롭) | 01장 1, 3절, 03장 2절 | 원본 PRD:12-13 |
| `PRD.md` 4.1 방 생성/삭제/관리, 상태 3단계 | 기획만 | 이식(유지) | LP-F-002, 003 | 분석:1254 |
| `PRD.md` 4.1 OBS 전체화면/크로마키 | 기획만 | 이식(디벨롭: 투명/그린/다크 파라미터) | LP-F-012 | 분석:1258 |
| `PRD.md` 4.2 닉네임/익명 입장, 무새로고침 전환 | 기획만 | 이식(유지) | LP-F-007, 005 | 분석:1255 |
| `PRD.md` 4.2 1인 1표(IP + LocalStorage/Cookie) | 기획만 | 디벨롭(참가자 토큰 + unique, IP는 실패 레이트 리밋 신호만) | LP-F-008, 05장 7절 | 분석:1257 |
| `PRD.md` 4.3 WebSocket/SSE 브로드캐스트 | 기획만 | 디벨롭(Realtime Broadcast 묶음 전송) | 02장 5-1절 | 분석:1256 |
| `PRD.md` 4.3, 5절 Redis 집계 | 기획만 | 폐기(2단계 보류) | 3절 | 분석:1260 |
| `PRD.md` 5절 Socket.io / FastAPI 후보 | 기획만 | 폐기 | 3절 | 분석:1259 |
| `PRD.md` 2절 지연 0.5초, 모바일, 트래픽 급증 | 기획만 | 이식(수치화) | 01장 5절 | 리뷰:39 |
| `CLAUDE.md` 2절 GEO 최적화 | 기획만 | 랜딩만 유지, 방 페이지는 폐기(noindex) | LP-F-024, 3절 | 분석:1261 |
| `CLAUDE.md` 2절 폴링 금지 | 기획만 | 이식 | 04장 1절 | 원본 CLAUDE:8 |
| `CLAUDE.md` 2절 경량 렌더링(CSS 애니메이션, 경량 차트) | 기획만 | 이식 | 02장 1절 | 원본 CLAUDE:9 |
| `CLAUDE.md` 3절 훅/UI 분리, 메모이제이션 | 기획만 | 이식 | 02장 2절, CLAUDE.md 5장 | 원본 CLAUDE:12-13 |
| `CLAUDE.md` 3절 IP 해시 검증 미들웨어 | 기획만 | 디벨롭(HMAC, 저장 안 함) | 05장 7절 | 리뷰:42 |
| `CLAUDE.md` 5절 재연결 로직 명시 | 기획만 | 이식(디벨롭: 스냅샷 복구, seq) | LP-F-010 | 원본 CLAUDE:21 |
| 리뷰가 지목한 재사용 자산(basic-master-module, Nomad-BlogStudio supabase 클라이언트/shadcn, Hospital 실시간 훅 구조, recharts) | 동작/부분 | 참고 | LP-06-001, 013, 015 | 리뷰:72-81 |
| `PRD.md` 5절 `Frontend: Next.js, Tailwind CSS, Shadcn UI`, `CLAUDE.md` 1절 "Tailwind CSS, Shadcn UI" | 기획만 | 디벨롭(버전 명시) | 02장 1절(Tailwind CSS v4, 4.x 고정), LP-06-001, 023 | 원본 PRD:32, 원본 CLAUDE:4, `docs/nomad-design-modules/_design-guide/DESIGN_SYSTEM.md:23` |
| `CLAUDE.md` 2절 GEO 시맨틱 마크업(`main`, `section`, `article`, `header`) | 기획만 | 이식(랜딩만) | LP-F-024, 03장 4절 | 원본 CLAUDE:7. AI 검색 엔진이 읽는 구조일 뿐 AI 기능이 아니다 |
| AI 어시스턴트, Q&A AI 정리, 자료 RAG, 행사 위키, 음성(진행자·청중), 3D 히어로 | 원본에 없음 | 신규 | 01장 LP-F-025~037, 02장 5절, LP-06-033~048 | 확정 결정 13~17 |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| 플로우와 상태 제어 | 상태를 draft/live/ended/archived(행사) + draft/open/closed(문항)로 나누고 전이를 트리거/RPC로 강제. "대기" = live 행사에 열린 문항 없음 |
| 1인 1표 | 클라이언트 식별(LocalStorage)을 서버 발급 httpOnly 토큰으로 바꾸고 DB unique로 판정. IP 차단 없음 |
| 실시간 엔진 | 투표마다 전송하지 않는다. 워커가 행사별 묶음 상태를 private 채널로 보낸다. 클라이언트는 seq로 순서와 유실을 판단 |
| OBS 모드 | 로그인 없는 오버레이 키 URL. 키는 해시만 저장, 재발급 가능 |
| 재연결 | 백오프 + 재구독 직후 스냅샷 1회. 15초 무수신 감지(hb) |
| 재사용 자산 | Supabase 클라이언트 3종은 `packages/core-db`를 쓴다(직접 복사하지 않음). Hospital 훅은 구조만 참고하고 아래 4절 결함을 피한다. 차트는 진행자 콘솔만 recharts, 청중/발표/오버레이는 CSS 막대 |
| 스택 표기 | 원본의 "Tailwind CSS"는 "Tailwind CSS v4"로 고친다. 지시·문서·ADR에 버전을 항상 적고 `tailwind.config.js`·v3 문법을 만들지 않는다 |
| AI 계층 | 이식할 원본이 없다. 투표·실시간 경로(5-1절)와 분리된 별도 프로세스·라우트로 새로 만든다(02장 6절 마지막 문단). 원본의 "폴링 금지"·"경량 렌더링" 원칙은 AI 결과 전달에도 적용한다(SSE, 주기 조회 금지) |

## 3. 폐기 목록과 사유

분석 "폐기" 3건(`docs/products/00_MERGE_ANALYSIS.md:1259-1261`)을 모두 적는다.

| 항목 | 분석 근거 | 사유 |
|---|---|---|
| 실시간 스택 후보 Socket.io, FastAPI WebSocket | `00_MERGE_ANALYSIS.md:1259` | Vercel 서버리스는 상주 WebSocket 서버를 띄울 수 없어 별도 서버와 Redis adapter가 필요하고 MVP가 2배 이상 커진다(리뷰:54). Supabase Realtime으로 확정했다 |
| Redis 집계(카운팅/캐싱) | `00_MERGE_ANALYSIS.md:1260` | 투표는 INSERT 1회, 집계는 워커가 행사별 250ms마다 한 번이라 Postgres만으로 처리량이 충분하다(리뷰:45). LP-06-027 부하 테스트에서 필요하다고 나오면 Phase 3에 다시 본다 |
| 방(행사) 페이지 GEO | `00_MERGE_ANALYSIS.md:1261` | 일시적이고 비공개인 페이지라 검색 노출 가치가 없고 오히려 noindex 해야 한다(리뷰:49). GEO는 랜딩에만 적용 |

추가로 이 기획에서 버린 것(분석에는 디벨롭으로 분류):

| 항목 | 사유 |
|---|---|
| IP 기반 하드 차단 | 같은 Wi-Fi/CGNAT 정상 사용자를 막는다(리뷰:55) |
| IP 해시 영구 저장 | 개인정보 처리와 역산 위험(리뷰:56). HMAC 레이트 리밋 키(1일)로 대체 |
| Supabase 익명 로그인 | 코어 가입 트리거가 익명 사용자마다 조직을 만든다(05장 7절) |
| `postgres_changes` 구독 | 구독자마다 권한 검사가 일어나 대규모에 부적합(리뷰:65) |
| `poll_counts` 원자적 증분 테이블(리뷰 권장안) | 같은 카운터 행에 300건/초가 몰리는 핫 로우 경합. 집계는 워커 시점 계산으로 대체(02장 5-1절) |
| 원본 PRD:32, CLAUDE:4의 버전 없는 "Tailwind CSS" 지시 | 버전을 적지 않으면 AI가 가장 흔한 v3로 만든다(`docs/nomad-design-modules/_design-guide/DESIGN_SYSTEM.md:23`). Tailwind CSS v4로 명시 |
| AI 도입 시 후보였다가 버린 것: 투표마다 AI 호출, 청중용 AI 채팅(MVP), AI 자동 질문 삭제, 청중 원문의 상용 모델 전송 | 비용 폭증·투표 경로 지연, 청중이 국외 이전 동의를 줄 수 없음, 자동 삭제는 오탐 책임이 진행자에게 있음. 대신 진행자가 누르는 Q&A 정리와 제안 적용(LP-F-029, 030), 청중 원문 오픈소스 강제(01장 D9) |

## 4. 복사 금지 결함

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 이벤트마다 전체 재조회 | `docs/reviews/Slido_Project.md:74`(Hospital #17) | 3,000명이 동시에 재조회하면 DB 폭주 | 브로드캐스트 페이로드 직접 반영, 스냅샷은 공백/재연결 때만 |
| 같은 화면에서 훅 2회 호출로 채널 중복 | `docs/reviews/Slido_Project.md:74`(Hospital #8) | 메시지 중복 처리, 연결 수 2배 | 훅 내부 채널 참조 카운트(LP-06-013) |
| 연결 상태 콜백 없음 | `docs/reviews/Slido_Project.md:74` | 끊김을 사용자가 모른다 | 연결 배지 4종 |
| `as any` 캐스팅 | `docs/reviews/Slido_Project.md:74`(Hospital #14), `SECURITY_BASELINE.md` 10장 | 타입 우회로 계약 위반이 숨는다 | 생성 타입 + zod |
| RLS 자기참조 재귀, `USING(true)` 업데이트 정책 | `docs/reviews/Slido_Project.md:78`(ERP, sellingstudio), `SECURITY_BASELINE.md` 14장 | 42P17 또는 전 행 수정 허용 | 코어 헬퍼만 사용, 쓰기 정책에 with check(05장 4절) |
| 프로필 없으면 admin, 클라이언트 PageGuard | `SECURITY_BASELINE.md` 14장 | 권한 상승, RSC 노출 | 서버 `requireSession`, 프로필 없으면 로그아웃 |
| 실키가 든 `.env` 커밋 | `SECURITY_BASELINE.md` 14장 | 키 유출 | env 검증 + `.env*` gitignore |
| `FOR ALL` 플랜/크레딧 정책 | `SECURITY_BASELINE.md` 14장 | 셀프 업그레이드 | 플랜은 코어 엔타이틀먼트만 읽는다 |
| 한글에 `\b` 경계 금지어 | `SECURITY_BASELINE.md` 14장 | 필터 무효 | `normalize_text` 부분 일치(조각:44) |
| 공개 Broadcast 채널에서 서버 메시지와 클라이언트 메시지를 구분 없이 신뢰 | 이 기획(02장 5-1절) | 토픽을 아는 청중이 가짜 결과를 보낼 수 있다 | private 채널, 송신 정책 없음 |
| 브라우저에서 Dify·FastAPI·LLM·음성 제공자 직접 호출 | `docs/products/_platform-core/SECURITY_BASELINE.md:299` | 인증·과금·조직 격리 우회 | `/api/ai/*`, `/api/voice/*`, `/api/p/voice-question`만 |
| Dify 입력에 서명 토큰·org·청중 정보 넣기 | `docs/products/_platform-core/SECURITY_BASELINE.md:285` | Dify 로그에 평문으로 남고 갱신도 어렵다 | 대화 매핑(`platform_conversation_id`, `dify_user`) |
| LLM·음성 키를 브라우저·Vercel·브로드캐스터에 두기 | 이 기획(02장 8절) | 키 유출, 비용 남용 | LLM 키는 FastAPI 전용, ElevenLabs 키와 토큰 개인키는 Next.js 서버 전용 |
| 청중 원문(질문, 닉네임, 음성)을 상용 모델로 보내기 | 이 기획(01장 6.1절, D9) | 청중에게 국외 이전 동의를 받을 수 없다 | `force_open_source` 행 4개 + 서버 검사 |
| AI 결과만으로 질문 숨김·삭제 | 이 기획(LP-F-030) | 오탐이 청중 발언권을 침해, 책임 소재 불명 | AI는 제안, 진행자가 `moderate_question`으로 적용 |
| 클라이언트가 보낸 임의 텍스트를 TTS | 이 기획(04장 2.1절) | 음성 생성 남용, 과금 우회 | DB의 assistant 메시지와 `ai_runs.output.summary`만 낭독 |
| 음성 오디오·변환 텍스트를 로그·DB에 저장 | `docs/products/_platform-core/SECURITY_BASELINE.md:304`, `VOICE_ARCHITECTURE.md:90` | 청중 음성은 개인 식별 정보 | 메모리 처리, `store_audio=false`, 응답으로만 반환 |
| 청중 음성 경로에 사용자·IP·행사 한도 없이 STT 연결 | 이 기획(02장 5-4절) | 익명 입력으로 진행자 지갑 소진 | 참가자·행사·IP 5중 한도 + 묶음 선차감 |
| 투표·브로드캐스트 경로에서 AI 서비스 동기 호출 | 이 기획(02장 6절) | AI 장애·지연이 투표에 전파 | 별도 라우트·프로세스, 투표 경로 수정 금지(06장 1절) |
| 레이트 리밋 히트 뒤 raise | 이 기획(조각 머리 주석 5) | 히트가 롤백되어 대입 공격이 세어지지 않는다(코어 `confirm_payment_order`의 PM001도 같은 원리라 `fail_payment_order`를 별도 호출로 분리했다) | 청중 RPC는 jsonb `{ok:false, code}` 반환 |

## 5. 아카이브 절차

| 단계 | 내용 |
|---|---|
| 1 | 원본 폴더 `구현해야 할 프로젝트/Slido_Project/`는 문서 2개뿐이다. 앱 저장소 생성(LP-06-001) 뒤 `archive/Slido_Project/`로 옮기는 것은 사용자가 결정한다(이 작업에서는 옮기지 않음) |
| 2 | 키 재발급: 원본에 키가 없어 해당 없음 |
| 3 | zip 중복: 없음 |
| 4 | 원본 PRD/CLAUDE의 내용은 01~07장에 흡수됐으므로 앱 저장소에는 복사하지 않는다 |

## 6. 인증 단계 복사 금지 결함 (2026-10-14 추가, 확정 결정 22)

원본 `Slido_Project`에는 코드가 없어 아래 패턴의 원본 사본은 없다. 다른 제품 원본에서 확인된 결함이라 재사용 자산(basic-master-module, Nomad-BlogStudio 클라이언트 등)을 옮길 때 섞여 들어오지 않게 4절 표에 더한다. 허용되는 Mock은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2장(로컬 시드 계정으로 실제 JWT, 배포 환경 404)뿐이다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 쿠키 역할 Mock(`lib/mock-auth.ts`, 쿠키에 역할·플랜을 적어 권한 판정) | `docs/products/nomad-blog/07_SOURCE_MIGRATION.md:88` | 권한 위조, 프로덕션 노출 | AUTH_ROADMAP 2장 Mock(`POST /api/dev/login`, `isMockAuthAllowed()`), 권한은 `session_context('poll')`만 |
| `mock-login` 라우트, `nomad_role`·`nomad_plan` 쿠키 | `docs/products/nomad-commerce/07_SOURCE_MIGRATION.md:96` | 쿠키 조작으로 셀프 업그레이드 | 같음. CI 금지 문자열(06장 LP-06-003) |
| 콜백 `next` 무검증 리다이렉트 | `docs/products/_platform-core/SECURITY_BASELINE.md` 17장 | 오픈 리다이렉트로 피싱 | `/`로 시작하고 `//`·`@`·`\` 없는 경로만, origin은 `NEXT_PUBLIC_APP_URL` 고정(AUTH_ROADMAP 3.2절 5번, 04장 8절) |
| `dev-user`·고정 사용자 id 우회, 원격 DB에 개발 계정 생성 | `docs/products/_platform-core/SECURITY_BASELINE.md` 14장, 17장 | 인증 우회, 운영 데이터 오염 | 시드 스크립트는 루프백 Supabase만(원격이면 exit 1) |
| 청중·오버레이 화면에 로그인 요구 또는 Supabase 익명 로그인으로 Mock 대체 | 이 기획(01장 D2, 3절 "Supabase 익명 로그인") | 청중 무로그인 설계 위반, 익명 사용자마다 조직 생성 | 청중은 참가자 토큰, 오버레이는 키. 인증 단계와 무관하게 유지 |
