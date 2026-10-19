# 01 PRD: FLORA Publishing

2026-10-13 개정: 확정 결정 13~17(`docs/products/00_MERGE_ANALYSIS.md:21-25`)에 따라 AI 계층(책별 RAG, 책 설정집 위키, LangGraph 초안 그래프, Dify 글쓰기 도우미 채팅), 음성(받아쓰기, 채팅 음성, 원고 낭독·오디오북 미리듣기), 상용/오픈소스 모델 이원화와 국외 이전 동의, 3D 히어로를 MVP에 넣었다. 설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `docs/products/_design-guide/HERO_3D.md`, `DESIGN_SYSTEM.md`이고 이 문서는 제품 요구만 정한다. 새 기능 ID는 PB-F-044~056, 새 열린 결정은 D12~D19다.

2026-10-14 FLORA 개편(검토용): 외부 제안서 "FLORA Publishing — UI/UX 및 AI 에이전트 통합 디자인 제안서"(ChatGPT 작성, 대표님 전달)를 기존 결정과 대조해 반영했다. 유지한 것: 교육 커리큘럼은 이 제품 범위가 아니다(2장 마지막 행), 랜딩은 실제 책 결과물 중심(기존 03장 4절 A안과 같은 방향), 기존 집필·출판 기능은 그대로 두고 에이전트는 그 위의 실행·검수 계층이다. 새로 넣은 것: 에이전트 실행 계층과 검수(PB-F-057, 058), 에이전트 작업 공간(PB-F-059), 에디터 AI 패널(PB-F-060), 운영 콘솔(PB-F-061), Phase 2 워크플로 빌더·콘텐츠 에이전트(PB-F-062, 063), 열린 결정 D23~D27. 제안서의 색·서체·헤드라인은 기존 확정 토큰과 충돌하므로 덮어쓰지 않고 D23~D25로 올렸다. 제품 표는 `publishing.agent_tasks` 1개만 더했다(05장 2.5절).

작성일 2026-10-12. 근거 표기: 리뷰는 `docs/reviews/<이름>.md:줄`, 분석은 `docs/products/00_MERGE_ANALYSIS.md:줄`(아래 "분석:줄"로 줄임), 원본은 저장소 루트 기준 경로. 원본·리뷰에 근거가 없는 수치는 "제안"으로 표시하고 이유를 적었다.

## 1. 페르소나와 핵심 과제

| 이름 | 상황 | 목표 | 좌절 | 근거 |
|---|---|---|---|---|
| 김서연(41, 에세이스트) | 블로그와 노트에 쓴 산문 원고가 100편 넘게 있다. 편집·조판 경험은 없다 | 원고를 B6 수필집 판형의 인쇄용 PDF로 묶어 소량 인쇄하고 ePub도 만든다 | 워드로 만든 PDF는 제본 여백이 없고, 무료 변환기는 한글이 깨지거나 쪽번호가 안 맞는다 | `Flora-v2/PRD.md:21`, `docs/reviews/Flora-v2.md:68`, `docs/reviews/SellingDocs.md:58` |
| 박준호(34, IT 실무자) | 사내 강의 자료를 실용서로 정리해 전자책 플랫폼에 등록하려 한다 | 키워드와 예상 독자만으로 목차를 받고, 챕터별 초안을 자동 생성한 뒤 다듬어 ePub으로 등록한다 | 생성형 AI 대화창으로는 책 한 권 분량이 중간에 끊기고, 챕터 사이 문체가 흔들린다 | `flora-publisher/frontend/docs/prd/02_user_flow.md:21-31`, `:56-60`, `docs/reviews/SellingDocs.md:51` |
| 이하은(27, 웹소설 지망생) | 단편 여러 편을 묶은 단편집을 만들고 싶다. 월 구독료는 1만 원 이하만 감당할 수 있다 | 페르소나 문체를 고르고, 막히는 문단만 AI에게 이어쓰기를 시킨 뒤 직접 고친다 | 고가 구독(월 ₩60,000~₩100,000)은 부담스럽고, 쓴 만큼만 내고 싶다 | `flora/PRD.md:48`, `Flora-v2/PRD.md:305-307`, 분석:228-231 |

| # | 핵심 과제 | 이 제품이 해결하는 방식 |
|---|---|---|
| J1 | 원고(또는 아이디어)를 책의 구조(챕터, 소제목, 단락)로 만든다 | 10단계 위저드(판형 → 장르 → 페르소나 → 제목 → 기획안 → 목차 → 집필 → 표지 → 책 정보 → 완성), 업로드 경로는 파싱 결과를 목차로 자동 매핑 |
| J2 | 판형에 맞는 인쇄용 PDF와 표준 ePub을 한 번에 얻는다 | WeasyPrint(CSS Paged Media) + Noto CJK 렌더 서비스, ePub3 빌더. 미리보기와 PDF가 같은 HTML 템플릿을 쓴다 |
| J3 | 문체가 일관된 원고를 끊기지 않고 끝까지 생성한다 | 페르소나 Taste를 서버에서 모든 호출에 주입, 전체 순차 생성은 서버 잡(섹션 단위 저장, 재시도 3회, 실패 섹션만 표시) |

## 2. 범위: MVP와 Phase

확정 결정 7 "출판: 전자책만"(분석:15)을 넘는 범위는 MVP에 넣지 않는다.

| 기능 | 범위 | 근거 |
|---|---|---|
| 인증, 조직, 세션, 라우트 보호 | MVP. 로그인은 단계로 켠다(2026-10-14): MVP 개발은 Mock(Stage A, 로컬 시드 계정), 공개 베타 전 Google(+이메일)(Stage B, P0), 카카오·네이버는 G2 후(Stage C, C1 카카오 P1, C2 네이버 P1) | 확정 결정 5, 22, `docs/reviews/Flora-v2.md:61-62`, `docs/products/_platform-core/AUTH_ROADMAP.md` 0장, 8장 |
| 10단계 전자책 위저드(판형, 장르, 페르소나, 제목, 기획안, 목차, 집필, 표지, 책 정보, 완성) | MVP | 확정 결정 7, `Flora-v2/PRD.md:41-56` |
| 원고 업로드 경로(txt, md, docx, pdf) | MVP | 분석:116-117. HWP는 열린 결정(8장) |
| 전체 순차 생성(서버 잡) | MVP | 분석:98 |
| 원고 에디터와 마이크로 프롬프트(이어쓰기, 살붙이기, 다듬기) | MVP | 분석:99 |
| PDF(WeasyPrint), ePub3 내보내기, 워터마크 서버 강제 | MVP | 분석:108, :111, :112 |
| AI 표지(fal, 3후보) | MVP | 분석:104 |
| 크레딧팩 + 저가 구독(Toss) | MVP | 확정 결정 4, 8 |
| 시드 3종 복제, 테마 7종, 진행바·Confetti | MVP | 분석:118, :121, :122 |
| 나만의 페르소나 합성(텍스트 샘플) | MVP(P1) | 분석:90 "프로 이상 기능" |
| 옴니버스(단편집) 모드 | MVP(P1) | 분석:97 "우선순위 낮음" |
| 아웃바운드 웹훅(`book.completed`, `export.*`) | MVP(P1) | 분석:139, :243 "자동화는 아웃바운드 웹훅 하나만" |
| 책별 자료 RAG(참고 파일, 원고 색인) | MVP | 확정 결정 13(`docs/products/00_MERGE_ANALYSIS.md:21`), PB-F-045 |
| 책 설정집 위키(캐릭터, 용어, 문체) | MVP | 확정 결정 13, `docs/products/_platform-core/LLM_WIKI.md:37-47`, PB-F-046 |
| AI 초안 그래프 `publishing.draft`(개요 → 초안 → 일관성 → 교정 → compliance) | MVP(Basic) | 확정 결정 13, PB-F-047 |
| 글쓰기 도우미 채팅(Dify 앱 `publishing-chat`) | MVP | 확정 결정 13, 14(`docs/products/00_MERGE_ANALYSIS.md:21-22`), PB-F-049 |
| 받아쓰기(STT), 채팅 음성 | MVP | 확정 결정 16(`docs/products/00_MERGE_ANALYSIS.md:24`), PB-F-050, PB-F-051 |
| 원고 낭독, 오디오북 미리듣기(TTS) | MVP(Basic) | 확정 결정 16, PB-F-052 |
| 상용/오픈소스 모델 이원화, 온보딩 국외 이전 동의 | MVP | 확정 결정 17(`docs/products/00_MERGE_ANALYSIS.md:25`), `docs/products/_platform-core/AI_ARCHITECTURE.md:86`, PB-F-044 |
| 랜딩 3D 히어로(원고 낱장 → 제본 → 책장 넘김) | MVP | 확정 결정 15(`docs/products/00_MERGE_ANALYSIS.md:23`), `docs/products/_design-guide/HERO_3D.md:82`, PB-F-055 |
| 에이전트 실행 계층(작업 1건 = `agent_tasks` 1행, 6개 에이전트로 기존 기능 묶기)과 검수 대기함·실행 이력 | MVP(P0) | 2026-10-14 FLORA 개편, PB-F-057, PB-F-058. 관리자 실행 추적·재실행·원가 집계가 이 행을 기준으로 한다 |
| 에이전트 작업 공간에서 새 작업 시작(에이전트 선택 → 범위 → 예상 크레딧 → 실행) | MVP(P1) | PB-F-059. 같은 동작은 위저드·에디터에서도 할 수 있으므로 P1 |
| 에디터 3단 레이아웃(목차·원고·AI 패널)과 AI 패널 추가 동작 3종 | MVP(P1) | PB-F-060 |
| 운영 콘솔(운영 홈, 작업 큐·실행 추적, 재실행, 원가, 사용자·권한, 출판 프로젝트, 설정 열람, 감사) | MVP(P1) | PB-F-061(PB-F-005 확장) |
| 워크플로 빌더(React Flow 노드 캔버스, 고급 사용자), 운영자용 실행 그래프 보기 | Phase 2 | PB-F-062. 일반 작가가 노드 편집기를 배우지 않아도 책을 만들 수 있어야 하고, 작업형 에이전트가 안정된 뒤 붙인다(제안서 5절) |
| 콘텐츠 에이전트(승인된 원고 → 소개문·홍보 글) | Phase 2 | PB-F-063. 외부 게시 기능이 MVP에 없고 책 소개 200자는 PB-F-022가 이미 만든다 |
| 비로그인 AI 상담(랜딩 채팅) | Phase 2 | 제안: 비로그인 상담은 운영자 예산과 강한 레이트 리밋이 필요하다(`docs/products/_platform-core/AI_ARCHITECTURE.md:130`) |
| 공개 책 페이지 + Book JSON-LD + GEO 랜딩 메타 | Phase 2 | 분석:114, :159, :269-273 |
| 번역 | Phase 2 | 분석:102 |
| 페르소나 합성의 음성 샘플 STT | Phase 2 | 분석:90. 음성 처리 비용과 동의 절차를 MVP에서 뺀다(제안) |
| 오디오북 전권, 멀티보이스, 등장인물 추출, 보이스 클로닝 | Phase 2(TTS 엔진은 확정 결정 16으로 정해졌다. 미리듣기는 아래 MVP) | 분석:129-131, :245-249, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:80` |
| 판매·정산 | Phase 3 이후(결정 필요) | 분석:157, :269-273 |
| 사진집, 룩북, AI 캔버스, n8n, Typst, DOC | 폐기 | 분석:138-142, :109-110. `07_SOURCE_MIGRATION.md` 3절 |
| 교육 프로그램(주차별 커리큘럼, 강의, 멤버십) | 범위 제외(별도 사업) | 2026-10-14 대표님 결정(제안서 머리말): 이 제품은 교육 사이트가 아니라 작가가 직접 책을 만드는 SaaS다. 랜딩·화면에 주차·강의 구성을 넣지 않는다. 서비스가 활성화되고 운영 데이터가 쌓인 뒤 별도 수익화 모듈로 검토한다 |

## 3. 기능 요구사항과 수용 기준

ID 접두사 `PB`(`docs/products/_platform-core/DB_CONVENTIONS.md` 1장 SQLSTATE 접두사와 같다). "크레딧"은 4장 단가표를 따른다.

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| PB-F-001 | 가입/로그인 | 통합 | 단계로 켠다(확정 결정 22, `docs/products/_platform-core/AUTH_ROADMAP.md`). Stage A(MVP 개발): 로컬 Supabase 시드 페르소나로 실제 JWT를 받는 Mock 로그인만(AUTH_ROADMAP 2장, `/login` 개발용 패널, 배포 환경에서 `/api/dev/login` 404). 쿠키 역할 Mock 금지, 개발용 로그인은 AUTH_ROADMAP 2장의 로컬 시드 계정만. Stage B(공개 베타 전, P0): Google OAuth + 이메일(`@supabase/ssr` 브라우저 클라이언트의 `signInWithPassword`, `signUp({options:{data:{signup_app:'publishing'}}})`, 이메일 인증 필수). OAuth 첫 로그인은 콜백 `finishLogin`이 `bootstrap_app_for_org('publishing')`를 1회 부른다. Stage C(G2 후): 카카오(C1, P1, D6 해소), 네이버(C2, P1) | Stage A: `owner` 페르소나 로그인 직후 `core.session_context('publishing')`이 `entitled=true`, `plan_code='free'`, `credit_balance=20`을 돌려준다. 로그인 후 `/dashboard`가 열리고 새로고침해도 유지된다. Stage B: 이메일 가입 직후와 새 Google 계정 첫 로그인 모두 같은 결과(재로그인 3회 뒤에도 가입 크레딧 1회)와 AUTH_ROADMAP 5.3절 B-1~B-6. Stage C: 7.1.3절 C1-1~C1-5, 7.2.4절 C2-1~C2-6 | 분석:74, `docs/reviews/Flora-v2.md:61`, `CORE_SPEC.md:70-80`, 확정 결정 22 |
| PB-F-002 | 콜백 리다이렉트 검증 | 디벨롭 | `/auth/callback`의 `next`는 `/`로 시작하고 `//`, `@`, `\`가 없는 경로만 허용. 검증은 `finishLogin`(AUTH_ROADMAP 3.2절 5번) 한 곳에서 하고 Stage A `/api/dev/login`도 같은 함수를 거친다 | `next=@evil.com`, `next=//evil.com`, `next=https://evil.com`, `next=/\evil.com` 요청은 `/dashboard`로 보낸다(B-2) | `docs/reviews/Flora-v2.md:71`, `:141` |
| PB-F-003 | API 인증 경계 | 디벨롭 | 모든 Route Handler는 `requireSession('publishing')`로 시작한다. 공개 예외는 `/api/waitlist`, `/api/webhooks/*`, `/health`뿐. FastAPI 엔진과 렌더 서비스는 공개 인터넷에서 호출되지 않고 내부 토큰을 요구한다 | 토큰 없이 LLM, 업로드, 내보내기 API를 호출하면 401. 엔진 내부 엔드포인트를 토큰 없이 호출하면 401 | `docs/reviews/Flora-v2.md:63`, `docs/reviews/flora.md:68`, `SHARED_MODULES.md:259` |
| PB-F-004 | 대기자 명단 | 유지(v2) | 출시 전 랜딩에서 이메일 수집. 실제 수만 표시하고 시드 수치를 넣지 않는다. IP당 5회/시간(제안: 스팸 방지 최소치) | 같은 이메일 2회 등록은 200 + "이미 등록됨". 카운트 API는 `publishing.waitlist` 행 수와 같다 | 분석:79, `docs/reviews/flora.md:82` |
| PB-F-005 | 운영자 화면 | 디벨롭 | `/admin`은 `profiles.platform_role='platform_admin'`만. 이메일 하드코딩 금지. 지표: 가입 수, 활성 책 수, 내보내기 수, 렌더 실패율, 크레딧 drift. 수동 크레딧 조정과 플랜 변경은 service_role 서버 경로 + 감사 로그. 메뉴와 실행 추적·원가·재실행은 PB-F-061(2026-10-14 확장) | 일반 사용자가 `/admin` 접근 시 404. 수동 조정 1건마다 `core.audit_log` 1행 | 분석:78, `docs/reviews/Flora-v2.md:89`, `SECURITY_BASELINE.md` 9장 |
| PB-F-006 | 위저드 10단계 | 통합 | v2 10단계 순서. 완료한 단계만 클릭 이동. 단계 진입 시 `books.current_step`, `step_state`를 2초 debounce로 저장 | 7단계에서 브라우저를 닫고 다시 열면 같은 책의 7단계가 열린다. `projectId='new'` 같은 공유 키가 없다 | `Flora-v2/PRD.md:41-56`, `docs/reviews/Flora-v2.md:79`, `Flora-v2/CLAUDE.md` "use-auto-save 2초" |
| PB-F-007 | 판형 선택 + Auto-Fit | 통합 | 6종 키(A6, B6, A5, shinkuk, B5, A4_variant), 판형별 본문 pt·행간·여백 프리셋, Auto-Fit 미세조정(본문 ±1pt, 여백 ±5mm, 제안). 안쪽 여백 > 바깥 여백 3~5mm 규칙은 미세조정 후에도 강제 | 미세조정으로 안쪽 여백이 바깥+3mm 미만이 되면 슬라이더가 멈추고 안내 문구가 뜬다. 같은 설정이 미리보기와 PDF에 같게 반영된다 | 분석:86, `Flora-v2/PRD.md:476-485`, `flora/PRD.md:179-189` |
| PB-F-008 | 장르 선택 | 유지 | 장르 8종(소설, 에세이, 시, 자기계발, 논픽션·비즈니스, IT·기술서, 동화, 판타지) | 선택한 장르가 `books.genre`에 저장되고 페르소나 탭 기본값이 된다 | `Flora-v2/PRD.md:65-68` |
| PB-F-009 | 페르소나 60종 | 디벨롭 | 60종을 JSON 단일 소스로 두고 프론트와 서버가 같은 파일을 읽는다. 실존 작가 이름 금지. Free는 40종, Basic은 60종(`features.personas`) | 60종 전부 서버 프롬프트에 문체 지시가 있다(빈 문자열 0건). Free 사용자가 41번째 이후 페르소나로 집필을 요청하면 403 | `docs/reviews/Flora-v2.md:77`, `Flora-v2/CLAUDE.md` "실존 작가 이름 절대 금지", `Flora-v2/PRD.md:312` |
| PB-F-010 | 페르소나 보관함/즐겨찾기 | 디벨롭 | 즐겨찾기(최대 60)와 최근 사용을 `publishing.member_settings`에 저장 | 다른 브라우저에서 로그인해도 즐겨찾기가 같다 | 분석:91 |
| PB-F-011 | 나만의 페르소나 합성 | 디벨롭(P1) | Basic 이상. 기준 페르소나 최대 3개 + 텍스트 샘플(최대 5,000자, 제안: 프롬프트 길이 상한)로 Taste 합성. 결과는 `custom_personas`에 서버가 저장 | Free에서 호출하면 403 `plan_required`. 합성 1회 3크레딧 차감, 실패 시 환불 행 1개 | 분석:90, `docs/reviews/Flora-v2.md:66` |
| PB-F-012 | 어조 슬라이더 | 유지(v1 이식) | 문장 길이, 어조, 리듬 3축 5단계. Basic 이상. 값은 `books.tone` | Free 화면에서 잠금 표시, API는 Free 요청의 tone 값을 무시하고 기본값을 쓴다 | 분석:92, `flora/PRD.md:48` |
| PB-F-013 | AI 제목 추천 | 유지 | 장르+페르소나+기획 방향으로 후보 3~5개(제목, 부제, 추천 이유). 직접 입력 가능 | 1회 1크레딧. 응답이 JSON 스키마를 어기면 1회 재시도 후 실패 + 환불 | `Flora-v2/PRD.md:76-80` |
| PB-F-014 | 기획안 3종 | 통합 | synopsis, logline, theme, characters + 입력 "타겟 독자", "강조 톤"(SD 6필드 중 2개). 탭 비교 후 1종 선택, 인라인 편집 | 선택본이 `books.plan_brief`에 저장된다. 1회 2크레딧 | 분석:94, `구현해야 할 프로젝트/SellingDocs/PRD.md:52` |
| PB-F-015 | 목차 3종 + 편집 | 통합 | 챕터 수(1~20), 소제목 수(챕터당 1~10), 단락 수(소제목당 1~5) 설정 → 목차 3종 → 선택 후 드래그 정렬·인라인 편집. 플랜 한도: Free 챕터 3·소제목 합계 6·단락 3 | Free 사용자가 4번째 챕터를 추가하면 DB가 `PB002`를 내고 화면에 "Free는 챕터 3개까지" 안내. 1회 2크레딧 | `Flora-v2/PRD.md:88-93`, 분석:95, `flora-publisher/frontend/docs/prd/02_user_flow.md:31` |
| PB-F-016 | 섹션 단건 집필 | 유지 | 소제목 1개를 스트리밍 생성(fetch POST + ReadableStream). 완료 시 서버가 sanitize 후 `sections.body_html` 저장. 2026-10-14: 본문이 이미 있는 소제목(`overwrite=true`)은 저장하지 않고 제안(Diff)으로만 돌려준다(PB-F-058) | 생성 중 연결이 끊겨도 서버가 끝까지 받아 저장하고, 다시 열면 본문이 보인다. fast 1크레딧, quality 3크레딧(2026-10-14 2 → 3, 4.3절) | 분석:96, `docs/reviews/Flora-v2.md:105` |
| PB-F-017 | 전체 순차 생성 | 디벨롭 | Basic 이상. 서버 잡이 챕터 단위로 그래프 `publishing.draft`(PB-F-047)를 실행하고 섹션 단위로 저장(2026-10-13). 책당 동시 3섹션, 섹션 재시도 3회(지수 백오프), 실패 섹션만 표시, 진행률은 Realtime. 이미 본문이 있는 섹션은 건너뛴다(덮어쓰기 옵션 별도). 취소 시 대기 섹션은 환불 | 15섹션 책에서 2개가 3회 실패하면 실행 상태 `partial`, 13개 저장, 2개 `failed`, 차감 = 성공 섹션분만(실패분 자동 환불). 취소 요청 후 60초 안에 새 섹션 생성이 멈춘다 | 분석:98, `flora-publisher/frontend/docs/prd/03_features.md:83-97`, `docs/reviews/Flora-v2.md:67`, `:122` |
| PB-F-018 | 원고 에디터 + 마이크로 프롬프트 | 디벨롭 | Tiptap. 선택영역 플로팅 툴바(이어쓰기, 살붙이기, 다듬기, 직접 명령), `/` 명령, 결과 Diff 카드(삽입/대체/재생성/취소). 저장 HTML은 서버 sanitize(허용 태그 목록) | `<script>`, `on*` 속성, `javascript:` 링크가 저장 후 사라진다. 선택영역 2,000자 초과는 청크로 나뉜다. 1회 1크레딧 | 분석:99, `flora-publisher/frontend/docs/prd/03_features.md:110-131`, `docs/reviews/SellingDocs.md:55` |
| PB-F-019 | 전체 다듬기 | 통합 | v1 "AI 고도화"를 대체. 원고 전체를 2,000자 청크로 나눠 순서대로 다듬고, 섹션별 Diff로 수락/거절. Basic 이상 | 3만 자 원고 → 15청크 처리, 마지막 1,000자만 처리되는 결함이 재현되지 않는다(청크 수 = 결과 수). 청크당 1크레딧 | 분석:100, `docs/reviews/flora.md:77` |
| PB-F-020 | 옴니버스 모드 | 유지(v1 이식, P1) | 집필 옵션 하나. 챕터를 독립 단편으로 보고 앞 챕터 요약을 프롬프트에 넣지 않는다 | 옵션을 켠 책의 섹션 생성 요청에 이전 챕터 요약이 포함되지 않는다(서버 로그 확인) | 분석:97, `flora/api/routers/llm.py:298`, `:472` |
| PB-F-021 | AI 표지 | 통합 | 스타일 5종, 3후보 동시 생성(fal 비동기 + 웹훅), 결과를 Storage `org-files`로 복사, 제목·저자 오버레이는 HTML/CSS로 렌더(이미지에 글자를 굽지 않음). 안전 필터 켬 | 3후보 6크레딧. 1장이라도 실패하면 실패분만 환불. 후보 선택 시 `books.cover_image_id` 저장, 다른 책의 표지 id는 `PB006` | 분석:104, `SHARED_MODULES.md:228-249` |
| PB-F-022 | 책 정보 생성 | 디벨롭 | 서버가 DB에서 제목, 기획안, 원고 앞 3,000자(제안: 토큰 비용 상한)를 읽어 부제, 키워드 5개, 소개글 200자, 출판사, ISBN 형식(참조용)을 생성 | ISBN 칸 옆에 "형식 참조용이며 실제 등록 번호가 아닙니다" 고지. 원고가 없는 책은 409 `manuscript_empty`. 1회 1크레딧 | 분석:105, `docs/reviews/Flora-v2.md:78`, `Flora-v2/PRD.md:115` |
| PB-F-023 | HTML 조립과 미리보기 | 통합 | 서버(FastAPI 엔진)가 DB 원고를 읽어 v1 템플릿으로 HTML 조립(병합 포함). 모든 텍스트 escape, 본문 HTML 재-sanitize. 미리보기 iframe은 sandbox + 같은 HTML | 미리보기 첫 3쪽과 PDF 첫 3쪽의 줄바꿈 위치가 같다(판형 6종 골든 테스트) | 분석:106-107, :113, `docs/reviews/flora.md:78` |
| PB-F-024 | PDF 내보내기 | 통합 | 렌더 잡(`render.pdf`) → WeasyPrint 서비스 → Storage `exports`. `@page` 판형, `:left/:right` 제책 여백, `:first` 표지 무쪽번호, `counter(page)` 쪽번호, `string-set` 러닝 헤더, 점선 목차, `orphans/widows 2`. 같은 원고·설정(content_hash)의 7일 내 재요청은 재과금 없이 기존 파일 | 한글 본문 200쪽 PDF가 120초 안에 생성되고 두부 문자 0개. 2크레딧. 실패 시 환불 행 1개 | 분석:108, `WeasyPrint - CSS Paged Media 명세.md:13-125`, `SHARED_MODULES.md:251-275` |
| PB-F-025 | ePub3 내보내기 | 통합 | v1 ePub3 빌더 이식. XML escape, 식별자 uuid5(책 id 기반), 표지 바이너리 포함, nav 문서, 한글 폰트 임베딩(라이선스 허용 폰트만) | epubcheck 오류 0건. 같은 책 2회 내보내기의 `dc:identifier`가 같다. 1크레딧 | 분석:111, `docs/reviews/flora.md:93` |
| PB-F-026 | 워터마크 강제 | 디벨롭 | 서버가 `features.watermark`를 읽어 렌더 옵션을 결정. 클라이언트 파라미터 무시. Free는 월 내보내기 2회(`exports_per_month`) | Free 계정이 `watermark=false`로 요청해도 PDF 모든 쪽에 워터마크. 3번째 내보내기는 403 `plan_limit` | 분석:112, `docs/products/_supabase-modular/seed.sql:33` |
| PB-F-027 | 원고 업로드 | 디벨롭 | 서명 업로드 URL로 Storage `org-files`에 직접 업로드 → 완료 통지 → 서버가 크기(20MB)·MIME·매직바이트 재검사 → 파싱 잡. 경로는 서버 생성 `<org>/publishing/manuscripts/<uuid>.<ext>`, 원래 파일명은 표시용만 | 25MB 파일은 413, 확장자를 바꾼 실행 파일은 415. 파싱 결과 챕터·소제목 목록이 60초 안에 보인다. 원본 파일은 파싱 24시간 뒤 삭제 | 분석:116, `docs/reviews/Flora-v2.md:66`, `:75`, `SECURITY_BASELINE.md` 10장 |
| PB-F-028 | 업로드 후 기획 검토 | 유지(v2) | 파싱 구조를 목차로 매핑하고 제목·기획안을 간소화 제안(4·5단계 축약) | 업로드 책의 6단계 목차가 파싱 구조와 같다. 7단계에 원문이 보인다 | 분석:117, `Flora-v2/PRD.md:139-150` |
| PB-F-029 | 시드 3종 복제 | 유지(v2) | 시드 원고 3종을 서버가 새 책으로 복제(`source='seed'`). 크레딧 없음 | 복제한 책이 내 책 목록에 생기고 Free 한도(3권)에 포함된다 | 분석:118, `Flora-v2/PRD.md:252-258` |
| PB-F-030 | 책 목록과 자동 저장 | 통합 | 목록(최근 수정순, 상태 필터), 소프트 삭제(휴지통 30일), 자동 저장은 DB 2초 debounce 하나 | 휴지통의 책은 30일 뒤 영구 삭제. localStorage 초안은 오프라인 임시본으로만 쓰고 서버 값이 우선 | 분석:119-120, `docs/reviews/flora.md:97` |
| PB-F-031 | 진행바와 완성 연출 | 유지(v2) | 원형 10단계 진행바, 완성 시 Confetti 1회(`prefers-reduced-motion`이면 생략) | 감소 모션 설정에서 Confetti가 실행되지 않는다 | 분석:121, `Flora-v2/DESIGN.md` 3.1절 |
| PB-F-032 | 화면 테마 7종 | 유지(v2) | 3종 basic, 4종 pro. 잠금은 DB 트리거가 강제 | Free가 Pro 테마를 저장하면 `PB008` | 분석:122, `Flora-v2/PRD.md:227-237` |
| PB-F-033 | Taste-Skill 서버 합성 | 디벨롭 | 프롬프트 합성(Taste + Skill + 어조)을 서버 한 곳에서. Taste는 집필 시작 후 잠금 | `status <> 'draft'`인 책의 페르소나 변경은 `PB011` | 분석:123, `Flora-v2/PRD.md:223-225` |
| PB-F-034 | 플랜·크레딧 서버 강제 | 신규 | 모든 유료 동작은 코어 선차감-환불 시퀀스. 기능 게이팅은 `features`를 서버가 해석. 클라이언트 잠금은 UX 보조 | 브라우저 콘솔에서 `rpc('grant_credits')`, `update app_entitlements`가 42501. 잔액 부족은 402와 필요량 표시 | 분석:149, `CORE_SPEC.md:172-183` |
| PB-F-035 | 결제 | 통합 | Toss 일반결제(크레딧팩, 첫 구독)와 빌링키 정기결제. 주문 선저장, 서버 confirm, 금액 대조, 웹훅은 보조 | 테스트 키로 팩 결제 → 원장 grant 1행. 같은 confirm 2회 → 지급 1회. 위조 웹훅 → 401 | 분석:151, `CORE_SPEC.md:210-233` |
| PB-F-036 | 아웃바운드 웹훅 | 디벨롭(P1) | 사용자 등록 HTTPS URL(조직당 5개, 제안)로 `book.completed`, `export.succeeded`, `export.failed`를 HMAC 서명 POST. 비밀은 `core.encrypted_credentials`. 5회 실패 후 `failing`, 20회 연속 실패 시 `disabled`(제안) | 수신 측이 `X-Signature`로 검증 가능. 사설 IP·localhost URL 등록은 422 | 분석:139, `SHARED_MODULES.md:160-172` |
| PB-F-037 | 랜딩 | 통합 | v2 랜딩 구조. 03장 4절 방향. 히어로는 3D(PB-F-055, 2026-10-13 사용자 결정으로 v1 히어로 연출 1회에서 변경). 금지 문구 통과. 2026-10-14: 섹션은 03장 8.3절 6개(히어로, 결과물 갤러리, 만드는 순서, AI 에이전트, 실제 제품 화면, 요금·FAQ). 2026-10-17: 03장 9.1절 8섹션("막히는 지점과 원인", "왜 FLORA인가" 추가, PB-F-064·065). 결과물 갤러리의 표지·목차·내지는 실제 렌더 결과만 쓰고 고객 결과물이 없으면 "샘플"로 표시. 교육 과정·주차 표현 금지 | 랜딩에 검증되지 않은 사용자 수·후기 0건. 갤러리 항목마다 "샘플" 또는 실제 작가 동의 표시. FAQ에 무료 범위·생성 한도·지원 파일 형식·AI 데이터 처리(국외 이전, 학습 미사용) 4문항 이상 | 분석:158, `docs/reviews/flora.md:82` |
| PB-F-038 | 탈퇴와 데이터 삭제 | 신규 | 설정 → 계정 삭제: 확인 문구 입력 → 조직 soft delete → 30일 유예 → `purge_organization`. 유예 중 로그인하면 복구 버튼. 내보내기 파일과 업로드는 즉시 삭제 예약 | 삭제 요청 후 30일 뒤 조직의 모든 publishing 행 0개, Storage 객체 0개 | 분석:217, `SECURITY_BASELINE.md` 12장 |
| PB-F-039 | 법무 페이지 | 신규 | 이용약관, 개인정보처리방침, 환불 규정, AI 생성물 안내, 사업자 정보(통신판매업 신고) | 랜딩·결제 화면 하단에서 5개 페이지 모두 1클릭 | 분석:214 |
| PB-F-040 | 공개 책 페이지 | 디벨롭(Phase 2) | 완성된 책만, owner/admin이 `set_book_visibility`로 켬. `/b/[slug]`에 표지·소개·목차·Book JSON-LD. 본문은 미리보기 1장까지만(제안: 판매 기능 결정 전 전문 공개 방지) | 미완성 책 공개 시 `PB009`. anon은 공개 컬럼만 조회 | 분석:114, :159, `docs/reviews/SellingDocs.md:52` |
| PB-F-041 | 번역 | 유지(Phase 2) | 완성 원고를 영어·일본어로 번역해 별도 책으로 복제 | Phase 2 기획에서 단가 확정 | 분석:102 |
| PB-F-042 | 오디오북 전권 | 디벨롭(Phase 2) | 전권 오디오북, 멀티보이스, 등장인물 추출. TTS 엔진은 확정 결정 16(ElevenLabs + 오픈소스)으로 정해졌고, MVP의 미리듣기는 PB-F-052가 맡는다. 산출물은 Storage + 서명 URL | 해당 없음(Phase 2) | 분석:129-131, :245-249 |
| PB-F-043 | 운영 기반 | 디벨롭 | 필수 환경변수 누락 시 기동 실패, Dockerfile(pango, cairo, Noto CJK), CI(tsc, lint, build, pytest, SQL 체커, RLS 스모크) | 빈 `SUPABASE_JWT_SECRET`이나 `RENDER_SERVICE_TOKEN`으로 엔진이 기동하지 않는다. main 브랜치 CI 녹색 | 분석:160, :216, `docs/reviews/Flora-v2.md:132-133` |
| PB-F-044 | AI 라우팅과 국외 이전 동의 | 신규 | 이메일 인증 직후(OAuth는 첫 로그인 직후 약관 동의 다음, Stage A는 페르소나 첫 로그인 직후) 온보딩에서 "AI 처리 방식"을 고른다: 상용 AI 사용(국외 이전 동의) 또는 국내 오픈소스만. 동의하면 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })`(owner)를 부르고 같은 시각·버전을 `core.audit_log`(`ai.consent.cross_border`)에 남긴다(제품 동의 표를 만들지 않음, 05장 6절·D16). 설정에서 언제든 철회한다. 기능별 기본 체인은 02장 5.1절(seed와 일치). 동의가 없으면 모든 AI·음성 기능이 오픈소스 제공자만 쓴다. 온보딩을 건너뛰면 미동의로 둔다 | 미동의 조직의 `ai_usage.provider_id`에 상용 제공자 0. 철회 직후 다음 요청부터 상용 0. 고지문 버전이 `ai_org_settings.cross_border_notice`와 감사 기록에 같게 남는다 | `docs/products/_platform-core/AI_ARCHITECTURE.md:86`, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:553-575` |
| PB-F-045 | 책별 자료 RAG | 신규 | 책마다 RAG 컬렉션 `book-<book_id>`(kind `rag`, 임베딩 `oss-embed`)를 둔다. 색인 대상: (1) 이용자가 올린 참고 파일(txt, md, docx, pdf, 파일당 20MB, 책당 `features.rag_files_max`개) (2) 그 책의 원고(소제목 본문 스냅샷, 저장 뒤 바뀐 소제목만 재색인). 업로드는 PB-F-027과 같은 서명 업로드 + 엔진 파싱 후 정규화 md를 FastAPI `/rag/ingest`로 색인한다. 업로드 때 "개인정보 포함" 여부를 묻고 `ai_documents.contains_pii`와 책의 오픈소스 전용 스위치(PB-F-056)에 반영한다. 참고 파일 원문은 색인 뒤 24시간 안에 Storage에서 삭제하고 청크는 책과 함께 보관한다. 검색은 서버가 `match_ai_chunks`로 그 책 컬렉션만 조회한다 | 책 A의 질의가 책 B 컬렉션 청크를 돌려주지 않는다(다른 컬렉션 id 요청 42501). 평가셋 40문항(제안)에서 상위 8개 안 정답 청크 재현율 0.8 이상(제안). 한도 초과 업로드 403 `plan_limit`. 색인 실패 문서는 `failed` + 재시도 버튼, 환불 | `docs/products/_platform-core/AI_ARCHITECTURE.md:94-107`, `docs/products/_platform-core/DB_CONVENTIONS.md:315-327` |
| PB-F-046 | 책 설정집 위키 | 신규 | 책별 설정집(캐릭터 `entity`, 용어·세계관 `concept`, 문체·시점·시제 가이드와 타임라인 `topic`, 목차 `index`)을 이용자 조직의 `core.wiki_pages`에 slug `books/<book_id>/...`로 둔다(app `publishing`). 이용자가 "설정집 만들기"를 누르면 ingest가 원고·참고 파일에서 새 페이지를 `draft`로 제안하고, 이용자가 검토·수정해 `published`로 채택한 페이지만 일관성 검사와 채팅의 근거가 된다. 이용자가 고친 블록은 사람 소유로 표시해 ingest가 덮어쓰지 않고, 저장은 `expected_version` 낙관적 잠금, 문서 1건당 갱신 페이지는 5개까지. "설정집 점검"(lint: 모순, 낡음, 고아, 깨진 링크, 출처 없는 주장)은 이용자가 직접 실행한다. 설정집은 그 조직 구성원만 열람하고 공개 화면은 없다. 개인정보 포함 원고에서 만든 페이지는 `derived_from_pii=true`로 오픈소스만 쓴다 | 새 페이지는 `draft`. "출처" 절이 없는 페이지 채택 409. 사람 소유 블록 변경 0(테스트). `expected_version` 불일치 409 `WIKI_VERSION_CONFLICT`. 다른 책 slug 조회 404. `derived_from_pii` 페이지 처리의 상용 제공자 0. 책 영구 삭제 시 설정집 페이지·개정 이력 삭제 | `docs/products/_platform-core/LLM_WIKI.md:21-47` |
| PB-F-047 | 초안 그래프 `publishing.draft` | 신규 | PB-F-017의 생성 엔진. FastAPI(`api/`) LangGraph 5노드: `outline`(목차·기획안·채택된 설정집·앞 챕터 요약으로 챕터 내 소제목별 개요, 라우팅 기능 `publishing.draft`) → `draft`(소제목별 초안, 동시 3, 페르소나 Taste·어조는 서버가 DB에서 합성해 주입) → `consistency`(채택된 설정집과 책 컬렉션 검색으로 캐릭터·용어·시제·시점 충돌을 검사하고 충돌 소제목만 메모를 붙여 1회 재작성) → `proofread`(맞춤법·문장 부호·반복 표현 교정, 의미 변경 금지) → `compliance`(마지막 노드, PB-F-054). 워커가 잡 토큰으로 챕터 단위 실행을 요청하고 결과 저장은 워커가 한다. 본문이 있는 소제목은 덮어쓰지 않고 제안(Diff)으로만 돌려준다. 옴니버스 모드는 앞 챕터 요약을 생략한다 | 챕터 1건당 `core.ai_runs` 1행(graph `publishing.draft`, `job_id`, `credit_ledger_id`)과 노드별 `ai_run_steps`. 설정집과 어긋난 이름·시제를 심은 시드 원고에서 충돌 100%가 메모로 남거나 재작성 뒤 통과. 교정 평가셋 20건에서 핵심 문장 보존 95% 이상(제안). 2회 연속 compliance 실패 소제목은 `failed` + 환불 | `docs/products/_platform-core/AI_ARCHITECTURE.md:109-119`, PB-F-017, PB-F-033 |
| PB-F-048 | 단건 생성 경로 `publishing.assist` | 디벨롭 | 제목, 기획안, 목차, 섹션 단건, 보조 집필, 전체 다듬기 청크, 책 정보, 페르소나 합성의 LLM 호출을 공용 LLM 게이트웨이(TS) 직접 호출에서 ai-service의 짧은 그래프 `publishing.assist`(노드 `compose`(DB에서 컨텍스트 합성) → `generate` → `compliance`)로 옮긴다. 요청·응답 계약은 PB-F-013~022와 같고 TS 게이트웨이는 `/api/ai/*` 호출용 얇은 래퍼로 남는다. LLM·임베딩 키는 `api/`에만 둔다 | PB-F-013~022 수용 기준을 그대로 통과(회귀). web·worker 환경변수에 LLM 키 0. 스트리밍 첫 토큰 p95 5초 유지(그래프 SSE 미지원 시 D13) | `docs/products/_platform-core/SHARED_MODULES.md:215` |
| PB-F-049 | 글쓰기 도우미 채팅 | 신규 | 에디터·위저드 옆 채팅 패널. 책에 묶은 대화는 그 책의 원고·설정집·참고 파일을 근거로 답하고("3장에서 주인공이 처음 나오는 곳은?", "이 장면의 시점이 흔들리는지 봐 줘", 막힘 해소 아이디어, 맞춤법), 묶지 않은 대화는 일반 글쓰기 상담이다. 읽기 전용: 답변은 원고를 바꾸지 않고 "본문에 넣기"를 누르면 Diff 카드로만 적용된다. 스트리밍, 답변마다 출처(원고 위치, 설정집, 참고 파일), "AI가 생성한 답변" 표시. 메시지 1,000자, 대화당 50턴(제안). 크레딧은 턴 선차감 후 정산(4.6절). 로그인 사용자 전용 | 답변에 출처 1개 이상 또는 "근거 자료를 찾지 못했습니다" 표시. 응답이 전달되지 않은 턴은 선차감 전액 환불. 잔액 부족 402(`CR001`). Dify 장애 시 대체 경로(`/tools/answer-direct`)로 답한다. 다른 사용자의 대화 id로 이어 쓰면 404. 다른 조직 책 `book_id`로 시작하면 404 | `docs/products/_platform-core/AI_ARCHITECTURE.md:44-56`, `:121-130` |
| PB-F-050 | 받아쓰기(STT) | 신규 | 에디터의 마이크 버튼. 한 구간 최대 120초(제안)이고 구간이 끝나면 다음 구간을 이어 녹음하는 연속 모드(수동 중지)를 둔다. STT(기능 `publishing.dictation`, 오픈소스 우선) 결과는 커서 위치에 "받아쓰기 초안"(강조 표시)으로 넣고 이용자가 확정·수정한다. 녹음 원본은 저장하지 않는다(`store_audio=false`). 첫 사용 때 음성 처리 고지(녹음 목적, 원본 미저장, 주변 다른 사람의 목소리가 담기지 않게 주의, 상용 제공자 사용 시 국외 이전)를 확인받는다 | 120초에 구간 자동 종료. 이 제품의 `voice_jobs.store_audio=false` 100%. 마이크를 거부해도 텍스트 편집 정상. 고지 확인 없이 STT 호출 403 `VOICE_CONSENT_REQUIRED`. 생성 중인 소제목에는 받아쓰기를 넣지 못한다(`PB005`). 변환 실패 시 환불 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:40-48`, `:85-95` |
| PB-F-051 | 채팅 음성 | 신규 | 채팅 패널의 마이크 버튼(`voice_chat` STT, 누르고 말하기 60초)과 답변 "읽어 주기"(`voice_chat` TTS, 자동 재생 기본 꺼짐). TTS 입력은 DB의 assistant 메시지에서만 읽는다 | 음성 없이도 채팅이 정상 동작. TTS 실패 시 환불하고 텍스트 유지. 클라이언트가 보낸 임의 텍스트 낭독 0 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:106-110` |
| PB-F-052 | 원고 낭독·오디오북 미리듣기 | 신규 | Basic(`features.narration`). 소제목 또는 챕터 단위로 본문(서버가 DB에서 읽어 태그를 제거)을 TTS(기능 `narration`)로 읽어 mp3(`exports/<org_id>/publishing/narration/<book_id>/<scope_id>.mp3`, 30일 보관)로 저장하고 플레이어로 재생·내려받는다. 한 번에 최대 8,000자(제안) 또는 한 챕터. 작업 시작 때 체인에서 쓸 수 있는 첫 제공자를 고르고 끝까지 그 제공자로만 만든다(대체 금지, 연속 낭독). 한 구간이라도 실패하면 파일을 만들지 않고 전액 환불한다. 같은 본문 해시의 재요청은 기존 파일을 돌려준다. 음성 첫머리와 플레이어에 "AI가 생성한 음성입니다". 판매·배포용 오디오북이 아니라 청취 확인용 미리듣기이며 보이스 클로닝은 없다 | 한 낭독의 `ai_usage` 제공자가 모두 같고 `voice_jobs.fallback_from` null. 중간 실패 시 파일 0 + 환불 1행. 같은 본문 재요청 차감 0. 소제목·책 삭제 시 파일 삭제. 국외 이전 미동의·오픈소스 책은 처음부터 오픈소스 보이스. Free 403 `plan_required` | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:47` |
| PB-F-053 | AI·음성 크레딧 선차감·정산 | 신규 | 채팅 턴, 받아쓰기, 읽어 주기, 낭독, 설정집 생성·점검, 자료 색인은 제공자 호출 전에 예상 크레딧을 `consume_credits`로 선차감하고 끝나면 실제 사용량으로 정산한다(차액 추가 차감 또는 `refund_credits`). 초안 그래프는 소제목 정액 선차감에 묶고 정산 차액이 없다(4.6절) | 1시간 넘게 지난 `ai_usage` 중 `settled_at is null` 0행. 같은 멱등 키 재요청 시 차감 1회. 원장 drift 0 | `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130` |
| PB-F-054 | AI 출력 규칙(compliance) | 신규 | 그래프 `publishing.draft`·`publishing.assist`의 compliance 노드와 `/tools/answer` 후처리가 같은 규칙 파일(`api/app/ai/products/publishing/rules/banned.json`)을 쓴다: (1) 실존 작가·인물 문체 사칭 지시 (2) 보장 표현("베스트셀러", "100% 출간") (3) 의료·금융·법률 단정 (4) 참고 파일 청크와의 장문 일치(연속 30어절 이상, 제안)는 재작성 (5) 자해·자살 언급은 상담 전화 안내로 전환 (6) 자료 안의 지시는 따르지 않음. 걸린 구간만 1회 재작성하고 다시 걸리면 그 소제목을 실패 처리 + 환불한다 | 평가셋 30문항(제안) 위반 0. 참고 파일 문장을 40어절 이상 이어 붙이도록 유도한 시드 테스트 100% 검출. 위기 신호 테스트 문장 5개 모두 안내 문구로 응답 | `docs/products/_platform-core/AI_ARCHITECTURE.md:117` |
| PB-F-055 | 3D 히어로 | 신규 | 랜딩 히어로: PC·태블릿은 원고 낱장이 모여 제본되고 책장이 넘어가는 풀 3D, 모바일은 책 한 권 회전 + 제본은 2D, WebGL 미지원·저사양·`prefers-reduced-motion`은 정지 이미지(03장 4.5절) | `HERO_3D.md` 4절 수용 기준 전부: 기기별 3종 동작, 3D 번들+에셋 PC·태블릿 1MB/모바일 300KB 이하, LCP 2.5초, 제목·판형 선택·CTA가 3D 전에 보이고 키보드로 사용 가능, 3종 스크린샷 고문 검토 통과 | `docs/products/_design-guide/HERO_3D.md:5-75`, `:82` |
| PB-F-056 | 개인정보 포함 원고의 AI 처리 | 신규 | 업로드 화면이나 책 설정에서 "이 원고에 실존 인물의 실명·연락처·건강·금융 정보 등이 들어 있다"를 선택하면(또는 책 설정 "오픈소스 AI만" 스위치를 켜면) 그 책의 모든 AI·음성 호출(그래프, 단건 생성, 채팅, 위키, 받아쓰기, 낭독)이 오픈소스 제공자로만 처리된다. 상용으로 대체하지 않고 오픈소스가 모두 실패하면 실패 + 환불. 스위치는 `books.book_info.ai_open_source_only`(제안, D12에서 전용 컬럼 승격 여부 결정). 6.1절 판단표를 따른다 | 스위치가 켜진 책의 `ai_usage.provider_id`에 상용 제공자 0(그래프·채팅·위키·STT·TTS 전부). 스위치를 끈 뒤에는 이미 `derived_from_pii=true`인 위키 페이지만 계속 오픈소스. 오픈소스 서버 장애 시 실패 + 환불(상용 대체 0) | `docs/products/_platform-core/SECURITY_BASELINE.md:291`, `docs/products/_platform-core/LLM_WIKI.md:33` |

### 3.1 에이전트·운영 기능 (2026-10-14 FLORA 개편)

에이전트는 새 생성 엔진이 아니다. 기존 기능(PB-F-011, 013~025, 045~047, 052)을 6개 에이전트로 묶어 실행·검수·재시도·추적을 한곳에서 하게 하는 계층이다(02장 10절). 에이전트별 동작과 기존 기능의 대응은 아래와 같다.

| 에이전트(`agent_key`) | 하는 일 | 기존 기능(실행 엔진) | 기본 승인 방식 |
|---|---|---|---|
| 기획(`planning`) | 제목, 기획안, 목차 제안, 페르소나 합성 | PB-F-011, 013~015(`publishing.assist`) | 목차는 저자가 고르고 구조를 저장해야 확정(구조 저장 = 승인) |
| 자료(`research`) | 참고 파일 색인, 설정집 만들기·점검, 출처 정리 | PB-F-045, 046(`/rag/ingest`, `wiki_ingest`, `wiki_lint`) | 작업 단위 검수는 없다. 설정집 페이지마다 `draft` → 저자 채택(`published`)이 검수이고 채택한 것만 근거로 쓴다 |
| 집필(`writing`) | 소제목 단건, 챕터 초안, 전체 순차 생성 | PB-F-016, 017, 047(`publishing.draft`, `publishing.assist`) | 본문이 있던 소제목은 제안으로만 오고 비교 후 승인(단건 생성의 덮어쓰기도 제안, PB-F-016). 빈 소제목은 "AI 초안 · 검토 전" 상태로 채운다(D26 (a) 기준) |
| 편집(`editing`) | 이어쓰기·살붙이기·다듬기, 전체 다듬기, 사례·예시 제안, 문체·설정 확인, 출처 검토 | PB-F-018, 019, 060(`publishing.assist`) | 선택 영역 동작(스트리밍)은 그 자리의 Diff 카드가 검수다(작업 검수 대기 없음). 전체 다듬기(잡)는 검수 대기함에서 비교 후 반영 |
| 출판(`publishing`) | 책 정보, 표지 3후보, PDF·ePub, 낭독 미리듣기 | PB-F-021, 022, 024, 025, 052(엔진·렌더·fal·TTS) | 작업 검수 없음. 내보내기 직전 확인 모달(쪽수, 워터마크, epubcheck 결과, 검토 전 AI 초안 수)이 최종 점검이고 다운로드를 막지 않는다 |
| 콘텐츠(`content`) | 승인된 원고로 소개문·홍보 글 | Phase 2(PB-F-063) | 외부 게시 전 승인 |

채팅(PB-F-049)·받아쓰기·읽어 주기(PB-F-050, 051)는 대화형이라 작업(`agent_tasks`)으로 기록하지 않는다. 대화 기록(`core.ai_conversations`)과 사용량(`core.ai_usage`)으로 추적한다.

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| PB-F-057 | 에이전트 실행 계층 | 신규 | 위 표의 작업형 동작(채팅·받아쓰기·읽어 주기 제외)은 요청 1건마다 서버가 `publishing.agent_tasks` 1행을 만든다(멱등 키 `(org_id, request_id)`, 크레딧 차감은 기존 멱등 키를 그대로 쓰고 모든 차감 행에 `ref_type='agent_task'`, `ref_id=<작업 id>`를 단다(챕터 초안처럼 소제목마다 여러 행이어도 같은 작업으로 묶인다). 행에는 에이전트·동작·범위 요약(id·개수만, 원고 본문 없음), 예상·실제 크레딧, 실제 실행의 `core.jobs.id`, `generation_runs.id`, `core.ai_runs.id`, 첫 차감 원장 id(표시용)를 잇는다. 실행 엔진·큐·그래프는 새로 만들지 않는다. 잡을 끝내는 쪽(워커·엔진·AI 서비스)이 같은 행의 상태를 갱신하고, 5분 주기 동기화가 누락을 고친다 | 01장 4.3·4.6절의 유료 작업형 동작마다 `agent_tasks` 정확히 1행, 그 작업의 차감·환불 원장이 모두 `ref_id=<작업 id>`로 조회되고 합계가 `credits_used`와 같다(E2E). 같은 `request_id` 재전송은 새 행 0. 잡이 끝나고 10분 넘게 `running`인 행 0, 차감 실패·중단으로 15분 넘게 `queued`인 행 0(동기화). 행에 원고 본문·프롬프트·키 0(스키마 검사) | 제안서 5절·6절, 02장 10절 |
| PB-F-058 | 검수 대기함과 승인 기반 반영 | 신규 | 결과가 잡에 남는 원고 작업(챕터 초안·전체 순차 생성·전체 다듬기, 02장 10.1절)은 끝나면(성공·부분·취소) `approval_status='pending'`이 된다. 선택 영역 동작은 기존 Diff 카드가 검수라 대기함에 쌓지 않는다. 저자는 검수 대기함(에이전트 화면 탭, 에디터 AI 패널 "제안" 탭)에서 항목별로 비교하고 전부 승인·일부 승인·거부한다. 제안 반영은 기존 `PATCH sections`(revision 확인), 빈 소제목 AI 초안의 승인은 서버가 그 소제목을 사람 확인 상태(`gen_status='edited'`)로, 거부는 다시 빈 소제목으로 돌린다(그사이 사람이 고쳤으면 건드리지 않음). 결정은 RPC `decide_agent_task`(감사 `agent_task.decide`). 승인 전에는 사용자가 쓴 본문을 바꾸지 않는다. "검토 전" 표시는 소제목 자체(`gen_status='generated'`)로 판단하므로 대기가 만료(30일, `expired`)돼도 남고, 내보내기 직전에 그 수를 알려 준다(막지 않음) | 본문이 있던 소제목의 AI 결과(단건 생성 덮어쓰기 포함)가 승인 전 `sections.body_html`을 바꾸는 경우 0. 빈 소제목 AI 초안 거부 시 그 소제목 본문이 비고 사람이 고친 소제목은 그대로. 이미 결정한 작업에 다시 결정하면 409 `PB012`. 부분 승인 시 승인한 소제목만 revision+1. 내보내기 확인 모달에 "검토 전 AI 초안 N개" 표시 | 제안서 4절 "승인 전 자동 반영 금지", PB-F-018, PB-F-047 |
| PB-F-059 | 에이전트 작업 공간 | 신규(P1) | `/dashboard/agents`: 탭 [에이전트] (6개 목록, 각 에이전트가 하는 일·쓸 수 있는 동작·플랜 잠금), [검수 대기], [실행 이력] (책·에이전트·상태 필터), [대화] (기존 채팅 목록). 새 작업 폼은 책 → 동작 → 범위(챕터·소제목) → 모드 → 예상 크레딧·잔액 확인 → 실행. 작업 상세 `/dashboard/agents/tasks/[id]`는 타임라인(대기 → 실행 → 노드별 진행 → 완료), 결과 검수, 실패 원인과 환불 여부, 재시도 버튼 | 위저드·에디터에서 시작한 작업도 실행 이력에 같이 보인다. 실패·부분 실패·취소 작업만 재시도 버튼이 보이고 한 작업은 한 번만 재시도된다(같은 작업 두 번째 재시도는 409, 재시도 작업이 다시 실패하면 그 작업을 재시도. 최대 10회). 진행 중 작업의 재시도는 409 `PB013`. 재시도는 재시도 범위(실패분, 취소 작업이면 처리하지 못한 나머지까지)만 새로 차감하고, 원래 작업의 결과 없는 차감이 모두 환불됐는지 원장(`ref_id=<작업 id>`)으로 먼저 확인한다(02장 10.4절). 콘텐츠 에이전트는 "준비 중"으로 비활성 | 제안서 5절 ② Agent Workspace |
| PB-F-060 | 에디터 3단 레이아웃과 AI 패널 | 디벨롭(P1) | 에디터를 좌 목차(장·절 이동, 소제목 상태 칩) · 중 원고(본문, 버전) · 우 AI 패널로 둔다. AI 패널 탭: [도우미] (기존 채팅 PB-F-049), [제안] (이 책의 검수 대기 항목, Diff 비교·적용·거부), [실행] (이 책의 진행 중·최근 작업). 선택 영역 동작에 기존 3종(이어쓰기, 살붙이기, 다듬기) 외에 사례·예시 제안(`examples`), 문체·설정 확인(`style_check`: 채택된 설정집과 비교), 출처 검토(`source_check`: 사실 주장 문장에 출처가 있는지, 참고 파일과 장문 일치가 있는지)를 더한다. 화면 폭 1279px 이하에서는 목차와 AI 패널을 접고 시트로 연다 | 새 동작 3종은 각 1크레딧(01장 4.3절 보조 집필과 같음), `writing_assist`(Basic). 결과는 Diff 카드나 메모로만 오고 원고를 바로 바꾸지 않는다. 375·768·1024·1440px에서 원고 폭 최소 560px(1024px 이상) 유지 | 제안서 4절 "원고 편집기는 세 영역", PB-F-018 |
| PB-F-061 | 운영 콘솔(Agent Operations) | 디벨롭(P1) | `/admin` 메뉴: 운영 홈(전체 사용자, 실행 중 작업, 기간 AI 원가, 미처리 실패 작업, 비용 경보, 최근 활동. 데이터가 없으면 숫자 대신 "—"와 연결 상태), 사용자·권한(가입 상태, 요금제, 계정 정지·복구, 플랫폼 역할), 출판 프로젝트(책 상태, 내보내기 실패, 저장 용량, 삭제 요청. 원고 본문은 보지 않는다), 에이전트·AI 운영(에이전트·동작별 실행 수, 성공률, p95 시간, 모델별 원가, 오류 코드 상위), 작업 큐·실행 이력(대기·실행·성공·실패·취소, 작업 id로 실행 추적: 요청 → `agent_tasks` → `core.jobs` → `ai_runs`·`ai_run_steps` → `ai_usage` → `credit_ledger`), 결제·크레딧·원가(결제, 원장, 기간·모델·에이전트·조직별 원가 대비 크레딧 매출, 환불), 플랫폼 설정(라우팅 기본값·플랜 features 열람만, 변경은 seed·마이그레이션), 감사 로그. 실패 작업 재실행은 원래 작업의 환불 원장을 확인한 뒤 새 작업(`origin='admin_retry'`)으로만 하고 이중 차감하지 않는다. 원고 열람은 기본 차단(D27) | 일반 사용자 `/admin/*` 404. 작업 id 하나로 추적 화면에 6단계가 모두 이어진다(누락 단계는 "기록 없음" 표시). 재실행 시 원래 작업이 환불되지 않았으면 409 `refund_missing`. 원가 표의 합계가 `core.ai_usage.cost_usd_micros` 합과 같다. 원가는 일반 사용자 화면·API 응답에 0. 프롬프트·키·토큰 값은 마스킹. 운영자 조회 1건마다 감사 `admin.view`(대상 종류·id) | 제안서 6절, PB-F-005, `SECURITY_BASELINE.md` 9장 |
| PB-F-062 | 워크플로 빌더 | Phase 2 | 고급 사용자가 "목차 확정 → 장별 집필 → 편집 검수 → 출판 준비"를 노드로 잇고 승인 지점을 둔다(React Flow/XYFlow). 노드는 PB-F-057의 동작만 쓰고 새 실행 엔진을 만들지 않는다. 운영 콘솔에는 같은 캔버스로 `ai_run_steps` 실행 그래프와 실패 지점을 읽기 전용으로 보여 준다 | Phase 2 기획에서 확정 | 제안서 5절 ③ |
| PB-F-063 | 콘텐츠 에이전트 | Phase 2 | 승인된 원고와 책 정보로 소개문, 목차 요약, 홍보 글 초안을 만든다. 외부 게시 전 저자 승인 | Phase 2 기획에서 확정 | 제안서 5절 표 |

## 4. 요금과 크레딧

### 4.1 플랜 (정본 출처: 확정 결정 8 "크레딧팩 + 저가 구독")

금액·크레딧은 모듈러 seed(`docs/products/_supabase-modular/seed.sql:33`, `:95`, `:100-101`)과 같게 두었다. 저가 구독 ₩9,900은 FP 기획의 NOMAD PRO 가격(`flora-publisher/frontend/docs/prd/02_user_flow.md:65`)이 근거다. 월 크레딧 수치는 제안이며 이유는 4.3절에 적었다. 가격은 모두 VAT 포함(B2C SaaS, 2026-10-14 `Price_Plans/_common/PRICING_PRINCIPLES.md` 7장). 런칭 할인·연간 결제·장기 pro 등급·pack_1500은 `Price_Plans/flora-publishing/PRICE_PLAN.md` 6장 단계 계획이며 이 절을 바꾸지 않는다.

| 코드 | 이름 | 월 가격 | 월 크레딧(plan 버킷) | 가입 크레딧 | 이월 | 주요 features |
|---|---|---|---|---|---|---|
| `free` | Free(기본) | ₩0 | 20 | 0(첫 달 20이 가입 시 지급) | 없음 | 워터마크, 월 내보내기 2회, 책 3권, 챕터 3, 소제목 6, 단락 3, 페르소나 40, fast 모드만 |
| `basic` | Basic | ₩9,900 | 200 | 0 | 없음(남은 plan 크레딧은 갱신 시 만료) | 워터마크 없음, 내보내기 월 100회, 책 100권(2026-10-14 "무제한"에서 숫자 상한으로, `Price_Plans/_common/PRICING_PRINCIPLES.md` 6장), 챕터 20, 소제목 200, 단락 5, 페르소나 60, 전체 순차 생성, 업로드, 어조, 보조 집필, quality 모드, 페르소나 합성, 웹훅, 공개 페이지(Phase 2) |

### 4.2 크레딧팩 (pack 버킷, 소멸 없음)

| 코드 | 크레딧 | 가격 | 크레딧당 | 근거 |
|---|---|---|---|---|
| `pack_100` | 100 | ₩9,900 | ₩99 | 모듈러 seed(`seed.sql:100`) |
| `pack_500` | 500 | ₩39,900 | ₩79.8 | 모듈러 seed(`seed.sql:101`) |

차감 순서는 plan 버킷 → pack 버킷(`CORE_SPEC.md:168`). 팩 크레딧은 Free 사용자도 살 수 있다(쓴 만큼만 내는 페르소나 이하은의 요구).

### 4.3 크레딧 단가 (전부 제안)

| 작업 | 크레딧 | 단위 | 이유 |
|---|---|---|---|
| 제목 추천 | 1 | 1회(3~5후보) | 짧은 출력 |
| 기획안 3종 | 2 | 1회 | 3안 동시 생성 |
| 목차 3종 | 2 | 1회 | 3안 동시 생성 |
| 섹션 집필 fast | 1 | 소제목 1개 | 원고 생성의 기본 단위. SD 리뷰가 "단계별 단가 분리"를 요구(`docs/reviews/SellingDocs.md:72`) |
| 섹션 집필 quality | 3 | 소제목 1개 | 상위 모델 비용. 2026-10-14 2 → 3: Sonnet 경로 원가가 크레딧당 약 18원으로 Basic 허용 원가 12.9원(70% 매출총이익률)을 넘는다(`Price_Plans/flora-publishing/PRICE_PLAN.md` 3.2절) |
| 이어쓰기/살붙이기/다듬기 | 1 | 선택영역 2,000자 청크 | 청크 단위로 비용 비례 |
| 사례·예시 제안, 문체·설정 확인, 출처 검토(PB-F-060, 2026-10-14) | 1 | 선택영역 2,000자 청크 | 보조 집필과 같은 출력 규모 |
| 전체 다듬기 | 1 | 2,000자 청크 | 위와 같음 |
| 책 정보 생성 | 1 | 1회 | 짧은 출력 |
| 페르소나 합성 | 3 | 1회 | 샘플 분석 + 합성 2단계 |
| 표지 3후보 | 6 | 1회(장당 2) | 이미지 생성 원가가 텍스트보다 높음 |
| PDF 내보내기 | 2 | 1회 | 렌더 컨테이너 CPU 시간 |
| ePub 내보내기 | 1 | 1회 | 렌더보다 가벼움 |
| 같은 content_hash 재내보내기(7일 내) | 0 | - | 같은 파일 재사용 |
| 원고 업로드 파싱, 시드 복제, 미리보기 | 0 | - | LLM 비용 없음. 미리보기는 레이트 리밋으로 보호 |

검산(단건 집필 기준, 4.6절의 그래프 초안 단가와 별개): Free 한도(챕터 3, 소제목 6)로 책 1권 = 제목 1 + 기획 2 + 목차 2 + 섹션 6 + 표지 6 + 정보 1 + PDF 2 = 20크레딧. Free 월 20크레딧으로 작은 책 1권을 끝까지 만들 수 있다(체험 목적). 5챕터 x 3소제목 책은 약 30크레딧이므로 Basic 200크레딧으로 월 6권 안팎을 만든다. 단가와 월 크레딧은 출시 전 실제 토큰 원가로 재검증한다(06장 PB-06-008).

### 4.4 `core.plans.features` 키 해석 (서버만 읽는다, `DB_CONVENTIONS.md` 11장)

키가 없으면 "기본값" 열(= Free 값)로 해석한다. 모듈러 seed는 2026-10-13부터 모놀리스 seed와 같은 16키를 담는다. 키가 누락된 경우의 대비로 기본값을 적용한다. AI 키 6개(아래 표 마지막 6행)는 2026-10-13에 추가했다. 모듈러는 `1000_publishing.sql` 15.2절의 병합 UPDATE에, 모놀리스는 `supabase/monolith/seed.sql` free·basic 행에 있다(모듈러 `seed.sql` 반영은 06장 R7).

| 키 | 타입 | 기본값 | 의미 | 강제 위치 |
|---|---|---|---|---|
| `watermark` | boolean | true | PDF/ePub 워터마크 | 렌더 잡 옵션(서버) |
| `exports_per_month` | integer | 2 | 월 내보내기 횟수(Basic 100. -1 무제한은 쓰지 않는다, 2026-10-14). KST 달력 월 기준 succeeded+진행 중 건수 | 내보내기 Route Handler |
| `themes` | text[] | `["basic"]` | 화면 테마 그룹 | `member_settings` 트리거(`PB008`) |
| `max_books` | integer | 3 | 삭제되지 않은 책 수(Basic 100, 2026-10-14 -1에서 변경) | `books` INSERT 트리거(`PB001`) |
| `max_chapters` | integer | 3 | 책당 챕터 수 | `chapters` INSERT 트리거(`PB002`) |
| `max_sections` | integer | 6 | 책당 소제목 합계 | `sections` INSERT 트리거(`PB003`) |
| `max_paragraphs` | integer | 3 | 소제목당 단락 목표 | `sections` 트리거(`PB004`) |
| `personas` | integer | 40 | 사용 가능 페르소나 수(카탈로그 앞에서부터) | LLM Route Handler |
| `write_all` | boolean | false | 전체 순차 생성 | Route Handler |
| `upload` | boolean | false | 원고 업로드 | Route Handler |
| `tone_slider` | boolean | false | 어조 슬라이더 반영 | 프롬프트 합성 |
| `writing_assist` | boolean | false | 이어쓰기/살붙이기/다듬기, 전체 다듬기 | Route Handler |
| `quality_mode` | boolean | false | quality 모드 선택 | LLM 게이트웨이 호출 전 |
| `persona_blend` | boolean | false | 나만의 페르소나 합성 | Route Handler |
| `webhooks` | boolean | false | 아웃바운드 웹훅 등록 | Route Handler |
| `public_page` | boolean | false | 공개 책 페이지(Phase 2) | `set_book_visibility`(`PB009`) |
| `ai_chat` | boolean | true | 글쓰기 도우미 채팅. 키가 없으면 true로 읽는다 | `/api/ai/*` Route Handler |
| `ai_chat_turns_per_day` | integer | 50 | 사용자당 하루 채팅 턴 상한(공정 사용). Basic 300(제안) | `/api/ai/chat` |
| `book_wiki` | boolean | true | 책 설정집 위키 | `/api/books/[id]/wiki/*` |
| `rag_files_max` | integer | 3 | 책당 참고 파일 수(원고 색인은 별도). Basic 20(제안) | `/api/books/[id]/references` |
| `voice_dictation` | boolean | true | 받아쓰기·채팅 음성 | `/api/voice/*` |
| `narration` | boolean | false | 원고 낭독·오디오북 미리듣기(Basic만) | `/api/voice/narrations` |

### 4.5 환불 규정 (제안, 법무 검토 필요)

| 대상 | 규칙 | 근거 |
|---|---|---|
| 크레딧팩 | 결제 후 7일 이내이고 해당 팩 크레딧을 쓰지 않았으면 전액 환불. 일부라도 쓰면 환불 불가(디지털 콘텐츠 제공 개시) | 전자상거래법 청약철회 7일(미확인: 디지털 콘텐츠 예외 적용 요건은 법무 확인) |
| Basic 구독 | 결제 후 7일 이내이고 그 달 plan 크레딧 사용 0이면 전액 환불. 그 외에는 해지 예약(기간 말까지 이용) | 제안 |
| 서비스 장애 | 생성·렌더 실패는 자동 환불(코어 `fail_job`). 장애로 인한 손실은 운영자가 원장 adjust로 복원 | `CORE_SPEC.md:180`, `:237` |
| 처리 | Toss 취소 API → `payments` 갱신 → 미사용 크레딧 회수(원장 adjust) → 감사 로그 | `CORE_SPEC.md` 5.4 |

### 4.6 AI·음성 크레딧 단가 (2026-10-13, 제안)

4.3절 기존 단가는 바꾸지 않는다(2026-10-14 섹션 집필 quality 2 → 3만 예외). 제공자 단가는 코어 seed `core.ai_model_prices`(`docs/products/_supabase-modular/seed.sql:243-262`: LLM 상용 1k 입력 1cr·출력 4cr, 오픈소스 0.2·0.5cr, STT ElevenLabs 3cr/분·오픈소스 0.5cr/분, TTS ElevenLabs 5cr/천 자·오픈소스 1cr/천 자, 임베딩 오픈소스 0.01cr/1k 토큰, 모두 제안값)이고 이 표는 그 값을 publishing 기능에 적용한 것이다. 계산 상수는 `web/src/server/ai-pricing.ts`(코드 상수, 4.3절 `pricing`과 같은 이유). 선차감과 정산 규칙은 `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130`, 음성 단가는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104`를 따른다.

| 작업 | 선차감(예상) | 정산 | 상용 경로 예 | 오픈소스 경로 예 | 멱등 키 |
|---|---|---|---|---|---|
| 챕터 초안 그래프(PB-F-047), 소제목당 | fast 2 / quality 4(정액) | 차액 없음. `ai_usage`에 원가만 기록하고 실행 끝에 `settled_at`을 채운다. 실패 소제목만 환불 | Claude 우선 | `oss-llm` | `consume:publishing:<run_id>:<section_id>` |
| 단건 생성(제목, 기획안, 목차, 섹션, 보조 집필, 책 정보, 페르소나 합성) | 4.3절 그대로 | 차액 없음(정액) | 4.3절 | 4.3절 | `consume:publishing:<request_id>` |
| AI 채팅 1턴 | 3 | 실제 토큰 × 단가 + Dify 보조 노드 오버헤드 0.5, 올림. 최소 1, 상한 5(초과분은 운영사 부담) | 원고 근거 질문 약 3~5 | 약 1~2 | `conv:<id>:turn:<n>` |
| 받아쓰기(구간 120초 이하) | 구간 길이(분) × 단가, 구간마다 올림 | 실제 `audio_seconds` | 60초 3 / 120초 6 | 60초 1 / 120초 1 | `voice:<voice_job_id>` |
| 답변 읽어 주기 TTS | 답변 글자 수 × 단가, 천 자 단위 올림 | 실제 `characters` | 600자 5 | 600자 1 | `voice:<voice_job_id>` |
| 원고 낭독·오디오북 미리듣기 | 본문 글자 수 × 낭독 단가(천 자당 ElevenLabs 8 / 오픈소스 1), 천 자 단위 올림. ElevenLabs 낭독은 코어 지표 5가 아니라 제품 단가 8(2026-10-14: Multilingual 원가가 크레딧당 22.4원으로 Basic 허용 원가 12.9원을 넘는다, `Price_Plans/flora-publishing/PRICE_PLAN.md` 3.2절) | 실제 `characters` | 8,000자 64 | 8,000자 8 | `voice:<voice_job_id>`(= 요청 `request_id`) |
| 낭독 재생·재다운로드, 같은 본문 해시 재요청 | 0 | - | - | - | - |
| 자료 색인(파일 1개) | 1, 10만 토큰마다 +1 | 실제 토큰 | 해당 없음(임베딩은 오픈소스 고정) | 1~2 | `rag:<document_id>` |
| 설정집 만들기(ingest) | 3 | 실제 사용량, 최소 1 상한 10 | 약 3 | 약 1 | `run:<ai_run_id>` |
| 설정집 점검(lint) | 2(정액) | 차액 없음 | 2 | 1 | `run:<ai_run_id>` |
| 설정집 열람·편집, 대화 목록 | 0 | - | - | - | - |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 경로별 단가 | 국외 이전에 동의하지 않은 조직과 오픈소스 전용 책은 체인에 오픈소스만 남으므로 오픈소스 단가가 자동 적용된다. 화면은 실제로 고른 경로의 예상치를 보여 준다 | `docs/products/_supabase-modular/migrations/0008_core_ai.sql:452-460` |
| 실패 환불 | 이용자에게 결과가 전달되지 않은 실패는 선차감 전액 환불. 낭독은 구간 하나라도 실패하면 전체 실패 | `docs/products/_platform-core/AI_ARCHITECTURE.md:129` |
| 정산 시점 | 응답·작업 종료 직후 정산. 스트림이 끊기면 선차감을 남기고 정산 잡이 `settled_at is null` 행을 5분 주기로 처리(제안) | `docs/products/_platform-core/AI_ARCHITECTURE.md:128` |
| 표시 | 보내기 전 "약 3크레딧(정산 후 1~5)", 낭독 버튼에 예상치, 정산 결과는 메시지 아래와 원장 표에 | 제안 |
| 공정 사용 | 사용자당 하루 채팅 턴 상한(`features.ai_chat_turns_per_day`) | 제안 |

검산: 5챕터 x 3소제목(15소제목) 책을 그래프 초안(fast)으로 쓰면 소제목 30 + 제목 1 + 기획 2 + 목차 2 + 표지 6 + 정보 1 + PDF 2 = 44크레딧이다. Basic 월 200크레딧으로 4권 안팎이며 4.3절의 "월 6권"은 단건 집필 기준이다. 그래프 초안 단가(2/4)는 일관성·교정 호출 2회분이 더해진 제안이므로 출시 전 토큰 원가로 재산정한다(PB-06-008, D14).

## 5. 비기능 요구사항

| 항목 | 목표 | 근거 |
|---|---|---|
| 동기 LLM(제목, 기획안, 목차, 책 정보) | p95 30초 이내 완료, 타임아웃 60초, 폴백 1회 | `SHARED_MODULES.md:207` |
| 섹션 단건 스트리밍 | 첫 토큰 p95 5초, 완료 p95 90초 | 제안: Vercel 함수 최대 실행 시간 안에 끝나야 함 |
| 전체 순차 생성 | 책당 동시 3섹션, 섹션 재시도 3회, 하트비트 30초, 무응답 10분이면 회수 | 분석:98, `CORE_SPEC.md:304` |
| PDF 렌더 | 200쪽 p95 60초, 타임아웃 120초, 렌더 서비스 동시 4건(제안: 컨테이너 2vCPU 기준) | `SHARED_MODULES.md:261` |
| ePub 생성 | p95 30초 | 제안 |
| 업로드 | 파일 20MB 상한, 형식 txt/md/docx/pdf, 파싱 p95 60초 | 분석:116 |
| 원고 크기 | 섹션 본문 200KB, 책당 소제목 200(Basic), 챕터 20, 소제목/챕터 10, 단락/소제목 5 | `Flora-v2/PRD.md:90`, 제안(DB CHECK) |
| 자동 저장 | 2초 debounce, 저장 실패 시 3회 재시도 후 배너 | `Flora-v2/CLAUDE.md` use-auto-save |
| 레이트 리밋 | 생성 API 조직당 60회/분, 로그인 IP당 10회/10분, 웹훅 수신 600회/분, 대기자 IP당 5회/시간, 미리보기 조직당 30회/분 | `SECURITY_BASELINE.md` 8장, 제안(대기자·미리보기) |
| 파일 보존 | 내보내기 파일 30일(서명 URL 7일, 만료 후 같은 해시면 재생성 무료), 업로드 원본은 파싱 24시간 뒤 삭제(파싱 결과는 책과 함께), 표지는 책과 함께 | `CORE_SPEC.md:317`, 제안 |
| 삭제 | 책 휴지통 30일, 조직 탈퇴 유예 30일 → purge | `SECURITY_BASELINE.md` 12장 |
| 감사 로그 보존 | 2년 | `CORE_SPEC.md:330` |
| 가용성 | 월 99.5%(Vercel + Railway + Supabase 합산) | 제안 |
| 한글 폰트 | PDF는 Noto Serif CJK KR / Noto Sans CJK KR 임베딩, ePub은 OFL 폰트만 포함 | 분석:215 |
| 채팅 첫 표시 | 용어·일반 상담 p95 3초, 원고 근거 질문 p95 12초 이하(Dify HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 표시) | 제안: 04장 6.2절 |
| 채팅 턴 완료 | p95 15초 이하 | 제안 |
| 초안 그래프(챕터 1개, 소제목 5개) | p95 180초 이하, 노드 재시도 포함 타임아웃 300초, 취소 후 60초 안 중단 | 제안: 소제목 동시 3, 검사 2회 추가 |
| 자료 색인(파일 1개 20MB 이하) | p95 90초 이하 | 제안 |
| 설정집 만들기 | p95 120초 이하 | 제안 |
| STT(120초 구간) | p95 8초 이하 | 제안: 오픈소스 GPU 서버 기준, 구현 시 확인 |
| TTS 첫 오디오(읽어 주기) | p95 2초 이하 | 제안 |
| 낭독 생성(8,000자) | p95 120초 이하 | 제안: 구간 단위 순차 TTS |
| AI 레이트 리밋 | 채팅 사용자당 20턴/분 + 하루 `ai_chat_turns_per_day`, STT 사용자당 10회/분, 낭독 조직당 5회/시간, 잡 토큰 발급 120회/분, 설정집 만들기 책당 1건 진행 | 제안: `docs/products/_platform-core/SECURITY_BASELINE.md:143-155` 기준 |
| AI 입력 상한 | 채팅 메시지 1,000자·대화당 50턴, 받아쓰기 구간 120초·5MB, 참고 파일 20MB, 책당 색인 텍스트 100만 자(제안) | 제안 |
| 3D 히어로 | 3D 번들+에셋 PC·태블릿 1MB, 모바일 300KB 이하, 60fps / 30fps 이상 | `docs/products/_design-guide/HERO_3D.md:32-41` |
| AI 기록 보존 | Dify 대화 로그 30일, `core.ai_messages`는 대화 삭제 또는 탈퇴 후 30일, 낭독 mp3 30일, 색인 청크·설정집은 책 영구 삭제(휴지통 30일 뒤) 또는 조직 purge 때 삭제 | `docs/products/_platform-core/AI_ARCHITECTURE.md:69`(제안 30일) |

## 6. 법, 개인정보, 금지 문구

| 항목 | 내용 |
|---|---|
| 개인정보 수집 항목 | 이메일, 표시 이름, 비밀번호 해시(Supabase Auth), 로그인 제공자 식별자(단계별: Stage B부터 Google 계정 식별자·이름·프로필 이미지 URL, C1부터 카카오 사용자 식별자·닉네임·프로필 이미지·비즈 앱이면 이메일, C2부터 네이버 고유 id·이메일·이름. AUTH_ROADMAP 5.2, 7.1.1, 7.2.3절), 결제 정보(Toss가 보관, 우리는 주문 id·금액·카드사·마스킹 번호만), 원고와 생성물, 접속 IP 해시(레이트 리밋, 원문 저장 안 함), 대기자 이메일 |
| 목적 | 계정 운영, 책 제작 기능 제공, 결제와 환불, 부정 사용 방지, 출시 알림(대기자, 마케팅 동의 시에만) |
| 보존 | 회원 정보는 탈퇴 후 30일 유예 뒤 삭제. 결제 기록은 전자상거래법상 5년(미확인: 적용 조항은 법무 확인). 업로드 원본 24시간, 내보내기 파일 30일, 감사 로그 2년, 대기자 이메일은 출시 후 90일 또는 수신 거부 시 삭제(제안) |
| 암호화 대상 | 아웃바운드 웹훅 서명 비밀은 `core.encrypted_credentials`(AES-256-GCM). 빌링키는 `core.billing_keys`. 원고는 Supabase 저장 암호화에 맡기고 컬럼 암호화는 하지 않는다(제안: 원고는 검색·렌더 대상이라 앱 계층 암호화 시 기능 손실) |
| 삭제 절차 | 책: soft delete(`deleted_at`) → 30일 뒤 purge 잡. 조직: soft delete → 30일 → `purge_organization` + Storage 폴더 삭제 |
| 제3자 제공(국외 이전 포함) | 상용 LLM 제공자(Anthropic, OpenAI, Google, OpenRouter, 2026-10-13 확정 결정 17): 국외 이전에 동의한 조직의 요청에만 쓰며, 프롬프트에 원고 일부, 기획안, 설정집, 페르소나 지시, 채팅 메시지를 보낸다. 음성 제공자(ElevenLabs): 동의한 조직의 요청에 한해 받아쓰기 음성과 낭독할 본문을 보낸다. 오픈소스 LLM·임베딩·음성 서버와 Dify는 운영사가 자체 운영한다(서버 위치·위탁 여부 구현 시 확인).  이미지 제공자(fal): 표지 프롬프트(제목·장르·스타일)만 보내고 원고 본문은 보내지 않는다. Toss: 결제 정보. 처리방침에 제공자, 항목, 국가, 보유 기간을 표로 고지. 각 제공자의 학습 사용 여부 정책은 미확인이며 계약 전 확인 |
| 약관/고지 | 이용약관, 개인정보처리방침, 환불 규정(4.5절), 사업자 정보(상호, 대표, 사업자등록번호, 통신판매업 신고번호, 주소)를 하단에 표시 |
| AI 생성물 안내 | 생성물의 권리와 책임은 이용자에게 있고, AI 생성물은 저작권 보호가 제한될 수 있으며 타인의 저작물과 유사할 수 있음을 생성 화면과 약관에 고지. 실존 작가 이름을 페르소나로 쓰지 않는다(`Flora-v2/CLAUDE.md` 페르소나 규칙). 업로드 원고는 이용자가 권리를 가진 것만 올리도록 업로드 화면에서 확인 체크 |
| AI 생성 표시 | 내보낸 PDF/ePub 판권면(마지막 쪽)에 "이 책의 일부는 AI 도구(FLORA Publishing)로 작성·편집되었습니다" 문구를 기본으로 넣고 이용자가 끌 수 있다(제안: 표시 의무 법제화 여부 미확인, 자율 표시로 시작) |
| ISBN | 9단계 ISBN은 형식 참조용이며 실제 등록 번호가 아님을 고지. 실제 ISBN은 국립중앙도서관 서지정보유통지원시스템에서 발급받아야 함을 안내(미확인: 절차 링크는 구현 시 확인) |
| 제휴/광고 | 해당 없음. 이 제품은 affiliate 모듈을 쓰지 않는다(`SHARED_MODULES.md:44`) |
| 플랫폼 약관 | 외부 플랫폼 자동 업로드가 없다. 아웃바운드 웹훅은 이용자가 등록한 URL로만 보낸다. 전자책 플랫폼 등록 규격(ePub 검증)은 이용자 책임이며 epubcheck 결과를 보여 준다 |
| 금지 문구(마케팅) | 가상 후기(존재하지 않는 작가 후기·평점), 허위 수치(검증되지 않은 사용자 수·출간 수·대기자 수, 원본의 시드 카운트 147 같은 값, `docs/reviews/flora.md:82`), 보장 표현("베스트셀러 보장", "100% 출간", "수익 보장"), 타사 상표 오용(교보문고, 리디, 크레마 등의 로고·이름을 제휴처럼 쓰는 것), "인쇄소 수준 보장" 같은 품질 단정 |
| 금지 문구(생성 콘텐츠) | 실존 인물 사칭 문체 지시, 의료·금융 단정 표현은 이용자 원고의 책임이지만 기본 시스템 프롬프트가 생성하지 않도록 지시한다. 표지 이미지 안전 필터를 끄지 않는다. AI 생성물에 대해 "표절 없음", "저작권 보장", "AI 탐지 회피" 같은 보장 표현을 쓰지 않는다. 6.1절 AI 대화 규칙 참조 |
| 규제 특례 | 해당 없음(의료·금융·미성년자 특화 없음). 만 14세 미만 가입 제한(제안: 법정대리인 동의 절차를 만들지 않기 위해) |

### 6.1 AI·음성 개인정보 판단과 대화 규칙 (2026-10-13)

원고의 개인정보 판단과 오픈소스 강제 범위(열린 결정 D12, 권고안으로 진행). 이 제품은 `contains_pii` 라우팅 결정을 아래와 같이 문서화한다.

| 항목 | 판단 | 이유와 처리 |
|---|---|---|
| 원고 | 이용자의 창작물이지만 에세이·회고록·실화 바탕 소설에는 실존 인물의 이름, 연락처, 건강, 금융, 가족 정보가 들어갈 수 있고 서버가 사전에 분류할 수 없다(법무 확인 필요) | 기본은 오픈소스 강제가 아니라 국외 이전 동의로 통제한다. 원고 임베딩은 모두 오픈소스(`oss-embed`)로 고정해 컬렉션에 모델이 섞이지 않게 하고 개인정보가 국외로 나가는 경로를 줄인다 |
| `contains_pii` 선택 | 업로드 화면과 책 설정에서 이용자가 "실존 인물 정보 포함"을 선택한다. 모르겠다면 켜는 쪽을 안내한다 | 선택 시 `ai_documents.contains_pii=true`, 그 문서에서 만든 설정집 페이지 `derived_from_pii=true`, 책의 `ai_open_source_only=true`. 이 책의 AI·음성 호출은 상용으로 대체하지 않는다. ai-service 라우터가 체인에서 상용 제공자를 제외하는 방식은 구현 시 확인(코어 요청 R8) |
| 오픈소스 전용 한계 | 오픈소스 모델은 상용보다 초안 품질이 낮을 수 있다 | 화면에 "이 책은 국내 오픈소스 AI로만 처리됩니다. 초안 품질이 다를 수 있습니다"를 보여 준다. 품질 평가셋(PB-06-047)을 두 경로로 모두 통과시킨다 |
| 채팅·받아쓰기 자유 입력 | 이용자가 민감한 내용을 적거나 말할 수 있다 | 입력란에 "주민등록번호, 계좌·카드 번호는 적지 마세요" 안내. 채팅 메시지는 서버가 주민등록번호·전화번호·이메일·계좌번호 형식을 마스킹해 AI로 보낸다(제안). 원고 본문은 내용 손상을 막으려고 마스킹하지 않는다 |
| Dify 보조 노드 | 조직을 알 수 없어 동의를 확인할 수 없다 | `dify.aux`는 오픈소스 강제(`force_open_source=true`, 02장 5절). 보조 노드에는 원고 본문을 넘기지 않는다 |
| 모델 학습 | 각 제공자가 입력을 학습에 쓰는지는 미확인 | 계약 전 제공자별 정책을 확인해 처리방침에 반영(구현 시 확인). 우리는 원고를 모델 학습에 쓰지 않는다 |

| 고지·동의 | 시점 | 기록 |
|---|---|---|
| 상용 AI 국외 이전 | 이메일 인증 직후 온보딩, 설정에서 변경 | `core.ai_org_settings`(고지문 버전) + `core.audit_log`(`ai.consent.cross_border`) |
| 음성 처리 고지(녹음) | 첫 마이크 사용 직전. 녹음 목적, 원본 미저장, 주변 다른 사람의 목소리가 담기지 않게 주의, 상용 제공자 사용 시 국외 이전 | `core.audit_log`(`voice.notice_ack`, 고지문 버전). 녹음 원본을 저장하지 않으므로 `voice_jobs.store_audio=false`이고 `consent_*`는 비운다. 제3자 음성을 저장하는 기능이 없어 `third_party_notice`는 쓰지 않는다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:85-95`) |
| AI 생성 표시 | 채팅 답변, 낭독 음성, 초안 제안, 판권면 | 채팅 답변마다 "AI가 생성한 답변", 낭독 음성 첫머리와 플레이어에 "AI가 생성한 음성입니다", 초안·교정 제안 카드에 "AI 제안", 설정집 제안 페이지에 "AI가 제안한 초안". 판권면 AI 고지(위 AI 생성 표시 행)는 AI 초안·AI 음성 사용 여부를 반영한다. 다른 모델로 대체된 답변은 "다른 AI 모델로 답했습니다" 표시 |

AI 대화 추가 규칙(PB-F-054의 근거):

| 분류 | 금지 | 대신 |
|---|---|---|
| 실존 인물 사칭 | 특정 작가·인물의 문체로 쓰라는 지시를 따르거나 이름을 페르소나로 노출 | 문체 특성을 설명하는 중립 지시(60종 카탈로그) |
| 보장 표현 | "베스트셀러가 됩니다", "표절 걱정이 없습니다", "AI가 썼다는 사실이 탐지되지 않습니다" | 편집 제안과 사실 확인 안내 |
| 복제 | 참고 파일·타인 저작물 문장을 연속으로 베끼기 | 요약·재구성 + 출처 안내. 인용은 이용자가 직접 표시 |
| 전문 판단 대행 | 의료 진단·처방, 법률 판단, 투자 권유를 사실처럼 쓰기 | 이용자 원고의 책임임을 안내하고 단정 표현은 완화 제안 |
| 위기 신호 | 자해·자살 언급에 글쓰기 조언만 하기 | 조언을 멈추고 자살예방 상담전화 109 등 안내(번호는 구현 시 확인) |
| 개인정보 요구 | 실명·주민등록번호·연락처를 묻기 | 묻지 않는다 |

## 7. KPI

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| 10단계 완성률 | 60% 이상 | `books`에서 `writing_started_at`이 있는 책 중 `completed_at`이 있는 비율 | 출시 후 90일 | 
| PDF/ePub 내보내기 완료율 | 70% 이상 | `book_exports.status='succeeded'` / 요청 수 | 월간 |
| 원고 업로드 경로 사용률 | 30% 이상 | `books.source='upload'` 비율 | 월간 |
| 전체 순차 생성 사용률(Basic) | 70% 이상 | Basic 조직 중 `generation_runs.kind='write_all'` 1회 이상 비율 | 월간 |
| Free → Basic 또는 팩 구매 전환율 | 8% | 가입 후 60일 안에 첫 결제한 조직 비율 | 코호트 60일 |
| 렌더 실패율 | 2% 미만 | `book_exports.status='failed'` / 전체 | 주간 |
| 크레딧 원장 drift | 0 | `core.credit_ledger_reconciliation` | 매일 |
| 대기자 명단 | 출시 전 1,000명 | `publishing.waitlist` 행 수 | 출시 전 |
| AI 채팅 사용률 | 집필 시작 책이 있는 사용자의 25%(제안) | `core.ai_conversations` 1개 이상 사용자 / `writing_started_at`이 있는 책의 소유 사용자 | 3개월 |
| 답변 출처 표시율 | 95% 이상(제안) | `ai_messages.citations`가 빈 배열이 아닌 assistant 메시지 비율 | 월 |
| 설정집 채택률 | "설정집 만들기"를 실행한 책의 50%가 `published` 페이지 1개 이상(제안) | `core.wiki_pages` slug `books/<id>/` | 3개월 |
| 초안 그래프 성공률 | 소제목 98% 이상(제안) | `generation_runs`의 succeeded 소제목 / (succeeded + failed) | 월 |
| 낭독 생성 성공률 | 98% 이상(제안) | `voice_jobs`(feature `narration`) succeeded / 전체 | 월 |
| 검수 처리율(2026-10-14) | 대기 항목의 70% 이상이 7일 안에 결정(제안) | `agent_tasks`에서 `approval_status`가 pending을 거쳐 결정된 행 / pending이 된 행 | 월 |
| 재시도 성공률 | 60% 이상(제안) | `retry_of`가 있는 행 중 `succeeded` 비율 | 월 |
| AI 원가율(운영 지표) | 크레딧 매출 대비 AI 원가 40% 이하(제안) | `core.ai_usage.cost_usd_micros` 합(원화 환산) / 같은 기간 소비 크레딧 × 크레딧당 단가(4.2절) | 월 |

근거: 첫 4개와 대기자 목표는 `Flora-v2/PRD.md:536-547`, 전환율은 v2 "프리 → 기본 8%"(`:539`)를 2단 플랜에 맞춰 옮김. 렌더 실패율·drift는 제안.

## 8. 열린 결정

| # | 항목 | 선택지 | 권고 | 근거 |
|---|---|---|---|---|
| D1 | 확정 결정 3의 FastAPI 범위 | (a) LLM 라우터까지 FastAPI(v2 방식) (b) LLM·크레딧·결제는 Next(공용 TS 모듈), FastAPI는 파싱·HTML 조립·ePub·렌더 호출 엔진 | (b)(2026-10-13 부분 변경: 크레딧·결제·잡은 그대로 (b)이고, LLM 라우터 본체는 확정 결정 17로 ai-service `api/`가 맡는다. D13 참조). LLM 게이트웨이·크레딧·Toss·잡 공용 모듈이 TS 패키지라 Python에서 다시 만들면 재정의 금지 위반(`SHARED_MODULES.md:11-16`, `:469-474`). Python 자산(pdfplumber, docx 파서, ePub3, WeasyPrint)은 엔진에 남긴다 | 확정 결정 3, 분석:221-225 |
| D2 | TTS 엔진 | (a) F5-TTS GPU 자체 배포 (b) 외부 TTS API (c) 오디오북 제외 | 닫힘(2026-10-13): 확정 결정 16으로 ElevenLabs + 오픈소스 이원화. 미리듣기는 MVP(PB-F-052), 전권·멀티보이스는 Phase 2. F5-TTS 공개 가중치는 비상업 라이선스라 쓰지 않는다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:57`) | 분석:245-249 |
| D3 | 판형 프리셋 값 충돌(A5 v1 10.5pt/20mm vs v2 9.5pt/18mm) | (a) v2 값 (b) v1 값 (c) v2 키 + 실물 출력 테스트로 확정 | (c). 확정 전 임시값은 v2 값 | 분석:257-261 |
| D4 | 업로드 형식 | (a) txt, md, docx, pdf, hwp (b) hwp 제외 (c) txt, md, docx만 | (b). DB CHECK도 hwp를 뺐다 | 분석:263-267, `docs/reviews/Flora-v2.md:76` |
| D5 | 판매·유통 | (a) 없음 (b) 공개 책 페이지만(Phase 2) (c) 판매·정산 | (b) | 분석:269-273 |
| D6 | 카카오 로그인 | (a) 이메일 + Google (b) 카카오 추가 | 닫힘(2026-10-14): 결정 22로 C1 확정. 공개 베타까지는 (a)(Stage B), 카카오는 G2 통과 후 C1(P1, PB-06-057). 카카오 이메일 정책은 8.1절 D20 | 분석:275-279, 확정 결정 22 |
| D7 | LLM 전략 | 공용 LLM 게이트웨이가 "Anthropic + OpenRouter 폴백, 2모드 노출"로 이미 정해져 있다(`SHARED_MODULES.md:204`) | 닫힘(2026-10-13): 확정 결정 17. 기능별 체인은 02장 5.1절(Claude → ChatGPT → Gemini → 오픈소스). "빠름/고품질" 2모드는 모델 선택이 아니라 프롬프트·단가 모드로 남긴다 | 분석:251-255 |
| D8 | 크레딧 단가·월 크레딧 | 4.3절 제안값 | 출시 전 실제 토큰 원가로 재산정. 결정됨(2026-10-14, Price_Plans 반영): 섹션 집필 quality 2 → 3. 표지 단가는 D11 모델 확정 후 | 제안 |
| D9 | Free의 업로드·전체 생성 허용 | (a) v2처럼 막음 (b) 크레딧이 비용을 막으므로 허용 | (a)로 시작(유료 전환 동기). 업로드 사용률 KPI가 목표 미달이면 (b) | `Flora-v2/PRD.md:313-314` |
| D10 | 모놀리스 스키마 | `public`(코어 lite와 같음) | 사용자 최종 확인 대기 | 작업 지시, `MONOLITH_CORE_LITE.sql:5` |
| D11 | 표지 이미지 모델 | fal 안의 모델 1~2개 | 출시 전 한글 제목 없는 표지 품질 비교 후 1개 | 분석:104 "제공자는 1~2개로 축소" |
| D12 | 원고의 개인정보 분류와 오픈소스 강제 범위(`contains_pii` 라우팅) | (a) 기본 비강제 + 국외 이전 동의 + 이용자 선택 시 책 단위 오픈소스 전용 (b) 전 책 오픈소스 강제(`force_open_source`) (c) 항상 상용 | (a). 6.1절. (b)를 고르면 02장 5.1절 `publishing.*`, `chat` 행을 `open_source` + `force_open_source=true`로 바꾸고 초안 품질 평가셋(PB-06-047)을 오픈소스 모델로 다시 통과시켜야 한다. 책 단위 스위치를 `book_info` 키로 둘지 전용 컬럼(`books.ai_open_source_only`)으로 승격할지도 이 결정에서 닫는다(승격하면 PB-06-001 후속 마이그레이션) | `docs/products/_platform-core/SECURITY_BASELINE.md:291` |
| D13 | 단건 LLM 호출 경로와 스트리밍 | (a) ai-service 그래프 `publishing.assist`로 이전하고 그래프 SSE 중계를 코어에 요청 (b) 기존 TS 게이트웨이 직접 호출 유지 | (a)(제안). 그래프 SSE가 공용 계약에 없다(`docs/products/_platform-core/AI_ARCHITECTURE.md:149-158`). 지원되기 전에는 Route Handler가 `GET /graphs/runs/{id}`로 완성본을 받아 SSE로 흘려보낸다(첫 토큰 목표 완화). 코어 요청 R9 | 02장 5절 |
| D14 | AI·음성 크레딧 단가 | 4.6절 제안값(초안 그래프 2/4, 채팅 3, 설정집 3 등) | 출시 전 `core.ai_usage` 원가로 재산정. 토큰 원가가 단가보다 크면 정산 상한을 조정. 결정됨(2026-10-14, Price_Plans 반영): 원고 낭독 ElevenLabs 천 자당 5 → 8. 나머지는 실측 후 | 4.6절 |
| D15 | 낭독·미리듣기 보이스와 ElevenLabs 데이터 보관 | (a) ElevenLabs 기본 보이스 1종 + 오픈소스 보이스 1종 고정 (b) 이용자 선택. 입력 보관·학습 사용·제로 리텐션 옵션 여부 | (a). 보이스 id는 환경변수(02장 8절). 오픈소스 보이스는 `VOICE_ARCHITECTURE.md` 4.1절 후보 중 코드·가중치 라이선스와 한국어 낭독 품질을 확인해 고른다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:63-73`). 생성 음성의 상업 이용 조건(미리듣기 파일을 이용자가 배포해도 되는지)과 데이터 보관 조건은 ElevenLabs 계약으로 구현 시 확인 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:81-83` |
| D16 | 동의 증빙 저장 위치 | (a) 코어 `ai_org_settings` + `audit_log`(제품 AI 표 없음) (b) 제품 `publishing.consents` 표 추가(astro-ai 방식) | (a)(제안: 제품 AI 표는 꼭 필요할 때만, `AI_ARCHITECTURE.md:165`). `audit_log` 보존은 2년(제안, 5절)이라 분쟁 증빙 기간이 부족하면 (b)로 전환하고 PB-06-001 후속 마이그레이션 | 05장 6절 |
| D17 | 채팅 화면 레퍼런스 Astryx | (a) Astryx 패턴 (b) Primer + shadcn/ui 패턴 | 존재·라이선스를 확인하면 (a) 패턴만 사용, 확인 실패 시 (b) | 확인 전까지 미확인(`docs/products/_design-guide/DESIGN_SYSTEM.md:11`). PB-06-039에서 확인 결과를 기록. 앱 화면의 주 레퍼런스는 Atlassian(03장 3.2절) |
| D18 | 워커의 그래프 호출 인증 | (a) Next.js 잡 토큰 발급 엔드포인트 `/api/internal/ai-token` (b) FastAPI가 잡을 직접 소비 (c) 워커에 개인키 배포 | (a)(제안). 개인키는 Next.js에만 둔다는 코어 규칙(`docs/products/_platform-core/SECURITY_BASELINE.md:284`)을 지킨다. 코어 표준화 요청 R10 | astro-ai D-18 |
| D19 | 무료 플랜의 AI 범위 | (a) Free도 채팅·받아쓰기·설정집(낭독·초안 그래프는 Basic) (b) 모든 AI를 Basic 이상으로 | (a)(제안). Free 월 20크레딧이 비용 상한이다. 전환 효과가 없거나 원가가 크면 (b) | 4.4절 |

### 8.1 인증 단계 결정 (2026-10-14, 확정 결정 22)

확정 결정 22(`docs/products/00_MERGE_ANALYSIS.md:30`)로 로그인은 Mock(A) → Google(+이메일)(B) → 카카오(C1)·네이버(C2) 순서로 켠다. 단계 규격은 `docs/products/_platform-core/AUTH_ROADMAP.md`가 정본이고, 아래는 이 제품에서 닫아야 할 남은 결정이다. 기존 D6은 이 결정으로 닫혔다.

| # | 항목 | 선택지 | 권고 | 닫는 시점 | 근거 |
|---|---|---|---|---|---|
| D20 | 카카오 이메일 정책(C1) | (a) 비즈 앱 전환 후 `account_email` 필수 동의 (b) 이메일 없이 허용(온보딩에서 연락 이메일 별도 입력, 같은 사람이 Google로 오면 다른 사용자) | (a). 영수증·알림 메일·계정 연결이 Google과 같아진다. 운영 주체의 사업자 정보로 비즈 앱 전환을 할 수 있는지는 미확인 | G2 판정 전(PB-06-057 착수 전) | AUTH_ROADMAP 7.1.2절 |
| D21 | 네이버 연동 경로(C2) | (a) Supabase 커스텀 OAuth2 `custom:naver` (b) 서버 브리지 + 코어 `staged/0010_core_auth_identity_links.sql` | 스파이크 결과로 결정(PB-06-058 첫 단계, 0.5일). 결과는 `NAVER_AUTH_PATH`와 task `log.md` `[DECISION]`에 기록. (b)면 06장 8.3절 코어 요청 R15 | PB-06-058 스파이크 직후 | AUTH_ROADMAP 7.2.2, 7.2.3절 |
| D22 | 이메일+비밀번호 가입 유지 여부(공개 가입 제품) | (a) 유지(Stage B에서 Google과 함께 켠다) (b) Google·카카오·네이버만 | (a). PB-F-001이 이메일 인증 필수 가입을 이미 정했고 이 결정은 그것을 바꾸지 않는다. 이메일 가입·메일 인증·비밀번호 재설정 화면은 Stage B 작업(PB-06-056)이 만든다 | G1 판정 전 | AUTH_ROADMAP 1장 "이메일+비밀번호" 행 |

### 8.2 FLORA 개편 결정 (2026-10-14, 검토 대기)

문서 본문(01장 3.1절, 02장 10절, 03장 8절, 06장 9절)은 각 결정의 **권고안을 가정**하고 썼다. 다른 선택지를 고르면 "영향" 열의 위치를 고친다. 외부 제안서(ChatGPT 작성)의 시각 방향은 "기존 토큰을 확인한 뒤 확정할 초안"이라고 스스로 밝히고 있다. 기존 03장 4.3절 토큰은 DP 1~5단계(레퍼런스, 브리프, 생성형 기본값 검토)와 3D 히어로 재질까지 묶여 확정됐으므로 덮어쓰지 않고 아래 결정으로 올린다.

| # | 항목 | 선택지 | 권고 | 닫는 시점 | 근거 |
|---|---|---|---|---|---|
| D23 | 브랜드 팔레트 | (a) 기존 확정 토큰 유지: 청먹 #1C2B39, 교정지 #EEF1F4, 공정 시안 #00739E, 맞춤 마젠타 #B0225C(03장 4.3절) (b) 제안서 팔레트: 딥 포레스트 그린 #245B46, 뮤트 세이지 #8FAE98, 잉크 블랙 #202521, 쿨 뉴트럴 #F5F6F4, 경계선 #DDE2DD | (a). 교정지·재단선 어휘(03장 4.2절 브리프)와 3D 히어로 재질이 이 팔레트로 설계됐다. (b)의 녹색·세이지는 같은 포트폴리오의 보태닉 브랜드 website-floria와 인상이 겹치고, 이름(FLORA/Floria)까지 비슷해 브랜드 구분이 약해진다. 제안서에서 가져올 것은 색 값이 아니라 "포인트 색은 주요 행동·선택·진행에만" 규칙(03장 8.2절) | PB-06-041(사람 검토) | 03장 4.3절, 8.2절, 제안서 2절 |
| D24 | 화면 서체 | (a) 전 화면 IBM Plex Sans KR(기존) (b) 전 화면 Pretendard(제안서) (c) 레이어별: 랜딩은 마루부리 + IBM Plex Sans KR 유지, 작업 공간·운영 콘솔은 Pretendard 후보 | (c). Pretendard는 한국어 UI의 습관적 기본값이라 랜딩 차별화에는 불리하지만(DP 생성형 기본값 12번), 정보 밀도가 높은 표·패널에서는 가독성 검증 사례가 많다. 041에서 실제 원고 편집기·운영 표 스크린샷 두 벌로 비교해 고른다. 출판 결과물 서체는 기존대로 Noto Serif/Sans CJK KR(제안서와 같음) | PB-06-041 | 03장 4.3절, 제안서 2절 |
| D25 | 랜딩 헤드라인 | (a) "원고를 넣으면 이 판형의 인쇄용 PDF와 ePub이 됩니다"(기존, 결과를 말함) (b) "당신의 경험을, 한 권의 책으로."(제안서, 정서) | (a)를 히어로에, (b)를 결과물 갤러리 섹션 제목에 쓴다. 출시 전 대기자 랜딩에서 두 문구를 기간을 나눠 번갈아 걸고 대기자 등록 전환율로 고른다(제안: 각 2주, 방문 1,000 이상). 개발 없이 검증할 수 있는 가장 싼 실험이다 | 공개 베타 전 | DP 카피 규칙(`DESIGN_PRINCIPLES.md:190`), 제안서 3절 |
| D26 | 빈 소제목의 AI 초안 반영 | (a) 바로 채우고 "AI 초안 · 검토 전" 표시, 내보내기 전에 수를 알림(기존 PB-F-017 동작 유지) (b) 빈 소제목도 제안으로만 두고 승인해야 원고가 됨 | (a). 사용자가 쓴 글은 어느 쪽이든 바뀌지 않는다. (b)는 15소제목 책에서 승인 클릭 15번을 강요해 전체 순차 생성의 가치를 깎는다. 제안서의 "승인 전 자동 반영 금지"는 본문이 있던 곳에 그대로 적용한다 | PB-06-059 착수 전 | PB-F-017, PB-F-058 |
| D27 | 운영자의 원고 열람 | (a) 기본 차단. 이용자가 설정에서 "지원 요청을 위해 24시간 열람 허용"을 켠 책만 사유 입력 후 열람, 감사 `admin.manuscript_view` (b) 운영자가 사유 입력만으로 열람 + 감사 | (a). 원고는 이용자의 미발표 저작물이고 실존 인물 정보가 있을 수 있다(6.1절). 허용 기록은 `books.book_info.support_access_until`(이용자 쓰기 컬럼이라 이용자만 켤 수 있다, 제안). 법령상 제출 요구 등 예외 절차는 법무 확인 | PB-06-062 착수 전 | 제안서 6절 "개인정보 보호", `SECURITY_BASELINE.md` 9장 |

| 결정 | 권고와 다르게 정하면 고칠 곳(영향) |
|---|---|
| D23·D24 | 03장 4.3절 토큰, 8.2절 레이어 표, 4.6절 3D 재질, `CLAUDE.md` 디자인 레이어 행 |
| D25 | 03장 8.3절 섹션 1·2 문구, PB-06-024 수용 기준 |
| D26 (b) | 01장 3.1절 집필 행·PB-F-058, 02장 10.1절 writing 행·10.3절 4단계, 03장 8.4·8.7절, PB-06-023·037·059 수용 기준(빈 소제목도 제안으로) |
| D27 (b) | 01장 PB-F-061, 03장 8.6절 개인정보 규칙, 04장 9.3절 `manuscript-view`, PB-06-062 수용 기준 |

## 9. 설득형 랜딩과 플랫폼 필요성 검증 (2026-10-17, 검토용)

근거는 공용 규칙 `docs/products/_design-guide/LANDING_PERSUASION.md`다. 다른 회사 랜딩의 문구·수치·비주얼은 쓰지 않고 설득 구조와 검증 방식만 쓴다(그 문서 1장). 시각 규칙은 03장 4절·8.2절 marketing 레이어 그대로다(카드 그리드·섹션 페이드업·큰 숫자 금지). 화면은 03장 9절, 작업은 06장 10절, 결정은 9.4절(D28~D32).

1~8장은 그대로 두고(다른 문서가 줄 번호로 인용한다) 이번 추가분을 이 장에 모았다. 각 절 제목에 어느 장의 추가분인지 적는다.

### 9.1 기능 요구사항과 수용 기준 (3장 추가분)

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| PB-F-064 | 랜딩 설득 칸 보강 | 디벨롭(P0) | 03장 8.3절 6섹션 사이에 "막히는 지점"(페르소나 좌절 장면 3개), "원인 하나"(기존 방식 / FLORA 방식 비교 1쌍)를 넣는다. 섹션 수는 8개 이하. 모든 문장은 주장 장부(03장 9.3절)에서 "검증" 상태인 것만 | 섹션 8개 이하, 장부에 없는 문장 0, 생성형 기본값 점검(03장 4.5절) 통과, 다른 회사 랜딩 문구 0(`LANDING_PERSUASION.md` 1장 9~12번) | `LANDING_PERSUASION.md` 2장 |
| PB-F-065 | "왜 FLORA인가" 판정 칸 | 신규(P0) | 대안 범주 4개(그대로 둔다, 범용 AI 채팅, 사람에게 맡긴다, 전문 도구) × 판정 기준 6개의 판정표, 우리 열 ○마다 증거 링크(샘플 PDF·ePub 내려받기, 가입 없이 판형 바꿔 보기), 표 아래 "이런 경우엔 다른 방법이 낫습니다" 3~4행. 특정 회사·서비스 이름과 로고는 쓰지 않는다(D28) | 우리 열에 △ 또는 ✕가 1개 이상, 우리 열 ○마다 증거 링크 1개, 샘플 파일은 CI가 렌더 서비스 출력에서 만든 것만, 375px에서 기준별 블록으로 접힘, 기호 + 텍스트(색만으로 구분 0) | `LANDING_PERSUASION.md` 3장 |
| PB-F-066 | 주장 장부와 필요성 검증 | 신규(P0, 문서 작업) | 랜딩·FAQ·인사이트 문장을 장부(03장 9.3절)에 등록하고 상태가 "검증"인 것만 게시한다. V0(인터뷰 5건, "왜 FLORA인가" 칸 유무 교대 실험)와 V1(5명 과업 시간 측정) 결과를 `[DECISION]`으로 남긴다 | 장부 상태와 게시 문장이 일치(점검 스크립트 또는 사람 점검표), V0 결과 기록 후 판정 기준 확정, 측정치 문장에 조건(인원·과업·기간) 표기 | `LANDING_PERSUASION.md` 3.4·3.6절, 린 검증 원칙 |
| PB-F-067 | 출판 인사이트 3편 | 신규(P2, D31) | `/insight/[slug]` 정적 글 3편. 주제: (1) 원고 파일과 책 지면은 다르다(판형·제책 여백·쪽번호·러닝 헤더), (2) 책 한 권 분량을 AI로 쓸 때 끊김과 문체 흔들림이 생기는 이유와 소제목 단위 생성, (3) AI 초안은 저자가 승인할 때 원고가 된다. 마지막 편은 비교 계산기(PB-F-068)와 무료 시작으로 잇는다 | 외부 인용은 원문 확인분만(출처·확인일), 메타 설명·OG 이미지·사이트맵, 화면에 영어 단계 라벨 0, 다른 회사 랜딩의 시리즈 제목·주장 문장 0 | `LANDING_PERSUASION.md` 5장 |
| PB-F-068 | 제작 비용·시간 비교 계산기 | 신규(P1) | `/tools/cost-compare`: 사용자가 원고 분량(자), 결과물(PDF·ePub·둘 다), 받은 외주 견적(원), 직접 작업할 때 예상 시간과 시간 가치를 넣으면 세 방법(직접, 외주, FLORA)의 비용·시간을 표로 보여 준다. FLORA 값은 01장 4장 정본(플랜 월 요금, 내보내기 단가, 업로드 파싱 0)으로 계산하고 공식을 화면에 보인다. 결과는 이메일 없이 먼저 보이고 아래에 기존 대기자·가입 폼을 선택으로 둔다 | 출처 없는 기본값 0(외주 단가 기본값은 비우거나 `Price_Plans/flora-publishing/PRICE_PLAN.md` 4장 출처·확인일과 함께), 결과 아래 추정치 고지, 입력값 서버 저장·수집 0, 큰 숫자 타일·카운트업 0, 계산 함수 단위 테스트 | `LANDING_PERSUASION.md` 6장 |
| PB-F-069 | 이중 타임라인과 문의 버튼 | 디벨롭(P1) | (1) 랜딩 "만드는 순서"와 에이전트 작업 상세(03장 8.5절) 타임라인을 "저자가 하는 일 / FLORA가 하는 일" 두 줄로 나눈다. 승인 지점은 저자 줄에 표시. (2) 마케팅 레이어에 고정 문의 버튼 하나(문의 경로는 D30). 자동으로 뜨는 말풍선·팝업 없음 | 작업 상세의 결정 단계가 저자 줄에만 표시, 문의 버튼 키보드 접근·375px에서 본문 가림 0, 자동 팝업 0 | `LANDING_PERSUASION.md` 4장 |

### 9.2 비교 표시 (6장 추가분)

| 항목 | 내용 |
|---|---|
| 비교 표시 | "왜 FLORA인가" 판정표(PB-F-065)와 계산기(PB-F-068)는 대안을 범주 이름으로만 쓰고 특정 회사·서비스 이름·로고를 쓰지 않는다(D28). 대안의 약점은 직접 해 보면 확인되는 사실만 쓰고, 측정치는 조건과 함께, 가격 비교는 출처·확인일·세금 포함 여부와 함께. 실명 비교광고의 법적 요건(「표시·광고의 공정화에 관한 법률」, 공정거래위원회 비교 표시·광고 심사지침)은 미확인이며 법무 확인 전에는 쓰지 않는다 |

### 9.3 KPI (7장 추가분)

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| "왜 FLORA인가" 칸 효과 | 칸이 있는 판의 대기자 등록률이 없는 판보다 낮지 않다(제안) | 칸 유무 판을 2주씩 교대, 판별 방문 수 대비 `publishing.waitlist` 신규 행(PB-06-063과 같은 집계) | 공개 베타 전 |
| 증거 클릭률 | 랜딩 방문의 10% 이상이 샘플 PDF·ePub 받기 또는 판형 바꿔 보기를 누른다(제안) | 분석 이벤트 `proof_click`(증거 ID만, 개인정보 없음) / 랜딩 방문 | 월 |
| 계산기 → 가입 전환 | 계산 실행 세션의 15%가 대기자 등록 또는 가입(제안) | 이벤트 `calc_run` 세션 중 같은 세션의 대기자 등록·가입 비율. 입력값은 수집하지 않는다 | 월 |

### 9.4 설득형 랜딩 결정 (8장 추가분, 검토 대기)

9.1절(PB-F-064~069)과 03장 9절은 아래 권고안을 가정하고 썼다.

| # | 항목 | 선택지 | 권고 | 닫는 시점 | 근거 |
|---|---|---|---|---|---|
| D28 | 판정표의 대안 표기 | (a) 범주 이름만(그대로 둔다, 범용 AI 채팅, 사람에게 맡긴다, 전문 도구) (b) 실명 비교(가격 플랜 4장의 도구 이름) | (a). 실명 비교는 근거 보관과 법무 확인이 필요하고(9.2절), 범주 비교로도 방문자가 자기 상황을 찾는다. 실명·가격은 내부 문서(`Price_Plans/flora-publishing/PRICE_PLAN.md` 4장)에만 | PB-06-066 착수 전 | `LANDING_PERSUASION.md` 3.1·3.5절 |
| D29 | 계산기 리드 수집 | (a) 결과는 이메일 없이 보이고 아래에 기존 대기자·가입 폼(DB 변경 없음) (b) 결과 메일 발송용 새 엔드포인트와 `waitlist.source` 컬럼 추가 | (a). 결과를 이메일 뒤에 숨기지 않는 것이 신뢰에 맞고, 유입 구분은 분석 이벤트로 충분하다. 메일 리포트가 전환에 필요하다는 데이터가 생기면 (b)로 PB-06-001 후속 마이그레이션 | PB-06-069 착수 전 | `LANDING_PERSUASION.md` 6장 |
| D30 | 문의 버튼 경로 | (a) 이메일(`mailto:`) (b) 카카오톡 채널 (c) 둘 다 (d) 두지 않음 | (a)로 시작. 1인 운영이라 응답 시간을 지킬 수 있는 경로 하나만 연다. 카카오톡 채널은 문의가 월 20건을 넘으면(제안) 추가 | PB-06-066 착수 전 | PB-F-069 |
| D31 | 인사이트 3편 시점 | (a) 공개 베타 전 1편 + 베타 후 2편 (b) 전부 Phase 2 (c) 하지 않음 | (b). V0 인터뷰로 판정 기준이 고객 언어로 확정된 뒤에 써야 검색어와 맞는다. 공개 베타 조건이 아니다 | V0 결과 기록 후 | `LANDING_PERSUASION.md` 5장 |
| D32 | 판정표 우리 열의 약점 표기 | (a) "디자인 자유도 △(판형·템플릿 안에서만)", "처음 쓰는 도구 △(위저드 10단계)" 두 칸을 그대로 둔다 (b) 약점 칸을 빼고 강점만 | (a). 우리 열이 전부 ○인 표는 믿기 어렵고, 자유 배치가 필요한 고객(화보집·그림책)을 미리 걸러 환불을 줄인다 | PB-06-066 착수 전 | `LANDING_PERSUASION.md` 3.2절 |

| 결정 | 권고와 다르게 정하면 고칠 곳(영향) |
|---|---|
| D28 (b) | 03장 9.2절 판정표 열 이름, 9.2절, PB-06-066 수용 기준. 법무 확인 기록 필요 |
| D29 (b) | 04장에 결과 메일 엔드포인트, 05장 `waitlist`에 `source` 컬럼(PB-06-001 후속 마이그레이션), 6장 개인정보 수집 항목(9.2절에 추가 행) |
| D31 (a) | 06장 10.2절 웨이브(068을 W5로), PB-06-068 우선순위 P1 |

## 10. 대시보드 셸·GNB 결정 대기 (2026-10-19 추가, 03장 10장)

03장 10장(헤더 + 좌측 GNB + 홈 구성)에서 사용자 결정이 필요한 항목이다. 결정 전에는 03장 10.1절 기본값으로 시안과 문서를 둔다. FLORA Publishing 전용이고 다른 제품에는 적용하지 않는다. 1~9장은 그대로 둔다(다른 문서가 줄 번호로 인용한다). 번호는 8·9장 열린 결정(D1~D32)에 이어 붙였다. 07장 3절의 폐기 ID(D-01~D-43, 하이픈 있음)와는 다른 번호 체계다.

| # | 항목 | 선택지 | 기본값(제안) | 닫는 시점 | 근거 |
|---|---|---|---|---|---|
| D33 | 책 화면(위저드·원고 편집기·설정집·완성)에서 GNB 표시 | (a) GNB를 숨기고 책 머리줄("← 내 책", 책 제목, 책 탭 4개) (b) 접힌 GNB 레일(64px) 유지 (c) 펼친 GNB 유지 | (a)(제안). 에디터 3단(목차 260px + AI 패널 400px)에 레일 64px를 더하면 1280px에서 원고 폭이 556px로 최소 560px보다 좁아진다. (b)는 1440px 이상에서만 가능해 폭별 분기가 생긴다 | PB-06-022 착수 전 | 03장 1절 :26 "전체 화면", 8.4절 :583-585 |
| D34 | "새 책 만들기"를 GNB 메뉴로 둘지 | (a) GNB "책" 묶음에 메뉴로 두고 헤더 "+ 새 책"도 유지 (b) 헤더 버튼과 홈 칸만(1절 사이드바 6개 그대로) | (a)(제안). 경로(`/dashboard/books/new`)는 1절에 이미 있고, 원본 v2 전자책 10단계·업로드 경로와 SellingDocs AI 책 기획 빌더가 모두 이 화면으로 모인다(03장 10.7절). 메뉴가 늘어나는 비용은 1개 | PB-06-023 착수 전 | 03장 1절 :23, :47 |
| D35 | 셸 검색 단축키 | (a) ⌘K/Ctrl+K는 대시보드 셸에서만 등록하고 책 화면에서는 에디터 툴바가 쓴다 (b) 셸 검색을 다른 키(`/`)로 (c) 셸 검색 단축키 없음 | (a)(제안). 03장 6절이 에디터 플로팅 툴바를 `Ctrl+K`로도 연다고 정했다(제안). D33 (a)면 책 화면에 셸 검색 버튼이 없어 충돌이 생기지 않는다. D33을 (b)·(c)로 정하면 (b)로 바꾼다 | PB-06-022 착수 전 | 03장 6절 :435 |
| D36 | 작가 GNB의 운영 콘솔 링크 | (a) `platform_admin`에게만 아래 고정 링크 "운영 콘솔 ↗" 1개 (b) 링크 없음(주소 직접 입력) | (a)(제안). 링크는 구조 공유가 아니고(03장 8.1절 :505 "작가 메뉴와 구조를 공유하지 않는다"), 일반 사용자에게는 렌더하지 않는다. `/admin/*`의 일반 사용자 404는 그대로(CLAUDE.md "에이전트 실행 계층 규칙" 운영 콘솔 행) | PB-06-027 착수 전 | 03장 1절 :35, 8.1절 :505 |

| 결정 | 기본값과 다르게 정하면 고칠 곳(영향) |
|---|---|
| D33 (b)·(c) | 03장 10.4절 전체, 10.6절 책 화면 행, 10.8절 원고 편집기 행, 8.4절 에디터 폭 표(레일 포함 폭 다시 계산), D35 기본값 |
| D34 (b) | 03장 10.3절 "새 책 만들기" 행 삭제, 10.8절 사이드바 행, 디자인 config의 `books-new` 메뉴(헤더 "+ 새 책"만 남김) |
| D35 (b)·(c) | 03장 10.2절 검색 행, 10.8절 키보드 행 |
| D36 (b) | 03장 10.3절 운영 콘솔 행, 10.7절 v2 관리자 페이지 행 |
