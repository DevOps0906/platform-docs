# 01 PRD: Stock Dashboard

작성일 2026-10-12. 원본은 기능 목록 수준 PRD 61행뿐이고(`docs/reviews/Stock_Trader_nomad.md:27`) 백엔드, 데이터 모델, 연동 방식, 법적 검토가 없다(`:21`). 이 문서는 그 공백을 수치, 상태, 정책으로 채운다. 원본·리뷰·분석에 근거가 없는 수치와 정책은 "제안"으로 표시하고 이유를 단다. 외부 사실(증권사 API, 약관, 법령 해석)은 확인하지 않았으면 "미확인"으로 적는다. 이 문서의 법률 관련 서술은 법률 자문이 아니며, 출시 전 전문가 검토가 필요하다(`docs/reviews/Stock_Trader_nomad.md:61`).

2026-10-13 개정: 확정 결정 13~17(`docs/products/00_MERGE_ANALYSIS.md:21-25`)에 따라 AI 계층(공시 RAG, LangGraph 리서치 요약, 주식 용어 위키, Dify 채팅), 음성(음성 질의, 브리핑 낭독), 상용/오픈소스 모델 이원화와 국외 이전 동의, 3D 히어로(시세 흐름 지형), 디자인 시스템을 MVP에 넣었다. 설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `docs/products/_design-guide/HERO_3D.md`, `DESIGN_SYSTEM.md`이고 이 문서는 제품 요구만 정한다. 유사투자자문업·투자자문업 해당 여부에 대한 법률 의견은 아직 받지 못했다(D-3). 그래서 AI 기능은 모두 초대제 무료 베타 안에서 "공개 자료의 사실 요약과 현재 상태 설명"으로 범위를 좁혔고, 모든 AI 출력에 투자 권유 금지 검사(ST-F-022)를 필수 단계로 둔다. 공시·뉴스 데이터의 이용 허락은 확인 전이라 열린 결정이다(D-10).

## 1. 페르소나와 핵심 과제

| 페르소나 | 상황 | 목표 | 좌절 | 근거 |
|---|---|---|---|---|
| 지훈(34, 직장인, 투자 2년차) | 점심시간과 퇴근 후에 MTS를 열어 보유 종목을 확인한다. 매매 기록은 엑셀에 손으로 옮긴다 | 내 계좌 상태(평가손익, 비중)와 매매 이력을 한 화면에서 본다 | 수동 정리, 캡처, 증권사 앱마다 다른 화면 | `구현해야 할 프로젝트/Stock_Trader_nomad/PRD.md:13`, `:44` |
| 수연(29, 초보 투자자) | 뉴스와 커뮤니티 글을 보고 한두 종목에 몰아서 샀다(FOMO) | 내 포트폴리오가 얼마나 한쪽에 쏠렸는지, 어떤 위험이 있는지 쉬운 말로 알고 싶다 | AI 챗봇에 물어보면 내 실제 보유 내역을 모르고 일반론만 말한다 | `PRD.md:6`, `docs/reviews/Stock_Trader_nomad.md:49` |
| 운영자(제품 소유자) | 초대한 사람만 쓰는 베타를 운영한다 | 법적 위험 없이 기능을 검증하고, 사고가 나면 즉시 멈춘다 | 투자자문 규제, 키 유출, 시세 재배포 위험 | `docs/reviews/Stock_Trader_nomad.md:41-44`, `:61` |

| 핵심 과제 | 설명 |
|---|---|
| J1. 내 계좌를 안전하게 연결해 한눈에 본다 | 증권사 키는 서버에만, 계좌번호는 마스킹, 1차는 모의투자 계좌 |
| J2. 내 포트폴리오의 쏠림과 위험 요인을 이해한다 | AI 진단은 "무엇을 사라"가 아니라 "지금 어떤 상태인가"를 설명한다 |
| J3. 매매 이력을 손으로 정리하지 않는다 | 체결 내역 자동 동기화(조회 전용) + 메모 + CSV |

## 2. 범위: MVP와 Phase

확정 결정 7(MVP 범위)과 8(플랜 정본)에 stock 항목이 없으므로(`docs/products/00_MERGE_ANALYSIS.md:15-16`) 범위는 리뷰 4.4 축소안과 분석 표를 따른다.

| 기능 | 범위 | 근거 |
|---|---|---|
| 초대제 가입, 베타 접근 게이트. 로그인 단계(2026-10-14): MVP 개발은 Mock(Stage A, 로컬 시드 페르소나), 공개 베타 전 Google(+초대 링크·이메일)(Stage B, P0), 카카오·네이버는 G2 후(Stage C, P2 선택) | MVP(로그인 B까지), C는 G2 후 | 과제 지시(초대제 베타), `docs/products/_supabase-modular/seed.sql:22`(signup_policy invite, beta), 확정 결정 22(`docs/products/00_MERGE_ANALYSIS.md:30`), `docs/products/_platform-core/AUTH_ROADMAP.md:333` |
| 투자 고지와 동의 기록 | MVP | `docs/reviews/Stock_Trader_nomad.md:41`(면책 고지 없음) |
| 증권사 1곳 모의투자 계좌 연결, `BrokerAdapter` + `MockBroker` | MVP | `docs/products/00_MERGE_ANALYSIS.md:1276`, `docs/reviews/Stock_Trader_nomad.md:70`, `:101` |
| 키 암호화 보관, 계좌번호 마스킹 | MVP | `docs/products/00_MERGE_ANALYSIS.md:1284`, `docs/reviews/Stock_Trader_nomad.md:79-80` |
| 잔고/보유/체결 동기화(조회 전용) | MVP | `docs/products/00_MERGE_ANALYSIS.md:1280` |
| 증권사/Total 탭 대시보드, 보유 그리드 블링크 | MVP | `docs/products/00_MERGE_ANALYSIS.md:1275`, `:1277` |
| 장중 시세 중계(상주 워커) | MVP | `docs/products/00_MERGE_ANALYSIS.md:1277`, `docs/reviews/Stock_Trader_nomad.md:71` |
| 종목 상세 모달, 재무지표 5종 | MVP | `docs/products/00_MERGE_ANALYSIS.md:1275`, `PRD.md:47` |
| 장 운영 시간, 휴장일, 시세 지연 표시 | MVP | `docs/products/00_MERGE_ANALYSIS.md:1284`, `docs/reviews/Stock_Trader_nomad.md:52` |
| AI 포트폴리오 진단(모델 1개, 스트리밍, 가격 제시 없음) | MVP | `docs/products/00_MERGE_ANALYSIS.md:1278`, `docs/reviews/Stock_Trader_nomad.md:101` |
| 운영자 화면(초대 발급/회수, 전역 킬 스위치) | MVP | 제안: 초대제 운영과 사고 대응에 필요 |
| 투자 권유 금지 검사(모든 AI 출력의 필수 단계) | MVP | 확정 결정 13(`docs/products/_platform-core/AI_ARCHITECTURE.md:117`), `docs/reviews/Stock_Trader_nomad.md:41` |
| 공시 RAG, AI 리서치 요약(그래프 `stock.research_summary`) | MVP | 확정 결정 13(`docs/products/00_MERGE_ANALYSIS.md:21`). 공시 이용 조건 확인이 색인 조건(D-10) |
| 주식 용어·공시 해설 위키(제품 지식 위키) | MVP | 확정 결정 13, `docs/products/_platform-core/LLM_WIKI.md:37-47` |
| AI 리서치 채팅(Dify, 투자 조언 아님) | MVP | 확정 결정 13, 14(`docs/products/00_MERGE_ANALYSIS.md:21-22`) |
| 음성 질의, 브리핑 생성과 낭독(TTS) | MVP | 확정 결정 16(`docs/products/00_MERGE_ANALYSIS.md:24`) |
| 상용/오픈소스 모델 이원화, 온보딩 국외 이전 동의 | MVP | 확정 결정 17(`docs/products/00_MERGE_ANALYSIS.md:25`), `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| 랜딩 3D 히어로(시세 흐름 지형, `/` 초대 전용 안내 화면) | MVP | 확정 결정 15(`docs/products/00_MERGE_ANALYSIS.md:23`), `docs/products/_design-guide/HERO_3D.md:88` |
| AI 관심 아이디어 + 성과 평가 + 내부 리더보드 | Phase 2 | `docs/products/00_MERGE_ANALYSIS.md:1279`, `docs/reviews/Stock_Trader_nomad.md:109` |
| AI 3사 비교 | Phase 2 | `docs/products/00_MERGE_ANALYSIS.md:1278` "3사 비교는 2단계" |
| 실계좌 조회 전용 연결 | Phase 2 | 제안: 리뷰 MVP는 모의 계좌만(`docs/reviews/Stock_Trader_nomad.md:101`). 실계좌 조회는 spike와 약관 확인 뒤 |
| 두 번째 증권사 | Phase 2 | `docs/reviews/Stock_Trader_nomad.md:102` |
| 유료 플랜(Toss) | Phase 2, 법률 검토 통과 조건 | 확정 결정 4(`docs/products/00_MERGE_ANALYSIS.md:12`), `docs/reviews/Stock_Trader_nomad.md:41` |
| 모의투자 주문 + 안전장치 전부 | Phase 3(선택) | `docs/reviews/Stock_Trader_nomad.md:110`, `:77-86` |
| 뉴스 본문 색인 | 조건부(D-10 결과) | 제안: 언론사 저작권과 이용 조건 확인 전에는 본문을 저장하지 않는다 |
| 브리핑 정기 자동 생성·푸시 | 보류(D-15, 법률 의견 후) | 제안: 불특정 다수 대상 통신물로 해석될 소지 |
| 실전 주문 | 범위 밖. 별도 사용자 결정 + 법률 검토 + 새 마이그레이션 필요 | `docs/reviews/Stock_Trader_nomad.md:60` |
| 공개 리더보드, GEO/JSON-LD | 폐기(법률 검토 전 보류) | `docs/products/00_MERGE_ANALYSIS.md:1282` |
| 스크래핑 | 폐기(영구) | `docs/products/00_MERGE_ANALYSIS.md:1281` |

## 3. 기능 요구사항과 수용 기준

ID 접두사 `ST`는 `DB_CONVENTIONS.md` 1장 SQLSTATE 접두사다(`docs/products/_platform-core/DB_CONVENTIONS.md:22`).

### 3.1 MVP

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| ST-F-001 | 초대제 가입과 베타 게이트 | 신규 | 운영자가 이메일로 초대를 발급한다. 토큰 원문은 링크로 1회만 보여 주고 DB에는 sha256만 저장한다. 초대는 14일 뒤 만료(제안: 2주면 수신 확인에 충분). 수락하면 개인 조직에 `beta_access`가 생기고 플랜이 default → beta로 바뀐다. 모든 도메인 RLS는 `has_stock_access(org)` = 멤버 + 엔타이틀먼트 + 베타 활성. 로그인 단계(2026-10-14, 확정 결정 22): 초대 토큰 흐름(sha256 저장, 14일 만료, 수락 시퀀스)은 단계와 무관하게 그대로다. Stage A(MVP 개발)는 로컬 시드 페르소나(초대 수락·미수락 포함, `05_DATA_MODEL.md` 10절)로 로그인하고, Stage B(공개 베타 전, P0)는 "초대 링크 수락 + Google로 계속하기"(+기존 이메일 가입·로그인), Stage C(카카오·네이버)는 G2 후 P2 선택. 쿠키 역할 Mock 금지, 개발용 로그인은 AUTH_ROADMAP 2장의 로컬 시드 계정만(배포 환경 404). 단계 분기는 `src/lib/auth/`·로그인 화면·콜백만 | 초대 없이 `signup_app='stock'`으로 가입하거나 `bootstrap_app_for_org('stock')`를 호출해도 도메인 테이블이 0행이다(스모크 테스트 C 사용자). 다른 이메일 계정으로 수락하면 `ST031`. 사용한 초대 재사용은 `ST030`. 베타 회수 즉시 본인 데이터도 0행. A: `owner`(초대 수락) 페르소나 로그인 → `/onboarding/disclaimer` 또는 `/dashboard`, `invitee`(초대 미수락)·`no_app` → `/no-access`(초대 링크 안내), `invitee`가 시드가 출력한 초대 링크로 수락 → beta. B: AUTH_ROADMAP 5.3 B-1~B-6(invite 앱이라 초대 링크 없이 Google 첫 로그인은 `entitled=false` → `/no-access`, `/invite/[token]`에서 Google로 로그인하면 콜백이 그 화면으로 돌아와 수락 → beta·300 크레딧), 초대 이메일과 다른 Google 계정이면 `ST031` + "초대받은 이메일로 로그인하세요". C(선택): 7.1.3 C1-1~C1-5, 7.2.4 C2-1~C2-6 | 코어가 `invite` 정책을 강제하지 않음(`docs/products/_supabase-modular/migrations/0003_core_credits.sql:400-402`는 approval만 처리) |
| ST-F-002 | 투자 고지와 동의 | 신규 | 첫 진입 시 투자 고지(정보 제공 목적, 투자 권유 아님, 손실 책임은 본인, 필수)와 AI 국외 이전 동의(선택, ST-F-029)를 받는다. 동의는 `consents`에 버전별로 남는다. 고지 문구가 바뀌면 버전을 올리고 재동의 전까지 AI 기능과 연결 추가를 막는다. 국외 이전에 동의하지 않아도 사용할 수 있고, 이때 AI·음성은 국내 오픈소스 제공자만 쓴다 | 동의 전 `/dashboard` 접근 시 `/onboarding/disclaimer`로 이동한다. 동의 행은 UPDATE/DELETE가 `ST000`으로 거부된다. 고지 버전이 `2026-10-12`에서 `2026-11-01`로 바뀌면 다음 요청에서 재동의 화면이 나온다. 국외 이전 동의를 거부하고 고지만 동의한 계정으로 AI를 쓰면 `ai_usage`의 제공자가 전부 오픈소스다 | `docs/reviews/Stock_Trader_nomad.md:41` |
| ST-F-003 | 증권사 연결 | 디벨롭 | `BrokerAdapter`(getBalance, getHoldings, getExecutions, subscribeQuotes)를 구현한 어댑터만 쓴다. MVP는 `mock`과 spike에서 고른 증권사 1곳의 모의투자 환경. 연결 수는 플랜 `broker_connections_max`(beta 2). 실계좌(live) 연결은 서버 플래그 `BROKER_LIVE_READ_ENABLED=false`로 막는다 | 연결 생성 시 토큰 발급 테스트에 실패하면 행이 `error`로 남고 사용자에게 원인 코드가 보인다. `mock` 연결은 즉시 `active`이고 화면에 "샘플 데이터" 배지가 붙는다. 세 번째 연결 시도는 409 | `docs/reviews/Stock_Trader_nomad.md:70`, `:101`, `:121` |
| ST-F-004 | 키 보관과 마스킹 | 신규 | app key/secret, 접근 토큰은 `encrypted_credentials`(AES-256-GCM, `key_version`)에만 저장한다. 계좌번호는 `account_masked`(숫자 5자리 이상 연속 금지 CHECK)와 HMAC-SHA256 해시만 저장한다. 키는 브라우저로 내려가지 않고 로그·오류·감사에 남지 않는다. ID/비밀번호, 공동인증서는 받지 않는다 | `50123456-01` 같은 원문 계좌번호 INSERT는 `23514`. 브라우저 번들에서 `CREDENTIALS_KEY`, `appSecret` 문자열 검색 결과 0건. 사용자 세션의 `encrypted_credentials` SELECT는 `42501` | `docs/reviews/Stock_Trader_nomad.md:39`, `:59`, `:79-80` |
| ST-F-005 | 동기화(조회 전용) | 유지 | 잔고·보유는 장중 5분, 장외 60분 주기(제안: 증권사 호출 한도 미확인이라 보수적으로), 체결은 장 마감 뒤 15:40 KST 1회 + 수동 동기화(연결당 60초에 1회). 체결은 `(connection_id, broker_exec_id)` 유니크로 중복 없이 upsert. 연속 오류 5회면 연결을 `error`로 바꾸고 알림 | 같은 체결을 두 번 동기화해도 `trades` 1행. 수동 동기화를 60초 안에 다시 누르면 429와 남은 초. 오류 5회 뒤 화면 상단에 "연결 오류, 다시 연결하세요" | `docs/products/00_MERGE_ANALYSIS.md:1280`, `docs/reviews/Stock_Trader_nomad.md:124` |
| ST-F-006 | 포트폴리오 홈 | 유지 | 증권사별/Total 탭, 총 평가금액, 예수금, 평가손익, 수익률, 보유 그리드(종목, 수량, 평균단가, 현재가, 평가금액, 손익률). 탭 전환 시 스켈레톤. 상승 빨강, 하락 파랑(한국 관례) | Total 탭의 합계가 각 연결의 최신 스냅샷 합과 일치한다. 연결이 0개면 빈 상태 안내 | `PRD.md:21-24`, `docs/products/_design-guide/REFERENCES.md:207` |
| ST-F-007 | 시세 중계와 블링크 | 디벨롭 | 상주 워커가 **사용자 본인의 증권사 연결**로 시세를 구독해 그 조직의 브라우저에만 SSE로 보낸다. 다른 조직과 시세를 공유하지 않는다. 브라우저는 zustand 종목별 셀렉터로 해당 셀만 다시 그린다. 값이 바뀐 셀은 400ms 동안 상승/하락 색으로 깜빡인다(`prefers-reduced-motion`이면 색만 바뀜) | 한 종목 틱이 오면 그 행 외 컴포넌트 리렌더 0회(React Profiler). 장중 마지막 틱 10초 초과면 "지연" 배지, 60초 초과면 "시세 끊김" 배지 | `docs/reviews/Stock_Trader_nomad.md:44`, `:48`, `:71` |
| ST-F-008 | 종목 상세 모달 | 유지 | 행 클릭 시 배경 블러 모달. 당일 라인 차트(사용자 본인 연결에서 받은 분 단위 시세, 서버에 저장하지 않음), 내 포지션(수량, 평단, 손익), 재무지표 PER/PBR/ROE/EPS/배당수익률과 출처·기준일 | 재무지표 카드마다 "출처: DART, 기준 2025FY" 같은 표기. 값이 없으면 "-"와 사유 | `PRD.md:43-47`, `docs/reviews/Stock_Trader_nomad.md:50` |
| ST-F-009 | 매매 일지 | 유지 | 체결 목록(기간·종목·매수/매도 필터), 체결별 메모(2,000자, 태그 10개), CSV 내보내기(최대 1년, 1만 행) | 메모는 작성자만 수정, owner/admin은 삭제 가능. CSV는 UTF-8 BOM, 계좌번호 마스킹 값만 포함 | `PRD.md:43-45` |
| ST-F-010 | 장 운영 정보 | 신규 | `market_calendar`로 개장일·정규장 시각을 판정하고 상단 "장 시간 바"에 장 전/정규장/장 마감/휴장을 표시한다. 정규장 시각은 KRX 공지 기준으로 매년 적재(정규장 09:00~15:30 KST로 알려져 있으나 미확인, 연도별 공지로 확정) | 휴장일에는 동기화 주기가 장외 주기로 바뀌고 시세 배지는 "휴장". 모든 시각은 timestamptz로 저장하고 KST로 표시 | `docs/reviews/Stock_Trader_nomad.md:52`, `docs/products/_platform-core/DB_CONVENTIONS.md:84-86` |
| ST-F-011 | AI 포트폴리오 진단 | 디벨롭 | LangGraph 그래프 `stock.diagnosis`(노드 `explain` → `advice_check` → `compliance`)를 Next.js AI 게이트가 호출한다. 모델은 라우터가 정한다(기능 `stock.diagnosis`, 코드·화면에 모델명 하드코딩 금지). 입력은 서버가 만든 스냅샷(종목코드, 비중, 평가손익률, 업종, 재무지표)만. 계좌번호, 금액 원값, 이름은 보내지 않는다. 출력은 zod 스키마(요약, 집중도, 업종 노출, 종목별 위험 수준과 요인, 데이터 공백). 위험 수준(낮음/중간/높음)은 서버 규칙이 정하고 LLM은 요인 설명만 한다. 매수/매도 권유, 매수가·목표가·손절가는 금지(DB CHECK, 금칙어 검사, 투자 권유 금지 검사 ST-F-022). 투자 권유 금지 검사를 통과한 뒤에만 결과를 보여 주므로 토큰 단위 스트리밍은 하지 않는다(진행 상태만 표시, 2026-10-13 변경 이유: 검사 전 문장을 먼저 보여 주면 필수 단계가 무의미해진다) | 진단 1회 10 크레딧 선차감, 실패 시 자동 환불. 상태 표시 1초 이내, 결과 표시 p95 30초 이내, 60초 타임아웃. 존재하지 않는 종목코드나 입력에 없는 종목이 나오면 1회 재생성 후 실패 처리. 결과 화면 상단에 고지와 "AI 생성" 배지, 모델명, 입력 기준 시각. `output.advice_check.passed=true` 없는 성공 저장은 `23514` | `docs/products/00_MERGE_ANALYSIS.md:1278`, `docs/reviews/Stock_Trader_nomad.md:49`, `:53`, `:72` |
| ST-F-012 | 운영자 화면 | 신규 | platform_admin만. 초대 발급/회수, 베타 회수, 전역 킬 스위치(Phase 3 주문용이지만 MVP부터 둔다), 동기화 오류 현황 | 모든 쓰기가 `audit_log`에 남는다. member 계정으로 접근하면 403 | `docs/products/_platform-core/SECURITY_BASELINE.md:157-165` |
| ST-F-022 | 투자 권유 금지 검사 | 신규 | 모든 AI 출력(진단, 리서치 요약, 채팅 답변, 브리핑 대본, 위키 초안)은 사용자에게 보이거나 저장되기 전에 이 검사를 통과해야 한다. 1단계 규칙 사전(`src/content/banned.json`, ST-06-026이 만든 언어 중립 파일을 FastAPI가 빌드 때 복사해 읽는다, 한글 경계 규칙): 매수·매도·보유 권유 표현, 매수가·목표가·손절가·적정가 제시, 수익·상승 보장과 단정, 특정 시점 지시, 평가·추천 어휘, 외부 기사나 증권사 리포트가 인용한 목표주가·투자의견. 2단계 LLM 판정(기능 `stock.advice_check`, 출력 `{violations:[{type,span}]}`, 온도 0). 둘 중 하나라도 위반이면 요약 노드를 위반 목록과 함께 1회 다시 생성하고, 또 위반이면 실패 처리하고 전액 환불한다. 검사를 실행할 수 없으면(판정 모델 경로 없음, 오류) 출력하지 않는다(fail-closed). 결과 JSON에 `advice_check{passed, rules_version, judge{provider, model}, regenerations, checked_at}`를 남기고, DB는 이 기록이 없는 `succeeded` 저장을 거부한다 | 평가셋 120문장(위반 60 / 정상 60, 제안)에서 위반 차단율 98% 이상, 정상 문장 오탐 5% 이하(제안). 판정 모델 경로를 끊으면 AI 출력 0건 + 환불 1건. `advice_check` 없는 성공 저장은 `23514`. 위반 유형 7종(권유, 가격 제시, 보장, 시점 지시, 평가 어휘, 인용 목표주가, 비교 우위)마다 테스트 문장이 차단된다 | 확정 결정 13(`docs/products/_platform-core/AI_ARCHITECTURE.md:117`), `docs/reviews/Stock_Trader_nomad.md:41`, `:61` |
| ST-F-023 | 리서치 요약 그래프 `stock.research_summary` | 신규 | 사용자가 종목 1~5개와 기간(7, 30, 90일)을 고르면 `retrieve`(공시·위키 검색) → `summarize`(사실 요약: 무엇이 언제 공시되었는지, 수치는 원문 그대로) → `advice_check` → `compliance`(금지 문구, 출력 스키마, AI 표시) → `assemble` 순서로 실행한다. 출력의 문장마다 출처 id가 1개 이상 있어야 하고 출처 없는 문장은 버린다. 근거가 하나도 없으면 "근거 자료를 찾지 못했습니다". 평가·전망·비교 우위 표현은 금지. 입력은 종목코드와 기간뿐이다(보유 수량·금액·이름·계좌 미전송). 8 크레딧 선차감 | 결과 문장 출처 누락 0. 입력에 없는 종목 언급 0. 기간 밖 공시 포함 0. `core.ai_runs` 1행 + 노드별 `ai_run_steps`(retrieve, summarize, advice_check, compliance, assemble). 실패 시 환불 1행. 결과 표시 p95 30초 | `docs/products/_platform-core/AI_ARCHITECTURE.md:109-119`, 확정 결정 13 |
| ST-F-024 | 공시·뉴스 RAG | 신규 | 운영자 조직 컬렉션 `stock-disclosures`(kind `rag`)에 DART 공시를 색인한다. 메타데이터는 종목코드, 접수번호, 보고서명, 접수일, 원문 URL, 이용 조건 확인 기록. 수집 대상은 `instruments.is_active` 종목(초기 KOSPI 200, 제안), 접수일 기준 증분 수집을 매일 18:30 KST(제안)에 한다. 임베딩은 오픈소스(`stock.knowledge`, 대체 없음). 뉴스는 이용 허락 확인(D-10) 전에는 색인하지 않고, 허락된 범위의 제목·링크·언론사 표기만 보여 준다. `STOCK_RAG_SOURCES`(형식 `disclosure:<확인 기록 id>,wiki:own`, 기본 `wiki:own`)에 확인 기록 id와 함께 없는 소스는 색인 잡이 거부한다. 확인 기록은 `docs/legal/data-sources.md`(ST-06-005)에 있고 청크 메타데이터 `terms_ref`로 남긴다 | 이용 조건 확인 기록이 없는 소스의 색인 잡은 `ST_SOURCE_DISABLED`로 실패한다. 평가셋 40문항(제안)에서 재현율@8 0.8 이상. 같은 접수번호 재수집 시 중복 청크 0. 다른 조직 컬렉션 요청은 `42501`. 컬렉션당 임베딩 모델 1종 | `docs/products/_platform-core/AI_ARCHITECTURE.md:94-107`, 01_PRD 6.1절 |
| ST-F-025 | 주식 용어·공시 해설 위키 | 신규 | 해설집(운영자 집필)과 공시 정의를 원본으로 위키 ingest가 `concept`(PER, PBR, 유상증자, 감자, 전환사채, 정정공시 등), `topic`(공시 종류별 읽는 법), `index` 페이지를 `draft`로 만든다(운영자 조직, app `stock`). 종목(`entity`) 페이지는 사업 개요 같은 사실 정보에 한정하고 평가 문장을 쓰지 않는다. ingest 결과는 규칙 사전(ST-F-022 1단계)을 통과해야 draft로 저장된다. 사람이 고친 블록은 에이전트가 덮어쓰지 않고(`<!-- owner:user -->`), 저장은 `expected_version` 낙관적 잠금, 문서 1건당 갱신 페이지 5개 상한(`docs/products/_platform-core/LLM_WIKI.md:30-31`, `:47`). 열람은 로그인한 베타 사용자만(D-16). 주 1회 lint | 공개 화면에 `draft` 0. 페이지마다 "출처" 절(문서 id)과 "AI가 정리하고 운영자가 검수한 문서" 표시. 출처 없는 페이지 게시 409. `expected_version` 불일치 409. 위키 페이지 본문에 목표가·매수 권유 표현 0 | `docs/products/_platform-core/LLM_WIKI.md:12-47` |
| ST-F-026 | AI 리서치 채팅(투자 조언 아님) | 신규 | 대시보드 우측 패널과 `/research`에서 "삼성전자 최근 공시 요약해 줘", "유상증자가 뭐야" 같은 질문에 답한다. 근거는 공시 RAG와 위키뿐이고 답마다 출처 칩과 "AI 생성, 투자 권유 아님"을 표시한다. 매수·매도·보유 판단, 가격 전망, 종목 비교 우위를 묻는 질문은 정중히 거절하고 사실 요약을 대안으로 제안한다(Dify 분류 노드 + FastAPI 자체 의도 판정의 이중 확인). 보유 수량·금액·평단은 대화에 넣지 않는다. Dify는 분류와 고정 거절 문구만 만들고, 모든 생성 텍스트는 FastAPI `/tools/answer`가 만든 뒤 투자 권유 금지 검사를 통과한 것만 쓴다. 답변은 검사 통과 후 스트리밍 형태로 재생한다. 메시지 1,000자, 대화당 50턴(제안). 크레딧은 턴 선차감 후 정산(4.4절) | 평가셋 60문항(제안: 사실 질문 30 / 조언 요청 20 / 우회 시도 10)에서 조언 요청·우회 시도 30문항이 모두 거절 문구, 사실 질문 답변은 출처 1개 이상 또는 "근거 자료를 찾지 못했습니다". Dify를 막으면 `/tools/answer-direct`로 답한다. 응답이 전달되지 않은 턴은 선차감 전액 환불. 다른 사용자의 대화 id로 이어 쓰면 404 | `docs/products/_platform-core/AI_ARCHITECTURE.md:44-71`, `:121-130` |
| ST-F-027 | 음성 질의 | 신규 | 채팅 패널의 마이크 버튼(누르고 말하기, 최대 60초, 제안). STT(`voice_chat`, 오픈소스 우선) → 변환 텍스트 미리보기·수정 → 전송 → ST-F-026과 같은 규칙. 녹음 원본은 저장하지 않는다(`store_audio=false`). 첫 사용 전에 음성 처리 고지를 확인받는다(`consents.kind='voice_processing'`). 음성은 질의 입력일 뿐이며 매매·주문·연결 변경을 음성으로 지시할 수 없다. "읽어 주기"(TTS)는 DB에 저장된 검사 통과 답변만 읽는다 | 60초가 되면 녹음 자동 중지. `voice_jobs.store_audio=false` 100%. 고지 확인 없이 STT 호출 시 403. 마이크 권한을 거부해도 텍스트 채팅 정상. "주문해 줘" 같은 음성 명령은 거절 문구와 함께 주문 호출 0 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:40-48`, `:85-95`, `:106-110` |
| ST-F-028 | 브리핑 생성과 낭독 | 신규 | 사용자가 요청할 때만 만든다(정기 자동 생성·푸시 없음, D-15). 입력은 관심 종목 코드 최대 10개(보유 종목에서 고르거나 직접 입력, 수량·금액 미전송)와 기간(전일 또는 1주). 그래프 `stock.research_summary`의 `briefing` 모드가 공시 요약, 장 상태, 용어 링크를 낭독용 대본(`output.script`, 600~1,500자)으로 만든다. 대본 앞뒤에 고정 안내("AI가 생성한 음성 브리핑이며 투자 권유가 아닙니다")를 붙인다. **낭독은 `ai_reports`(kind `briefing`, status `succeeded`)의 `output.script`만 읽고(`advice_check.passed=true`를 DB가 보장), 클라이언트가 보낸 텍스트는 읽지 않는다.** 한 브리핑은 한 제공자로만 만든다(작업 도중 대체 금지, 실패 시 전체 실패 + 환불). 재생·재다운로드는 무료 | 검사 통과 전 대본으로 TTS 호출 0(임의 텍스트 요청 400). 한 낭독의 `ai_usage` 제공자가 모두 같고 `voice_jobs.fallback_from` null. 중간 실패 시 파일·크레딧 변동 없음(전액 환불 1행). 국외 이전 미동의 조직은 처음부터 오픈소스 보이스. 같은 브리핑 재요청은 기존 결과 반환(추가 차감 0) | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:44-47`, 확정 결정 16 |
| ST-F-029 | AI 라우팅과 국외 이전 동의 | 신규 | 온보딩(`/onboarding/disclaimer`)에서 "AI 처리 방식"을 고른다: 상용 AI 사용(국외 이전 동의) 또는 국내 오픈소스만. 동의하면 `core.set_ai_cross_border_ack(org, true, 고지문 버전)`(사용자 세션, owner)과 `consents(ai_overseas_transfer)`를 함께 기록하고, 설정에서 철회할 수 있다. 기능별 기본 체인은 02장 5절이며 seed와 일치한다. 동의가 없으면 모든 AI·음성 기능이 오픈소스 제공자만 쓰고 채팅 패널 상단에 "국내 오픈소스 AI로 답하고 있습니다"를 표시한다. 제품 화면에서 `set_ai_routing`을 쓰지 않는다 | 미동의 조직의 `ai_usage.provider_id`에 상용 제공자 0. 철회 직후 다음 요청부터 상용 0. 고지문 버전이 `ai_org_settings.cross_border_notice`와 `consents.version`에 같게 남는다. `dify.aux`는 동의 후에도 `oss-llm` | `docs/products/_platform-core/AI_ARCHITECTURE.md:86`, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:553-575` |
| ST-F-030 | AI 크레딧 선차감·정산 | 신규 | 채팅 턴·STT·TTS·낭독은 시작 때 예상 크레딧을 `consume_credits`로 선차감하고 끝나면 실제 사용량으로 정산한다(차액 추가 차감 또는 `refund_credits`). 진단·리서치 요약·브리핑 생성은 정액 선차감에 묶고 정산 차액이 없다(재생성과 판정 호출 비용은 정액에 포함). 투자 권유 금지 검사 실패로 결과가 나가지 않은 경우도 전액 환불한다(4.4절) | 1시간 넘게 지난 `ai_usage` 중 `settled_at is null` 0행. 같은 멱등 키 재요청 시 차감 1회. 원장 drift 0. 검사 실패 환불 1행 | `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130` |
| ST-F-031 | 3D 히어로(시세 흐름 지형) | 신규 | 랜딩(`/` 초대 전용 안내)의 히어로: PC·태블릿은 시세 흐름을 지형으로 보여 주는 풀 3D(가로 = 장 시간 구간, 깊이 = 업종, 높이 = 거래 활동의 상대 크기, 고정 시드의 샘플 데이터), 모바일은 2D 지형 단면(SVG), WebGL 미지원·저사양·`prefers-reduced-motion`은 정지 이미지(03장 4.5절). 수익률·퍼센트 숫자·상승/하락 색을 장면에 쓰지 않고 "샘플 데이터, 실제 시세 아님" 배지를 고정한다 | `HERO_3D.md` 4절 수용 기준 전부(기기 3종 동작, 번들+에셋 PC·태블릿 1MB / 모바일 300KB 이하, LCP 2.5초, 3D 전에 제목·CTA 사용 가능, 스크린샷 3종 고문 검토). 빌드 산출물과 정지 이미지에 `%` 기호와 수익 관련 단어 0 | `docs/products/_design-guide/HERO_3D.md:5-75`, `:88`, 01_PRD 6.6절 |

### 3.2 Phase 2

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| ST-F-013 | AI 관심 아이디어와 성과 평가(내부 리더보드) | 디벨롭 | 아이디어는 "관찰해 볼 종목과 이유"만 제시한다(가격 제시 없음). 성과 계산 규칙 `rule_version=idea-eval-v1`(아래 3.4) 고정. 리더보드는 같은 조직이 받은 아이디어만 모델별로 집계하고 다른 사용자와 공유하지 않는다 | 표본 20건 미만 모델은 순위를 표시하지 않고 "표본 부족". 화면마다 기간, 표본 수, 규칙 버전, "과거 성과는 미래 수익을 보장하지 않습니다" | `docs/products/00_MERGE_ANALYSIS.md:1279`, `docs/reviews/Stock_Trader_nomad.md:46`, `:73` |
| ST-F-014 | AI 3사 비교 | 디벨롭 | 같은 입력 스냅샷으로 모델 3개를 병렬 호출해 진단을 나란히 보여 준다. 모델 목록은 설정(LLM 게이트웨이 `resolveModel`)에서 읽는다 | 모델명이 코드에 하드코딩되지 않는다(검색 0건). 한 모델 실패 시 그 칸만 실패 표시, 실패분 부분 환불 | `docs/reviews/Stock_Trader_nomad.md:54`, `docs/products/_platform-core/SHARED_MODULES.md:104` |
| ST-F-015 | 실계좌 조회 연결 | 디벨롭 | spike와 약관 확인 뒤 `BROKER_LIVE_READ_ENABLED=true`. 화면 상단에 "실계좌(조회 전용)" 고정 배너. 실계좌 연결은 주문 기능을 켤 수 없다(DB CHECK) | `env='live'` 연결에 `orders_enabled=true`는 `23514` | `docs/reviews/Stock_Trader_nomad.md:81` |
| ST-F-016 | 유료 플랜 | 신규 | 법률 검토 결과에 따라 pro 플랜(월 9,900원, 제안)을 연다. 결제는 코어 Toss 흐름 | 법률 의견서 수령 전에는 `plans.is_active=false`로 결제 화면에 노출되지 않는다 | 확정 결정 4 |
| ST-F-017 | 두 번째 증권사 | 디벨롭 | 같은 `BrokerAdapter` 계약으로 추가 | 어댑터 계약 테스트(공통 스위트) 통과 | `docs/reviews/Stock_Trader_nomad.md:102` |

### 3.3 Phase 3 (선택): 모의투자 주문과 안전장치

리뷰 4.2의 8개 요구를 모두 넣고(`docs/reviews/Stock_Trader_nomad.md:77-86`), 모의투자 환경에서 검증되기 전에는 실전 주문 경로를 코드에 두지 않는다(`:60`). DB가 `env='paper'`만 허용하므로 실전 주문 행은 만들 수 없다.

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| ST-F-018 | 모의투자 주문 | 신규 | 지정가만(시장가 금지, 제안: 괴리 검사를 항상 적용하기 위해). 흐름: 주문 입력 → 서버 한도 판정 → `pending_confirm`(60초) → 사용자가 확인 화면에서 수량·가격·예상 금액을 보고 확인 → `confirmed` → 워커 제출 → 증권사 응답 반영. 클라이언트가 만든 `client_order_id`(UUID)가 멱등 키 | 같은 `client_order_id` 2회 요청은 같은 주문 1건. 60초 지나 확인하면 `expired`. 다른 사용자는 확인 불가(`42501`). AI 화면에서 넘어온 값은 입력란을 채우기만 하고 확인 단계를 건너뛰지 못한다 | `docs/reviews/Stock_Trader_nomad.md:83`, `:85` |
| ST-F-019 | 주문 한도 | 신규 | 기본값(제안): 1회 100만원, 일 500만원, 일 20건, 종목 비중 30%, 현재가 대비 괴리 5%, 시세 나이 10초. 플랫폼 상한: 1회 1,000만원, 일 5,000만원, 일 100건, 괴리 10%. owner/admin만 변경, 변경은 감사 | 상한 초과 설정은 `23514`. 한도 위반 주문은 예외가 아니라 `blocked` 행과 `block_reason`(`max_order_krw`, `max_daily_krw`, `max_orders_per_day`, `price_deviation`, `quote_stale`, `kill_switch`)으로 남는다 | `docs/reviews/Stock_Trader_nomad.md:82` |
| ST-F-020 | 킬 스위치 | 신규 | 범위 전역/조직/연결. 수동: 조직 멤버 누구나 켤 수 있고 owner/admin만 끈다. 자동(워커): 시세 60초 끊김, 증권사 오류 연속 3회, 잔고 불일치(주문 후 예상 잔고와 동기화 잔고 차이 1% 초과, 제안). 자동·전역 스위치는 service_role만 해제. 켜지는 순간 대기/확인 주문은 `blocked` | 스위치가 켜진 뒤 생성 주문은 전부 `blocked/kill_switch`(스모크 테스트). 사용자가 전역 스위치 해제 시도 시 `42501` | `docs/reviews/Stock_Trader_nomad.md:84` |
| ST-F-021 | 주문 감사 | 신규 | 모든 요청, 한도 판정, 확인, 증권사 응답을 `order_events`(append-only)에 남긴다. 비밀값, 계좌번호 원문 금지 | `order_events` UPDATE/DELETE는 `ST000` | `docs/reviews/Stock_Trader_nomad.md:86` |

### 3.4 성과 계산 규칙 `idea-eval-v1` (ST-F-013)

리뷰 #8이 요구한 항목(진입 시점, 보유 기간, 수수료·세금, 기준 지수)을 고정한다(`docs/reviews/Stock_Trader_nomad.md:46`). 모두 제안이며 규칙을 바꾸면 `rule_version`을 올리고 이전 결과는 다시 계산하지 않는다.

| 항목 | 규칙 | 이유 |
|---|---|---|
| 진입 | 아이디어 생성 시각 다음 개장일의 시가 | 생성 시점 이후 가격만 써서 사후 선택(look-ahead)을 막는다 |
| 평가 시점 | 진입일로부터 5, 20, 60 개장일 뒤 종가 | 단기/중기/장기 구분(`PRD.md:33`)을 거래일로 고정 |
| 수익률 | `(평가 종가 / 진입 시가 - 1) x 100`, 수수료·세금 미반영 | 증권사별 요율 차이를 피한다. 화면에 "수수료·세금 미반영" 명시 |
| 기준 지수 | 같은 기간 코스피 지수(내부 코드 `IDXKSP`) 수익률. 초과수익 = 수익률 - 지수 수익률 | 시장 전체 상승분과 구분 |
| 거래정지·상장폐지 | 평가일 직전 마지막 종가로 평가하고 표시 플래그 | 결측으로 빼면 성과가 부풀려진다 |
| 집계 | 모델별 평균 초과수익, 중앙값, 승률(초과수익 > 0 비율), 표본 수 | 평균만 쓰면 이상치에 흔들린다 |
| 최소 표본 | 20건 미만이면 순위 미표시 | 소표본 과장 방지 |
| 가격 데이터 | `daily_prices`(사용자에게 노출하지 않음). 출처와 라이선스는 6장 | 시세 재배포 제한 |

## 4. 요금과 크레딧

정본 출처: 확정 결정 8에 stock 항목이 없으므로 이 절이 정본이다. 모듈러 `seed.sql`의 stock 행은 default 플랜만 있으므로(`docs/products/_supabase-modular/seed.sql:41`) beta/pro는 `1900_stock.sql`이 보충하고, 모놀리스는 `supabase/monolith/seed.sql`이 넣는다. 금액과 크레딧은 모두 제안이다.

### 4.1 플랜

| 코드 | 가격 | 월 크레딧 | 가입 크레딧 | 이월 | 상태 | features |
|---|---|---|---|---|---|---|
| `default` | 0원 | 0 | 0 | - | invite 앱이라 가입 트리거는 부여하지 않는다. 초대 수락 시 서버가 service_role로 `bootstrap_app_for_org('stock', org)`를 호출해 부여(2026-10-13 코어 반영). 기능 없음(베타 게이트에 막힘) | `{}` |
| `beta` | 0원 | 300 | 0 | 안 함 | 초대 수락 시 서버가 전환 | 아래 표 |
| `pro` | 9,900원/월(제안: 개인 도구 가격대, 법률 검토 뒤 확정) | 600 | 0 | 안 함 | `is_active=false`. 법률 의견 수령 전 판매 금지 | 아래 표 |

크레딧팩은 두지 않는다. AI 진단을 건별로 파는 구조는 "투자 조언을 대가를 받고 제공"으로 해석될 위험을 키우기 때문이다(제안, 6.1절).

### 4.2 크레딧 단가

| 작업 | 크레딧 | 근거 |
|---|---|---|
| AI 포트폴리오 진단(quality) | 10 | 제안: 월 300 크레딧으로 하루 1회 꼴(30회) 사용을 가정 |
| AI 관심 아이디어(Phase 2) | 10 | 제안: 진단과 같은 입력 크기 |
| AI 3사 비교(Phase 2) | 25 | 제안: 3회 호출을 묶어 1/6 할인 |
| 동기화, 시세, 재무지표, CSV | 0 | 원가가 증권사/DART 호출뿐이고 횟수 제한으로 관리 |

AI·음성 단가(리서치 요약, 채팅, 브리핑, STT, TTS)는 4.4절이다.

차감 순서는 코어 규약 그대로다: `consume_credits` 선차감 → 호출 → 실패 시 `refund_credits`(`docs/products/_platform-core/CORE_SPEC.md:172-183`). 멱등 키 `consume:stock:<request_id>`.

### 4.3 `core.plans.features` 키 해석

| 키 | 타입 | 의미 | beta | pro |
|---|---|---|---|---|
| `ai_diagnosis_per_day` | number | 조직당 하루(KST) AI 진단·아이디어 생성 합계 상한 | 10 | 20 |
| `broker_connections_max` | number | `status <> 'revoked'` 연결 수 상한 | 2 | 3 |
| `ai_modes` | string[] | 허용 LLM 모드(fast/quality) | `["quality"]` | `["fast","quality"]` |
| `ai_compare` | boolean | ST-F-014 사용 | false | true |
| `ideas` | boolean | ST-F-013 아이디어 생성 | false | true |
| `leaderboard` | boolean | 내부 리더보드 화면 | false | true |
| `paper_orders` | boolean | ST-F-018 모의주문(서버 플래그 `ORDERS_ENABLED`와 AND) | false | true |
| `history_days` | number | 스냅샷·리포트 조회 기간 | 365 | 730 |
| `ai_chat` | boolean | AI 리서치 채팅 허용. 키가 없으면 true로 읽는다 | true | true |
| `ai_chat_turns_per_day` | number | 사용자당 하루 채팅 턴 상한(공정 사용). 키가 없으면 100 | 100 | 200 |
| `ai_research_per_day` | number | 조직당 하루(KST) 리서치 요약·브리핑 생성 합계 상한. 키가 없으면 20 | 20 | 40 |
| `voice_chat` | boolean | 음성 질의와 읽어 주기 허용. 키가 없으면 true | true | true |
| `briefing` | boolean | 브리핑 생성·낭독 허용. 키가 없으면 true | true | true |

AI 키 5개는 2026-10-13에 추가했다. 모놀리스는 `supabase/monolith/seed.sql`의 beta, pro 행에, 모듈러는 `docs/products/_supabase-modular/migrations/1900_stock.sql` 14.3절의 병합 UPDATE에 있다(모듈러 `seed.sql` 반영은 06장 6절 R-6).

서버만 읽는다(`docs/products/_platform-core/CORE_SPEC.md:135`). 베타 접근 자체는 features가 아니라 `beta_access` 행으로 판정한다.

### 4.4 AI·음성 크레딧 단가 (2026-10-13, 제안)

진단 단가(4.2절)와 플랜(4.1절)은 바꾸지 않는다. 제공자 단가는 코어 seed `core.ai_model_prices`(`docs/products/_supabase-modular/seed.sql:228-246`: LLM 상용 1k 입력 1cr·출력 4cr, 오픈소스 0.2·0.5cr, STT ElevenLabs 3cr/분·오픈소스 0.5cr/분, TTS ElevenLabs 5cr/천 자·오픈소스 1cr/천 자, 모두 제안값)이고, 이 표는 그 값을 stock 기능에 적용한 것이다. 계산 상수는 `apps/stock-dashboard/src/server/ai-pricing.ts`(코드 상수). 선차감과 정산 규칙은 `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130`, 음성 단가는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104`를 따른다.

| 작업 | 선차감(예상) | 정산 | 상용 경로 예 | 오픈소스 경로 예 | 멱등 키 |
|---|---|---|---|---|---|
| 포트폴리오 진단(그래프 `stock.diagnosis`) | 10(정액) | 차액 없음. 재생성·판정 호출 비용 포함, 초과분은 운영사 부담. `ai_usage`에 원가를 기록하고 실행 끝에 `settled_at`을 채운다 | Claude 우선 | `oss-llm` | `consume:stock:<request_id>` |
| 리서치 요약(그래프 `stock.research_summary`) | 8(정액) | 같음 | 같음 | 같음 | `consume:stock:<request_id>` |
| 브리핑 생성 | 10(정액) | 같음 | 같음 | 같음 | `consume:stock:<request_id>` |
| AI 리서치 채팅 1턴 | 5 | 실제 토큰 x 단가 + Dify 보조 노드 오버헤드 0.5, 올림. 최소 1, 상한 8(초과분은 운영사 부담) | 공시 청크 8개 기준 약 5~7 | 약 2 | `conv:<id>:turn:<n>` |
| 음성 질의 STT(60초 이하) | 오픈소스 1, ElevenLabs 3 | 실제 `audio_seconds` | 3 | 1 | `voice:<voice_job_id>` |
| 답변 읽어 주기 TTS | 답변 글자 수 x 단가, 천 자 단위 올림 | 실제 `characters` | 600자 답변 5 | 600자 답변 1 | `voice:<voice_job_id>` |
| 브리핑 낭독 | 대본 글자 수 x 단가, 천 자 단위 올림 | 실제 `characters` | 1,500자 8 | 1,500자 2 | `voice:<voice_job_id>` |
| 낭독 재생·재다운로드, 위키 열람 | 0 | - | - | - | - |
| 공시 색인, 위키 ingest·lint | 사용자 과금 없음. 운영자 조직 지갑에서 사용량 차감 | 사용량 | - | - | `run:<id>` |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 경로별 단가 | 국외 이전에 동의하지 않은 조직은 체인에 오픈소스만 남으므로 오픈소스 단가가 자동 적용된다. 화면은 실제로 고른 경로의 예상치를 보여 준다 | `docs/products/_supabase-modular/migrations/0008_core_ai.sql:452-460` |
| 실패 환불 | 사용자에게 결과가 전달되지 않은 실패는 전액 환불한다. 투자 권유 금지 검사 실패(재생성 후에도 위반, 판정 불가)로 결과를 저장·표시하지 않은 경우도 같다. 브리핑 낭독은 한 부분이라도 실패하면 전체 실패 | `docs/products/_platform-core/AI_ARCHITECTURE.md:129` |
| 정산 시점 | 응답·작업 종료 직후. 스트림이 끊기면 선차감을 남기고 정산 잡이 `settled_at is null` 행을 5분 주기로 처리(제안) | `docs/products/_platform-core/AI_ARCHITECTURE.md:128` |
| 표시 | 보내기 전 "약 5크레딧(정산 후 1~8)", 낭독 버튼에 예상치, 정산 결과는 메시지 아래와 원장 표에 | 제안 |
| 공정 사용 | 사용자당 하루 채팅 턴(`features.ai_chat_turns_per_day`), 조직당 하루 요약·브리핑(`ai_research_per_day`), 진단(`ai_diagnosis_per_day`)을 따로 센다 | 제안 |
| 월 300 크레딧 예산(beta) | 진단 10회(100) + 요약 10회(80) + 브리핑 3회(30) + 채팅 20턴 안팎(약 90)을 한 달에 쓸 수 있는 규모 | 제안 |

## 5. 비기능 요구사항

모두 제안이다. 리뷰 #14가 지적한 장 시간, 지연, 장애 동작을 수치로 정한다(`docs/reviews/Stock_Trader_nomad.md:52`).

| 항목 | 목표 | 이유 |
|---|---|---|
| 대시보드 LCP | p75 2.5초 이하 | Core Web Vitals 기준 |
| 시세 반영 지연 | 증권사 틱 수신 → 브라우저 반영 p95 1초 이하 | 중계 1홉(워커 → SSE) 기준 |
| 시세 지연 배지 | 장중 마지막 틱 10초 초과 "지연", 60초 초과 "시세 끊김" | 리뷰 #14 |
| 동기화 주기 | 장중 5분, 장외 60분, 체결 15:40 KST, 수동 60초당 1회 | 증권사 호출 한도 미확인이라 보수적 |
| AI 진단 | 상태 표시 1초, 결과 표시 p95 30초, 전체 60초 타임아웃. 투자 권유 금지 재생성은 1회, 제공자 대체는 라우터 체인 | 검사 통과 후에만 표시하므로 토큰 스트리밍 없음(ST-F-011). 값은 제안 |
| AI 리서치 요약·브리핑 | 요청 → 결과 표시 p95 30초, 전체 60초 타임아웃, 입력 종목 5개(브리핑 10개) | 제안: 검색 + 요약 + 검사 2단계 |
| AI 채팅 | 질문 → 답변 표시 p95 15초(검사 포함), 상태 표시 1초, Dify 장애 판정 10초 | 제안: 답변이 길지 않은 요약 중심 |
| 투자 권유 금지 검사 | 규칙 단계 100ms 이하, LLM 판정 포함 p95 4초 | 제안 |
| 음성 | 10초 이하 발화의 STT 결과 p95 5초, 브리핑 낭독 시작 p95 8초(대본 저장 후) | 제안 |
| AI 입력 상한 | 채팅 메시지 1,000자, 대화당 50턴, 음성 발화 60초·5MB, 요약 종목 5개, 브리핑 종목 10개 | 제안 |
| AI 레이트 리밋 | 채팅 사용자당 20턴/분 + 하루 `ai_chat_turns_per_day`, 요약·브리핑 조직당 분당 3회 + 하루 `ai_research_per_day`, STT 사용자당 10회/분, 낭독 조직당 5회/시간, 서명 토큰 발급 사용자당 120회/분 | `docs/products/_platform-core/SECURITY_BASELINE.md:143-155` 기준 + 제품 값(제안) |
| 3D 히어로 | 3D 번들+에셋 PC·태블릿 1MB, 모바일 300KB 이하, 60fps / 30fps 이상, LCP 2.5초 | `docs/products/_design-guide/HERO_3D.md:32-41` |
| AI 기록 보존 | Dify 대화 로그 30일, `core.ai_messages`는 대화 삭제 또는 탈퇴 후 30일, 리서치·브리핑 리포트는 `history_days` | `docs/products/_platform-core/AI_ARCHITECTURE.md:69`(제안 30일) |
| 동시 SSE 연결 | 베타 100(사용자당 탭 3개까지) | 초대 30명 x 탭 3 + 여유 |
| 가용성 | 베타 99.5%(월 3.6시간 이내 중단) | 무료 베타 |
| 레이트 리밋 | 로그인/가입 IP당 10회/10분, 초대 수락 IP당 10회/10분, AI 진단 조직당 분당 3회 + 일 `ai_diagnosis_per_day`, 연결 생성 조직당 시간당 5회, 스트림 토큰 사용자당 분당 30회 | `docs/products/_platform-core/SECURITY_BASELINE.md:143-155` 기준 + 제품 값 |
| 보존 | 잔고 스냅샷·AI 리포트 `history_days`(365일), 체결과 메모는 연결 유지 기간 전체, 연결 해제 시 자격증명 즉시 폐기 + 데이터 30일 뒤 삭제, 탈퇴 시 조직 soft delete 30일 뒤 `purge_organization`, 감사 로그 2년, `order_events` 3년 | `docs/products/_platform-core/SECURITY_BASELINE.md:197`, `CORE_SPEC.md:330`. 주문 이벤트는 분쟁 대비로 더 길게 |
| 장애 시 화면 | 증권사 오류면 마지막 성공 스냅샷을 "기준 시각"과 함께 보여 주고 mock으로 대체하지 않는다 | `docs/products/_platform-core/SECURITY_BASELINE.md:188` |
| 키 교체 | `CREDENTIALS_KEY_V<n>` 추가 → 재암호화 워커 → 구 키 제거, 분기 1회 | `docs/products/_platform-core/CORE_SPEC.md:275` |

## 6. 법, 개인정보, 금지 문구

이 절은 법률 자문이 아니다. "미확인"은 조문·약관 원문을 확인하지 않은 항목이며, 출시 전 금융 규제 전문 변호사 검토(ST-06-005)를 받는다.

### 6.1 금융 규제 특례 (규제 특례 항목)

| 쟁점 | 내용 | 제품 설계 | 상태 |
|---|---|---|---|
| 투자자문업(자본시장법, 금융위 등록) | 특정인에게 개별 포트폴리오에 맞춘 투자판단 조언을 영업으로 하면 투자자문업 등록 대상이 될 수 있다. 원본의 "포폴분석"이 해당될 수 있다고 리뷰가 지적 | AI 진단은 "현재 상태 설명"(집중도, 업종 노출, 위험 요인)만 한다. 매수·매도 권유, 매수가·목표가·손절가를 내지 않는다(DB CHECK `ai_reports_no_price_targets_check` + 금칙어 검사). 베타는 무료다 | 해석 미확인. 전문가 검토 필요 |
| 유사투자자문업(자본시장법, 금융위 신고) | 불특정 다수를 대상으로 간행물·통신물 등으로 투자판단 조언을 업으로 하면 신고 대상. 개별 종목 매수가·목표가·손절가 제공은 이 영역이라고 리뷰가 지적. 최근 법 개정으로 유사투자자문업자의 온라인 양방향 채널(1:1 대화형) 영업이 제한되었다고 알려져 있다 | MVP와 Phase 2 모두 개별 종목 가격 제시 없음. 공개 리더보드·공개 랜딩의 성과 노출 없음. 유료화(ST-F-016)는 "신고 또는 등록이 필요한지" 의견서 수령 후에만 | 개정 내용과 적용 범위 미확인 |
| 마이데이터(신용정보법 본인신용정보관리업, 허가제) | 타인의 여러 금융회사 계좌를 모아 보여 주는 서비스는 마이데이터 영역과 겹친다 | 스크래핑 영구 제외. 사용자가 **본인 명의 계좌**에 대해 증권사가 개인에게 발급한 API 키를 직접 입력하는 구조. 다른 사람 계좌 연결 기능 없음. 연결 화면에 "본인 계좌만 연결" 동의 체크 | 이 구조가 허가 대상이 아닌지 미확인. 전문가 검토 필요 |
| 시세 정보 이용·재배포 | 거래소 시세를 받은 자가 다른 사용자에게 재배포하면 시세 이용 약관과 충돌할 수 있다(리뷰 #6) | 플랫폼 공용 시세 피드를 두지 않는다. 시세는 각 사용자 본인 연결로 받아 그 사용자에게만 보낸다. 서버에 틱을 저장하지 않는다. 일봉(`daily_prices`)은 성과 계산 전용으로 사용자 GRANT 없음. 화면에 "시세 출처: 연결한 증권사, 지연 가능" 표기 | 증권사 Open API 약관의 제3자 서비스 이용 허용 여부, KRX 일봉 데이터 이용 조건 미확인 |
| 증권사 Open API 약관 | 개인 키를 제3자 서비스에 입력하는 것, 호출 한도, 자동화 허용 범위 | spike(ST-06-004)에서 약관 원문 확인을 수용 기준에 포함. 약관이 금지하면 그 증권사는 쓰지 않는다 | 미확인 |
| 주문(Phase 3) | 자동매매·주문 대행이 투자일임 또는 투자중개 영역과 겹칠 수 있다 | 모의투자만, 사람 확인 필수, AI는 주문을 만들지 않는다. 실전 주문은 범위 밖 | 미확인 |
| AI 리서치 요약·채팅·브리핑(2026-10-13) | AI가 종목별 공시를 요약해 주는 것이 "투자판단에 관한 조언"으로 해석되면 유사투자자문업(불특정 다수 대상)이나 투자자문업(개별 맞춤) 쟁점이 될 수 있다. 요약 대상 선택, 어휘, 개인 보유 내역 반영 여부가 해석에 영향을 줄 수 있다(미확인) | (1) 사실 요약만 하고 평가·전망·비교 우위·가격 제시는 만들지 않는다(D-11). (2) 모든 출력에 투자 권유 금지 검사(ST-F-022)를 필수 단계로 둔다. (3) 보유 수량·금액·평단은 AI 입력에 넣지 않는다. (4) 무료 초대 베타로 한정하고 유료화(ST-F-016)는 법률 의견서 뒤에만 연다. (5) 브리핑은 사용자 요청 시에만 만들고 푸시하지 않는다(D-15). (6) 모든 결과에 "AI 생성, 투자 권유 아님" 고지 | 유사투자자문업 해당 여부 법률 의견 미수령(D-3, ST-06-005에 질의 포함). 해석 미확인 |
| 공시·뉴스 데이터 이용 | DART 오픈API와 거래소 공시의 상업 서비스 내 가공·저장·검색 이용 조건, 언론사 기사의 저작권(복제·요약·링크)은 확인하지 않았다 | 이용 조건 확인 기록이 있는 소스만 색인한다(`STOCK_RAG_SOURCES`, ST-F-024). 뉴스 본문은 저장하지 않고 허락된 범위의 제목·링크·출처 표기만(D-10). 원문 URL과 접수번호를 항상 출처로 표시. 공시 원문은 공개 정보라도 제3자 사이트 약관을 확인 | DART·KIND 약관, 언론사 약관 미확인(D-10) |

### 6.2 개인정보

| 항목 | 내용 |
|---|---|
| 수집 항목 | 이메일, 표시 이름(코어 프로필), 로그인 제공자 식별자(단계별, 2026-10-14: B Google 계정 식별자·이름·프로필 이미지 URL, C를 켜면 카카오 회원번호·닉네임·프로필 이미지·(비즈 앱이면) 이메일, 네이버 고유 id·이메일·이름. 제공자 토큰은 저장하지 않음, `docs/products/_platform-core/AUTH_ROADMAP.md:208`, `:292`), 증권사 API 키·접근 토큰(암호문), 계좌번호 마스킹 값과 HMAC 해시, 잔고·보유·체결 내역, 매매 메모, 동의 기록, AI 진단 입력 요약과 결과 |
| 목적 | 본인 계좌 조회 화면 제공, 매매 일지, AI 진단, 보안 감사 |
| 성격 | 잔고·체결 내역은 신용정보법상 개인신용정보에 해당할 수 있어(미확인) 민감 정보 수준으로 다룬다 |
| 암호화 대상 | API 키·토큰(`encrypted_credentials.ciphertext`, AES-256-GCM, `SECURITY_BASELINE.md` 5장). 계좌번호 원문은 저장하지 않는다(HMAC 키 `ACCOUNT_HASH_KEY`) |
| 보존·삭제 | 5장 보존 표. 연결 해제 → `revoke_credential`로 암호문 즉시 비움 → 30일 뒤 연결 데이터 삭제. 탈퇴 → 조직 soft delete → 30일 → `purge_organization` |
| 제3자 제공·국외 이전 | 상용 AI 제공자(LLM: Anthropic, OpenAI, Google, OpenRouter / 음성: ElevenLabs)는 온보딩에서 국외 이전에 동의한 조직의 요청에만 쓴다(2026-10-13, ST-F-029). 진단에는 종목코드, 종목명, 비중(%), 평가손익률(%), 업종, 재무지표를 보낸다. 리서치 요약·채팅·브리핑에는 종목코드, 기간, 질문 텍스트(마스킹 후), 공개 자료 청크를 보낸다. 음성은 STT 오디오(상용 경로일 때)와 낭독할 대본을 보낸다. 보내지 않는 것: 계좌번호, 금액 원값, 보유 수량, 평단, 이름, 이메일, 키. 임베딩은 오픈소스 서버에서만 한다(`stock.knowledge`). 오픈소스 LLM·임베딩·음성 서버와 Dify는 운영사가 자체 운영한다(서버 위치·위탁 여부 구현 시 확인). 동의하지 않으면 오픈소스 제공자만 쓴다. 개인정보처리방침에 이전받는 자, 국가, 항목, 보유 기간을 적는다 |
| 열람·내보내기 | 매매 일지 CSV, 계정 설정의 "내 데이터 내려받기"(JSON) |
| 로그 | 애플리케이션 로그에 키, 토큰, 계좌번호, 금액 원값을 남기지 않는다(마스킹 유틸 필수, `SECURITY_BASELINE.md:199`) |
| AI 대화 기록 | `core.ai_messages`(본인만 열람, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`)와 Dify 대화 로그(운영사 자체 호스팅, 30일 보존, 조직 데이터 저장소로 관리, `docs/products/_platform-core/AI_ARCHITECTURE.md:69`). 대화 삭제·탈퇴 시 30일 안에 둘 다 삭제. 사용자가 입력한 질문에 계좌번호·주민등록번호 형식이 있으면 서버가 마스킹한 뒤 저장·전송한다(제안) |
| 음성 | 녹음 원본은 저장하지 않는다(`store_audio=false`). 첫 마이크 사용 전 처리 목적·원본 미저장·상용 제공자 사용 시 국외 이전을 고지하고 `consents(voice_processing)`로 남긴다. 제3자 목소리가 담기는 기능(강의 녹음 등)이 없어 `third_party_notice` 동의는 쓰지 않는다 |

### 6.3 약관과 고지

| 문서 | 필수 내용 |
|---|---|
| 이용약관 | 정보 제공 서비스이며 투자 권유가 아님, 투자 판단과 손실 책임은 이용자 본인, 시세 지연 가능성, 증권사 장애 시 데이터 지연, 베타 서비스 중단 가능성, 본인 계좌만 연결 |
| 개인정보처리방침 | 6.2절 전부, 국외 이전 항목 |
| 투자 고지(화면 상시) | 대시보드 하단 고정: "이 화면은 정보 제공용이며 투자 권유가 아닙니다. 과거 수익률은 미래 수익을 보장하지 않습니다." AI 결과 상단: "AI가 생성한 진단입니다. 사실과 다를 수 있으며, 특정 종목의 매수·매도를 권하지 않습니다." |
| AI 생성 표시 | 결과마다 "AI 생성" 배지, 모델명, 생성 시각, 입력 기준 시각, 고지 버전. 채팅 답변마다 "AI가 생성한 답변, 투자 권유 아님", 위키 페이지에 "AI가 정리하고 운영자가 검수한 문서", 브리핑 음성은 첫머리와 끝에 "AI가 생성한 음성 브리핑이며 투자 권유가 아닙니다"를 읽고 플레이어에도 표시 |
| 샘플 데이터 표시 | `mock` 연결과 `is_sample=true` 행은 모든 숫자 옆에 "샘플 데이터" 배지(리뷰 #18) |
| AI 입력창 안내 | 채팅 입력창 위: "이 AI는 공시와 용어를 요약합니다. 매수·매도 판단이나 가격 전망은 하지 않습니다. 계좌번호와 개인정보는 적지 마세요." |

### 6.4 제휴·광고

이 제품은 제휴 링크와 광고를 두지 않는다. affiliate 공용 모듈의 소비 제품이 아니며(확정 결정 12), 금융 화면에 대가성 링크를 섞으면 투자 권유로 오인될 수 있다(제안).

### 6.5 플랫폼 약관과 사용자 동의

| 대상 | 위험 | 동의/조치 |
|---|---|---|
| 증권사 Open API | 약관 위반 시 키 정지, 계정 제한(미확인) | 연결 화면에서 "증권사 약관에 따라 키가 정지될 수 있음"과 "본인 계좌만 연결" 체크. spike 결과 금지되면 그 증권사 미지원 |
| LLM 제공자 | 국외 이전 | `ai_overseas_transfer` 동의 |
| 음성 제공자(ElevenLabs) | 국외 이전, 입력 보관·학습 사용 조건 미확인 | `ai_overseas_transfer` 동의 + `voice_processing` 고지. 보관·제로 리텐션 조건은 계약 확인 뒤 처리방침에 반영(D-14) |
| DART·언론사 | 데이터 이용 조건, 저작권 | D-10 결정 전 본문 색인 금지 |
| 모의주문(Phase 3) | 사용자가 모의와 실전을 혼동 | `paper_order_risk` 동의, 화면 상단 "모의투자" 고정 배너 |

### 6.6 금지 문구 (마케팅, 화면, AI 출력 공통)

| 금지 | 예 | 대체 |
|---|---|---|
| 수익 보장·확정 표현 | "확정 수익", "100% 수익", "손실 없는", "반드시 오른다" | 표현 자체를 쓰지 않는다 |
| 허위·미검증 수치 | 원본 PRD의 "+52.23%" 같은 예시 수익률(`PRD.md:41`), 미검증 사용자 수·누적 수익 | 실제 측정값만, 기간·표본·규칙 버전과 함께 |
| 가상 후기·평점 | 존재하지 않는 투자자 후기, "수익 인증" | 베타 기간에는 후기 영역 자체를 두지 않는다 |
| 투자 권유·단정 | "지금 사세요", "매도하세요", "강력 매수", "목표가 9만원", "손절가" | "비중이 높습니다", "변동성이 큰 업종입니다" 같은 상태 설명 |
| 성과 비교 과장 | "AI가 시장을 이긴다", 모델 순위를 공개 광고에 사용 | 내부 리더보드만, 표본 부족 시 순위 미표시 |
| 실존 종목 목업의 무표시 노출 | 원본 지시의 "-83.13%" 같은 극단 목업 수치(`claude.md:31`)를 배지 없이 표시 | "샘플 데이터" 배지 필수 |
| 타사 상표 오용 | 증권사 로고·상표를 제휴처럼 사용, 서비스명 "InvestGEN"의 상표 확인 전 사용 | 증권사명은 연결 대상 표기로만. 브랜드명은 8장 D-6 결정 |
| 의료·금융 단정 | "안전한 종목", "위험 없는" | 위험 수준 낮음/중간/높음과 판정 기준 표시 |
| AI 전망·평가 표현 | "상승 여력이 큽니다", "저평가", "수혜주", "유망", "추천 종목", "지금이 기회" | 공시에 적힌 사실과 날짜만("2026-10-01 유상증자 결정 공시"). 평가 어휘 사전 차단 |
| 인용된 목표주가·투자의견 | 기사나 증권사 리포트가 말한 "목표주가 9만원", "매수 의견"을 요약에 옮기기 | 인용도 금지. 출처 링크로만 안내 |
| 3D·카피의 수익 약속 | 히어로에 수익률 숫자, 우상향 곡선, "내 자산이 자라는" 같은 은유 | 지형은 거래 활동의 상대 크기이며 상승/하락 색·퍼센트를 쓰지 않는다. "샘플 데이터" 배지 필수 |
| 음성 브리핑 어조 | 확신에 찬 권유 어조("꼭 확인하세요 지금 사야")나 감정 유도 | 중립 낭독 보이스, 대본은 검사 통과분만 |

AI 출력은 서버 금칙어 검사(정규식 사전, 한글 경계 처리)와 LLM 판정으로 이루어진 투자 권유 금지 검사(ST-F-022)를 통과해야 저장·표시된다. 걸리면 1회 재생성, 다시 걸리면 실패 처리하고 환불한다(`docs/products/_platform-core/SHARED_MODULES.md:345`의 규칙 사전 방식을 제품 범위에서 사용). 같은 사전 파일(`src/content/banned.json`)을 Next.js와 FastAPI compliance 노드가 함께 읽는다.

### 6.7 AI 대화 규칙과 개인정보 판단 (2026-10-13)

| 항목 | 판단·규칙 | 이유와 처리 |
|---|---|---|
| 보유 내역의 AI 입력 | 진단에만 비중(%)·손익률(%)·업종을 쓰고, 리서치·채팅·브리핑에는 종목코드만 쓴다 | 잔고·체결 내역은 개인신용정보에 해당할 수 있어(미확인) 최소화한다. 개별 맞춤 조언으로 읽힐 여지를 줄인다 |
| 진단 경로 | 오픈소스 강제(`force_open_source`)를 걸지 않고 국외 이전 동의로 통제한다(D-13 권고) | 진단 품질이 신뢰의 핵심. 입력이 비식별 비율이며 동의 없는 조직은 `resolve_ai_route`가 상용을 걸러 낸다(`docs/products/_supabase-modular/migrations/0008_core_ai.sql:452-456`) |
| Dify 보조 노드 | 오픈소스 강제(`dify.aux`) | 조직을 알 수 없어 동의를 확인할 수 없다 |
| 질문 자유 입력 | 입력창에 "계좌번호·개인정보 입력 금지" 안내. 서버가 계좌번호·주민등록번호·전화번호·이메일 형식을 마스킹한 뒤 보낸다(제안) | 사용자가 보유 현황을 적을 수 있다 |

| 사용자 요청 | 응답 규칙 |
|---|---|
| 매수·매도·보유 여부, 목표가, 손절가, 비중 조절을 묻는 질문 | 정중히 거절하고 "공시 요약, 용어 설명, 위험 요인 설명은 도와드릴 수 있습니다"를 안내한다. 우회 시도("만약 너라면", "가상으로", "친구에게 한다면")도 같다 |
| 종목 비교 우위, 어느 쪽이 더 오를지 | 거절. 각 종목의 공시 사실을 나란히 요약하는 대안을 제안 |
| 특정 사건(유상증자 등)이 주가에 미칠 영향 | 사실과 용어만 설명하고 주가 영향 판단은 하지 않는다 |
| 손실로 힘들다, 빚으로 투자했다는 호소 | 투자 답변을 멈추고 금융 상담·긴급 상담 창구를 안내한다(번호·기관은 구현 시 확인) |
| 개인정보(계좌번호, 주민등록번호)를 묻거나 입력 | 묻지 않고, 입력되면 마스킹한다 |
| 음성으로 주문·연결 변경 지시 | 거절. 음성은 질의 입력이다 |

## 7. KPI

모두 제안이다(베타 목표).

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| 초대 수락률 | 70% 이상 | `beta_invites` accepted / issued | 베타 8주 |
| 연결 완료율 | 수락자의 80%가 연결 1개 이상(mock 포함) | `broker_connections` status active 보유 조직 비율 | 베타 8주 |
| 주간 활성 | 연결 보유 조직의 60%가 주 1회 이상 대시보드 방문 | 서버 로그(세션당 1회 집계) | 주 단위 |
| 동기화 성공률 | 99% 이상 | `core.jobs` `stock.sync` succeeded / 전체 | 일 단위 |
| 시세 지연 | 장중 "지연" 배지 노출 시간 비율 1% 미만 | 워커 지표 | 일 단위 |
| AI 진단 성공률 | 97% 이상(환불 건 3% 미만) | `ai_reports` succeeded / 전체 | 주 단위 |
| AI 진단 재사용 | 진단 사용 조직의 50%가 2회 이상 | `ai_reports` 조직별 건수 | 베타 8주 |
| 금칙어 차단 | 저장된 AI 결과 중 금칙어 0건 | 주간 샘플 감사 | 주 단위 |
| 보안 사고 | 키·계좌번호 노출 0건 | 로그 스캔, 번들 검색 | 상시 |
| AI 리서치 요약 성공률 | 97% 이상(환불 건 3% 미만) | `ai_reports` kind research·briefing succeeded / 전체 | 주 단위 |
| 투자 권유 금지 | 저장된 AI 결과 중 `advice_check.passed` 누락 0건, 주간 샘플 감사에서 권유·가격 표현 0건 | DB 조회 + 샘플 50건 감사 | 주 단위 |
| 조언 요청 거절률 | 평가셋 조언·우회 질문 30문항 100% 거절 | 평가셋 회귀(ST-06-046) | 배포마다 |
| 출처 있는 답변 | 사실 질문 답변의 95% 이상이 출처 1개 이상 | `core.ai_messages.citations` | 주 단위 |
| 음성 사용 | 활성 조직의 20%가 음성 질의 또는 브리핑 낭독 1회 이상 | `core.voice_jobs` | 베타 8주 |

## 8. 열린 결정

| ID | 결정 사항 | 선택지 | 권고 |
|---|---|---|---|
| D-1 | 모놀리스 스키마 | `public`(MONOLITH_CORE_LITE 규칙) / 별도 스키마 | `public`. 사용자 최종 확인 대기 |
| D-2 | 첫 증권사 | 한국투자증권 KIS Developers / 키움 REST / 하나증권 | spike(ST-06-004)로 결정. 개인 개발자용 REST + WebSocket + 모의투자 서버가 확인되는 곳(리뷰 #5 권고). 세 곳 모두 지원 여부 미확인 |
| D-3 | 유료화, 유사투자자문업 법률 의견 | 무료 유지 / pro 판매 | 법률 의견서(유사투자자문업 신고·투자자문업 등록 필요 여부, AI 요약·브리핑 범위 포함) **수령 전까지 무료이고 초대제 베타 게이트를 유지한다.** 의견이 오기 전에는 AI 범위를 사실 요약에서 넓히지 않는다 |
| D-4 | Phase 3 주문 | 진행 / 보류 | 보류 권고. 조회·진단 KPI 확인 후 별도 결정 |
| D-5 | 상승/하락 색 | 한국 관례(상승 빨강, 하락 파랑) / 원본(수익 녹색, 손실 적색, `claude.md:8`) | 한국 관례(`REFERENCES.md:207`). **미결로 유지한다.** 03장의 값은 잠정이고, 토큰을 의미 이름(`--color-up`, `--color-down`)으로 두어 결정 뒤 값만 바꾼다. 3D 지형과 AI 화면은 이 두 색을 쓰지 않는다 |
| D-6 | 브랜드명 | InvestGEN / 새 이름 | 상표 확인 전 InvestGEN 사용 보류 |
| D-7 | 베타 규모와 초대 발급자 | 30명 / 100명 | 30명, 발급은 platform_admin만 |
| D-8 | 코어 `invite` 정책 강제 | 코어에서 차단 / 제품 게이트 유지 | 제품 게이트는 유지한다. 코어 `invite` 강제는 2026-10-13 반영 완료(06장 6절) |
| D-9 | 대체거래소(NXT) 시간대 반영 | 반영 / 미반영 | 미확인. Phase 2에서 시세 출처가 정해진 뒤 검토 |
| D-10 | 공시·뉴스 데이터 이용 허락 | (a) DART 공시만 색인, 뉴스는 허락된 범위의 제목·링크·출처 표기만 (b) 뉴스 제휴·라이선스 계약 뒤 본문 색인 (c) 뉴스 제외 | (a). DART 오픈API 이용약관(상업 서비스에서의 가공·저장·검색), KRX KIND 이용 조건, 언론사 저작권 모두 미확인. 확인 기록이 없으면 색인 잡이 거부한다(ST-F-024). 결정 전 ST-06-041은 공시 중 약관이 확인된 범위만 수집 |
| D-11 | AI 요약의 범위 | (a) 공시 사실 요약만 (b) 시장 해설·전망 포함 | (a)로 고정. (b)는 법률 의견(D-3)에서 허용 범위가 확인된 뒤 Phase 2 이후 |
| D-12 | 투자 권유 금지 검사 구성 | (a) 규칙 사전 + LLM 판정 2단, 판정 불가 시 출력하지 않음 (b) 규칙 사전만 (c) LLM 판정만 | (a). 규칙은 결정적이고 LLM은 우회 표현을 잡는다. 오탐이 많으면 사전·평가셋을 조정(ST-06-040) |
| D-13 | 진단 입력의 LLM 경로 | (a) 국외 이전 동의 기반 + 입력 최소화(비율만) (b) 오픈소스 강제 | (a)(제안). (b)를 고르면 02장 5.1절 `stock.diagnosis`, `stock.advice_check` 행을 `open_source` + 강제로 바꾸고 진단 평가셋을 오픈소스 경로로 다시 통과시킨다 |
| D-14 | 음성 제공자 조건 | ElevenLabs 입력 보관·학습 사용·제로 리텐션 여부, 브리핑·읽어 주기 보이스 선택, 오픈소스 TTS 후보 | 보이스는 ElevenLabs 기본 1종 + 오픈소스 1종 고정(환경변수). 후보 라이선스는 `VOICE_ARCHITECTURE.md` 4.1절에서 코드·가중치 각각 확인(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:63-73`, `:75-83`). 확인 전까지 처리방침에 보관 조건을 단정하지 않는다 |
| D-15 | 브리핑 제공 방식 | (a) 사용자 요청 때만 생성 (b) 정시 자동 생성·푸시 | (a). (b)는 불특정 다수에게 보내는 통신물로 해석될 소지가 있어 법률 의견 뒤 |
| D-16 | 위키 공개 범위 | (a) 로그인한 베타 사용자만 (b) 공개(SEO) | (a). 공개 랜딩을 법률 검토 뒤로 미룬 것과 일관 |
| D-17 | 채팅 화면 레퍼런스 Astryx | 존재·라이선스 확인 뒤 패턴만 사용 / 확인 실패 시 Primer + shadcn/ui 패턴 | 확인 전까지 미확인(`docs/products/_design-guide/DESIGN_SYSTEM.md:11`). ST-06-035에서 확인 결과를 기록 |
| D-18 | 랜딩 3D 지형의 데이터 | (a) 고정 시드 샘플 + "샘플 데이터" 배지 (b) 실제 시세·시장 데이터 | (a). (b)는 시세 재배포 제한(6.1절)과 수익 약속 오인 위험 때문에 법률·약관 확인 뒤 |

### 8.1 인증 단계 결정 (2026-10-14, 확정 결정 22)

확정 결정 22(`docs/products/00_MERGE_ANALYSIS.md:30`)와 정본 `docs/products/_platform-core/AUTH_ROADMAP.md`를 이 제품에 적용한 결과다. 이 제품은 invite 앱이라 B단계 로그인은 "초대 링크 수락 + Google"(+기존 이메일)이고, 카카오·네이버(C)는 P2 선택이다(`AUTH_ROADMAP.md:333`). 기존 결정(초대제, ST-F-001 초대 토큰 흐름, `beta_access` 게이트, 1인 1워크스페이스)은 바꾸지 않았다.

| 단계 | 언제 | 로그인 수단 | 이 제품에서 바뀌는 것 |
|---|---|---|---|
| A | W0부터 G1까지(MVP 개발) | 로컬 시드 페르소나 원클릭(`POST /api/dev/login`). 초대 수락·미수락 페르소나 포함 | 개발용 패널과 `MOCK AUTH · 로컬 전용` 배지. 초대 토큰 발급·수락 RPC는 실제 경로 그대로 |
| B | G1 통과 후, 초대 베타 공개 전(P0) | `/invite/[token]`에서 "Google로 계속하기" 또는 기존 이메일 가입·로그인. `/login`은 Google + 이메일 | 초대 이메일과 다른 Google 계정이면 `ST031` + "초대받은 이메일로 로그인하세요" |
| C1, C2 | G2 통과 후(P2 선택) | 카카오, 네이버 | 초대 수락 규칙(이메일 일치) 그대로. 이메일 없는 카카오 계정은 초대를 수락할 수 없다 |

| ID | 결정 사항 | 선택지 | 권고 |
|---|---|---|---|
| D-19 | C단계(카카오·네이버) 착수 시점 | (a) G2 직후 착수 (b) 작업(ST-06-053, 054)은 P2 선택으로 계획에 두고 착수는 사용자 판단 | (b)(제안: 초대 30명 안팎(D-7)이고 초대 수락이 이메일 일치를 요구하므로 초대 베타 동안은 Google·이메일로 충분하다). 공개 전환(D-3 법률 의견 이후) 때 다시 판단 |
| D-20 | 카카오 이메일 정책(C1을 켤 때) | (a) 비즈 앱 전환 후 `account_email` 필수 (b) 이메일 없이 허용 | (a)(`AUTH_ROADMAP.md:249`). 이 제품은 초대 수락에 이메일 일치가 필요하므로 (b)로는 초대를 수락할 수 없다 |
| D-21 | 네이버 경로(C2를 켤 때) | `supabase_custom`(`custom:naver`) / 서버 브리지 | C2 첫 단계 스파이크(`AUTH_ROADMAP.md:275-284`) 결과로 정하고 `[DECISION]`으로 기록 |
| D-22 | 매직링크 유지 | (a) 03장 1절 `/login` 표기대로 B단계 이메일 수단에 포함 (b) 제외(이메일+비밀번호만) | 미결. AUTH_ROADMAP 1장은 매직링크를 로드맵 범위 밖(다른 제품의 연기 결정, `docs/products/00_MERGE_ANALYSIS.md:317`)으로 두지만 이 제품의 기존 화면 표기를 바꾸지 않았다. 무료 크레딧 반복 수령 문제(연기 사유)는 초대제라 해당하지 않는다. ST-06-052 착수 전 확정 |
| D-23 | OAuth 왕복 중 초대 토큰 보관 | (a) `next=/invite/<token>` (b) HttpOnly·SameSite=Lax 쿠키(10분)에 두고 `next=/invite/continue` | (b)(제안: 토큰이 리디렉트 URL·인증 서버 로그에 남지 않게). 쿠키는 HttpOnly·Secure·HMAC 서명이고 수락 직후 삭제한다 |
