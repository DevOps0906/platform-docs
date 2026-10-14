# 01 PRD: 로컬뉴스 클라우드(가칭)

작성일 2026-10-15. 신규 기획(원본 프로젝트·리뷰 없음). 장 구조는 `docs/products/_platform-core/DOC_TEMPLATE.md` 2.2절을 따른다. 기능 ID `NW-F-###`와 열린 결정 D-1~D-12의 번호는 이 문서가 정본이다. 근거 표기: 저장소 문서는 `경로:줄`, 외부 사실은 URL(조사일 2026-10-15). 근거가 없는 수치·정책은 "제안"으로, 확인하지 못한 외부 사실은 "미확인"으로 적었다. 확정 결정 번호는 `docs/products/00_MERGE_ANALYSIS.md` 상단 표(4 Toss `:12`, 5 테넌시 `:13`, 8 플랜 정본 `:16`, 13~17 AI·음성 `:21-25`, 15 3D 히어로 `:23`, 22 인증 단계 `:30`)를 가리킨다.

## 1. 페르소나와 핵심 과제

| 이름 | 상황 | 목표 | 좌절 | 근거 |
|---|---|---|---|---|
| 최정민(46, 인터넷 지역신문 대표 겸 기자) | 시 단위 인터넷신문 등록 6년차. 기자 2명과 셋이 하루 4~6건을 올린다. 연 매출 1억 원 미만이고 수입 대부분이 지자체·업소 광고다 | 기사 쓰기부터 게시·광고 교체·법정 표기까지 혼자서 하루 1시간 안에 끝내고, 네이버 뉴스 검색제휴 심사 전에 자체기사 비율을 관리한다 | 임대형 CMS는 요금이 비공개이고 벤더 로고가 푸터에 박힌다. 보도자료 받아쓰기 비중이 높아 포털 심사에서 감점될까 걱정이지만 주간 비율을 셀 도구가 없다. 필요적 게재사항 누락 과태료를 어디서 확인하는지 모른다 | 인터넷신문 66.9%가 연 매출 1억 원 미만, 평균 기자 4명: https://www.journalist.or.kr/news/article.html?no=57578 . 자체기사 비율·보도자료 감점: https://journalist.or.kr/news/article.html?no=60389 |
| 한경숙(52, 지역 주간지 편집국장) | 군 단위 주간지, 기자 8명. 매주 수요일 지면을 내고 웹에도 같은 기사를 올린다. 지역신문발전기금 우선지원 대상 신청을 준비한다 | 기자 초안 → 데스크 승인 → 예약 게시 흐름을 웹에서 운영하고, 지면 PDF와 지원사업 서류(발행 실적, 광고 비중, 자체기사 비율)를 한 번에 뽑는다 | 웹과 지면을 이중으로 작업한다. 정정보도 청구가 들어오면 3일 통지 기한을 달력에 손으로 적는다. 공공 통합CMS는 도입사 불만 보도를 봐서 망설인다 | 주간지 평균 기자 4명(같은 출처), 우선지원 74개사 중 주간 45: https://journalist.or.kr/m/m_article.html?no=60304 . 선정 요건(광고 비중 50% 이하 등): https://kbmaeil.com/article/202502030907920 . 통합CMS 불만: https://www.journalist.or.kr/m/m_article.html?no=46189 |
| 박영수(57, 읍 주민, 지역 독자) | 휴대폰으로 우리 동네 소식과 부고·인사를 본다. 카카오톡 링크로 기사에 들어오는 일이 많다 | 큰 글씨로 우리 읍 소식, 부고, 행사, 날씨를 한 화면에서 보고, 쉬운 로그인으로 댓글·제보·뉴스레터를 쓴다 | 팝업과 전면광고가 기사를 가리고, 화면이 밀려 엉뚱한 광고를 누른다. 비밀번호를 또 만들어야 하는 가입은 포기한다 | 한국 유료 뉴스 이용 19%: https://reutersinstitute.politics.ox.ac.uk/digital-news-report/2026/south-korea . 팝업·CLS 안티패턴: https://web.dev/articles/optimize-cls , https://www.betterads.org/standards/ |
| 오세진(39, 읍내 카페 사장) / 군청 홍보팀 주무관 | 사장은 개업·행사 홍보를 지역신문에 싸게 내고 싶다. 주무관은 군 공고를 지역신문에 싣고 게재 증빙을 결재 서류에 붙인다 | 사장: 신청서 하나로 업소 광고를 직접 올리고 카드로 결제한다. 주무관: 게재 기간·URL·노출 수가 담긴 증빙을 내려받는다 | 사장: 전화·계좌이체·원고 메일을 몇 번씩 오간다. 주무관: 정부광고는 언론진흥재단 대행이라 신문사와 직접 계약할 수 없는데 증빙은 신문사에 따로 요청해야 한다 | 정부광고 재단 대행·수수료 10%: https://journalist.or.kr/news/article.html?no=59081 . 지역 업소 광고 카드형 모듈: http://www.okinews.com/ (업소·공지 모듈 사례) |

| # | 핵심 과제 | 이 제품이 해결하는 방식 |
|---|---|---|
| J1 | 1~10명 편집국이 법정 요건을 지키며 기사를 생산·게시한다 | 데스크 워크플로(1인 신문사 자가 승인 모드 포함), 필요적 게재사항 미완성 시 공개 차단, 기사 유형 태그와 주간 자체기사 비율 대시보드, 정정·반론 청구 SLA 타이머, 보도자료 → 초안 AI(사람 승인 필수) |
| J2 | 신문사 제호·도메인으로 빠르고 읽기 쉬운 독자 사이트를 운영한다 | 템플릿 3종(A 전통 신문형, B 모던 매거진형, C 모바일 피드형) + 블록 레지스트리, Theming L1·L2, CWV p75 목표(LCP 2.5초, INP 200ms, CLS 0.1), 광고 슬롯 공간 예약, 시군·읍면 칩, 부고·인사 모듈 |
| J3 | 지역 수익원을 한 곳에서 운영하고 지원사업 증빙을 만든다 | 광고 직판(IAB 고정 슬롯·하우스 광고), 업소 셀프 광고, 지자체 공고 증빙, 뉴스레터(이중 동의·2년 재확인), 후원·멤버십(신문사 자기 Toss 가맹), 지원사업 리포트 |

## 2. 범위: MVP와 Phase

우선순위 매핑: P0 = MVP, P1 = Phase 2(공개 베타 후 3개월 안, 제안), P2 = Phase 3. 기능별 우선순위는 3장 표가 정본이다.

| 기능 | 범위 | 근거 |
|---|---|---|
| 편집국 인증·조직·세션. 단계: Stage A(MVP 개발, 시드 페르소나 Mock), Stage B(공개 베타 전, P0: Google + 이메일·초대 메일), C1 카카오·C2 네이버는 P2 선택(편집국은 초대제 업무 도구라 Google·이메일로 충분) | MVP(A·B), Phase 3(C 선택) | 확정 결정 22, `docs/products/_platform-core/AUTH_ROADMAP.md:7-14`, `:330`(초대제 제품 microweb과 같은 P2 선택) |
| 독자 로그인. 단계: Stage A(시드 독자 페르소나), Stage B(공개 베타 전, P0: 이메일 매직 링크 + Google, D-15), C1 카카오 P1(지역 독자 핵심), C2 네이버 P1. 방문자(비로그인)는 단계와 무관하게 공개 기사를 읽는다 | MVP(A·B), Phase 2(C1·C2) | 확정 결정 22, `docs/products/_platform-core/AUTH_ROADMAP.md:321-340`. 이 제품 행은 AUTH_ROADMAP 8장 매트릭스에 아직 없다(코어 문서 갱신 요청, 06장 6절) |
| 신문사 개설 신청 → 운영자 승인(정기간행물 등록증 확인) → 체험 30일 | MVP | `signup_policy='invite'`: `docs/products/_platform-core/MONOLITH_CORE_LITE.sql:260-266` |
| 매체정보·법정 푸터·정책 페이지, 정정·반론 청구 SLA, 자체기사 비율 대시보드, 광고 라벨 강제 | MVP | 6.1절 법령 표 |
| 기사 에디터·메타·데스크 워크플로·홈 편집·미디어 라이브러리·수정 표시 | MVP | J1 |
| 독자 사이트 템플릿 3종, 섹션·지역·기자 페이지, 많이 본 뉴스, 검색, 제보 | MVP | https://www.kgnews.co.kr/mobile/article.html?no=842335 (한국 사이트 '많이 본 뉴스' 사례: https://www.khan.co.kr , https://www.yongin21.co.kr) |
| 광고 직판(IAB 슬롯), 뉴스레터, RSS·뉴스 사이트맵·구조화 데이터 | MVP | https://developers.google.com/search/docs/crawling-indexing/sitemaps/news-sitemap , INN 지역 매체 뉴스레터 구독자 중간값 6,000명: https://inn.org/research/inn-index/2026-index/revenue-expenses/ |
| Theming L1(로고·색·서체 프리셋)과 서브도메인 | MVP | `Multi-tenant_Theming/README.md:25-32` |
| 커스텀 도메인(Theming L2) | Phase 2 | 같음, `Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md:55` |
| AI·음성: 보도자료 → 초안 그래프, 제목·요약·교정, 편집국 AI 어시스턴트(RAG, 음성 대화 포함), 인터뷰 받아쓰기 | MVP | 확정 결정 13~17 |
| 오디오 기사(TTS), 사진 alt 초안 | Phase 2 | 같음. 게시 품질에 영향이 적어 MVP 직후 |
| 독자 기사 Q&A 챗봇(방문자 모드) | Phase 3 | 비로그인 AI 비용은 신문사 예산이 되므로 원가 실측 뒤(`docs/products/_platform-core/AI_ARCHITECTURE.md:130`) |
| 댓글·신고·임시조치, 경조사 신청, 지역 생활 블록, 지면 PDF, 속보 바·라이브 기사 | Phase 2 | 지역 필수 모듈이지만 MVP 핵심 흐름(J1) 뒤. 부고·인사 모듈 사례: https://www.ihalla.com , https://www.kwnews.co.kr |
| 후원·멤버십·페이월, 업소 셀프 광고, 지자체 공고 증빙, 외부 광고망 태그, 웹 푸시 | Phase 2 | 결제는 신문사별 Toss 가맹 연동이 필요(D-4) |
| 선거 모드, 통신사 전재 계약, AI 크롤러 정책, 지원사업 리포트, CMS 이관, 해지·내보내기 | Phase 2 | 다음 전국선거 2028 총선(공직선거법 108조). 이관은 첫 고객 전환 때 필요 |
| SNS 자동 공유, 카카오 알림톡, 외부 검색 엔진(Meilisearch/Typesense) | Phase 3 | 외부 계정 연동 약관·비용 미확인 |
| 3D 히어로 | 독자 사이트 제외, 플랫폼 마케팅 랜딩만 선택(D-11) | 확정 결정 15의 예외 요청. 뉴스 사이트는 LCP가 우선(https://web.dev/articles/vitals) |
| 정부광고 직접 계약·결제 | 범위 밖(게재 증빙만) | 정부광고는 언론진흥재단만 대행: https://journalist.or.kr/news/article.html?no=59081 |
| 행사 티켓 판매, 네이티브 앱, 팝업·전면광고 | 범위 밖 | 팝업은 Better Ads 기준 미달·Google 인터스티셜 불이익(https://developers.google.com/search/docs/appearance/avoid-intrusive-interstitials) |

## 3. 기능 요구사항과 수용 기준

ID 접두사 `NW`(SQLSTATE 접두사와 같다, `docs/products/_platform-core/DB_CONVENTIONS.md` 1장). 처리 분류는 전부 "신규"다. 오류 코드 번호는 04장 7절이 정한다. 크레딧은 4.3절, 플랜 키는 4.2절을 따른다. "편집국"은 `news.staff` 역할(publisher, editor, desk, reporter, contributor, ad_manager)을 가진 조직 멤버다.

### 3.1 개설·매체정보·브랜딩·인증

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| NW-F-001 | 신문사 개설 신청과 승인(P0) | 신규 | 로그인한 사용자가 `/apply`에서 제호, 정기간행물 등록번호, 등록연월일, 발행인 성명, 연락처, 희망 slug(3~30자 영문 소문자·숫자·하이픈, 예약어 `www`·`newsroom`·`login`·`api`·`admin`·`ops` 거부), 등록증 파일(PDF·JPG·PNG, 10MB 이하)을 내면 `news.request_newspaper`가 신청 행(`pending`)을 만든다. 운영자가 `news.approve_newspaper`(service)로 승인하거나 사유를 적어 반려한다. 승인은 한 트랜잭션으로 `core.organizations`(`is_personal=false`), 신청자 owner, `news` 엔타이틀먼트(`news_trial`, 30일), `news.newspapers`, `news.staff`(publisher), 감사 `news.newspaper.approve`를 만든다 | 신청 직후 운영 콘솔 대기 목록에 1건, 신청자 화면에 "심사 중". 승인 1회 뒤 org 1·owner 1·엔타이틀먼트 1(만료 = 승인 시각 + 30일)·staff 1. 같은 신청을 다시 승인해도 행 수가 같다(멱등). 활성 신문사가 쓰는 등록번호·slug로 신청하면 거부. 반려 시 사유 메일 1통, 조직 0. 등록증은 신청자와 운영자만 읽는다. 체험 종료 7일·1일 전 알림 메일, 종료 후 14일 유예 동안 편집국 읽기 전용·독자 사이트 유지, 유예 후 독자 사이트 "발행 일시 중단" 화면(유예 14일은 제안) | README 1장, `docs/products/_platform-core/MONOLITH_CORE_LITE.sql:260-266`, https://www.kgnews.co.kr/mobile/article.html?no=842335 |
| NW-F-002 | 매체정보(필요적 게재사항)(P0) | 신규 | publisher·editor가 `news.set_newspaper_profile`로 제호, 등록번호, 등록연월일, 발행인, 편집인, 청소년보호책임자 성명·연락처, 발행소 주소·전화, 최초발행일(발행연월일), 매체 종류(인터넷신문·주간·일간)를 입력한다. `news.is_profile_complete`가 거짓이면 독자 사이트·RSS·사이트맵을 내지 않는다. 등록번호·제호 변경은 운영자 재확인 대기(제안) | 필수 항목 중 하나라도 비면 `is_profile_complete=false`이고 독자 도메인 모든 경로가 "발행 준비 중"(HTTP 503, `X-Robots-Tag: noindex`)을 돌려준다. 모두 채우면 60초 안에 공개. 공개 중에 필수 항목을 비우는 저장은 거부. 홈·기사·섹션·404 페이지 모두의 푸터에 필수 항목이 보인다(E2E HTML 검사). 변경마다 감사 `news.profile.update` | 신문법 제21조·시행령 제7조의2: https://www.wipo.int/wipolex/en/text/438729 , https://www.nepla.ai/law/신문-등의-진흥에-관한-법률-시행령 (현행 조문 번호·과태료 미확인) |
| NW-F-003 | 브랜딩·도메인(P0 L1·서브도메인 / P1 커스텀 도메인) | 신규 | Theming L1: 로고(SVG·PNG 1MB 이하, 가로형·정사각), 파비콘, 브랜드 색 primary·accent, 서체 프리셋 4종(A Noto Serif KR + Pretendard, B 본명조 + Pretendard, B' 나눔명조, C Pretendard Variable). KoPub World는 프리셋에 넣지 않는다. 그리드 비율·광고 슬롯 크기는 테넌트가 바꿀 수 없다. L2: `slug` 서브도메인은 승인 즉시, 커스텀 도메인은 `tenant_domains` DNS 검증 후 TLS 발급(`news.domain` 잡 = Theming 워커) | 색 저장 시 본문 대비 4.5:1 미만이면 거부. 저장 후 60초 안에 독자 사이트 반영. 커스텀 도메인 검증 성공 시 서브도메인 요청은 커스텀 도메인으로 301, canonical은 커스텀 도메인. `news_custom_domains` 한도 초과 등록 거부. 검증 실패 72시간이면 `failed` 표시와 DNS 안내 | `Multi-tenant_Theming/README.md:25-32`, `Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md:5-15`, 서체 라이선스: https://github.com/orioncactus/pretendard , https://www.sandollcloud.com/free-font/15810/KoPubWorldDotum |
| NW-F-004 | 편집국 구성원 초대·역할(P0) | 신규 | publisher·editor가 `news.invite_staff(email, role)`로 초대(7일 만료, 제안), 수락은 `news.accept_staff_invite`, 변경은 `news.set_staff_role`. 코어 매핑 owner→publisher, admin→editor, member→desk·reporter·contributor·ad_manager. 권한: contributor는 자기 초안만, reporter는 자기 기사 작성·제출, desk는 승인·반려, editor는 게시·홈 편집·정정, publisher는 매체정보·결제·도메인·구성원, ad_manager는 광고·업소·공고만 | 활성+초대 중 인원이 `news_staff_max`에 이르면 초대 거부. reporter가 남의 초안 UPDATE → 거부. contributor가 남의 기사 SELECT → 0행. ad_manager가 기사 UPDATE → 거부. 마지막 publisher의 강등·탈퇴 거부. 역할 변경마다 감사 | `docs/products/_platform-core/MONOLITH_CORE_LITE.sql:486-517`(코어 초대 RPC), README 1장 |
| NW-F-005 | 편집국 로그인(인증 단계 A → B, C 선택)(P0) | 신규 | Stage A(MVP 개발): 쿠키 역할 Mock 금지. 개발용 로그인은 AUTH_ROADMAP 2장의 로컬 시드 계정만(배포 환경 `/api/dev/login` 404). 공통 페르소나 + 제품 페르소나 `desk`, `contributor`, `ad_manager`(05장 10절). Stage B(공개 베타 전, P0): `newsroom.<플랫폼>`에서 Google + 이메일(초대 메일 수락 시 비밀번호 설정). 콜백 `finishLogin('news')`, invite 앱이므로 엔타이틀먼트 없는 사용자는 `/no-access`("개설 신청" 또는 "초대받은 이메일로 로그인" 안내). Stage C: 카카오·네이버는 P2 선택(D-17) | Stage A: `owner` 페르소나 로그인 → `session_context('news')`가 `entitled=true`, `plan_code='news_trial'`, `news.staff.role='publisher'`, `/newsroom` 대시보드가 열리고 새로고침해도 유지. Stage B: 3.8절 편집국 열(B-1~B-6). Stage C: 채택 시 3.8절 C1·C2 행 | 확정 결정 22, `docs/products/_platform-core/AUTH_ROADMAP.md:35-104`, `:210-219` |
| NW-F-006 | 독자 로그인과 독자 가입(인증 단계 A → B → C1·C2)(P0) | 신규 | 독자 로그인은 신문사 도메인(서브도메인·커스텀 도메인)에서 일어난다(D-3). Stage A: 시드 독자 페르소나 `reader`, `reader_member`, `reader_other`와 `anon` 시나리오. Stage B(P0): 이메일 매직 링크 + Google(D-15). Stage C1 카카오(P1, D-13), C2 네이버(P1, D-14). 계정은 플랫폼 공통이고(같은 사람이 여러 신문의 독자) 첫 로그인 직후 동의 화면(이용약관, 개인정보 수집·이용, 만 14세 이상 확인, 뉴스레터 선택)을 거쳐 `news.ensure_reader(org)`가 그 신문사 `readers` 행을 만든다. 독자 콜백은 엔타이틀먼트를 판정하지 않는다(편집국 호스트만 `/no-access` 분기). 동의 화면 브랜드는 플랫폼 브랜드(D-16) | Stage A: `reader` 로그인 → 로그인 전 보던 기사로 돌아오고 그 신문사 `readers` 1행. `reader_other`(B 신문 독자)가 A 신문 편집국 화면 접근 → `/no-access`. A 신문 편집국이 B 신문 독자 행 조회 → 0행. Stage B·C: 3.8절 독자 열. 만 14세 미만 체크 시 가입 중단 | 확정 결정 22, `develop/_shared/auth/README.md:18`(AUTH-D1), `docs/products/_platform-core/AUTH_ROADMAP.md:340` |

### 3.2 뉴스룸(M1 newsroom-cms)

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| NW-F-010 | 기사 에디터(P0) | 신규 | 블록: 문단, 소제목, 사진(캡션·출처 필수), 인용, 표, 임베드(YouTube, 지도. 지도 서비스 임베드 조건 미확인). 붙여넣기는 서버 sanitize. 자동 저장 2초 debounce, `article_revisions`는 상태 전이·수동 저장·10분 간격 스냅샷(제안). 본문 200KB 상한(제안) | 입력 후 2초 안에 "저장됨". 네트워크 끊김 시 로컬 임시본 보관 후 재접속 시 복구 배너. `<script>`·`on*` 속성이 든 붙여넣기 → 저장본에 없음. 허용 목록 밖 iframe 거부. 두 버전 비교·복원이 되고 복원도 새 버전으로 남는다 | `docs/products/_platform-core/SECURITY_BASELINE.md` 10장, flora 자동 저장 규칙(`docs/products/flora-publishing/01_PRD.md:271`) |
| NW-F-011 | 기사 메타(P0) | 신규 | 유형(`original` 자체, `wire` 전재, `press_release` 보도자료, `contribution` 기고, `sponsored` 기사형 광고) 필수, 섹션 1개 필수, 지역(시·군·읍면) 0~N, 태그 10개 이하, 바이라인 1~5명(구성원 또는 외부 기고자 이름). `wire`는 전재 계약(NW-F-043) 연결, `press_release`는 출처 기관명, `sponsored`는 광고주 필수 | 유형 없이 제출 거부. 계약 없는 `wire` 저장 거부. 출처 없는 `press_release` 제출 거부. `sponsored` 기사는 목록·상세·RSS·뉴스레터 모두에 "기사형 광고"와 광고주명이 보인다 | 신문법 제6조 3항·자체기사 30%: https://www.wipo.int/wipolex/en/text/438729 |
| NW-F-012 | 데스크 워크플로(P0) | 신규 | 상태: `draft` → `submitted` → `approved` → `scheduled`/`published` → (`updated`) → `unpublished`/`archived`, 반려(`submitted` → `draft`, 사유 필수), 엠바고(예약 시각 전 비공개). 전이는 `news.submit_article`, `news.review_article`, `news.publish_article`, `news.schedule_article`, `news.unpublish_article`만. 1인 신문사 모드(신문사 설정): publisher·editor가 자기 기사를 자가 승인할 수 있고 감사에 `self_approved` 표시 | 표 밖 전이(예: reporter가 `draft` → `published`) 거부. 예약 기사는 예정 시각 + 60초 안에 공개. 엠바고·미게시 기사는 anon SELECT·RSS·사이트맵·검색·API 어디에도 0건. 비게시(`unpublished`)는 사유 필수, 기사 URL은 410(제안). 1인 모드가 꺼진 신문사에서 자가 승인 거부 | J1, 평균 기자 4명(https://www.journalist.or.kr/news/article.html?no=57578) |
| NW-F-013 | 홈 편집(P0) | 신규 | 템플릿 A·B·C 선택, 블록 순서·ON/OFF, 톱·서브 기사 지정, 홈 레이아웃 예약 게시, 미리보기, 이전 버전 되돌리기. `news.publish_home_layout`. 법정 푸터·광고 라벨은 끌 수 없다 | 게시 후 p95 60초 안에 홈 반영(캐시 태그 `news:<org>:home` 무효화). 미리보기 URL은 편집국 로그인 필요 + noindex. 되돌리기 1회 클릭으로 직전 레이아웃 복원. 데이터 없는 블록은 숨김(빈 상자 없음) | https://www.texastribune.org , https://www.kyeongin.com (블록 순서 사례) |
| NW-F-014 | 미디어 라이브러리(P0) | 신규 | 사진 업로드(JPG·PNG·WebP·GIF, 20MB 이하), alt 필수(장식 이미지 표시 선택 가능), 저작권자·출처 필수, 파생 크기 자동 생성, EXIF 위치 정보 제거, 같은 파일 해시 중복 경고 | alt·출처가 없는 사진은 기사에 삽입 불가. 업로드 후 30초 안에 파생 4종(320·640·1024·1600px, WebP). 파생본·원본에서 GPS 메타가 제거됨. 중복 업로드 시 기존 자산 제시 | WCAG 대체 텍스트, `docs/products/_platform-core/SECURITY_BASELINE.md` 12장 |
| NW-F-015 | 지면 PDF·지면보기(P1) | 신규 | 호별 PDF(100MB 이하), 발행일·호수, 페이지 이미지 생성, 멤버 전용 설정 가능. `news_print_pdf` 플랜만 | 플랜 밖 업로드 거부. 업로드 후 10분 안에 지면보기 열람. 멤버 전용 호는 비회원 접근 시 가입 안내 | 지면보기 메뉴 사례: https://www.imaeil.com , https://www.kyeongin.com |
| NW-F-016 | 속보 바·라이브 기사(P1) | 신규 | 속보 바는 editor 이상, 만료 시각 기본 3시간(제안). 라이브 기사는 시각이 붙은 업데이트 타임라인 | 속보 등록 후 60초 안에 모든 페이지 상단 표시, 만료 시 자동 제거. 라이브 업데이트는 열린 독자 화면에 30초 안 반영 | Baltimore Banner LIVE 사례: https://www.thebanner.com/ |
| NW-F-017 | 기사 수정 표시·정정 이력(P0) | 신규 | 게시 후 수정은 유형 선택: 단순 수정(오탈자), 내용 수정, 정정. `news.record_article_correction`. 내용 수정·정정은 사유 필수이고 기사에 수정 시각·사유가 공개된다. 정정은 기사 하단 정정문 + 신문사 정정 이력 페이지 | 게시 기사 저장 시 "수정 2026-10-15 14:03" 표시. 정정·내용 수정은 사유 없이 저장 거부. 정정 이력 페이지에 기사 링크·정정 내용·시각. 단순 수정은 내부 이력만 | 정정 정책 공개 사례: https://www.texastribune.org |

### 3.3 독자 사이트(제품, M5, M7, M8)

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| NW-F-020 | 메인 템플릿 3종 + 블록 레지스트리(P0) | 신규 | A 전통 신문형, B 모던 매거진형, C 모바일 피드형. 브레이크포인트 xs 0~599(4열), sm 600~1023(8열), md 1024~1279(12열), lg 1280 이상(12열, 최대 1200px), xl 1440 이상(날개 광고 선택). 블록: 유틸 바, 마스트헤드, GNB+시군 탭, 속보 티커, 리드, 많이 본 뉴스, 섹션 블록, 오피니언, 경조사 탭, 행사·날씨, 공고, 업소 광고, 뉴스레터·후원 CTA, 정정·반론, 푸터. 팝업·전면광고 블록은 없다 | 세 템플릿이 360px·1280px에서 가로 스크롤 없이 렌더. 시드 기사 50건 기준 Lighthouse 모바일 실험실 측정 LCP 2.5초 이하, CLS 0.1 이하. 뉴스레터·후원 CTA는 홈에 최대 2회 | https://raw.githubusercontent.com/guardian/csnx/main/libs/%40guardian/source/src/foundations/__generated__/breakpoints.ts , https://build.washingtonpost.com/foundations/breakpoints , https://web.dev/articles/vitals |
| NW-F-021 | 섹션·지역·태그·기자 페이지, 기사 상세(P0) | 신규 | 목록 페이지당 20건 페이지네이션(SEO). 기사 상세: 바이라인, 게시·수정 시각, 관련 기사 4~6건, 공유(링크 복사, 카카오톡 공유는 SDK 조건 미확인), 글자 크기 3단계, 시군·읍면 칩(쿠키 저장, '우리 동네' 필터) | 게시 기사가 아닌 URL은 404(비게시는 410). 글자 크기·지역 칩은 재방문 시 유지. 기자 페이지는 공개 프로필만(이메일 공개는 기자 선택) | https://www.kwnews.co.kr (18개 시군 메뉴) |
| NW-F-022 | 많이 본 뉴스·검색(P0) | 신규 | `news.most_read`(공개): 1시간·24시간 버킷 합산, 5분 갱신. 조회는 `/api/r/view` → `news.increment_article_views`(service), 봇 제외, 같은 IP 해시·기사 30분 1회(제안). 검색: 제목·본문·태그, 최신순·관련도순, 기간 필터(D-7) | 봇 UA 조회는 집계 0. 같은 브라우저 30분 내 반복 조회 1회. 기사 10만 건에서 검색 p95 800ms 이하. 비공개 기사 검색 결과 0 | https://www.khan.co.kr , https://www.ihalla.com (많이 본 뉴스 5~10) |
| NW-F-023 | 지역 생활 블록(P1) | 신규 | 날씨·미세먼지(기상청·에어코리아 API, 이용 조건 미확인, D-8), 서버 캐시 30분(제안), 출처 표기. 행사 캘린더(`events`, 편집국 등록). 공고 리스트(NW-F-034) | 외부 API 실패 시 마지막 값을 3시간까지 보이고 이후 블록 숨김(오류 문구 없음). "자료: 기상청" 출처 표시. 지난 행사는 자동으로 목록에서 내림 | 조사한 한국 사이트(https://www.khan.co.kr , https://www.kyeongin.com , https://www.ihalla.com)에 날씨 블록 없음 = 차별화 |
| NW-F-024 | 경조사 신청·게재(P1) | 신규 | 독자 신청 폼(부고·인사·동정·화촉), 신청자 연락처, 당사자·유족 동의 확인 체크, 편집국 검토 후 게재. 유료 게재 옵션(신문사 가격, 신문사 가맹 결제) | 검토 전 비공개. 게재 후 60초 안에 홈 경조사 탭 반영. 부고는 30일 뒤 홈 탭에서 내리고 목록에는 남김(제안). 신청자 삭제 요청은 3영업일 안 처리(제안) | https://www.ihalla.com (궨당소식), http://www.okinews.com/ |
| NW-F-025 | 독자 제보·투고(P0) | 신규 | 폼: 제목, 내용 10,000자 이하, 첨부 5개(각 20MB 이하, 이미지·PDF·영상·문서), 연락처(투고 필수, 제보 선택·익명 허용), 수집 동의. 서버 Route Handler → `news.submit_tip`(service). 편집국 제보함(새로움·검토 중·취재 중·종결) | 동의 없이 제출 거부. 실행 파일 MIME 거부. 제출 즉시 접수 번호 표시(연락처가 있으면 메일). 제보함은 desk 이상과 배정 기자만 열람. 제보 원문은 상용 AI로 보내지 않는다. 종결 1년 뒤 파기(제안) | https://www.ihalla.com (독자마당 제보·투고) |
| NW-F-026 | 댓글·신고·임시조치(P1) | 신규 | 기본 끔(D-6), 신문사·기사별 켬. 로그인 독자만 작성. 금칙어 목록, AI 모더레이션 보조(`news.moderation`, 오픈소스 강제)는 보류 큐로만 보내고 삭제는 사람이 한다. 권리침해 신고 → 임시조치(정보통신망법 44조의2, 기간 30일 이내는 원문 미확인) | 비로그인 작성 401. 금칙어 포함 댓글은 보류. 신고 3건이면 자동 보류(제안). 임시조치 시 작성자 통지와 처리 기록. 댓글을 끈 기사는 기존 댓글 숨김. 실명 확인을 요구하지 않는다 | 정보통신망법 44조의2, 게시판 본인확인제 2012 위헌(조문 원문 미확인) |
| NW-F-027 | 정정·반론·추후보도 청구 SLA(P0) | 신규 | 공개 폼(청구 유형, 대상 기사, 청구인 이름·연락처, 청구 내용, 안 날·보도일) → `news.submit_correction_request`(service). `news.respond_correction_request`로 수용·거부(사유)·게재. 타이머: 접수 후 3일 안 수용 여부 통지, 수용 시 7일 안 게재. 청구 기간(안 날 3개월·보도 후 6개월) 경과 청구는 경고만(거부하지 않음) | 접수 즉시 청구인에게 접수 번호 메일. 통지 기한 24시간 전·기한 시각에 publisher·editor 알림. 수용 후 게재 시 원기사 하단에 "이 기사에 대한 정정보도" 링크가 60초 안 표시. 기한 넘긴 건은 대시보드에 빨간 표시. 처리 이력 3년 보존(제안) | 언론중재법 14·15조(3일·7일은 일반 법리로 정리된 값, 원문 미확인) |
| NW-F-028 | 법정 푸터·정책 페이지(P0) | 신규 | 푸터에 NW-F-002 항목 자동 렌더. 정책 페이지: 청소년보호정책, 개인정보처리방침(신문사 = 처리자, 플랫폼 = 수탁자 표기 템플릿), 윤리강령(템플릿 제공, 신문사 수정), 기사배열 방침(선택), AI 이용 원칙(제안) | 청소년보호정책·개인정보처리방침이 비어 있으면 `is_profile_complete=false`. 윤리강령 미작성은 대시보드 경고만. 푸터에 플랫폼 로고를 강제로 넣지 않는다(전 플랜, 제안: 벤더 로고 강제는 경쟁 CMS의 불만 요인) | 윤리강령 보유 인터넷신문 47.9%(https://www.journalist.or.kr/news/article.html?no=57578), https://www.kyeongin.com 푸터 사례 |

### 3.4 광고·수익(M2, M3, M4)

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| NW-F-030 | 광고 관리(P0) | 신규 | IAB 고정 슬롯(970x250, 728x90, 300x250, 300x600, 160x600, 320x100, 320x50), 광고주·캠페인(기간, 슬롯, 우선순위, 노출 목표)·소재·링크, 하우스 광고 대체, 노출·클릭 일 집계(`news.record_ad_stats`, service), 슬롯 공간 예약(min-height·aspect-ratio) | 크기가 다른 소재 업로드 거부. 초기 로드 무게 MREC 150KB·Billboard 250KB 초과 거부. 캠페인 없으면 하우스 광고, 그것도 없으면 빈 예약 공간 유지(레이아웃 이동 0). 모바일 광고 밀도 30% 초과 레이아웃 저장 거부. 일별 노출·클릭 CSV 내보내기 | https://www.iab.com/wp-content/uploads/2019/04/IABNewAdPortfolio_LW_FixedSizeSpec.pdf , https://web.dev/articles/optimize-cls , https://www.betterads.org/standards/ |
| NW-F-031 | 외부 광고망 태그(P1) | 신규 | Google Ad Manager·AdSense 슬롯 매핑. 스크립트 출처는 허용 목록(CSP), 신문사 임의 스크립트 금지 | 허용 목록 밖 스크립트 저장 거부. 외부 광고 무응답 3초면 하우스 광고(제안) | https://support.google.com/adsense/answer/6002621 |
| NW-F-032 | 광고·기사형 광고·후원 라벨 강제(P0) | 신규 | 모든 광고 슬롯 "광고", `sponsored` 기사 "기사형 광고 · 광고주명", 후원 콘텐츠 "후원: 기관명". 라벨을 끄는 설정을 만들지 않는다 | 광고 슬롯·`sponsored` 기사·뉴스레터 광고 블록에서 라벨 누락 0(E2E). `sponsored`는 자체기사 비율 분자·분모에서 모두 제외 | 신문법 제6조 3항: https://www.wipo.int/wipolex/en/text/438729 |
| NW-F-033 | 업소 셀프 광고·디렉토리(P1) | 신규 | 업주 신청(상호, 업종, 사업자등록번호 형식 검사, 소재, 기간) → 결제(신문사 가맹) → 편집국 검수 → 게재. 업종 차단 목록(성인·사행성·대부, 제안). `news_self_ads` 플랜만 | 결제 완료와 검수 승인이 둘 다 있어야 노출. 반려 시 결제 자동 취소. 기간 종료 시 자동 내림. 디렉토리 업종·지역 필터 | http://www.okinews.com/ (옥천장터·상가탐방), https://inn.org/research/inn-index/2026-index/revenue-expenses/ |
| NW-F-034 | 지자체 공고·게재 증빙(P1) | 신규 | 공고 리스트(기관, 제목, 게재 기간, 원문 링크·PDF). 광고주 유형 `government`는 직판 결제·계약을 만들 수 없다. 게재 증빙 리포트(게재 URL, 기간, 일별 노출 수, 게재 화면 기록) | `government` 광고주로 결제 주문 생성 시도 거부. 증빙 PDF 1클릭 생성. 게재 기간 종료 시 자동 내림 | 정부광고법(재단 대행): https://journalist.or.kr/news/article.html?no=59081 |
| NW-F-035 | 독자 후원·유료 멤버십(P1) | 신규 | 정기(월·연)·일시 후원과 멤버십 등급. 결제는 신문사 자기 Toss 가맹 키(`core.encrypted_credentials`)로 받는다(D-4). 서버 주문 행이 금액 정본, 빌링키 정기결제, 셀프 해지, 영수증 메일. 플랫폼 수수료는 `news_reader_fee_bps`로 월 집계(4.5절) | 신문사 키 미등록 시 후원 버튼 숨김. 클라이언트가 보낸 금액은 무시하고 주문 행 금액으로 승인. 웹훅 서명 검증·같은 event 재수신 시 변화 0. 해지 시 다음 결제일부터 중단, 기간 말까지 혜택. 월 수수료 = (성공 − 환불) × bps ÷ 10,000, 원 단위 절사 | 확정 결정 4, `docs/products/_platform-core/CORE_SPEC.md` 5장, 6장 |
| NW-F-036 | 미터형 페이월·프리미엄 기사(P1) | 신규 | 월 N건(기본 5, 0~20 설정, 제안) 무료 후 로그인 유도, 그다음 멤버십 안내. 프리미엄 기사 지정. 구조화 데이터 `isAccessibleForFree` 표기. 정정보도·재난·선거 공지는 페이월 제외(제안) | 비로그인 6번째 기사에서 앞 3문단 + 가입 안내. 카운트는 KST 매월 1일 초기화. 멤버는 전문. 제외 유형 기사는 카운트하지 않는다 | Ghost·Newspack 멤버십 패턴(https://ghost.org/pricing/ , https://newspack.com/pricing/), 한국 유료 이용 19% |
| NW-F-037 | 뉴스레터(P0) | 신규 | 목록(신문사당 5개, 제안), 이중 동의(확인 링크 48시간), 아침 브리핑 자동 구성(전날 18시~당일 6시 게시 기사 상위 N건, 편집자 확인 또는 자동 발송), 발송(`news.newsletter` 잡, 월 `news_newsletter_monthly` 한도), 광고 블록 포함 시 제목 '(광고)', 21~08시 발송은 야간 수신 동의자만, 2년마다 수신 동의 재확인, 토큰 원클릭 수신거부(`news.unsubscribe_newsletter`), 열람·클릭률 | 확인 전 구독자 발송 0. 월 한도 초과 발송 예약 거부와 남은 수 표시. 수신거부 후 1분 안에 상태 변경, 다음 발송 제외. 동의 후 2년 − 30일에 재확인 메일, 2년 무응답 자동 중단. 하드 바운스 3회 자동 중단 | 정보통신망법 50조(조문 원문 미확인), INN 뉴스레터 중간값 6,000명 |
| NW-F-038 | 속보 웹 푸시(P1) | 신규 | VAPID 웹 푸시, 독자 동의, editor 이상 발송, 신문사당 하루 5회 상한(제안). 카카오 알림톡은 P2 | 동의하지 않은 브라우저 발송 0. 구독 1만 기준 5분 안 발송 완료. 하루 6번째 발송 거부 | 제안 |

### 3.5 배포·준수(M6, M7)

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| NW-F-040 | RSS·뉴스 사이트맵·구조화 데이터·OG(P0) | 신규 | RSS 전체·섹션별 최근 50건. 뉴스 사이트맵: 최근 2일, 파일당 1,000개, `news:publication`(name, language)·`publication_date`·`title`. NewsArticle JSON-LD(headline, datePublished, dateModified, author, publisher logo, image). OG·canonical(커스텀 도메인 우선) | 게시 5분 안 사이트맵 포함, 2일 지난 기사 제외, 1,000개 초과 시 분할. 비게시 5분 안 사이트맵·RSS 제거. 시드 기사 10건의 구조화 데이터 검사 오류 0(수동 점검표) | https://developers.google.com/search/docs/crawling-indexing/sitemaps/news-sitemap |
| NW-F-041 | 포털·법정 지표 대시보드(P0) | 신규 | `news.compliance_weekly_stats`: KST 월~일 주 단위. 자체기사 비율 = `original` ÷ (그 주 신규 게재 − `sponsored`), AI 초안 규칙은 D-9. 30% 미만 경고, 35% 미만 주의(제안). 주간 신규 게재 0건 경고. 보도자료 비율 50% 초과 경고(제안: 포털 감점 대비) | 시드(한 주 original 2, press_release 8) → 20%와 빨간 경고. 진행 중인 주는 "현재까지" 값 표시. 지난 52주 CSV | 신문법 시행령 제2조(자체 30%·주간 신규 게재), 네이버 뉴스제휴 자체기사 비율·보도자료 감점: https://journalist.or.kr/news/article.html?no=60389 , 다음 정량평가: https://journalist.or.kr/news/article.html?no=56817 |
| NW-F-042 | SNS 자동 공유(P2) | 신규 | 게시 시 신문사 SNS 계정에 링크 공유. 외부 API 약관 확인 후 설계 | 해당 단계에서 정함 | 제안 |
| NW-F-043 | 통신사 전재 계약 관리(P1) | 신규 | 계약(통신사명, 기간, 허용 범위, 출처 표기 문구), `wire` 기사 연결, 만료 시 자동 비노출(KST 00:00 잡) | 만료 다음 날 00:05까지 해당 `wire` 기사 anon SELECT 0, 편집국에 목록 알림. 출처 표기 문구가 기사 하단에 자동 표시 | 통신사 전재계약 필요·요금 비공개(계약 조건 미확인) |
| NW-F-044 | 선거 모드(P1) | 신규 | `election_periods`(선거명, 선거일, 공표 금지 시작 = 선거일 6일 전 0시, 종료 = 투표 마감 시각). `여론조사` 표시 기사는 금지 기간에 게시·예약 게시 차단. 여론조사 필수 표시 템플릿(조사기관, 의뢰자, 조사 일시, 대상, 표본 수, 방법, 오차범위 등. 항목 원문은 미확인). 댓글 정책 토글 | 금지 기간 중 여론조사 기사 게시 시도 거부와 사유 표시, 금지 기간에 걸친 예약은 저장 거부. 필수 표시 항목 누락 제출 거부 | 공직선거법 108조(조문 원문 미확인), 다음 전국선거 2028 총선 |
| NW-F-045 | AI 크롤러 정책(P1) | 신규 | 신문사별 `robots.txt` 생성, 검색 크롤러와 AI 학습 크롤러를 따로 허용·차단, `llms.txt`(표준 지위 미확인). 기본값: 검색 허용, AI 학습 크롤러 차단(제안) | 변경 후 5분 안 반영. 기본값 신문사의 `robots.txt`에 AI 학습 크롤러 차단 행 존재 | AI 챗봇 뉴스 이용 14%: https://www.nocutnews.co.kr/news/6533916 |

### 3.6 AI·음성(확정 결정 13~17, MVP 필수)

공통 수용 기준: (1) 브라우저는 `/api/ai/*`, `/api/voice/*`만 호출한다. (2) 결과가 전달되지 않은 실패는 선차감 전액 환불(`docs/products/_platform-core/AI_ARCHITECTURE.md:129`). (3) 음성 기능이 꺼지거나 마이크를 거부해도 같은 기능을 텍스트로 쓸 수 있다. (4) AI 산출물은 사람이 승인하기 전에 기사·홈에 반영되지 않는다(언론계 생성형 AI 준칙: https://www.journalist.or.kr/news/article.html?no=57255).

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| NW-F-050 | 보도자료 → 기사 초안(P0) | 신규 | 입력: 텍스트 붙여넣기 또는 PDF·DOCX(20MB 이하, 추출 20,000자 이하. HWP 미지원). 그래프 `news.press_to_draft`: 분류 → 사실 추출 → 초안 → 표기 점검 → 사람 승인. 결과는 `draft` 상태 `press_release` 유형 기사이고 `ai_assisted=true`. 화면에 원문 대비 숫자·날짜·고유명사 대조표. 보도자료에 없는 인용문을 만들지 않는다 | 초안에 있고 원문에 없는 숫자·고유명사는 "원문에 없음" 표시(평가셋 50건에서 표시 누락 0, 제안). 자동 게시 경로 0(그래프 출력은 항상 `draft`). 실패 시 선차감 전액 환불이 원장에 남음. 게시 기사 하단에 AI 보조 표시(D-9 문구). `original` 전환은 D-9 규칙만 | 확정 결정 13, AI기본법 표시(https://mobile.newsis.com/view/NISX20260121_0003484769) |
| NW-F-051 | 제목·요약·SEO 메타 추천, 표기 점검(P0) | 신규 | `news.headline`: 제목 3안(낚시성 금칙어 필터), `news.summary`: 3문장 요약·메타 설명 120자 이하, `news.proofread`: 맞춤법·띄어쓰기·사내 표기 규칙(위키) 제안 카드 | 제안을 적용하기 전에는 본문 불변. 제목 후보에 금칙어 목록 단어 0. 표기 제안마다 근거 규칙 표시. 실패 환불 | `docs/products/_platform-core/LLM_WIKI.md`(사내 규칙 위키) |
| NW-F-052 | 오디오 기사(P1) | 신규 | 게시 기사 → TTS(`news.tts`), 기사당 1회 생성, 본문 수정 시 재생성 선택. 첫머리 "AI 음성으로 읽어 드립니다". 작업 도중 제공자 대체 금지 | 같은 본문 해시 재요청 0크레딧. 구간 하나라도 실패하면 파일 미생성·전액 환불. 플레이어에 "AI 음성" 표시 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104` |
| NW-F-053 | 편집국 AI 어시스턴트(P0) | 신규 | Dify 앱 `news` 채팅. 근거: 그 신문사 게시 기사(게시 시 자동 색인)와 사내 규정 위키(표기 규칙, 윤리강령, 업로드 규정 파일). 답변에 출처(기사 링크·규정 페이지) 표시. 음성 대화: 마이크 → STT → 답변 → 읽어 주기 | 답변마다 출처 1개 이상 또는 "근거를 찾지 못했습니다". 교차 테넌트 평가셋에서 다른 신문사 기사 인용 0. 마이크 거부 시 텍스트 채팅 정상. 실패 턴 환불 | `docs/products/_platform-core/AI_ARCHITECTURE.md` 2장, 5장, `docs/products/_platform-core/SECURITY_BASELINE.md:279-307` |
| NW-F-054 | 인터뷰 받아쓰기(P0) | 신규 | 녹음 → STT(`news.stt`, 오픈소스 강제) → 기사 메모(수정 가능). 원본 미저장(`store_audio=false`). 녹음 전 고지(취재원 녹음 동의는 기자 책임 안내, 고지문 버전 감사 `voice.notice_ack`). 구간 120초 분할, 1회 최대 90분(제안) | 처리 후 Storage에 음성 파일 0. 고지 확인 전 녹음 버튼 비활성. 60분 녹음 → 메모 p95 10분 안(제안). 실패 구간만 환불 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:85-95` |
| NW-F-055 | 사진 alt·캡션 초안(P1) | 신규 | `news.alt_text`: 사진 → alt·캡션 제안. 인물 실명 추정 금지 | 제안 적용 전 alt 불변. 출력에 사람 이름이 있으면 경고(캡션 입력값에 있던 이름 제외) | WCAG, 제안 |
| NW-F-056 | 독자 기사 Q&A 챗봇(P2) | 신규 | 방문자 모드, 근거는 그 신문사 게시 기사만, 비용은 신문사 크레딧, 방문자 키 결합 | 방문자 IP 해시당 하루 10턴(제안), 다른 신문사 기사 인용 0 | `docs/products/_platform-core/AI_ARCHITECTURE.md:130` |

### 3.7 운영·분석·이관(M8, 운영)

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| NW-F-060 | 편집국 대시보드(P0) | 신규 | 오늘 게시 수, 시간대별 조회(1시간 버킷), 유입(네이버·다음·구글·SNS·직접·기타, referrer 도메인 그룹), 많이 본 기사, 기자별 게시 수. 개인 단위 데이터 없음 | 조회 반영 지연 5분 이하. 다른 신문사 수치 0. 숫자 없으면 "—" | 포털 뉴스 경로 61%(https://www.nocutnews.co.kr/news/6533916) |
| NW-F-061 | 지원사업·ABC 리포트(P1) | 신규 | 월 발행 실적, 자체기사 비율, 광고 비중(플랫폼이 아는 직판·독자 매출 + 신문사 입력 외부 매출), 독자·뉴스레터 수. PDF·XLSX. `news_support_reports` 플랜만 | 1클릭 생성. 수치마다 출처(표·기간) 각주, 신문사 입력값은 "신문사 입력" 표시 | 선정 요건: https://kbmaeil.com/article/202502030907920 , 제8차 계획: https://kbmaeil.com/article/20260731500057 |
| NW-F-062 | 플랫폼 운영 콘솔(P0) | 신규 | 개설 심사, 신문사 목록·플랜·체험 만료, 도메인 상태, 잡 실패, 장애 공지. `platform_admin`만. 기사 초안·독자 개인정보 열람 기본 차단(신문사가 지원 열람을 24시간 허용한 경우만, 사유 입력) | 비운영자 404. 조회마다 감사 `admin.view`. 허용 없는 신문사 독자 목록 요청 거부 | `docs/products/_platform-core/SECURITY_BASELINE.md` 9장 |
| NW-F-063 | 기존 CMS 기사 이관(P1) | 신규 | 가져오기: RSS, CSV, XML, 사이트맵 크롤. 기사·사진·바이라인·게시일 매핑, 드라이런 리포트, 옛 URL → 새 URL 301 리디렉션 맵. 크롤은 도메인 소유 확인(DNS TXT 또는 파일) 후에만, robots 준수. `news.ingest` 잡 | 드라이런이 건수·오류 리포트를 낸다. 본 실행 후 원본 대비 매칭 99% 이상(제안). 옛 URL 표본 100건 301 확인. 소유 확인 없는 크롤 요청 거부. 이관 기사는 과거 주 통계에만 반영 | 엔디소프트 거래 매체 3,644 표기(https://www.ndsoft.co.kr), 07장 |
| NW-F-064 | 신문사 해지·데이터 내보내기(P1) | 신규 | 기사(JSON·CSV·HTML), 미디어 ZIP, 독자·구독자 명단(CSV, 신문사 소유), 리디렉션용 URL 목록. 해지 후 90일 보관 뒤 purge(제안) | 요청 후 24시간 안 서명 URL(7일 유효). 해지 90일 뒤 purge 잡이 신문사 행 0을 확인. 독자 정기결제는 해지 전 일괄 해지 안내 | `docs/products/_platform-core/SECURITY_BASELINE.md:191-201` |

### 3.8 인증 단계별 수용 기준 (편집국과 독자)

공통 기준 원문은 `docs/products/_platform-core/AUTH_ROADMAP.md:210-219`(B), `:252-260`(C1), `:301-310`(C2). 독자 열은 이 제품의 적용 방식이다.

| # | 편집국(NW-F-005, `newsroom.<플랫폼>`) | 독자(NW-F-006, 신문사 도메인) |
|---|---|---|
| A | 공통 페르소나(owner=publisher, admin=editor, member=reporter, viewer, outsider=다른 신문사 publisher, no_app, suspended, ops) + `desk`, `contributor`, `ad_manager`. outsider는 이 신문사 기사 0행, no_app은 `/no-access`, suspended는 403, ops는 운영 콘솔 | `reader`(이 신문 독자), `reader_member`(유료 멤버: 프리미엄 전문), `reader_other`(다른 신문 독자: 이 신문 `readers` 행 조회 0), `anon`(공개 기사만). 독자가 편집국 호스트로 가면 `/no-access` |
| B-1 | 새 Google 계정 첫 로그인 → `entitled=false`, `/no-access`, 크레딧 원장 변화 0(invite 앱). 초대 이메일과 같은 Google 계정이면 초대 조직 멤버 | 새 Google 계정·새 매직 링크 첫 로그인 → 엔타이틀먼트·크레딧 변화 0, 이 신문사 `readers` 1행. 재로그인 3회 뒤에도 1행 |
| B-2 | `next=//evil.com`, `https://evil.com`, `/\evil.com` → `/newsroom` | 같은 공격 → 신문사 홈. 리다이렉트 origin은 요청 Host가 `resolve_tenant`로 확인된 도메인일 때만 |
| B-3 | `code` 없음·재사용·만료 → `/login?error=callback`, 로그에 토큰·코드 없음 | 같음(신문사 도메인 `/login`) |
| B-4 | 배포 빌드에서 `/api/dev/login` 404, 개발용 패널 없음, `AUTH_MODE=mock`이면 빌드 실패 | 같음(라우트 그룹 공통) |
| B-5 | Mock E2E 녹색, Google 실로그인 수동 점검표(데스크톱·모바일, 신규·기존) | 같음 + 점검표에 서브도메인 1개·커스텀 도메인 1개 포함 |
| B-6 | Google 설정·Redirect URLs·`AUTH_PROVIDERS`가 배포 체크리스트와 일치 | Redirect URLs에 서브도메인 패턴과 활성 커스텀 도메인 콜백이 모두 있다(D-3). 커스텀 도메인 활성화 후 10분 안 등록 확인 |
| C1-1 | P2 선택(D-17). 채택 시 독자 열과 같은 기준 | 새 카카오 계정 첫 로그인 → B-1 독자 결과 |
| C1-2 | 같음 | 비즈 앱(D-13 (a))이면 같은 이메일의 Google 독자와 같은 `user_id`, `readers` 행 그대로 |
| C1-3 | 같음 | (b)면 뉴스레터 구독·후원 전에 연락 이메일 입력 화면 |
| C1-4 | 같음 | 표시 이름은 카카오 닉네임(없으면 `user`). 댓글 표시명은 독자 설정이 우선 |
| C1-5 | 같음 | 카카오 버튼 색·문구는 카카오 디자인 가이드(최신판 미확인) |
| C2-1 | P2 선택. 채택 시 독자 열과 같은 기준 | 스파이크 결과 `[DECISION]` 기록, `NAVER_AUTH_PATH` 일치(D-14) |
| C2-2 | 같음 | 새 네이버 계정 첫 로그인 → B-1 독자 결과 |
| C2-3 | 같음 | 재로그인 5회 → 같은 `user_id`, 사용자·`readers` 행 증가 0 |
| C2-4 | 같음 | (브리지) state 변조·재사용·쿠키 없음·다른 브라우저 콜백 재생 → 거부, 세션 0 |
| C2-5 | 같음 | (브리지) 같은 이메일의 Google 독자가 네이버 첫 로그인 → `email_in_use`, 새 사용자 0 |
| C2-6 | 같음 | 네이버 검수 통과 전 운영 `AUTH_PROVIDERS`에 `naver` 없음 |

## 4. 요금과 크레딧

정본 출처: 확정 결정 8(플랜 정본은 01_PRD 4장 + seed). 이 제품은 신규라 원본 가격이 없고 아래 금액·크레딧은 모두 제안이다. 신문사 대상 B2B 가격은 VAT 별도, 독자에게 보이는 후원·멤버십 가격은 VAT 포함으로 표기한다(`Price_Plans/_common/PRICING_PRINCIPLES.md:84-91`). 단계별 계획과 원가 검증은 `Price_Plans/local-news/PRICE_PLAN.md`.

### 4.1 플랜 (제안)

| 코드 | 이름 | 월 가격(VAT 별도) | 연간(2개월 할인) | 월 AI 크레딧 | 가입 크레딧 | 이월 | 포함(요약) | 이유 |
|---|---|---|---|---|---|---|---|---|
| `news_trial` | 체험 | 0원(30일) | - | 300 | 0 | 없음 | Standard 기능, 기자 3명, 서브도메인만, 뉴스레터 월 1,000통, 저장 5GB | 30일 안에 첫 호 발행과 홈 편집까지 해 보는 양. 커스텀 도메인은 체험 종료 후 DNS 정리 부담 때문에 제외(제안) |
| `news_starter` | 스타터(인터넷 지역신문) | 99,000원 | 990,000원 | 300 | 0 | 없음 | 기자 3명, 서브도메인, 템플릿 3종, 광고 직판, 뉴스레터 월 5,000통, 저장 10GB, 독자 결제 수수료 3% | 기자 1~3명 인터넷신문(66.9%가 매출 1억 미만). 월 매출의 1% 안팎 |
| `news_standard` | 스탠다드(주간지) | 199,000원 | 1,990,000원 | 1,500 | 0 | 없음 | 기자 10명, 커스텀 도메인 1, 후원·멤버십(수수료 0%), 뉴스레터 월 30,000통, 업소 셀프 광고, 저장 50GB, 이관 1회 무료 | 주력 등급. 평균 기자 4명인 주간지 + 여유 |
| `news_pro` | 프로(지역 일간) | 390,000원 | 3,900,000원 | 4,000 | 0 | 없음 | 기자 30명, 커스텀 도메인 3, 지면 PDF, 지역판, 뉴스레터 월 100,000통, 저장 200GB, 지원사업 리포트, API | 앵커 등급. Newspack 최저 월 $750(약 105만원)의 약 37% |
| `news_enterprise` | 엔터프라이즈 | 별도 견적 | 별도 | 별도 | 0 | 없음 | 전용 DB(판매 모델 B), SLA, 전용 로그인 브랜드 | 일간 평균 기자 46명 규모 |

결제는 플랫폼 Toss 가맹으로 신문사에 청구한다(확정 결정 4, 코어 빌링). 연간 결제 할인 16.7%는 공용 원칙 15~20% 범위 안이다(`Price_Plans/_common/PRICING_PRINCIPLES.md:79`). 플랜 하향 시 초과 자원(기자 수, 도메인)은 신규 추가만 막고 기존 것은 유지, 저장 한도 초과는 업로드만 막는다(제안).

### 4.2 `core.plans.features` 키 해석 (서버만 읽는다, `docs/products/_platform-core/DB_CONVENTIONS.md:231-242`)

키가 없으면 "기본값" 열로 해석한다. 기본값은 가장 낮은 권한이다.

| 키 | 타입 | 기본값 | trial / starter / standard / pro | 의미 | 강제 위치 |
|---|---|---|---|---|---|
| `news_staff_max` | integer | 3 | 3 / 3 / 10 / 30 | 활성+초대 중 편집국 인원 | `news.invite_staff` |
| `news_custom_domains` | integer | 0 | 0 / 0 / 1 / 3 | 활성 커스텀 도메인 수 | Theming 도메인 등록 RPC 앞 Route Handler |
| `news_newsletter_monthly` | integer | 1000 | 1,000 / 5,000 / 30,000 / 100,000 | KST 달력 월 발송 통수(수신자 수 기준) | `news.newsletter` 잡 예약 |
| `news_storage_gb` | integer | 5 | 5 / 10 / 50 / 200 | 미디어·지면·첨부 합계 | 업로드 Route Handler |
| `news_print_pdf` | boolean | false | false / false / false / true | 지면 PDF·지면보기 | 지면 업로드 |
| `news_regional_editions` | boolean | false | false / false / false / true | 지역판(시군별 홈 변형) | 홈 레이아웃 RPC |
| `news_reader_fee_bps` | integer | 300 | 300 / 300 / 0 / 0 | 독자 결제 플랫폼 수수료(만분율) | 월 수수료 집계 잡 |
| `news_self_ads` | boolean | false | true / false / true / true | 업소 셀프 광고(브리프 키 목록에 없어 추가 제안) | 업소 신청 Route Handler |
| `news_api` | boolean | false | false / false / false / true | 외부 기사 API 키 발급 | API 키 발급 화면 |
| `news_support_reports` | boolean | false | false / false / false / true | 지원사업·ABC 리포트 | 리포트 Route Handler |
| `ai_monthly_credits` | integer | 0 | 300 / 300 / 1,500 / 4,000 | 월 지급 AI 크레딧(plan 버킷) | 코어 월 지급 |
| `theming_level` | integer | 1 | 1 / 1 / 2 / 2(enterprise 3) | Theming 단계 L1~L3 | `Multi-tenant_Theming` 런타임 |

### 4.3 AI·음성 크레딧 단가 (제안)

기본값은 코어 seed 단가(`docs/products/_supabase-modular/seed.sql:243-259`: LLM 상용 1k 입력 1·출력 4, 오픈소스 0.2·0.5, 오픈소스 임베딩 0.01/1k), 선차감·정산 규칙은 `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130`, 음성 기본 단가는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104`(STT ElevenLabs 3/분·오픈소스 0.5/분, TTS ElevenLabs 5/천 자·오픈소스 1/천 자)다. 국외 이전 미동의 신문사와 오픈소스 강제 기능은 오픈소스 단가가 자동 적용된다.

| 작업 | 선차감 | 정산 | 상용 경로 예 | 오픈소스 경로 예 | 멱등 키 |
|---|---|---|---|---|---|
| 보도자료 초안 그래프(NW-F-050), 보도자료 1건 | 상용 15 / 오픈소스 3 | 실제 사용량, 최소 1, 상한 25(초과분 운영사 부담) | 2,000자 기준 약 15~20(4노드) | 약 3 | `run:<ai_run_id>` |
| 제목 3안·요약·메타(NW-F-051) | 2 | 실제, 최소 1, 상한 4 | 약 2 | 1 | `consume:news:<request_id>` |
| 표기 점검, 기사 3,000자당 | 3 | 실제, 최소 1 | 약 3 | 1 | `consume:news:<request_id>` |
| 사진 alt·캡션(NW-F-055), 장당 | 2 | 정액 | 2 | 비전 오픈소스 모델 미확인 | `consume:news:<request_id>` |
| AI 어시스턴트 채팅 1턴(NW-F-053) | 3 | 실제 + Dify 보조 노드 0.5, 올림, 최소 1, 상한 5 | 3~5 | 1~2 | `conv:<id>:turn:<n>` |
| 받아쓰기·음성 질문 STT(분, 구간마다 올림) | 구간 길이 × 단가 | 실제 `audio_seconds` | `news.stt`는 오픈소스 강제라 해당 없음 | 0.5/분(60분 30) | `voice:<voice_job_id>` |
| TTS(오디오 기사, 읽어 주기), 천 자당 | 글자 수 × 단가 | 실제 `characters` | ElevenLabs 10(제품 단가, 코어 기본 5보다 높음: PRICE_PLAN 3.2절 원가) | 1 | `voice:<voice_job_id>` |
| 게시 기사 자동 색인(오픈소스 임베딩) | 0(플랜 포함) | `ai_usage`에 원가만 기록 | 해당 없음 | 기사 2,000자 약 0.02 | `rag:<article_id>:<revision>` |
| 사내 규정 파일 색인, 파일 1개 | 1, 10만 토큰마다 +1 | 실제 | 해당 없음 | 1~2 | `rag:<document_id>` |
| 댓글 AI 모더레이션 | 0(플랜 포함, 신문사당 하루 2,000건 상한, 제안) | 원가만 기록 | 해당 없음(오픈소스 강제) | 건당 약 0.05 | `mod:<comment_id>` |
| 같은 본문 해시 오디오 재요청, 대화 목록·위키 열람 | 0 | - | - | - | - |

검산: Starter 300크레딧 = 상용 보도자료 초안 약 15~20건 + 제목·요약 30회, 또는 오픈소스 경로 초안 약 100건. 하루 4~6건 게시 신문사에서 보도자료 비중 30%를 가정하면 월 약 30~45건이라 상용 경로만 쓰면 부족할 수 있다. 4.4절 크레딧팩으로 보충하고 원가 실측 후 D-5에서 월 크레딧을 다시 정한다.

### 4.4 AI 크레딧팩 (제안, pack 버킷, 소멸 없음)

| 코드 | 크레딧 | 가격(VAT 별도) | 크레딧당 | 이유 |
|---|---|---|---|---|
| `news_ai_1000` | 1,000 | 20,000원 | 20원 | 허용 원가 크레딧당 약 5.8원(PRICE_PLAN 3.2절) 안에 상용 LLM·ElevenLabs Flash TTS가 들어온다 |
| `news_ai_5000` | 5,000 | 90,000원 | 18원 | 일간지 대량 사용 |

차감 순서는 plan 버킷 → pack 버킷(`docs/products/_platform-core/CORE_SPEC.md` 4장). 체험 신문사는 팩을 살 수 없다(제안: 체험 남용 방지).

### 4.5 독자 결제 규칙 (신문사 자기 가맹, D-4)

| 항목 | 규칙 | 근거 |
|---|---|---|
| 판매자 | 후원·멤버십·경조사 유료 게재·업소 광고의 판매자는 신문사다. 신문사가 자기 Toss 가맹 계약을 맺고 키를 등록한다. 플랫폼은 대금을 수납·정산하지 않는다 | 전자금융·지급대행 책임 회피(D-4) |
| 키 보관 | 신문사 Toss 시크릿 키·웹훅 시크릿은 `core.encrypted_credentials`(publisher만 등록, 평문 컬럼 금지, 화면은 끝 4자리) | `docs/products/_platform-core/SECURITY_BASELINE.md` 5장 |
| 주문·승인 | 서버가 주문 행을 먼저 저장(금액 정본) → 결제창 → 서버 confirm(신문사 키) → 금액·주문번호 대조 → 멱등 반영. 웹훅은 서명 검증 후 보조 | `docs/products/_platform-core/CORE_SPEC.md` 5장(코어 흐름을 신문사 키로 쓰는 확장은 06장 코어 요청) |
| 가격 표기 | 독자 화면 가격은 VAT 포함. 정기 후원은 금액·주기·다음 결제일·해지 방법을 결제 전 표시 | `Price_Plans/_common/PRICING_PRINCIPLES.md:89` |
| 영수증·환불 | 영수증 발행자는 신문사. 환불 정책은 신문사가 정하고 기본 템플릿(정기 후원은 다음 결제일부터 해지, 일시 후원은 7일 안 요청 시 환불, 제안)을 제공. 기부금 영수증 발급 가능 여부는 신문사 법인 형태에 따름(미확인) | 제안 |
| 플랫폼 수수료 | 매월 1일 KST에 전월 독자 결제 (성공 − 환불) × `news_reader_fee_bps` ÷ 10,000을 계산해 신문사 B2B 청구에 합산. 명세에 결제 건수·금액·환불 표시 | 4.2절 |
| 미성년자 | 만 14세 미만은 독자 가입이 막혀 결제도 불가 | 6.3절 |
| 비활성 | 신문사 해지·결제 키 만료 시 독자 정기결제를 새로 만들지 않고, 기존 독자에게 해지 안내 메일 | NW-F-064 |

### 4.6 B2B 결제·해지·환불 (제안, 법무 검토 필요)

| 대상 | 규칙 |
|---|---|
| 월 구독 | 결제 후 7일 이내이고 기사 게시 0건이면 전액 환불. 그 외에는 해지 예약(기간 말까지 이용) |
| 연간 결제 | 해지 시 남은 개월 수 × 월 정가 기준 차감 후 환불(할인 회수) |
| 크레딧팩 | 미사용 팩만 7일 안 환불 |
| 장애 | 월 가용성 99.5% 미달 시 다음 달 이용료 10% 크레딧(제안). AI 작업 실패는 자동 환불 |
| 세금계산서 | 사업자 고객 발행 필요. Toss 연동 발행 가능 여부 미확인 |

## 5. 비기능 요구사항

| 항목 | 목표 | 근거 |
|---|---|---|
| 독자 사이트 CWV | p75(모바일·데스크톱) LCP 2.5초 이하, INP 200ms 이하, CLS 0.1 이하. 테넌트별 실사용 측정 | https://web.dev/articles/vitals |
| 독자 사이트 응답 | 캐시 적중 TTFB p75 200ms 이하, 캐시 미적중 p95 1초 이하(제안) | 제안: ISR·캐시 태그 |
| 게시 → 반영 | 기사 URL 열람 가능 5초 이하, 홈·섹션 반영 p95 60초 이하, 사이트맵·RSS 5분 이하, 예약 게시 정확도 + 60초 | 제안: 속보 경쟁 |
| 속보 급증 | 평시 10배 요청에서 독자 사이트 5xx 1% 미만(캐시 제공, 오류 시 stale 제공) | 제안: 단독 DB 이유 1(README 5장) |
| 편집국 화면 | 기사 목록·에디터 열기 p95 1.5초, 자동 저장 2초 debounce, 저장 실패 3회 재시도 후 배너 | 제안 |
| 뉴스레터 발송 | 시간당 50,000통 처리(발송 제공자 한도 미확인), 1만 통 15분 안 완료 | 제안 |
| 웹 푸시 | 구독 1만 5분 안 | 제안 |
| 조회 집계 | 1시간 버킷, 많이 본 뉴스 5분 갱신, 원시 조회 이벤트는 저장하지 않음 | 제안: 개인정보 최소화 |
| 검색 | 기사 10만 건 p95 800ms 이하 | 제안(D-7) |
| 이미지 | 원본 긴 변 2,400px로 축소 저장, 파생 4종 WebP, 기사 첫 이미지 우선 로드 | 제안: LCP |
| 광고 소재 | MREC 150KB, Billboard 250KB 초기 로드 상한, 슬롯 공간 예약 | https://www.iab.com/wp-content/uploads/2019/04/IABNewAdPortfolio_LW_FixedSizeSpec.pdf |
| 파일 상한 | 사진 20MB, 등록증 10MB, 로고 1MB, 지면 PDF 100MB, 제보 첨부 5개 각 20MB, 규정 파일 20MB, 보도자료 20MB, 이관 파일 200MB | 제안 |
| AI 응답 | 제목·요약 p95 10초, 채팅 첫 표시 p95 3초(기사 근거 질문 12초), 보도자료 초안 그래프 p95 90초·타임아웃 180초, 60분 받아쓰기 p95 10분, 오디오 기사 3,000자 p95 60초 | 제안: `docs/products/flora-publishing/01_PRD.md:278-286` 기준 |
| AI 입력 상한 | 채팅 메시지 1,000자·대화당 50턴, STT 구간 120초·5MB, 보도자료 20,000자 | 제안 |
| 레이트 리밋(코어) | 로그인·매직 링크 IP당 10회/10분, 생성 API 조직당 60회/분, 웹훅 제공자당 600회/분 | `docs/products/_platform-core/SECURITY_BASELINE.md:143-155` |
| 레이트 리밋(제품) | 조회 비콘 IP 해시당 60회/분(`/r/` 기준 준용), 댓글 독자당 5회/분·50회/일, 제보 IP 해시당 5회/시간, 정정 청구 IP 해시당 3회/시간, 뉴스레터 구독 IP 해시당 5회/시간, 경조사 신청 독자당 3회/일, 검색 IP 해시당 30회/분, 채팅 사용자당 20턴/분 | 제안: 같은 표 기준 |
| 보존 | 게시 기사·정정 이력: 신문사 계약 기간 영구. 기사 개정 이력 2년(제안). 제보: 종결 후 1년. 정정 청구 기록 3년. 댓글: 삭제 후 30일. 조회 집계 2년. 감사 로그 2년. Dify 대화 로그 30일. 해지 신문사 데이터 90일 뒤 purge | `docs/products/_platform-core/AI_ARCHITECTURE.md:69`, 나머지 제안 |
| 가용성 | 월 99.5%(Vercel + Railway + Supabase 합산). 독자 사이트는 DB 장애 시 캐시된 페이지 제공 | 제안 |
| 접근성 | WCAG 2.1 AA, 글자 크기 3단계, 키보드로 모든 편집 동작 | 03장 6절 |

## 6. 법, 개인정보, 금지 문구

### 6.1 법령 → 제품 의무

현행 조문 번호·과태료 액수는 law.go.kr 원문을 확인하지 못했다(미확인). 아래 조문 표기는 조사 출처(https://www.wipo.int/wipolex/en/text/438729 , https://www.nepla.ai/law/신문-등의-진흥에-관한-법률-시행령)를 따른다. 법적 의무의 주체는 신문사이고 제품은 지키기 쉽게 만드는 도구다(약관에 명시).

| 법령 | 의무 | 제품 처리 | 기능 |
|---|---|---|---|
| 신문법 제21조(필요적 게재사항) | 명칭, 등록번호, 등록연월일, 제호, 발행인, 편집인, 발행소, 발행연월일 게재 | 필수 입력, 미완성 시 공개 차단, 전 페이지 푸터 | NW-F-002, 028 |
| 신문법 시행령 제7조의2 | 청소년보호책임자 성명을 인터넷신문 첫 화면에 표시 | 전 페이지 푸터 필수, 청소년보호정책 페이지 필수 | NW-F-002, 028 |
| 신문법 제6조 제3항 | 기사와 광고 구분 | 광고·기사형 광고·후원 라벨 강제, 끄는 설정 없음 | NW-F-032 |
| 신문법 제2조·시행령 제2조 | 인터넷신문: 주간 게재 기사 30% 이상 자체 생산, 주간 단위 신규 게재 | 기사 유형 필수, 주간 비율·신규 게재 경고 | NW-F-011, 041 |
| 언론중재법 14·15조 | 정정보도 청구 기간(안 날 3개월·보도 후 6개월), 청구 후 3일 안 수용 여부 통지, 수용 시 7일 안 게재 | 청구 접수, SLA 타이머, 원기사 연결, 이력 3년 | NW-F-027 |
| 정보통신망법 50조 | 광고성 정보 사전 동의, 21~08시 별도 동의, '(광고)' 표기, 2년마다 수신동의 확인 | 이중 동의, 야간 발송 제한, 광고 블록 시 제목 표기, 2년 재확인(뉴스레터의 광고성 정보 해당 여부는 법무 확인) | NW-F-037 |
| 정보통신망법 44조의2 | 권리침해 신고 시 임시조치 | 신고 접수, 임시조치, 작성자 통지, 기록 | NW-F-026 |
| 개인정보보호법 | 처리방침, 최소 수집, 만 14세 미만 법정대리인 동의, 파기, 위탁 공개 | 처리방침 템플릿(처리자·수탁자 표), 만 14세 미만 가입 차단, 파기 잡 | NW-F-006, 028, 6.2절 |
| 공직선거법 108조 | 선거일 전 6일~투표 마감 여론조사 공표 금지, 공표 시 조사기관·표본 등 표시. 82조의6 실명확인은 2021 위헌(이후 개정 미확인) | 선거 모드 엠바고, 필수 표시 템플릿, 실명 확인 기능 없음 | NW-F-044 |
| 정부광고법 | 정부·지자체 광고는 언론진흥재단만 대행 | `government` 광고주 직판 차단, 게재 증빙만 | NW-F-034 |
| 저작권법 | 통신사 기사는 전재계약 필요, 사진 출처 | 전재 계약 메타·만료 비노출, 사진 출처 필수, 이관 시 타사 기사 권리 확인 체크 | NW-F-014, 043, 063 |
| AI기본법(2026-01-22 시행) | 생성형 AI 결과물 표시. 계도기간 1년 이상, 과태료 최대 3천만 원 | AI 보조 기사 표시, AI 음성 고지, 채팅 답변 표시, AI 사용 로그 | NW-F-050~056, 6.4절. https://mobile.newsis.com/view/NISX20260121_0003484769 |
| 언론계 생성형 AI 준칙(2024-12-05) | AI 산출물 직접 사용 시 고지, 사람 감독, AI 단독 기사 발행 지양 | 사람 승인 없는 게시 경로 없음, AI 사용 기록 | 3.6절. https://www.journalist.or.kr/news/article.html?no=57255 |

### 6.2 개인정보 처리 구조: 처리자와 수탁자

| 데이터 | 개인정보처리자 | 플랫폼 지위 | 처리 |
|---|---|---|---|
| 신문사별 독자 정보(`readers`, 멤버십, 후원, 댓글, 제보, 경조사, 정정 청구, 뉴스레터 구독) | 신문사 | 수탁자(처리 위탁) | 신문사 처리방침 템플릿에 "수탁자: 플랫폼 운영사, 위탁 업무: 사이트 운영·데이터 보관" 기본 기재. 신문사 이용약관에 위탁 계약 조항(법무 확인) |
| 독자 로그인 계정(이메일, 제공자 식별자) | 플랫폼 운영사(공통 계정, D-16) | 처리자 | 플랫폼 처리방침. 신문사는 자기 `readers` 행만 본다 |
| 편집국 계정·결제 정보 | 플랫폼 운영사 | 처리자 | 플랫폼 처리방침 |
| 운영자 접근 | - | - | 독자 개인정보는 신문사가 허용한 지원 열람(24시간, 사유)만, 감사 기록(NW-F-062) |

### 6.3 수집 항목·목적·보존·암호화·삭제

| 항목 | 내용 |
|---|---|
| 수집 항목(편집국) | 이메일, 표시 이름, 비밀번호 해시(Supabase Auth), 역할, 등록증 파일, 발행인 연락처. 로그인 제공자 식별자: Stage B부터 Google 계정 식별자·이름·프로필 이미지 URL, C 채택 시 카카오 사용자 식별자·닉네임·프로필 이미지(비즈 앱이면 이메일), 네이버 고유 id·이메일·이름(`docs/products/_platform-core/AUTH_ROADMAP.md:208`, `:242`, `:293-295`) |
| 수집 항목(독자) | Stage B: 이메일(매직 링크), Google 계정 식별자·이름·프로필 이미지 URL. C1: 카카오 사용자 식별자·닉네임·프로필 이미지·(비즈 앱) 이메일. C2: 네이버 고유 id·이메일·이름. 공통: 동의 기록(약관·처리방침 버전, 만 14세 이상 확인, 뉴스레터·야간 수신 동의 시각), 댓글 표시명, 결제 정보(Toss가 보관, 우리는 주문 id·금액·마스킹 번호만) |
| 수집 항목(비회원) | 제보·투고 연락처(선택·투고 필수), 정정 청구인 이름·연락처, 경조사 신청자 연락처·당사자 정보, 업소 사업자등록번호·연락처, 접속 IP 해시(일 단위 솔트, 원문 저장 안 함) |
| 목적 | 기사 제공, 독자 서비스(댓글·뉴스레터·후원), 제보 취재, 정정 청구 처리(법정 의무), 광고 집행, 부정 이용 방지 |
| 보존 | 5장 보존 행. 독자 탈퇴 시 30일 유예 후 그 신문사 `readers` 행과 연결 데이터 삭제(댓글은 "탈퇴한 독자"로 익명화, 제안). 결제 기록은 전자상거래법상 5년(적용 조항 미확인) |
| 암호화 대상 | 신문사 Toss 키·웹훅 시크릿·외부 광고망 키는 `core.encrypted_credentials`(AES-256-GCM). 제보 연락처·정정 청구인 연락처는 컬럼 암호화(제안: 취재원 보호). 본문은 Supabase 저장 암호화 |
| 삭제 절차 | 독자: soft delete → 30일 → purge. 신문사: 해지 → 90일 → `purge_organization` + Storage 폴더 삭제(`docs/products/_platform-core/SECURITY_BASELINE.md:191-201`) |
| 제3자 제공·국외 이전 | 상용 LLM(Anthropic, OpenAI, Google, OpenRouter)과 ElevenLabs: 신문사(publisher·editor)가 `set_ai_cross_border_ack`로 동의한 경우에만 기사 초안·보도자료·채팅 메시지·오디오 기사 본문을 보낸다. 독자 개인정보·제보 원문·댓글·인터뷰 음성은 상용 제공자로 보내지 않는다. Toss(결제), 메일 발송 제공자(미정, 미확인). 처리방침에 제공자·항목·국가·보유 기간 표 |
| 약관·고지 | 플랫폼 이용약관(신문사용), 신문사 독자 이용약관 템플릿, 처리방침(플랫폼·신문사 템플릿), 청소년보호정책 템플릿, 사업자 정보 하단 표시 |

### 6.4 AI·음성 고지와 오픈소스 강제 범위

| 항목 | 규칙 | 근거 |
|---|---|---|
| 오픈소스 강제 | `news.moderation`(댓글), `news.stt`(인터뷰·음성 질문)는 `force_open_source=true`. 제보함 원문은 어떤 AI 기능의 입력으로도 쓰지 않는다 | `docs/products/_platform-core/SECURITY_BASELINE.md:279-307` "개인정보" 행 |
| 녹음 고지 | 첫 녹음 전 목적·원본 미저장·상용 제공자 미사용·취재원 동의는 기자 책임을 고지, `voice.notice_ack`(고지문 버전) 감사. 원본을 저장하지 않으므로 `voice_jobs.consent_*`는 비운다 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:85-95` |
| AI 생성 표시 | AI 보조 기사 하단 문구(D-9), 오디오 기사 첫머리와 플레이어 "AI 음성", 채팅 답변 "AI가 생성한 답변", 제목·요약·교정 카드 "AI 제안". AI 이미지 생성 기능은 제공하지 않는다(보도사진 신뢰, 제안) | AI기본법, 언론계 준칙 |
| AI 대화 규칙 | 사실 단정 추가 금지, 보도자료에 없는 인용문·수치 생성 금지, 선거 여론조사 수치 생성 금지, 실존 인물 사칭 금지, 자료 안 지시 무시(프롬프트 인젝션) | `docs/products/_platform-core/SECURITY_BASELINE.md:279-307` |
| 미성년자 | 독자 가입 만 14세 이상. 청소년보호책임자 표시는 6.1절 | 개인정보보호법 |

### 6.5 금지 문구

| 대상 | 금지 | 대신 |
|---|---|---|
| 마케팅·랜딩·영업 자료 | 가상 후기(존재하지 않는 신문사 대표 추천사·평점), 미검증 고객 수·사용 매체 수 등 허위 수치("전국 300개 신문사가 선택"), "포털 입점 보장", "네이버 뉴스 검색제휴 통과 보장", "100% 노출", "구글 뉴스 상위 노출", "지원사업 선정 보장", "과태료 걱정 끝", "법적 책임 없음", "AI가 기사를 대신 씁니다", "기자 없이 신문 발행" | 기능 설명("주간 자체기사 비율을 자동으로 계산합니다"), 실제 측정값만, 심사 결과는 포털·재단 판단이라는 고지 |
| 타사 표기 | 엔디소프트·언론진흥재단·네이버·카카오·구글 로고나 이름을 제휴·인증처럼 쓰기, 경쟁사 비방 | 사실 비교(공개 가격·기능, 확인일 표기) |
| AI 생성 콘텐츠 | 낚시성 제목 금칙어("충격", "경악" 등 목록), 원문에 없는 인용문·수치, 여론조사 수치, "AI 탐지 회피", "표절 없음 보장" | 원문 대조표, 사람 승인 |
| 광고 운영 | 라벨 없는 광고, 기사로 위장한 광고, 선정·사행성 소재 | NW-F-032 라벨, 업종 차단 목록 |
| 제휴 링크 | 해당 없음(affiliate 모듈 미사용). 기사형 광고는 신문법 라벨로 처리 | - |
| 규제 특례 | 의료·금융 특화 없음. 미성년자(청소년보호책임자·만 14세), 선거(공직선거법)는 위 표 | - |

## 7. KPI

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| 유료 신문사 수 | 30곳(제안: SaaS 초기 게이트) | 유료 플랜 엔타이틀먼트 활성 조직 수 | 출시 후 6개월 |
| 체험 → 유료 전환율 | 30%(제안) | 체험 종료 신문사 중 14일 안 유료 결제 비율 | 코호트 월 |
| 첫 기사 게시 시간 | 승인 후 24시간 안 70%(제안) | `approve` 감사 시각 → 첫 `published` | 월 |
| 주간 활성 신문사 | 유료 신문사의 85%가 주 5건 이상 게시(제안) | 주별 `published` 건수 | 주 |
| 자체기사 비율 경고 회복 | 경고 주의 다음 주 30% 이상 회복 60%(제안) | `compliance_weekly_stats` | 분기 |
| 정정 청구 SLA 준수 | 3일 통지 100%, 7일 게재 100% | `correction_requests` 기한 대비 처리 시각 | 월 |
| 필수 게재사항 완료 | 공개 신문사 100% | `is_profile_complete` | 상시 |
| CWV 통과 | 테넌트의 90%가 p75 3개 지표 모두 통과(제안) | 실사용 측정(web-vitals) | 월 |
| 게시 → 홈 반영 | p95 60초 이하 | 게시 이벤트 → 캐시 무효화 완료 로그 | 주 |
| 뉴스레터 열람률 | 30% 이상(제안) | 발송 대비 열람 | 월 |
| 독자 가입 | 신문사당 월 신규 100명(제안) | `readers` 신규 행 | 월 |
| AI 초안 사용률 | 보도자료 기사의 50%가 초안 그래프 경유(제안) | `ai_assisted=true` `press_release` 비율 | 월 |
| AI 초안 수정률 | 게시본이 초안 대비 수정된 비율 90% 이상(제안: 사람 검수 확인) | 초안 revision 대비 게시 revision diff | 월 |
| 월 해지율 | 3% 이하(제안) | 해지 신문사 / 월초 유료 신문사 | 월 |
| 이관 성공률 | 기사 매칭 99%, 옛 URL 404 1% 미만(제안) | 이관 리포트 | 이관 건별 |

## 8. 열린 결정

| # | 항목 | 선택지 | 권고 | 근거 |
|---|---|---|---|---|
| D-1 | 제품 브랜드명 | (a) "로컬뉴스 클라우드" 확정 (b) 새 이름 | 상표 검색(미확인) 후 결정. 기존 언론사 제호와 혼동되는 이름 금지. 그전까지 가칭 | README 1장 |
| D-2 | 1차 DB | (a) 모놀리스 단독 Supabase 프로젝트 (b) 통합 DB(`2500_news.sql`) | (a). 독자 트래픽 격리, 독자 계정 풀 분리, 처리자·수탁자 경계 단순(README 5장). 모듈러 조각은 같은 도메인 모델로 유지 | `docs/products/_supabase-modular/ARCHITECTURE.md:31-46` |
| D-3 | 독자 로그인 도메인 | (a) 서브도메인 와일드카드 Redirect URL + 커스텀 도메인 활성화 때 관리 API로 `https://<host>/auth/callback` 자동 등록 (b) 중앙 로그인 도메인 `login.<플랫폼>` + 일회용 코드로 신문사 도메인에 세션 전달 | (a). 허용 목록 상한과 와일드카드 패턴 지원은 미확인이라 스파이크로 확인하고, 상한이 커스텀 도메인 수보다 작으면 (b). AUTH_ROADMAP은 와일드카드 지양(`:195`)이므로 플랫폼 소유 서브도메인 한정 예외로 기록 | `docs/products/_platform-core/AUTH_ROADMAP.md:195` |
| D-4 | 독자 결제 | (a) 신문사 자기 Toss 가맹 (b) 플랫폼 일괄 수납·정산(지급대행) | (a). (b)는 전자금융·지급대행 요건(미확인)과 정산 책임이 생긴다. (a)는 코어 Toss 흐름을 조직별 키로 쓰는 확장이 필요(코어 요청) | 확정 결정 4, 4.5절 |
| D-5 | 가격과 독자 결제 수수료 | 4.1절 제안(99,000 / 199,000 / 390,000원, 수수료 Starter 3%) | 체험 신문사 30곳 반응과 원가 실측 후 확정. 월 AI 크레딧은 4.3절 검산상 Starter가 빠듯하므로 실측 후 재조정 | `Price_Plans/local-news/PRICE_PLAN.md` |
| D-6 | 댓글 기본값 | (a) 기본 끔, 신문사가 켬 (b) 기본 켬 | (a). 임시조치·모더레이션 운영 부담과 선거 기간 위험을 신문사가 알고 켜게 한다 | 정보통신망법 44조의2 |
| D-7 | 검색 엔진 | (a) Postgres `pg_trgm` + `tsvector('simple')` (b) `pg_bigm`(Supabase 지원 미확인) (c) 외부 Meilisearch·Typesense | (a)로 시작, 신문사당 기사 10만 건 또는 p95 800ms 초과 시 (c)(P2) | 02장 |
| D-8 | 날씨·미세먼지·공고 외부 API | 기상청·에어코리아(공공데이터포털)·지자체 공고 API의 이용 조건·트래픽 한도·출처 표기 | 플랫폼 키 1개 + 서버 캐시 30분, 신문사별 호출 없음. 조건 확인(미확인) 전에는 NW-F-023 날씨 블록 비활성 | 날씨 블록 차별화(NW-F-023) |
| D-9 | AI 보도자료 초안 표시 문구와 자체기사 비율 규칙 | (a) AI 초안 기사는 `press_release` 고정, 비율 분모 포함·분자 제외 (b) 기자가 "추가 취재" 체크 + 본문 변경률 50% 이상이면 `original` 전환 허용 | (a)를 기본, (b)는 감사 기록과 함께 허용(변경률 50%는 제안). 표시 문구 제안: "이 기사는 보도자료를 바탕으로 AI 도구의 도움을 받아 작성됐으며 기자가 검수했습니다." 포털 심사 기준과의 관계는 미확인 | 6.1절, https://journalist.or.kr/news/article.html?no=60389 |
| D-10 | 기존 CMS 이관 범위·가격 | (a) Standard 이상 1회 무료(RSS·CSV·사이트맵), 엔디소프트 DB 직접 이관은 견적 (b) 전부 유료 | (a). 전환 비용이 국내 1위 사업자의 해자다. 엔디소프트 내보내기 형식은 미확인 | https://www.ndsoft.co.kr , Newspack 무료 이관(https://newspack.com/pricing/) |
| D-11 | 3D 히어로 | (a) 독자 사이트 미적용, 플랫폼 마케팅 랜딩만 선택 (b) 독자 사이트 적용 | (a). 확정 결정 15의 예외라 대표님 확인 필요. 뉴스 홈은 LCP·광고 밀도가 우선 | https://web.dev/articles/vitals |
| D-12 | 지역신문발전기금 연계 영업 | (a) 재단 문의 후 공급사 요건 확인, 영업 자료에 "지원 대상 가능성"만 표기 (b) 연계 없이 판매 | (a). SaaS 이용료의 사업비 인정 여부·공급사 요건 미확인. 제8차 계획의 클라우드 웹호스팅 비용 지원이 근거. 지원사업 리포트를 Standard로 내릴지도 함께 정한다 | https://kbmaeil.com/article/20260731500057 , https://kbmaeil.com/article/20260917500737 |

### 8.1 인증 단계 결정 (확정 결정 22)

단계 규격 정본은 `docs/products/_platform-core/AUTH_ROADMAP.md`. 이 제품은 편집국과 독자가 서로 다른 단계 우선순위를 가지므로 AUTH_ROADMAP 8장 매트릭스에 행 추가를 요청한다(2장 표).

| # | 항목 | 선택지 | 권고 | 닫는 시점 | 근거 |
|---|---|---|---|---|---|
| D-13 | 카카오 이메일 정책(독자 C1) | (a) 비즈 앱 전환 후 `account_email` 필수 동의 (b) 이메일 없이 허용(뉴스레터·후원 전 연락 이메일 입력) | (a). 독자 뉴스레터·영수증이 이메일 기반이고 Google 독자와 계정 연결이 된다 | G2 판정 전 | `docs/products/_platform-core/AUTH_ROADMAP.md:245-250` |
| D-14 | 네이버 연동 경로(독자 C2) | (a) `custom:naver` (b) 서버 브리지 + 코어 `auth_identity_links` | 스파이크(0.5일) 결과로 결정, `NAVER_AUTH_PATH`와 `[DECISION]` 기록. 브리지는 신문사 도메인마다 콜백이 필요해 D-3과 함께 검증 | C2 작업 첫 단계 | `:275-297` |
| D-15 | 독자 이메일 로그인 방식 | (a) 매직 링크(비밀번호 없음) (b) 이메일 + 비밀번호 (c) 이메일 없이 소셜만 | (a). 50대 이상 지역 독자의 비밀번호 생성 부담을 없앤다. 다만 AUTH_ROADMAP 1장은 매직링크를 범위 밖으로 둬서(`:32`) 이 제품 독자 경로만 예외 승인이 필요하다. 편집국은 이메일 + 비밀번호(초대 수락) 유지 | G1 판정 전 | `:31-32` |
| D-16 | 독자 공통 계정의 처리자와 동의 화면 브랜드 | (a) 로그인 계정은 플랫폼이 처리자, 신문사별 독자 정보는 신문사 처리자·플랫폼 수탁자. 동의 화면은 플랫폼 브랜드 (b) 신문사별 독자 계정 분리(같은 사람이 신문마다 가입) | (a). AUTH-D1과 같은 이유로 제공자 앱 1세트. 독자에게 "플랫폼 계정으로 로그인" 안내 문구 필요. 법무 확인 필요. 전용 DB(Enterprise)만 자기 브랜드 | G1 판정 전 | `develop/_shared/auth/README.md:18`, 6.2절 |
| D-17 | 편집국 카카오·네이버 | (a) 채택 안 함(P2 선택 유지) (b) 독자 C 작업과 같은 웨이브에 편집국 호스트도 켬 | (a). 초대제 업무 도구이고 영수증·세금계산서가 이메일 기반 | G2 후 | `docs/products/_platform-core/AUTH_ROADMAP.md:330` |
| D-18 | 독자 가입 시 코어 개인 조직 생성 | (a) 코어 동작 그대로(독자마다 `is_personal=true` 조직 1행, 엔타이틀먼트 없음) (b) 코어 요청: 독자 가입 표시가 있으면 개인 조직 생략 | (a)로 시작. 독자 수십만 명 규모에서 조직 행 증가가 문제가 되면 (b)를 코어에 요청 | 공개 베타 후 | `docs/products/_platform-core/MONOLITH_CORE_LITE.sql:241-252` |
