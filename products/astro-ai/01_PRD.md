# 01 PRD: 신비로운AI

표기: "제안"은 원본 문서와 리뷰에 근거가 없어 이 문서가 새로 정한 값이다. 근거 경로의 `AA/`는 `Astro AI/기획안/`, `FD/`는 `FortuneDocs/`다.

2026-10-13 개정: 확정 결정 13~17(`docs/products/00_MERGE_ANALYSIS.md:21-25`)에 따라 AI 계층(RAG, LangGraph, 제품 지식 위키, Dify 채팅), 음성(음성 대화, 리딩 낭독), 상용/오픈소스 모델 이원화와 국외 이전 동의, 3D 히어로를 MVP에 넣었다. 설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `docs/products/_design-guide/HERO_3D.md`, `DESIGN_SYSTEM.md`이고 이 문서는 제품 요구만 정한다.

## 1. 페르소나와 핵심 과제

| 페르소나 | 상황 | 목표 | 좌절 |
|---|---|---|---|
| 서윤(31, 마케터) | 이직을 고민 중. 점집은 부담스럽지만 운세는 궁금하다(`docs/reviews/Astro_AI.md:8`) | 자기 기질과 앞으로 10년 흐름을 한 번에 정리한 리포트를 갖고 싶다 | 조회형 앱은 화면을 닫으면 끝이고, 해석이 "고향을 떠나 고생한다" 같은 옛날 말투다(`FD/PRD.MD:61`) |
| 민호(38, 회사원, 두 아이 아빠) | 부모님 생신 선물과 가족 사주를 한곳에 정리하고 싶다(`FD/PRD.MD:50`) | 가족 4~5명의 리포트를 보관함에 두고 필요할 때 다시 받는다 | 가족의 생년월일시를 어디에 맡겨도 되는지, 삭제는 되는지 불안하다(`docs/reviews/FortuneDocs.md:50`) |
| 지아(26, 대학원생) | 진로 질문 하나를 타로로 빠르게 보고 싶다 | 카드 3장을 직접 뽑고 질문에 대한 해설을 받는다 | 결과가 너무 길거나, 크레딧이 빠졌는데 실패하면 돌려받을 수 있는지 모른다(`docs/reviews/Astro_AI.md:50`) |

| 핵심 과제 | 성공 조건 |
|---|---|
| 정확한 원국 | 입춘·절기 기준 년·월주, 자시 방식, 생시 모름, 서머타임, 경도 보정을 반영한 엔진이 골든 테스트 100건을 모두 통과한다(`docs/reviews/FortuneDocs.md:59`) |
| 소장할 만한 결과물 | A4 책자형 PDF(사주 약 10쪽, 타로 약 8쪽, 통합 약 18쪽, `AA/공통/GEO.md:154-156`)를 1분 안팎에 받고 언제든 다시 내려받는다 |
| 돈과 개인정보의 신뢰 | 실패하면 자동 환불되고, 제3자 정보는 동의 후에만 저장되며 즉시 삭제할 수 있다 |

## 2. 범위: MVP와 Phase

| 기능 | 범위 | 근거 |
|---|---|---|
| 로그인(이메일 + Google, 이후 카카오·네이버) | MVP 개발은 Mock(Stage A, 로컬 시드 계정), 공개 베타 전 Google + 이메일(Stage B, P0), 카카오·네이버는 G2 후(Stage C, C1 카카오 P1, C2 네이버 P1). 단계 정의는 `docs/products/_platform-core/AUTH_ROADMAP.md` 0장, 8장 | `docs/products/00_MERGE_ANALYSIS.md:313`, `:30`(확정 결정 22) |
| 프로필 보관함(본인, 가족, 지인) + 제3자 동의 | MVP | `docs/products/00_MERGE_ANALYSIS.md:315` |
| 만세력 엔진(로컬 절기 테이블) + 원국 프리뷰 + 대운 타임라인 | MVP | `docs/products/00_MERGE_ANALYSIS.md:322-325` |
| 사주 리딩, 타로 3카드 리딩, 통합 리딩 | MVP | 확정 결정 7, `docs/products/00_MERGE_ANALYSIS.md:327-328` |
| A4 책자형 PDF(WeasyPrint 공용 렌더), 테마 2종, 테마 변경 재생성 | MVP | `docs/products/00_MERGE_ANALYSIS.md:338-341` |
| 이메일 발송(서명 URL) + 대시보드 Realtime | MVP | `docs/products/00_MERGE_ANALYSIS.md:349-351` |
| 크레딧팩 4종 Toss 일반결제 | MVP | 확정 결정 7, `docs/products/00_MERGE_ANALYSIS.md:360-361` |
| 실패 자동 환불, 관리자 수동 환불 | MVP | `docs/products/00_MERGE_ANALYSIS.md:363` |
| 최소 어드민(유저 조회, 결제·환불, 크레딧 조정, 발송 모니터) | MVP | `docs/products/00_MERGE_ANALYSIS.md:371` |
| 랜딩 + GEO(JSON-LD, `/llms.txt`), 비회원 Live Demo(LLM 미사용) | MVP | `docs/products/00_MERGE_ANALYSIS.md:372-375` |
| 리딩 생성 LangGraph 그래프 `astro.reading`, 명리·타로 해설집 RAG | MVP | 확정 결정 13(`docs/products/00_MERGE_ANALYSIS.md:21`) |
| AI 채팅(내 사주 질문, 용어 설명), 제품별 Dify 채팅 앱 | MVP | 확정 결정 13, 14(`docs/products/00_MERGE_ANALYSIS.md:21-22`) |
| 사주 용어·해석 위키(제품 지식 위키, 공개 열람) | MVP | 확정 결정 13, `docs/products/_platform-core/LLM_WIKI.md:37-47` |
| 음성 대화, 리딩 낭독(TTS) | MVP | 확정 결정 16(`docs/products/00_MERGE_ANALYSIS.md:24`) |
| 상용/오픈소스 모델 이원화, 온보딩 국외 이전 동의 | MVP | 확정 결정 17(`docs/products/00_MERGE_ANALYSIS.md:25`), `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| 랜딩 3D 히어로(혼천의 → 펼쳐지는 책) | MVP | 확정 결정 15(`docs/products/00_MERGE_ANALYSIS.md:23`), `docs/products/_design-guide/HERO_3D.md:81` |
| 비회원 AI 상담(랜딩 채팅) | Phase 2 | 제안: 비로그인 상담은 운영자 예산과 강한 레이트 리밋이 필요하다(`docs/products/_platform-core/AI_ARCHITECTURE.md:130`). MVP의 비회원 체험은 LLM 없는 Live Demo로 둔다 |
| 사용자 보이스 선택, 보이스 클로닝 | Phase 2 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:80` |
| 구독 플랜(Basic/Pro/Master) + 빌링키 + 연간 20% 할인 | Phase 2 | `docs/products/00_MERGE_ANALYSIS.md:359`, `:362` |
| 궁합(2인), 연간 운세(12섹션) | Phase 2 | `docs/products/00_MERGE_ANALYSIS.md:329-330` |
| 카카오 알림톡 | Phase 2 | `docs/products/00_MERGE_ANALYSIS.md:350` |
| ePub | Phase 2 | `docs/products/00_MERGE_ANALYSIS.md:339` |
| 템플릿 마켓플레이스, 크리에이터 대시보드 | Phase 3 이후(현 단계 폐기) | `docs/products/00_MERGE_ANALYSIS.md:367-368`, 확정 결정 7 |
| 멀티버티컬, 기업 API, 다국어 | 폐기(현 단계) | `docs/products/00_MERGE_ANALYSIS.md:376-378` |

## 3. 기능 요구사항과 수용 기준

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| AS-F-001 | 가입/로그인 | 통합 | 이메일+비밀번호, Google OAuth(Supabase Auth). 가입 폼은 `signup_app='astro'`를 보낸다. 매직링크와 Apple은 넣지 않는다. 인증 단계(확정 결정 22): A(MVP 개발) 로컬 시드 계정 Mock 로그인만. 쿠키 역할 Mock 금지, 개발용 로그인은 `AUTH_ROADMAP.md` 2장의 로컬 시드 계정만(배포 환경 404). B(공개 베타 전, P0) Google + 이메일 가입·인증·비밀번호 재설정. C1 카카오, C2 네이버(G2 후, P1). OAuth 가입은 `signup_app`을 보낼 수 없어 콜백이 `bootstrap_app_for_org`를 1회 호출한다 | 가입 직후 `session_context('astro')`가 `entitled=true`, `plan_code='starter'`를 돌려준다. A: `owner` 페르소나 Mock 로그인으로 같은 결과. B: `AUTH_ROADMAP.md` 5.3절 B-1~B-6. C1: 7.1.3절 C1-1~C1-5. C2: 7.2.4절 C2-1~C2-6 | `docs/products/_platform-core/CORE_SPEC.md:83`, `docs/products/00_MERGE_ANALYSIS.md:313`, `docs/products/_platform-core/AUTH_ROADMAP.md` 8장 |
| AS-F-002 | 환영 크레딧 30 | 신규(공백 8) | 이메일 인증 완료 또는 Google 로그인 확인 뒤 서버가 `grant_credits(30, 멱등 키 signup:<org>:astro)`를 1회 호출한다(제안: 가입 트리거 시점은 이메일 인증 전이라 반복 수령을 막지 못함). Stage C부터 카카오·네이버 로그인 확인 뒤에도 같은 규칙이다(2026-10-14, 확정 결정 22). 같은 IP 해시에서 하루 가입 3회 초과 시 지급 보류(제안) | 미인증 계정 잔액 0, 인증 후 30. 같은 조직에 2번 호출해도 원장 1행. Stage A: `welcome_pending` 페르소나(05장 10절) 첫 Mock 로그인 뒤 30, 재로그인 뒤에도 원장 1행 | `AA/공통/PRD.md:31`, `docs/reviews/FortuneDocs.md:51`, `docs/products/00_MERGE_ANALYSIS.md:453` |
| AS-F-003 | 프로필 보관함 CRUD | 유지(FD) | 대상: 호칭(20자), 관계(본인/가족/연인/친구/기타), 성별(필수), 생년월일, 생시 또는 "모름", 양력/음력, 윤달, 자시 방식, 출생지(시·군 목록 → 경도). 조직당 본인 1명, 전체 20명(제안, `features.max_subjects`) | 21번째 등록은 409. 성별 없이 저장 불가. 본인 2명 등록 불가 | `FD/PRD.MD:50`, `:55`, `docs/reviews/FortuneDocs.md:41-42` |
| AS-F-004 | 제3자 정보 동의 | 신규(공백 6) | 관계가 본인이 아니면 "이 사람에게 정보 제공 동의를 받았거나 법정대리인입니다" 체크와 약관 버전을 저장(`subjects.third_party_consent_at`, `consents.kind='third_party_birth'`) | 체크 없이 가족 등록 시 400. DB 제약(`subjects_consent_check`)도 거부 | `docs/reviews/FortuneDocs.md:50`, `docs/products/00_MERGE_ANALYSIS.md:420` |
| AS-F-005 | 생년월일시 암호화 | 디벨롭 | 이름과 생년월일시(원문 입력)는 서버에서 AES-256-GCM으로 암호화해 `*_ciphertext`에만 저장. 키는 환경변수 `ASTRO_PII_KEY_V<n>` | DB 덤프에 실명·생년월일 평문 0건. 사용자 세션으로 암호문 컬럼 SELECT 시 42501 | `AA/공통/PRD.md:117`, `docs/products/_platform-core/SECURITY_BASELINE.md:12장` |
| AS-F-006 | 만세력 엔진 | 디벨롭 | `packages/saju-engine` 순수 함수. 입춘 기준 년주, 절입 시각 기준 월주, 일주(율리우스일), 시주(일간 기준), 자시 방식 2종, 생시 모름(삼주), 한국 서머타임(1948~1960, 1987~1988 해당 기간), 진태양시(경도 보정, 기본 127.0), 음력·윤달 변환(1900~2100 테이블), 십신, 오행 점수, 대운 순역행과 대운수 | 골든 테스트 100건(절기 경계 ±1시간 30, 입춘 경계 15, 자시 20, 서머타임 10, 윤달 10, 일반 15) 전부 통과. KASI 대조 배치에서 불일치 0 | `docs/reviews/FortuneDocs.md:40-42`, `:97`, `docs/products/00_MERGE_ANALYSIS.md:322`, `:415` |
| AS-F-007 | 원국 프리뷰 | 유지(FD) | 입력 즉시 4주 8자를 오행 색 카드로 표시. 엔진을 브라우저에서 실행(입력이 서버로 가지 않음). 金은 테두리형, 水는 밝은 테두리로 다크 배경 대비 확보 | 입력 변경 후 100ms 안에 갱신. 대비 3:1 이상(비텍스트 요소) | `FD/PRD.MD:56`, `docs/reviews/FortuneDocs.md:55` |
| AS-F-008 | 대운 타임라인 | 유지(FD) | 대운 8~10구간(10년 단위), 현재 구간 강조, 읽기 전용 | 대운 시작 나이가 엔진 결과와 같다 | `FD/PRD.MD:80` |
| AS-F-009 | 사주 리딩 | 통합 | 15cr. 6장 구성: 타고난 기질(일간), 오행 균형과 보완 습관, 일과 재능(십신), 관계와 소통, 대운 흐름, 올해의 흐름과 질문 답변. 본문 2,500자 이상, 호칭 3회 이상 | 생성물 zod 검증 통과, 글자 수와 호칭 횟수 충족, 금지 표현 0건 | `AA/공통/PRD.md:40`, `:71-72`, `docs/reviews/FortuneDocs.md:103` |
| AS-F-010 | 타로 3카드 리딩 | 유지(AA) | 20cr. 메이저 아르카나 22장, 정/역방향. 펼친 카드에서 3장 선택(과거/현재/미래 자리, 제안). 섞기와 정역 방향은 브라우저 `crypto.getRandomValues`, 서버는 0~21 중복 없음만 검증. 4장 구성, 2,000자 이상(제안) | 같은 카드 2장 선택 불가. 질문 200자 초과 불가 | `AA/공통/PRD.md:41`, `:67`, `AA/대시보드/PRD_DASHBOARD.md:28-29` |
| AS-F-011 | 통합 리딩 | 유지(AA) | 30cr. 사주 6장 + 타로 연결 2장, 4,000자 이상 | 사주·타로 각 수용 기준 + 4,000자 | `AA/공통/PRD.md:42`, `:68`, `:72` |
| AS-F-012 | 리딩 상태 머신 | 신규(공백 4) | `queued → generating → rendering → completed`, `failed`, `canceled`. 전이는 DB 트리거가 강제. 실패하면 `fail_job`이 자동 환불, 대기 중 취소는 `cancel_reading`이 환불 | 생성 실패 리딩 100%가 환불 원장 행을 가진다. 원장 drift 0 | `docs/reviews/Astro_AI.md:50`, `:73`, 05장 3절 |
| AS-F-013 | PDF 렌더 | 통합 | 공용 WeasyPrint 서비스(`services/render-weasyprint`)로 A4 렌더. Noto CJK 포함, `url_fetcher`는 자체 Storage만 | 한글·한자 누락 0. 외부 URL 참조 HTML은 렌더 거부 | `docs/products/_platform-core/SHARED_MODULES.md:264-288` |
| AS-F-014 | 테마 | 유지(AA) | MVP 2종(`mystical-dark`, `oracle-gold`). `ThemeConfig → CSS 변수` 변환기 1개. 사용자 업로드 테마 없음 | 같은 리딩을 두 테마로 렌더했을 때 본문 텍스트가 같다 | `docs/products/00_MERGE_ANALYSIS.md:341`, `docs/reviews/Astro_AI.md:87` |
| AS-F-015 | 테마 변경 재생성 | 유지(AA) | 5cr. 본문은 다시 생성하지 않고 렌더만 새로 한다(`reading_renders`) | 재생성 후 이전 PDF도 히스토리에서 받을 수 있다 | `AA/공통/PRD.md:45` |
| AS-F-016 | PDF 보관과 재다운로드 | 신규(공백 9) | PDF와 본문은 사용자가 삭제하거나 탈퇴 후 30일이 지날 때까지 보관(제안: 소장형 정체성). 다운로드는 7일 서명 URL을 요청 때마다 새로 발급하며 무료. 원본 "24시간 삭제"는 적용하지 않는다 | 생성 30일 뒤에도 다운로드 성공. 발급 URL은 7일 뒤 만료 | `docs/reviews/Astro_AI.md:55`, `docs/products/00_MERGE_ANALYSIS.md:343`, `:421` |
| AS-F-017 | 이메일 발송 | 유지(AA) | Resend. PDF 첨부가 아니라 서명 URL 링크(제안: 첨부는 메일함 보존 기간을 통제할 수 없음). outbox 재시도 5분 간격 3회. 설정에서 이메일 발송 끌 수 있음 | 3회 실패 시 `dead`, 어드민 모니터에 표시, 사용자 재발송 가능(일 3회, 제안) | `AA/공통/PRD.md:82`, `:86`, `docs/reviews/Astro_AI.md:85` |
| AS-F-018 | 진행률 | 디벨롭 | `readings` 행 `postgres_changes` 구독(RLS 적용). broadcast 채널 없음 | 다른 조직 사용자는 진행 이벤트를 받지 못한다 | `docs/reviews/Astro_AI.md:60`, `:84` |
| AS-F-019 | 크레딧팩 결제 | 디벨롭 | Toss 결제창 → successUrl → 서버 confirm → `confirm_payment_order` 금액 대조 → 멱등 지급. 웹훅은 상태 동기화만 | 같은 결제를 2번 confirm해도 지급 1회. 금액 변조 시 지급 0 | `docs/reviews/Astro_AI.md:53`, `:75`, `docs/products/_platform-core/CORE_SPEC.md:215-226` |
| AS-F-020 | 결제 환불 | 유지(AA) + 신규 | 어드민 환불 모달(사유 필수) → Toss 취소 API → 미사용 크레딧 조정 → 감사 로그 | 사유 없이 환불 불가. 환불 1건당 `audit_log` 1행 | `AA/대시보드/PRD_DASHBOARD.md:124`, `docs/products/00_MERGE_ANALYSIS.md:363` |
| AS-F-021 | 대시보드 | 통합 | 홈, 보관함, 리딩 시작, 히스토리(발송 상태 포함), 크레딧, 설정 | 03장 1절 화면이 모두 서버 가드 뒤에 있다 | `docs/products/00_MERGE_ANALYSIS.md:370` |
| AS-F-022 | 최소 어드민 | 디벨롭 | `platform_admin`만. 유저 조회, 결제·환불, 크레딧 지급(사유 필수), 발송 모니터·강제 재발송. 모든 쓰기는 서버에서 역할 재검증 + 감사 | 일반 사용자의 `/api/admin/*` 호출은 403 | `docs/reviews/Astro_AI.md:52`, `:102`, `:131` |
| AS-F-023 | 랜딩 + GEO | 유지(AA) | 03장 4절 구성. JSON-LD는 WebSite, Product(크레딧팩), FAQPage만. `aggregateRating`, `Review`는 실제 후기 수집 전까지 넣지 않음 | 빌드 산출물에 `aggregateRating` 문자열 0건 | `docs/reviews/Astro_AI.md:54`, `:76` |
| AS-F-024 | 비회원 Live Demo | 디벨롭 | 생년월일시 입력 → 엔진으로 일간·오행 강약 기반 키워드 3개(LLM 미사용). IP 해시당 하루 3회(`core.rate_limit_hit`). 입력은 저장하지 않음 | 4번째 호출 429. LLM 호출 로그 0 | `AA/랜딩페이지/CLAUDE_LANDING.md:256-277`, `docs/reviews/Astro_AI.md:86`, `:133` |
| AS-F-025 | 레이트 리밋 | 신규(공백 8) | 리딩 생성 조직당 10회/분, 진행 중 리딩 조직당 3건(제안: 단가 30cr 작업의 동시 남용 방지), 다운로드 URL 발급 60회/시간 | 초과 시 429와 재시도 시각 | `docs/products/_platform-core/SECURITY_BASELINE.md:8장` |
| AS-F-026 | 보관함 대상 삭제 | 신규(공백 6) | 대상 삭제 시 그 대상의 리딩, 렌더, 발송 기록, PDF 파일, 낭독 음성 파일(AS-F-034)을 함께 지운다. 동의 기록은 대상 참조만 끊고 남긴다(증빙) | 삭제 후 Storage에서 해당 PDF 0개(24시간 내), 리딩 0행 | `docs/reviews/FortuneDocs.md:50` |
| AS-F-027 | 탈퇴와 데이터 내보내기 | 신규(공백 6) | 탈퇴 = 조직 soft delete → 30일 유예 → `purge_organization` + Storage 삭제. 내보내기 = 보관함과 리딩 본문 JSON + PDF 링크 | 유예 중 로그인 시 복구 안내. 30일 뒤 조직 행 0 | `docs/products/_platform-core/SECURITY_BASELINE.md:12장` |
| AS-F-028 | 프롬프트 가이드 | 신규(공백 7) | 현대적 재해석 사전, 장 구성과 분량, 금지 표현(5장 3절과 6절), 수치는 엔진 입력만 사용, 이름은 `{{호칭}}` 토큰 | 사전 항목 30개 이상(제안), 금지 표현 검사 규칙과 일치 | `FD/PRD.MD:61`, `docs/reviews/FortuneDocs.md:47`, `:103` |
| AS-F-029 | 리딩 생성 그래프 `astro.reading` | 디벨롭 | FastAPI(`apps/api`)의 LangGraph 그래프 5노드: `chart`(명식 계산: `packages/saju-engine`이 Route Handler에서 결정적으로 계산해 `readings.chart`에 저장한 값을 그대로 주입하고 `engine_version`·스키마를 검증. LLM 없음) → `retrieve`(해설집·위키 검색) → `draft`(장별 리딩 초안, 라우팅 기능 `astro.reading`) → `compliance`(금지 문구·수치·출력 스키마 검사, 걸린 장만 1회 재작성) → `assemble`(책자 섹션 조립, 면책·AI 생성 표시 포함). 워커가 잡 토큰으로 실행을 요청하고, 결과 저장과 PDF 렌더는 워커가 한다(02장 4절). 용신·격국은 판정하지 않는다(D-10) | 리딩 1건당 `core.ai_runs` 1행(graph=`astro.reading`, `job_id`, `credit_ledger_id`=리딩 원장)과 노드별 `ai_run_steps`. 본문의 수치가 엔진 값과 100% 일치. 용신·격국 판정 문형 검출 0. 그래프 최종 실패 시 리딩 `failed` + 환불 원장 1행 | `docs/products/_platform-core/AI_ARCHITECTURE.md:109-119`, `docs/reviews/FortuneDocs.md:47`, D-10 |
| AS-F-030 | 명리·타로 해설집 RAG | 신규 | 운영자가 직접 쓴 해설집(천간·지지·십신·오행·대운 해설, 메이저 아르카나 22장 정·역 해설)을 운영자 조직의 컬렉션 `astro-knowledge`(kind `rag`)에 색인한다. 임베딩은 오픈소스(`astro.knowledge`, 대체 없음, 02장 5절). 조직 구분 없는 제품 공통 지식이라 Dify에는 외부 지식 API(`/dify/retrieval`)로만 노출하고, 그래프와 `/tools/answer`는 FastAPI 안에서 같은 컬렉션을 검색한다 | 평가셋 40문항(제안)에서 상위 8개 안 정답 청크 재현율 0.8 이상(제안). 외부 지식 API 응답에 사용자 조직 데이터 0. 원고 항목마다 작성자·검수일 메타데이터 | `docs/products/_platform-core/AI_ARCHITECTURE.md:58-66`, `:94-107` |
| AS-F-031 | 사주 용어·해석 위키 | 신규 | 해설집을 원본으로 위키 ingest가 `concept`(용어), `topic`(해석 주제), `index` 페이지를 만든다(운영자 조직, app `astro`). 새 페이지는 `draft`로 만들고 운영자가 검수해 `published`로 바꾼다. 운영자가 고친 블록은 사람 소유로 표시해 ingest가 덮어쓰지 않고, 저장은 `expected_version` 낙관적 잠금, 문서 1건당 갱신 페이지는 5개까지(`docs/products/_platform-core/LLM_WIKI.md:30-31`, `:47`). 공개 화면 `/wiki`에서 누구나 읽는다. 주 1회 lint(모순, 낡음, 고아, 깨진 링크, 출처 없는 주장) | 공개 화면에 `draft` 페이지 0. 페이지마다 "출처" 절(해설집 문서 id)과 "AI가 정리하고 운영자가 검수한 문서" 표시. 출시 시 lint 깨진 링크 0 | `docs/products/_platform-core/LLM_WIKI.md:12-47` |
| AS-F-032 | AI 채팅(내 사주 질문, 용어 설명) | 신규 | 로그인 사용자 전용. 대시보드 채팅 패널과 리딩 상세의 "이 리포트에 대해 묻기". 리딩에서 시작한 대화는 그 리딩의 원국 스냅샷과 본문을 근거로 답한다(대화 매핑 경로, 조직 데이터). 용어 설명은 해설집·위키를 근거로 한다. 스트리밍, 답변마다 출처, "AI가 생성한 답변" 표시. 메시지 1,000자, 대화당 50턴(제안). 크레딧은 턴 선차감 후 정산(4.7절) | 답변에 출처 1개 이상 또는 "근거 자료를 찾지 못했습니다" 표시. 응답이 전달되지 않은 턴은 선차감 전액 환불. 잔액 부족 402(`CR001`). Dify 장애 시 대체 경로(`/tools/answer-direct`)로 답한다. 다른 사용자의 대화 id로 이어 쓰면 404 | `docs/products/_platform-core/AI_ARCHITECTURE.md:44-56`, `:121-130` |
| AS-F-033 | 음성 대화 | 신규 | 채팅 패널의 마이크 버튼(누르고 말하기). 발화 최대 60초(제안). STT(`voice_chat`, 오픈소스 우선) → 변환 텍스트 미리보기·수정 → 전송 → 답변 → "읽어 주기"(TTS, ElevenLabs 우선, 자동 재생 기본 꺼짐). 녹음 원본은 저장하지 않는다. 첫 사용 때 음성 처리 고지를 확인받는다(`consents.kind='voice_processing'`) | 60초가 되면 녹음 자동 중지. 이 제품의 `voice_jobs.store_audio=false` 100%. 마이크 권한을 거부해도 텍스트 채팅 정상. 고지 확인 없이 STT 호출 시 403 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:40-48`, `:85-95`, `:106-110` |
| AS-F-034 | 리딩 낭독 | 신규 | 완료된 리딩 본문을 장 단위로 TTS(기능 `narration`)해 mp3 1개로 저장(`exports/<org_id>/astro/narration/<reading_id>.mp3`)하고 플레이어로 재생·다운로드한다. 작업 도중 다른 제공자로 대체하지 않는다(같은 목소리). 시작 전에 ElevenLabs를 쓸 수 없으면(국외 이전 미동의, 비활성) 처음부터 오픈소스 보이스로 만든다. 재생과 재다운로드는 무료. 음성 첫머리에 "AI가 생성한 음성입니다" 안내 | 한 낭독의 `ai_usage` 행 제공자가 모두 같고 `voice_jobs.fallback_from` null. 중간 실패 시 파일 미생성 + 선차감 전액 환불. 같은 리딩 재요청은 기존 파일 URL 반환(추가 차감 0). 리딩·대상 삭제 시 파일 삭제 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:45-47` |
| AS-F-035 | AI 라우팅과 국외 이전 동의 | 신규 | 이메일 인증 직후 온보딩에서 "AI 처리 방식"을 고른다: 상용 AI 사용(국외 이전 동의) 또는 국내 오픈소스만. 동의하면 `core.set_ai_cross_border_ack(org, true, 고지문 버전)`과 `consents(kind='overseas_transfer')`를 함께 기록하고, 설정에서 언제든 철회한다. 기능별 기본 체인은 02장 5절(seed와 일치). 동의가 없으면 모든 AI·음성 기능이 오픈소스 제공자만 쓴다 | 미동의 조직의 `ai_usage.provider_id`에 상용 제공자 0. 철회 직후 다음 요청부터 상용 0. 고지문 버전이 `ai_org_settings.cross_border_notice`와 `consents.version`에 같게 남는다 | `docs/products/_platform-core/AI_ARCHITECTURE.md:86`, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:553-575` |
| AS-F-036 | AI 크레딧 선차감·정산 | 신규 | 채팅 턴·STT·TTS·낭독은 시작 때 예상 크레딧을 `consume_credits`로 선차감하고, 끝나면 실제 사용량으로 정산한다(차액 추가 차감 또는 `refund_credits`). 리딩 그래프는 리딩 정액 차감에 묶고 정산 차액이 없다(4.7절) | 1시간 넘게 지난 `ai_usage` 중 `settled_at is null` 0행. 같은 멱등 키 재요청 시 차감 1회. 원장 drift 0 | `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130` |
| AS-F-037 | 3D 히어로 | 신규 | 랜딩 히어로: PC·태블릿은 혼천의(24절기 고리)가 입력한 생일의 절기를 가리킨 뒤 책으로 접혀 펼쳐지는 풀 3D, 모바일은 고리만 있는 가벼운 혼천의 + 2D 페이지 넘김, WebGL 미지원·저사양·`prefers-reduced-motion`은 정지 이미지(03장 4.5절) | `HERO_3D.md` 4절 수용 기준 전부: 기기별 3종 동작, 3D 번들+에셋 PC·태블릿 1MB/모바일 300KB 이하, LCP 2.5초, 제목·입력·CTA가 3D 전에 보이고 키보드로 사용 가능, 3종 스크린샷 고문 검토 통과 | `docs/products/_design-guide/HERO_3D.md:5-75`, `:81` |
| AS-F-038 | AI 출력 규칙(리딩·채팅·낭독·위키) | 신규 | 6.4절 금지 문구와 6.5절 AI 대화 규칙을 그래프 compliance 노드와 `/tools/answer` 후처리에 같은 규칙 파일(`packages/astro-report/rules/banned.json`)로 적용한다. 단정 예언, 의료·법률·투자 판단 요청은 정중히 거절하고 전문가를 안내한다. 자해·자살 언급은 상담 전화 안내로 전환한다 | 채팅 금지 문구 평가셋 30문항(제안) 위반 0. 위기 신호 테스트 문장 5개 모두 안내 문구로 응답 | `docs/products/_platform-core/AI_ARCHITECTURE.md:117`, 6.4절 |

## 4. 요금과 크레딧

정본은 Astro AI 단가표다(확정 결정 8). MVP는 크레딧팩 일회 결제만 판다(확정 결정 7, `docs/products/00_MERGE_ANALYSIS.md:451`).

### 4.1 플랜

| 코드 | 가격 | 월 크레딧 | 가입 크레딧 | 이월 | 범위 | 근거 |
|---|---|---|---|---|---|---|
| `starter` | 0원 | 0 | 30(1회, 지급 시점은 AS-F-002) | 해당 없음(pack 버킷) | MVP 기본 플랜 | `AA/공통/PRD.md:31` |
| `basic` | 9,900원/월 | 300 | 0 | 안 함(제안) | Phase 2 | `AA/공통/PRD.md:32`의 200에서 2026-10-14 변경: 구독 크레딧당 단가(33.0원)를 `pack_300`(39.1원)보다 싸게(`Price_Plans/astro-ai/PRICE_PLAN.md` 10장) |
| `pro` | 29,900원/월 | 1,000 | 0 | 안 함(제안) | Phase 2 | `AA/공통/PRD.md:33`의 700에서 2026-10-14 변경: 29.9원/cr로 `pack_700`(34.9원)보다 싸게(`Price_Plans/astro-ai/PRICE_PLAN.md` 10장) |
| `master` | 69,900원/월 | 3,000(통합 리딩 100건, 원가 상한 확보). 판매 페이지·플랜명에 "무제한"을 쓰지 않는다(공용 가격 원칙 6장) | 0 | 안 함 | Phase 2 | `AA/공통/PRD.md:34`의 "무제한"을 수치 한도로 대체(2026-10-14, `Price_Plans/astro-ai/PRICE_PLAN.md` 10장), `docs/reviews/Astro_AI.md:62` |

연간 구독 20% 할인은 Phase 2 빌링키와 함께 연다(`AA/공통/PRD.md:99`).

### 4.2 크레딧 단가

| 작업 | 크레딧 | 범위 | 근거 |
|---|---|---|---|
| 사주 리딩 | 15 | MVP | `AA/공통/PRD.md:40` |
| 타로 3카드 리딩 | 20 | MVP | `AA/공통/PRD.md:41` |
| 통합 리딩(사주+타로) | 30 | MVP | `AA/공통/PRD.md:42` |
| PDF 재생성(테마 변경) | 5 | MVP | `AA/공통/PRD.md:45` |
| 연간 운세 리포트 | 50 | Phase 2 | `AA/공통/PRD.md:43` |
| 궁합 분석 | 25 | Phase 2 | `AA/공통/PRD.md:44` |
| 다운로드 URL 재발급, 이메일 재발송 | 0 | MVP | 제안: 소장형 정체성상 다시 받는 데 비용을 받지 않는다 |
| 비회원 Live Demo | 0 | MVP | `AA/랜딩페이지/CLAUDE_LANDING.md:260` |

단가는 코드 상수(`apps/astro-ai/src/server/pricing.ts`)로 둔다. 원본의 `credits_config` 테이블(`AA/공통/CLAUDE.md:267`)은 만들지 않는다. 코어 `priceOf`가 제품 단가표를 주입받는 구조(`docs/products/_platform-core/SHARED_MODULES.md:133-137`)를 따르기 때문이다.

### 4.3 크레딧팩

| 코드 | 가격 | 기본 | 보너스 | 지급 총량(`credit_packs.credits`) | 근거 |
|---|---|---|---|---|---|
| `pack_100` | 4,900원 | 100 | 0 | 100 | `AA/공통/PRD.md:55` |
| `pack_300` | 12,900원 | 300 | 30 | 330 | `AA/공통/PRD.md:56` |
| `pack_700` | 27,900원 | 700 | 100 | 800 | `AA/공통/PRD.md:57` |
| `pack_2000` | 69,900원 | 2,000 | 400 | 2,400 | `AA/공통/PRD.md:58` |

모듈러 `seed.sql`은 2026-10-13에 모놀리스 `seed.sql`과 같은 값으로 맞춰져 위 표를 따른다(`docs/products/_supabase-modular/VERIFICATION.md`).

### 4.4 크레딧 운영 규칙

| 규칙 | 내용 | 근거 |
|---|---|---|
| 차감 시점 | 리딩 생성 요청을 받은 Route Handler가 잡을 만들기 전에 `consume_credits`(멱등 키 `consume:astro:<request_id>`) | `docs/products/_platform-core/CORE_SPEC.md:177-186` |
| 자동 환불 | 잡 최종 실패 → `fail_job`이 원 차감 전액 환불. 대기 중 취소 → `cancel_reading`이 환불 | `docs/products/_platform-core/CORE_SPEC.md:185-186` |
| 환불하지 않는 경우 | PDF까지 완료된 뒤 사용자가 내용에 불만이 있는 경우(어드민 판단으로 수동 지급만 가능) | 제안 |
| 차감 순서 | plan 버킷 → pack 버킷(코어 규칙). MVP는 pack만 있다 | `docs/products/_platform-core/CORE_SPEC.md:173` |
| 만료 | 팩 크레딧은 만료하지 않는다(제안: 유효기간을 두면 약관과 표시 의무가 늘어남) | 제안 |
| 가입 크레딧 | 30, 조직당 1회, 이메일 인증 또는 Google 로그인 뒤(Stage C부터 카카오·네이버 로그인 뒤 포함) | AS-F-002 |

### 4.5 결제 환불 규정 (제안, 법무 확인 필요)

| 경우 | 처리 |
|---|---|
| 결제 후 7일 이내, 해당 팩 크레딧 미사용 | 전액 환불(전자상거래법 청약철회 기간 7일 기준) |
| 일부 사용 | 미사용 유상 크레딧 비율만큼 환불, 보너스 크레딧은 제외. 수수료 공제 여부는 미확인(콘텐츠이용자보호지침 확인 필요) |
| 가입·환영 크레딧, 어드민 지급 크레딧 | 환불 대상 아님 |
| 생성 실패 | 크레딧 자동 환불(현금 환불 아님) |

### 4.6 `core.plans.features` 키 해석

| 키 | 타입 | 의미 | MVP 값(`starter`) |
|---|---|---|---|
| `readings` | text[] | 허용 리딩 종류. 없는 종류는 403 | `["saju","tarot","combined"]` |
| `pdf_themes` | text[] | 선택 가능 테마 키 | `["mystical-dark","oracle-gold"]` |
| `max_subjects` | int | 조직당 보관함 대상 상한 | 20(제안) |
| `email_delivery` | bool | 이메일 발송 허용 | true |
| `welcome_credits` | int | 인증 후 서버가 지급할 환영 크레딧 | 30 |
| `monthly_fair_use` | int | Phase 2 Master 월 공정 사용 한도(cr) | 없음 |
| `ai_chat` | bool | AI 채팅(텍스트) 허용. 키가 없으면 true로 읽는다 | true |
| `ai_chat_turns_per_day` | int | 사용자당 하루 채팅 턴 상한(공정 사용). 키가 없으면 200 | 200(제안) |
| `voice_chat` | bool | 음성 대화 허용. 키가 없으면 true | true |
| `narration` | bool | 리딩 낭독 허용. 키가 없으면 true | true |

AI 키 4개는 2026-10-13에 추가했다. 모놀리스는 `supabase/monolith/seed.sql`의 starter 행에, 모듈러는 `docs/products/_supabase-modular/migrations/1100_astro.sql` 13.2절의 병합 UPDATE에 있다(모듈러 `seed.sql` 반영은 06장 6절 R-9).

모듈러 seed의 `{"readings":["saju","tarot"],"pdf_themes":2}`(`docs/products/_supabase-modular/seed.sql:34`)는 옛 값이었고, 2026-10-13에 모놀리스 seed와 일치하도록 갱신되었다(06장 6절 R-2 해결).

### 4.7 AI·음성 크레딧 단가 (2026-10-13, 제안)

리딩 단가(4.2절)와 크레딧팩(4.3절)은 바꾸지 않는다. 제공자 단가는 코어 seed `core.ai_model_prices`(`docs/products/_supabase-modular/seed.sql:228-246`: LLM 상용 1k 입력 1cr·출력 4cr, 오픈소스 0.2·0.5cr, STT ElevenLabs 3cr/분·오픈소스 0.5cr/분, TTS ElevenLabs 5cr/천 자·오픈소스 1cr/천 자, 모두 제안값)이고, 이 표는 그 값을 astro 기능에 적용한 것이다. 계산 상수는 `apps/astro-ai/src/server/ai-pricing.ts`(4.2절과 같은 이유로 코드 상수). 선차감과 정산 규칙은 `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130`, 음성 단가는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104`을 따른다.

| 작업 | 선차감(예상) | 정산 | 상용 경로 예 | 오픈소스 경로 예 | 멱등 키 |
|---|---|---|---|---|---|
| 리딩 생성(그래프 포함) | 15 / 20 / 30(정액) | 차액 없음. `ai_usage`에 원가만 기록하고 실행 끝에 `settled_at`을 채운다. 별도 `run:<id>` 차감을 하지 않는다 | Claude 우선 | `oss-llm` | `consume:astro:<request_id>` |
| AI 채팅 1턴(텍스트) | 3 | 실제 토큰 × 단가 + Dify 보조 노드 오버헤드 0.5, 올림. 최소 1, 상한 5(초과분은 운영사 부담) | 용어 설명 약 3, 리딩 근거 질문 약 5(상한) | 약 1~2 | `conv:<id>:turn:<n>` |
| 음성 질문 STT(60초 이하) | 녹음 길이 기준 올림: 오픈소스 1, ElevenLabs 3 | 실제 `audio_seconds` | 3 | 1 | `voice:<voice_job_id>` |
| 답변 읽어 주기 TTS | 답변 글자 수 × 단가, 천 자 단위 올림 | 실제 `characters` | 600자 답변 5 | 600자 답변 1 | `voice:<voice_job_id>` |
| 리딩 낭독 | 본문 글자 수 × TTS 단가, 천 자 단위 올림 | 실제 `characters` | 사주 3,000자 15, 통합 5,000자 25 | 사주 3 / 통합 5 | `voice:<voice_job_id>`(= 요청 `request_id`) |
| 낭독 재생·재다운로드 | 0 | - | - | - | - |
| 위키 열람, 용어 페이지 | 0 | - | - | - | - |
| 해설집 색인, 위키 ingest·lint | 사용자 과금 없음. 운영자 조직 지갑에서 사용량 차감 | 사용량 | - | - | `run:<id>` |
| 비회원 Live Demo | 0(LLM 없음, 변경 없음) | - | - | - | - |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 경로별 단가 | 국외 이전에 동의하지 않은 조직은 체인에 오픈소스만 남으므로 오픈소스 단가가 자동 적용된다. 화면은 실제로 고른 경로의 예상치를 보여 준다 | `docs/products/_supabase-modular/migrations/0008_core_ai.sql:452-460` |
| 실패 환불 | 사용자에게 결과가 전달되지 않은 실패는 선차감 전액 환불. 낭독은 장 하나라도 실패하면 전체 실패 | `docs/products/_platform-core/AI_ARCHITECTURE.md:129` |
| 정산 시점 | 응답·작업 종료 직후 정산. 스트림이 끊기면 선차감을 남기고 정산 잡이 `settled_at is null` 행을 5분 주기로 처리(제안) | `docs/products/_platform-core/AI_ARCHITECTURE.md:128` |
| 표시 | 보내기 전 "약 3크레딧(정산 후 1~5)", 낭독 버튼에 예상치, 정산 결과는 메시지 아래와 원장 표에 | 제안 |
| 공정 사용 | 사용자당 하루 200턴(`features.ai_chat_turns_per_day`) | 제안 |

## 5. 비기능 요구사항

원본의 "30초" 목표는 기준점이 문서마다 다르다(`docs/reviews/Astro_AI.md:56`). 기준점을 "크레딧 차감이 끝나고 리딩이 `queued`가 된 시각(T0)"으로 하나로 정한다.

| 항목 | 목표 | 근거 |
|---|---|---|
| 리딩 생성 API 응답(202) | p95 800ms 이하 | 제안: 차감·INSERT·enqueue 3회 왕복 |
| T0 → 본문 생성 완료 | p95 30초 이하(장별 병렬 생성) | `AA/공통/PRD.md:109`, `docs/reviews/Astro_AI.md:57` |
| 본문 → PDF 저장 | p95 15초 이하 | `AA/공통/PRD.md:110` |
| T0 → 대시보드에서 PDF 받기 가능 | p95 60초 이하(대기 15초 여유 포함) | 제안: 위 두 값의 합 + 큐 대기 |
| PDF 준비 → 이메일 발송 완료 | p95 30초 이하 | `AA/공통/PRD.md:111` |
| 원국 프리뷰 갱신 | 100ms 이하(브라우저 엔진) | 제안 |
| Live Demo API | p95 300ms 이하 | 제안: LLM 없음 |
| 랜딩 LCP / CLS / Lighthouse 성능 / 접근성 | 2.5초 / 0.1 / 90점 / 95점 이상 | `AA/랜딩페이지/PRD_LANDING.md:132-139` |
| 가용성 | 월 99.9%, RTO 1시간 | `AA/공통/PRD.md:122-123` |
| 발송 성공률 | 99.5% 이상(재시도 포함) | `AA/공통/PRD.md:87` |
| 워커 동시성 | 리딩 잡 워커 인스턴스당 4건, 장별 LLM 호출 동시 3 | 제안: LLM 분당 한도 대비 여유 |
| 렌더 타임아웃 | 120초 | `docs/products/_platform-core/SHARED_MODULES.md:274` |
| LLM 타임아웃 | 장당 60초, 장 재시도 1회, 잡 재시도 1회(`max_attempts=2`) | `docs/products/_platform-core/SHARED_MODULES.md:220`, `docs/reviews/FortuneDocs.md:102` |
| 입력 상한 | 질문 200자, 호칭 20자, 보관함 20명 | `AA/대시보드/PRD_DASHBOARD.md:29`, 제안 |
| PDF 크기 | 리딩당 10MB 이하(제안: 폰트 서브셋 임베딩) | 제안 |
| 레이트 리밋 | 로그인/가입 IP당 10회/10분, 리딩 생성 조직당 10회/분 + 진행 중 3건, Live Demo IP당 3회/일, 다운로드 URL 60회/시간, Toss 웹훅 600회/분 | `docs/products/_platform-core/SECURITY_BASELINE.md:8장`, 제안 |
| 채팅 첫 표시 | 용어 설명 p95 3초, 리딩 근거 질문 p95 12초 이하(Dify HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 표시) | 제안: 04장 6.2절 |
| 채팅 턴 완료 | p95 15초 이하 | 제안 |
| STT(60초 발화) | p95 5초 이하 | 제안: 오픈소스 GPU 서버 기준, 구현 시 확인 |
| TTS 첫 오디오(읽어 주기) | p95 2초 이하 | 제안 |
| 리딩 낭독 생성(사주 약 3,000자) | p95 60초 이하 | 제안: 장 단위 순차 TTS |
| 그래프 실행(`astro.reading`) | 위 "T0 → 본문 생성 완료 p95 30초"에 포함 | 이 표 3행 |
| AI 레이트 리밋 | 채팅 사용자당 20턴/분 + 하루 200턴, STT 사용자당 10회/분, 낭독 조직당 5회/시간, 잡 토큰 발급 120회/분 | 제안: `docs/products/_platform-core/SECURITY_BASELINE.md:143-155` 기준 |
| AI 입력 상한 | 채팅 메시지 1,000자, 대화당 50턴, 음성 발화 60초·5MB | 제안 |
| 3D 히어로 | 3D 번들+에셋 PC·태블릿 1MB, 모바일 300KB 이하, 60fps / 30fps 이상 | `docs/products/_design-guide/HERO_3D.md:32-41` |
| AI 기록 보존 | Dify 대화 로그 30일, `core.ai_messages`는 대화 삭제 또는 탈퇴 후 30일 | `docs/products/_platform-core/AI_ARCHITECTURE.md:69`(제안 30일) |
| 보존 기간 | 6장 1절 표 | 공백 9 |

## 6. 법, 개인정보, 금지 문구

### 6.1 개인정보

| 항목 | 내용 |
|---|---|
| 수집 항목(회원) | 이메일, 표시 이름, 로그인 제공자, 결제 내역(Toss 결제키, 금액. 카드번호는 받지 않음), 접속 IP 해시. 단계별 제공자 식별자(확정 결정 22): Stage B Google 계정 식별자·이름·프로필 이미지 URL, Stage C1 카카오 사용자 식별자·닉네임·프로필 이미지(비즈 앱이면 이메일), Stage C2 네이버 사용자 고유 id·이메일·이름(브리지 경로면 `core.auth_identity_links`에 저장). Stage A 시드 계정은 로컬 DB에만 있고 실제 개인정보가 아니다 |
| 수집 항목(대상) | 호칭, 관계, 성별, 생년월일, 생시(선택), 양/음력, 윤달, 자시 방식, 출생 시·군(선택), 실명(선택, PDF 표지용) |
| 목적 | 사주 원국 계산, 리포트 생성과 전달, 결제와 환불, 부정 이용 방지 |
| 암호화 | `subjects.name_ciphertext`, `subjects.birth_ciphertext`, `readings.question_ciphertext`, `deliveries.recipient_ciphertext`(AES-256-GCM, `ASTRO_PII_KEY_V<n>`). 원국 스냅샷(`readings.chart`)은 렌더에 필요해 평문 jsonb로 두되 RLS와 대상 삭제 연쇄로 보호한다 |
| 보존 | 대상 정보: 사용자가 삭제할 때까지 / 리딩 본문과 PDF: 삭제 또는 탈퇴 후 30일 / 동의 기록: 탈퇴 후 1년(제안: 분쟁 증빙) / 발송 기록: 1년(제안) / 결제 기록: 5년(전자상거래법상 대금결제 기록, 코어 purge와 충돌하므로 06장 6절 코어 요청) / Live Demo 입력: 저장하지 않음 |
| 삭제 절차 | 대상 삭제: 즉시 DB 삭제 + Storage 파일 24시간 내 삭제. 탈퇴: 조직 soft delete → 30일 → `purge_organization` |
| 제3자(가족·지인) 정보 | 등록 시 "정보주체 동의 또는 법정대리인" 확인 체크를 필수로 받고 약관 버전과 함께 `consents`에 남긴다. 14세 미만 아동의 정보는 법정대리인만 등록하도록 안내(제안) |
| 제3자 제공·처리위탁 | 상용 AI 제공자(LLM: Anthropic, OpenAI, Google, OpenRouter / 음성: ElevenLabs)는 국외 이전에 동의한 조직의 요청에만 쓴다. 보내는 범위: 호칭 토큰, 성별, 원국 간지·오행 점수·십신·대운 나이, 타로 카드, 질문·채팅 메시지, 채팅 근거로 쓰는 리딩 본문, 낭독할 리딩 본문, 음성 질문 오디오(STT). 실명, 생년월일시 원문, 이메일은 어떤 AI 제공자에도 보내지 않는다(실명은 PDF 렌더 시점에 템플릿이 넣는다). 오픈소스 LLM·임베딩·음성 서버와 Dify는 운영사가 자체 운영한다(서버 위치·위탁 여부 구현 시 확인). Resend: 수신 이메일. Toss: 결제 정보. Supabase/Railway/Vercel: 호스팅 |
| 국외 이전 | 호스팅 국외 이전은 개인정보처리방침에 이전 국가, 항목, 목적, 보유 기간을 공개한다. 상용 AI·음성 제공자로의 이전은 이메일 인증 직후 온보딩에서 선택 동의로 받는다(`consents.kind='overseas_transfer'` + `core.set_ai_cross_border_ack`, AS-F-035). 거부하면 국내 오픈소스 모델만 쓴다. 동의 방식(필수/선택)과 처리방침 공개만으로 가능한 범위는 개인정보 보호법 국외 이전 조항 기준으로 법무 확인(구현 시 확인, 미확인: 각 사업자의 리전 정책) |
| AI 대화 기록 | `core.ai_messages`(본인만 열람, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`), Dify 대화 로그(운영사 자체 호스팅, 30일 보존, 조직 데이터 저장소로 관리, `docs/products/_platform-core/AI_ARCHITECTURE.md:69`). 대화 삭제·탈퇴 시 30일 안에 둘 다 삭제. 음성 녹음 원본은 저장하지 않는다 |

### 6.2 약관과 고지

| 항목 | 내용 |
|---|---|
| 이용약관, 개인정보처리방침, 환불 규정 | `/legal/terms`, `/legal/privacy`, `/legal/refund`. 가입 화면에서 필수 동의 2개(`terms_required`, `privacy_required`). OAuth(Google·카카오·네이버) 첫 로그인은 가입 화면을 거치지 않으므로 온보딩 첫 단계 `/onboarding/terms`(제안, `/onboarding/ai` 앞)에서 같은 2개를 받는다(`docs/products/_platform-core/AUTH_ROADMAP.md` 5.2절) |
| 점술 서비스 면책 | 모든 리포트 첫 장과 랜딩 하단: "이 리포트는 명리학과 타로의 전통 해석을 AI가 재구성한 참고용 콘텐츠이며 의료, 법률, 투자 판단을 대신하지 않습니다"(`docs/reviews/Astro_AI.md:61`) |
| AI 생성 표시 | PDF 판권면과 대시보드 결과 화면에 "AI가 생성한 해설". 채팅 답변마다 "AI가 생성한 답변", 낭독 음성 첫머리와 플레이어에 "AI가 생성한 음성입니다", 위키 페이지에 "AI가 정리하고 운영자가 검수한 문서". 다른 모델로 대체된 답변은 "다른 AI 모델로 답했습니다" 표시 |
| 저작권 | 리포트는 사용자가 개인적으로 소장·공유할 수 있다. 상업적 재판매 금지. 테마 디자인과 템플릿의 저작권은 운영사에 있다 |
| 통신판매업 정보 | 사업자 상호, 대표자, 사업자등록번호, 통신판매업 신고번호, 주소, 연락처를 푸터에 표시(`AA/랜딩페이지/PRD_LANDING.md:82`). 신고번호는 미확인 |
| 마케팅 수신 | 선택 동의(`marketing_email`), 기본 해제. 카카오 알림톡(Phase 2)은 휴대폰 번호 수집 동의, 발신 프로필, 템플릿 심사가 선행 조건(`docs/reviews/Astro_AI.md:61`) |

### 6.3 제휴/광고, 플랫폼 약관, 규제 특례

| 항목 | 내용 |
|---|---|
| 제휴/광고 | 해당 없음. affiliate 모듈을 쓰지 않는다(소비 제품은 video, blog, `docs/products/_platform-core/SHARED_MODULES.md:51`) |
| 외부 플랫폼 자동화 | 해당 없음. 외부 플랫폼에 자동 게시하지 않는다 |
| 규제 특례 | 건강·재테크 해석은 의료법·유사투자자문 규제 대상이 될 수 있어 다루지 않는다(`docs/reviews/Astro_AI.md:67`). 금지 표현(6.4절)으로 생성물에서도 차단 |

### 6.4 금지 문구 (마케팅과 생성 콘텐츠 공통)

| 분류 | 금지 | 대체 |
|---|---|---|
| 가상 후기·평점 | 존재하지 않는 고객 후기, `aggregateRating 4.9 / reviewCount 1240`(`AA/공통/GEO.md:70-73`), 후기 마퀴 12개(`AA/랜딩페이지/PRD_LANDING.md:69-72`) | 실제 후기 수집 기능 전에는 후기 블록 자체를 두지 않는다 |
| 허위 수치 | "12,470+" 카운터(`AA/공통/DESIGN.md:111`), 미측정 사용자 수, 정확도 %, "평균 30초"(측정 전) | DB 집계로 확인된 값만, 집계 시각과 함께 표시. 1,000건 미만이면 숨김(제안) |
| 보장 표현 | "운명이 바뀝니다", "100% 정확", "확실한 재물운" | "전통 해석에 따르면", "경향" |
| 의료 단정 | 질병 발생·진단·치료·처방, "~병에 걸린다" | 생활 습관 수준의 일반 조언("휴식 리듬을 점검해 보세요") |
| 금융 단정 | 종목·코인·부동산 매수 권유, 수익 보장, 투자 시기 단정 | "재물에 대한 태도와 관리 습관" 수준 |
| 공포·결정 강요 | 사망·사고·이혼 단정, 부적·굿·액땜 상품 권유, 결혼 시기 확정 | 다른 선택지를 열어 두는 서술 |
| 차별 | 성별·나이·출신에 대한 비하, 성 역할 고정 서술 | 중립 서술 |
| 상표 | 타사 서비스명(점신, 포스텔러 등) 비교 광고 문구 | 비교 없이 자사 기능 설명 |

금지 표현은 프롬프트 지시와 생성 후 규칙 검사(`packages/astro-report/rules/banned.json`, 한글은 `\b` 대신 형태 경계 규칙, `docs/products/00_MERGE_ANALYSIS.md:791`) 두 단계로 막는다. 검사에 걸린 장은 1회 재생성하고, 다시 걸리면 잡을 실패시켜 환불한다.

### 6.5 AI·음성 개인정보 판단과 대화 규칙 (2026-10-13)

생년월일시가 민감 데이터인지에 대한 이 기획의 판단(열린 결정 D-12, 권고안으로 진행):

| 항목 | 판단 | 이유와 처리 |
|---|---|---|
| 생년월일시 | 개인정보 보호법상 민감정보(사상·신념, 건강 등 열거 항목)는 아니지만 개인 식별에 쓰일 수 있는 개인정보로 다룬다(법무 확인 필요) | 원문은 어떤 AI 제공자에도 보내지 않는다. AI에는 엔진이 계산한 간지·오행·대운만 간다. 간지 4주는 60년 주기 안에서 생년월일시를 거의 특정할 수 있으므로 국외 이전 동의 대상에 포함한다 |
| 오픈소스 강제 여부 | 강제하지 않는다(`force_open_source=false`). 국외 이전 동의로 통제한다 | 리딩 품질이 제품의 핵심이라 상용 모델 우선. 동의가 없는 조직은 `resolve_ai_route`가 상용을 자동으로 걸러 낸다(`docs/products/_supabase-modular/migrations/0008_core_ai.sql:452-456`) |
| 질문·채팅 자유 입력 | 사용자가 건강·금융 등 민감한 내용을 적을 수 있다 | 입력란에 "건강 상태, 계좌·카드 번호, 주민등록번호를 적지 마세요" 안내. 보내기 전 서버가 주민등록번호·전화번호·이메일·계좌번호 형식을 마스킹한다(제안). 질문 원문은 암호화 저장(6.1절) |
| Dify 보조 노드 | 조직을 알 수 없어 동의를 확인할 수 없다 | `dify.aux`는 오픈소스 강제(`force_open_source=true`, 02장 5절) |

| 고지·동의 | 시점 | 기록 |
|---|---|---|
| 상용 AI 국외 이전 | 이메일 인증 직후 온보딩, 설정에서 변경 | `consents(overseas_transfer)` + `ai_org_settings`(고지문 버전) |
| 음성 처리 고지(녹음) | 첫 마이크 사용 직전. 녹음 목적, 원본 미저장, 상용 제공자 사용 시 국외 이전 | `consents(voice_processing)`. 녹음 원본은 저장하지 않으므로 `voice_jobs.store_audio=false`이고 녹음 보관 동의는 받지 않는다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:85-95`) |
| AI 생성 표시 | 채팅·낭독·위키·PDF | 6.2절 |

AI 대화 추가 규칙(6.4절에 더해 채팅·낭독에 적용):

| 분류 | 금지 | 대신 |
|---|---|---|
| 확정 예언 | "올해 반드시 이직합니다", "~할 운명입니다", 날짜를 못 박은 사건 예언 | "전통 해석에서는 ~한 흐름으로 봅니다" |
| 전문 판단 대행 | 진단·처방, 소송 승패, 종목·코인·부동산 매수 시점 | 해당 전문가 상담 안내. 사주·타로는 참고용이라고 다시 알린다 |
| 타인 판단 강요 | 궁합으로 이별·결혼 결정 권유, 가족 구성원 운세로 책임 전가 | 선택은 사용자에게 있다는 서술 |
| 명리 판정 | 용신·격국 단정(D-10), 엔진에 없는 수치 생성 | 엔진 값(오행 점수, 십신, 대운)만 인용 |
| 위기 신호 | 자해·자살 언급에 운세로 답하기 | 운세 답변을 멈추고 자살예방 상담전화 109 등 안내(번호는 구현 시 확인) |
| 개인정보 요구 | 실명·주민등록번호·연락처를 묻기 | 묻지 않는다 |

## 7. KPI

원본 KPI(`AA/공통/PRD.md:129-136`) 중 MVP 범위에 맞는 것만 남기고, 마켓·구독 지표는 Phase 2로 미룬다.

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| AI 채팅 사용률 | 첫 리딩 완료 사용자의 30%(제안) | `core.ai_conversations` 1개 이상 사용자 / 첫 리딩 완료 사용자 | 3개월 |
| 답변 출처 표시율 | 95% 이상(제안) | `ai_messages.citations`가 빈 배열이 아닌 assistant 메시지 비율 | 월 |
| 낭독 생성 성공률 | 98% 이상(제안) | `voice_jobs`(feature `narration`) succeeded / 전체 | 월 |
| 가입 → 첫 리딩 완료 전환 | 40%(제안) | `readings.status='completed'`가 있는 조직 / 가입 조직 | 출시 후 3개월 |
| 크레딧팩 결제 전환율 | 12% 이상 | `payments` 1건 이상 조직 / 첫 리딩 완료 조직 | 6개월(`AA/공통/PRD.md:132`) |
| 리딩 생성 성공률 | 98% 이상(제안) | completed / (completed + failed) | 월 |
| T0 → PDF p95 | 60초 이하 | 워커 로그 `completed_at - created_at` | 주 |
| 발송 성공률 | 99.5% 이상 | `deliveries` sent / (sent + dead) | 월(`AA/공통/PRD.md:133`) |
| 재구매율 | 25%(제안) | 결제 2회 이상 조직 / 결제 조직 | 6개월 |
| 보관함 평균 대상 수 | 2.0명 이상(제안: 가족 소장 포지셔닝 검증) | `subjects` 수 / 조직 | 3개월 |
| Live Demo → 가입 | 15% 이상 | 데모 완료 세션 중 가입 | 월(`AA/랜딩페이지/PRD_LANDING.md:93`) |
| MAU | 5,000명 | Supabase Auth 집계 | 6개월(`AA/공통/PRD.md:131`) |
| 엔진 오류 신고 | 월 0건 확정 오류 | CS 태그 + 골든 테스트 추가 | 월 |

## 8. 열린 결정

분석 B-5(`docs/products/00_MERGE_ANALYSIS.md:431-479`)의 8개 항목 중 확정 결정으로 닫힌 것은 아키텍처(결정 3), 타로 포함(결정 7), 수익 모델 MVP(결정 7, 8), 범위(결정 7), 서비스명(결정 10)이다. 남은 항목과 이 기획에서 새로 생긴 항목은 아래와 같다. 각 항목의 "이 기획의 가정"으로 01~07장을 썼다.

| ID | 결정 | 선택지 | 권고와 이 기획의 가정 |
|---|---|---|---|
| D-1 | 제품 정체성(B-5 #1) | (a) 30초 즉시 리딩 + 3채널 (b) 소장형 책 (c) 소장형 책자 + 이메일·대시보드 | (c). 랜딩 메시지와 PDF 보관 정책(AS-F-016)이 이 가정을 따른다 |
| D-2 | LLM(B-5 #5) | (a) Claude 단일 (b) 3사 체인 (c) Claude + OpenRouter 폴백 | 닫힘(확정 결정 17, 2026-10-13): FastAPI 라우터 체인 Claude → ChatGPT → Gemini → 오픈소스. 기능별 기본값은 02장 5절 |
| D-3 | 가입 크레딧 양과 지급 시점(B-5 #4) | (a) 30cr 가입 즉시 (b) 30cr 이메일 인증·Google 확인 뒤 (c) FD식 3cr | (b). Stage C의 카카오·네이버 로그인 확인 뒤도 같은 규칙(확정 결정 22). 모놀리스 seed의 `signup_credits=0`과 `features.welcome_credits=30`이 이 가정이다. 모듈러 seed도 2026-10-13부터 같은 값이다 |
| D-4 | 만세력 데이터 소스(B-5 #6) | (a) KASI 실시간 (b) 로컬 절기 테이블 + KASI 검증 (c) 외부 라이브러리 | (b). 라이브러리를 쓰더라도 골든 테스트 통과가 조건 |
| D-5 | 리포트·PDF 보관 기간 | (a) 계정 존속 기간 (b) 1년 (c) 원본 24시간 삭제 | (a). (c)는 다른 프로젝트 잔재(`docs/reviews/Astro_AI.md:55`) |
| D-6 | 결제 환불 규정 | 4.5절 초안 | 법무 확인 후 확정 |
| D-7 | Master 공정 사용 한도(Phase 2) | 월 3,000cr / 리딩 100건 / 다른 값 | 결정됨(2026-10-14, Price_Plans 반영): 월 3,000cr, "무제한" 표기 삭제(4.1절) |
| D-8 | 테마 팔레트 | 원본 보라 토큰 유지 / 주제 기반 재추출 | 재추출(03장 4절). 테마 키 이름은 원본을 유지 |
| D-9 | 배포 DB와 모놀리스 스키마 | 모듈러 `astro` / 모놀리스 `public` | 모듈러 기본. 모놀리스 `public`은 코어 축소판을 따른 것이며 확정 대기 |
| D-10 | 용신·격국 판정 | (a) MVP에서 엔진 규칙으로 판정 (b) MVP는 "보완 오행"으로 대체, 판정은 Phase 2 엔진 사양에서 | (b). LLM이 판정하게 두지 않는다(`docs/reviews/FortuneDocs.md:47`) |
| D-11 | 타로 자리 의미 | 과거/현재/미래 / 상황/장애/조언 | 과거/현재/미래(제안) |
| D-12 | 생년월일시·자유 입력의 민감 데이터 분류 | (a) 민감 아님, 국외 이전 동의로 통제 + 원문 미전송 + 입력 마스킹 (b) 민감으로 보고 리딩·채팅을 오픈소스 강제 | (a). 6.5절. (b)를 고르면 02장 5절 `astro.reading`, `chat` 행을 `open_source` + `force_open_source=true`로 바꾸고 리딩 품질 평가셋(AS-06-033)을 오픈소스 모델로 다시 통과시켜야 한다 |
| D-13 | 리딩 낭독 요금 | (a) 글자 수 × 제공자 단가(사주 약 15cr, 오픈소스 약 3cr) (b) 리딩 종류별 정액(예: 사주 10, 타로 8, 통합 15) | (a)(제안). 선차감·정산 규칙을 그대로 쓴다. 판매 데이터를 보고 (b) 재검토 |
| D-14 | AI 채팅 무료 제공 | (a) 무료 없음(턴 선차감) (b) 리딩 1건당 무료 질문 3턴 | (a)(제안). (b)는 전환 효과를 본 뒤 결정 |
| D-15 | 해설집 원고 작성과 위키 공개 | (a) 운영자 직접 집필 + 위키 공개(SEO) (b) AI 초안 + 운영자 검수 + 위키 공개 (c) 위키는 로그인 사용자만 | (b)(제안). 원고 항목마다 검수자·검수일을 남기고 공개 위키는 `published`만 |
| D-16 | 낭독 보이스와 ElevenLabs 데이터 보관 | (a) ElevenLabs 기본 보이스 1종 + 오픈소스 보이스 1종 고정 (b) 사용자 선택. ElevenLabs 입력 보관·학습 사용·제로 리텐션 옵션 여부 | (a). 보이스 id는 환경변수(02장 8절). 오픈소스 보이스는 `VOICE_ARCHITECTURE.md` 4.1절 후보 중 코드·가중치 라이선스와 한국어 낭독 품질을 확인해 고른다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:63-73`). 생성 음성의 상업 이용 조건과 데이터 보관 조건은 ElevenLabs 계약으로 구현 시 확인하고 처리방침에 반영(`:81-83`) |
| D-17 | 채팅 화면 레퍼런스 Astryx | 존재·라이선스 확인 후 패턴만 사용 / 확인 실패 시 Primer + shadcn/ui 패턴 | 확인 전까지 미확인(`docs/products/_design-guide/DESIGN_SYSTEM.md:11`). AS-06-039에서 확인 결과를 기록 |
| D-18 | 워커의 그래프 호출 인증 | (a) Next.js 잡 토큰 발급 엔드포인트(02장 4절) (b) FastAPI가 잡을 직접 소비하고 렌더도 Python으로 (c) 워커에 개인키 배포 | (a)(제안). 개인키는 Next.js에만 둔다는 코어 규칙(`docs/products/_platform-core/SECURITY_BASELINE.md:284`)을 지킨다. 코어 표준화 요청 R-8 |

### 8.1 인증 단계 결정 (2026-10-14, 확정 결정 22)

확정 결정 22(`docs/products/00_MERGE_ANALYSIS.md:30`)로 로그인은 A Mock → G1 → B Google + 이메일 → G2 → C1 카카오, C2 네이버 순서로 켠다(`docs/products/_platform-core/AUTH_ROADMAP.md` 0장, 8장 astro-ai 행). 단계 순서와 우선순위(B P0, C1·C2 P1)는 확정이고, 아래 3개가 남은 결정이다. 이 기획에는 기존 카카오 로그인 열린 결정이 없었다(카카오 알림톡은 로그인과 무관한 Phase 2 발송 기능, 2절).

| ID | 결정 | 선택지 | 권고와 이 기획의 가정 | 확정 시점 |
|---|---|---|---|---|
| D-19 | 카카오 로그인 이메일 정책 | (a) 비즈 앱 전환 후 `account_email` 필수 동의 (b) 이메일 없이 허용, 결제·발송 전 연락 이메일 입력 | (a)(`AUTH_ROADMAP.md` 7.1.2절 권장). astro는 PDF 이메일 발송(AS-F-017)과 결제 영수증이 이메일에 기대고, Google·이메일 가입자와 같은 사람을 한 계정으로 묶어야 환영 크레딧 중복 수령(AS-F-002)을 줄일 수 있다. (b)는 비즈 앱 전환 전 임시로만 | G2 판정 전(C1 착수 전) |
| D-20 | 네이버 로그인 경로 | (a) Supabase 커스텀 OAuth2 `custom:naver` (b) 서버 브리지 + 코어 `staged/0010_core_auth_identity_links.sql` | C2 작업 첫 단계 스파이크(`AUTH_ROADMAP.md` 7.2.2절, 0.5일) 결과로 정한다. 결과는 task `log.md` `[DECISION]`과 `NAVER_AUTH_PATH`에 남긴다. 브리지면 06장 8절의 코어 요청 R-14 | C2 스파이크 직후 |
| D-21 | 이메일+비밀번호 가입 유지 | (a) 유지(Stage B에 Google과 함께 켠다) (b) 빼고 소셜 로그인만 | (a). 기존 결정(AS-F-001, `docs/products/00_MERGE_ANALYSIS.md:313`)을 바꾸지 않는다. 이메일 인증 완료가 환영 크레딧 지급 조건(AS-F-002)이라 이메일 경로가 남아 있어야 소셜 계정이 없는 사용자도 크레딧을 받는다 | G1 판정 전(B 착수 전) |

## 9. 대시보드 셸·GNB 결정 대기 (2026-10-19 추가, 03장 8장)

03장 8장(헤더 + 좌측 GNB + 홈 구성)에서 사용자 결정이 필요한 항목이다. 결정 전에는 03장 8.1절 기본값으로 시안과 문서를 둔다. 신비로운AI 전용이고 다른 제품에는 적용하지 않는다. 1~8장은 그대로 둔다(다른 문서가 줄 번호로 인용한다). 번호는 8장 열린 결정(D-1~D-21)에 이어 붙였다.

| ID | 결정 | 선택지 | 권고와 이 기획의 가정 | 확정 시점 |
|---|---|---|---|---|
| D-22 | GNB 바탕색 | (a) 쪽빛 #23304A GNB(03장 4.3절 :259 그대로), 메뉴 글자 백자 (b) 백자 계열 밝은 GNB, 쪽빛은 현재 위치 막대와 primary 버튼에만 | (b)(제안). 금니는 "강조 1곳"(명식표 격자 선, 주 CTA, 혼천의, 03장 4.3절 :263)이라 셸에 쓸 수 없고, (a)에서는 쪽빛 위 현재 위치를 백자 명도 차이로만 구분해야 한다. 쪽빛은 primary 버튼 바탕(03장 3.2절 :219)이기도 해 (a)는 GNB와 버튼이 같은 면 색이 된다. (a)를 고르면 03장 8.6절 색 행과 시안 토큰을 다시 정한다 | AS-06-040(디자인 사람 검토) |
| D-23 | 헤더 검색 범위 | (a) 메뉴 이름과 원본 기능 이름만 (b) (a) + 보관함 호칭(`alias`) (c) 검색 없음 | (b)(제안). 호칭은 평문 컬럼(05장 :66)이라 복호화 없이 찾을 수 있고, 보관함 상한이 20명(AS-F-003)이라 조회 비용이 작다. 생년월일·실명·질문(암호화 필드)과 리포트 본문은 어떤 선택지에서도 검색하지 않는다 | AS-06-021 착수 전 |
| D-24 | AI 채팅 패널 여는 곳 | (a) 헤더 "AI에게 묻기" 버튼 + 리딩 상세 "이 리포트에 대해 묻기" (b) 화면 오른쪽 아래 떠 있는 버튼 + 리딩 상세 (c) 리딩 상세와 GNB "AI 대화"에서만 | (a)(제안). 03장 1절 :27이 패널을 "모든 `/dashboard/*` 오른쪽 시트"로 정했지만 여는 곳은 적지 않았다. (b)는 375px에서 리딩 시작 스테퍼의 확인 버튼과 겹칠 수 있다(미확인, 시안에서 확인). (c)는 용어 질문(2.6절 4단계)을 하려면 리포트가 있어야 하는 것처럼 보인다 | AS-06-050 착수 전 |
| D-25 | 셸 밖 링크(용어 위키, 운영 콘솔) | (a) GNB 아래 고정 링크 2개: "용어 위키 ↗"(모두), "운영 콘솔 ↗"(`platform_admin`만), 새 탭 (b) 같은 탭에서 연다 (c) 링크 없음(위키는 채팅 답변의 위키 링크로만, 운영 콘솔은 주소 직접 입력) | (a)(제안). 공개 위키는 셸 밖 레이아웃(03장 1절 :28, ISR)이라 같은 탭으로 가면 진행 중인 리딩 화면과 채팅 패널을 잃는다. 운영 콘솔 링크는 구조 공유가 아니고 일반 사용자에게는 렌더하지 않는다. 일반 사용자의 `/api/admin/*` 호출 403은 그대로(AS-F-022) | AS-06-021 착수 전 |

| 결정 | 기본값과 다르게 정하면 고칠 곳(영향) |
|---|---|
| D-22 (a) | 03장 8.1절 GNB 바탕색 행, 8.6절 현재 위치·색 행, 8.8절 4.3절 쪽빛 행, 디자인 config 토큰(`nav`, `raised`, 현재 위치 색) |
| D-23 (a)·(c) | 03장 8.2절 검색 행, 8.1절 검색 행, 디자인 config `searchHint` |
| D-24 (b)·(c) | 03장 8.2절 AI에게 묻기 행, 8.4절 채팅 패널 행, 8.8절 채팅 패널 행, 8.7절 신규 AI 채팅 행 |
| D-25 (b)·(c) | 03장 8.3절 용어 위키·운영 콘솔 행, 8.4절 위키 행, 8.7절 어드민 6탭·위키 행, 디자인 config `connected` |


## 10. 사주·타로 확장 기획 (2026-10-19 추가, 08·09 문서 근거)

이 장은 대표 요청 4가지(타로 기능 추가와 경쟁사 벤치마킹, 연화선녀 기획 반영, 명리학 논문을 근거로 한 연애·이직 등 주제별 풀이, 좌측 GNB 항목 확대)를 기획으로 정리한다. 근거는 `08_BENCHMARK.md`(경쟁사 벤치마킹, 이하 08 문서)와 `09_MYEONGRI_BASIS.md`(명리 해석 근거, 이하 09 문서)다. 화면과 GNB는 03장 9장이 맡는다. 1~9장은 그대로 두고(다른 문서가 줄 번호로 인용한다) 이 장은 덧붙이기만 한다. 이 장의 새 기능은 모두 P1 또는 Phase 2이며 MVP 범위(2절)를 넓히지 않는다. 이 장의 결정 대기 항목(10.8절, D-26~D-33)이 승인되기 전까지 2절 범위, 4절 단가, 03장 8장 GNB가 정본이다.

### 10.1 배경·목표·차별화

#### 10.1.1 배경

| 대표 요청 | 이 장의 대응 |
|---|---|
| "타로 기능을 추가하고, 경쟁업체를 벤치마킹해서 더 복잡한 구조의 기획으로" | 경쟁사 25곳 조사(08 문서). 타로를 스프레드 라이브러리, 덱 선택, 역방향 설정, 카드 도감, 타로 일기, 사주×타로 통합 질문으로 확장(10.3절) |
| "사주의 경우 연화선녀의 기획 등을 더 추가" | 1차 출처로 확인되는 "연화선녀" 서비스는 없다(08 문서 2.1절). 같은 이름의 개인 상담소에서 확인된 정서적 위로형 말투, 가족 단위 상품, 계절 의례 캘린더만 가져오고(08 문서 2.5절), 대상 서비스는 대표가 확인한다(D-32) |
| "명리학 박사의 논문 등을 참고하고, 연애·이직 등을 풀어 주는 콘텐츠" | 박사·석사논문과 학술논문을 확인 등급(A/B/C)과 함께 정리(09 문서 2절). 주제별 풀이 10종과 6레이어 해석 엔진(10.4절) |
| "좌측 GNB 항목이 너무 없다. 벤치마킹해서 추가" | GNB를 7개 메뉴에서 34개 메뉴(묶음 7개 + 아래 고정)로 확장하는 안(03장 9장, D-26) |

#### 10.1.2 벤치마킹 요약 (08 문서 요약표)

| 관점 | 경쟁사 현황 | 신비로운AI에 주는 시사점 |
|---|---|---|
| 결과물 | 웹 화면 또는 "한 장 리포트"(척척사주). 책에 가까운 사례는 우주고양이 보라의 약 50쪽 신년운세 하나(사주 단일)(08 문서 1.4절, 1.6절) | "사주×타로 한 권의 책"은 비어 있는 자리다 |
| 타로 깊이 | Labyrinthos가 기준점: 덱 여러 종, 스프레드 70개 이상과 빌더, 역방향 끄기, 저널과 Mirror 패턴 리포트, 학습(08 문서 3.5절). 국내 앱은 주제별 리딩 수준이 많고 상세는 (미확인)(08 문서 4.1절) | 국내에서 덱·스프레드·일기를 갖춘 리포트형 서비스는 확인되지 않았다 |
| 리텐션 | 오늘의 카드와 데일리 푸시, 출석 보상, 친구 그래프, 지인 프로필(08 문서 4.2절) | 매일 오는 이유(오늘)와 남는 이유(서재)를 함께 만든다 |
| 페르소나 | 청월당·텔링·헬로우봇·사주GPT가 해석자 캐릭터를 상품 단위로 쓴다(08 문서 1.6절, 1.3절) | 해석자 캐릭터 선택(문체만 바꾸고 근거·규칙은 같게) |
| 불만 | 결과가 일반적이다, 같은 질문에 답이 다르다, 기록이 사라진다, 가격이 불투명하다, 광고가 많다(08 문서 1절, 3절) | 근거 각주, 재질문 쿨다운, 기록 소유권, 단일 가격표 |

#### 10.1.3 목표

| 목표 | 성공 조건(10.6절 KPI) |
|---|---|
| 매일 들를 이유를 만든다 | 오늘의 카드 7일 재방문율 25%(제안) |
| 주제별 질문을 책으로 판다 | 오늘 메뉴 이용자의 주제별 풀이 첫 구매 8%(제안) |
| 타로를 기록 자산으로 만든다 | 타로 리딩 완료 중 일기 작성 30%(제안) |
| 신뢰를 지킨다 | 금지 문구 검출 출고 0건, 청약철회 분쟁 0건 |

#### 10.1.4 차별화 5가지 (08 문서 7절)

| # | 차별화 | 내용 | 이 장에서 구현하는 곳 |
|---|---|---|---|
| 1 | 사주×타로 한 권의 책 | 명식, 대운 연표, 주제별 풀이, 그해의 타로 리딩 기록과 일기를 장으로 엮은 A4 PDF 책(목차, 판권면). 연말 "나의 1년 타로 연감"(Phase 2) | AS-F-043, AS-F-044, AS-F-066, AS-F-068, AS-F-078 |
| 2 | 해석 근거 각주와 일관성 | 장마다 "근거 노트"(본 명리 요소, 카드 정·역과 자리 의미, 참고 연구 번호)를 각주로 보인다. 같은 질문 24시간 재뽑기 대신 "심화"로 안내한다 | AS-F-044, AS-F-062, AS-F-072 |
| 3 | 기록 소유권 | 모든 리딩을 자동 저장하고 제목·태그를 달며 PDF·이미지로 내보낸다(Trusted Tarot·Sanctuary 기록 유실 불만 대응) | AS-F-064, AS-F-068 |
| 4 | 불안 마케팅 배제와 건강한 사용 | 흉살·29금·재회 집착 상품과 굿·부적 업셀을 하지 않는다. 성찰형 문체와 하루 리딩 횟수 안내 | AS-F-073, AS-F-075, 10.7절 |
| 5 | 투명한 단일 가격표 | "책 1권 = 정가", 크레딧 무기한(4.4절 :142 유지), 웹·앱 가격 차이가 있으면 이유를 고지 | 10.5절 |

### 10.2 확장 범위 표

| 기능 | 단계 | 근거 |
|---|---|---|
| 사주 리딩, 타로 3카드 리딩(메이저 22장), 통합 리딩 | MVP 유지 | 2절 :28, AS-F-009~011(:62-64) |
| 프로필 보관함, 만세력 엔진, 원국 프리뷰, 대운 타임라인 | MVP 유지 | 2절 :26-27, AS-F-003(:56), AS-F-006~008 |
| A4 PDF, 테마 2종, 이메일 발송, 리딩 히스토리 | MVP 유지 | 2절 :29-30 |
| AI 채팅, 위키, 음성, 낭독 | MVP 유지 | 2절 :36-38 |
| 크레딧팩 결제, 실패 자동 환불 | MVP 유지 | 2절 :31-32 |
| 오늘의 운세, 오늘의 카드 | P1 | 08 문서 6절 3항, 8.2절 |
| 주간·월간 운세 | P1 | 08 문서 1.4절(척척사주 월간운세), 3.3절(Sanctuary 일·주·월·연) |
| 신년 운세 책(= 2절 :44 연간 운세 12섹션) | Phase 2 → P1 앞당김 (D-33) | 2절 :44, 08 문서 6절 10항(12~2월 신년 특수) |
| 주제별 풀이 10종과 6레이어 엔진 | P1(건강 주의는 Phase 2, D-33) | 09 문서 3절, 4절 |
| 결혼·궁합(2인) | Phase 2 → P1 앞당김 (D-33) | 2절 :44, 09 문서 4.2절 |
| 만세력·명식 조회, 대운·세운 타임라인 확장 | P1 | 08 문서 1.1절(포스텔러 만세력), 1.4절(척척만세력), 09 문서 3.2절 |
| 타로 스프레드 라이브러리(20종), 덱 선택과 78장, 역방향 on/off, 질문 템플릿, 뽑기 연출 | P1 | 08 문서 3.5절, 3.7절, 8.2절 |
| 카드 도감(학습 퀴즈는 Phase 2) | P1 | 08 문서 3.5절, 3.7절 |
| 타로 일기 | P1 | 08 문서 3.5절, 6절 4항 |
| 패턴 리포트(Mirror형), 타로 연감 PDF | Phase 2 | 08 문서 8.2절 |
| 사주×타로 통합 질문 리딩 | P1 | 08 문서 8.2절, 09 문서 2.7절 M4 |
| 해석자 캐릭터 선택(2종) | P1 (D-28) | 08 문서 1.6절, 2.5절, 6절 2항 |
| 리포트 서재, 가족·지인 그룹, 친구 궁합 공유 링크, 알림·출석 | P1 | 08 문서 6절 3·7·8항, 7절 3항 |
| 해석 근거·참고 연구 공개 | P1 | 09 문서 6절, 8절 표시광고법 행 |
| 모바일 하단 탭 | P1 (D-27) | 08 문서 8.1절 |
| 전문가 상담 연결 | Phase 2 이후 (D-30) | 08 문서 1.7절, 5절 8항 |
| 커스텀 스프레드 빌더, 추가 덱 판매 | Phase 2 | 08 문서 3.5절, 8.2절 |
| 구독 플랜 | Phase 2 유지 | 2절 :43 |
| 굿·부적·액막이 상품, 흉살·29금 상품, 재회 확률 상품 | 하지 않음 | 08 문서 2.5절, 7절 4항 |

### 10.3 기능 요구사항

AS-F-039는 비워 둔다(번호 충돌 방지 여유). 처리 열 대신 구분 열에 "신규/확장 · 단계"를 적는다. 단가는 10.5절, 화면은 03장 9.3절.

| ID | 기능 | 구분 | 설명 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| AS-F-040 | 오늘의 운세 | 신규 · P1 | 본인 프로필 일주와 오늘 일진(엔진 계산)으로 한 줄 운세와 분야 4줄(일·돈·관계·나)을 만든다. 같은 날 같은 프로필은 같은 결과(날짜·프로필 키로 캐시). "전통 해석에서는 ~로 봅니다" 문형만 쓴다. 0크레딧 | 같은 날 다시 열어도 문장이 같다. 금지 문구(6.4절, 09 문서 4절) 검출 0건. 결과 칩에 "AI 생성" 표시. 본인 프로필이 없으면 등록 안내 | 08 문서 6절 3항, 09 문서 4.10절 |
| AS-F-041 | 오늘의 카드 | 신규 · P1 | 하루 1장 무료. 카드 뽑기는 브라우저 난수(AS-F-010과 같은 방식), 서버는 하루 1회만 저장한다. 한 줄 해석 + 일주 연계 문장 1개. 알림 시간 설정(AS-F-071) | 같은 날 두 번째 뽑기는 409와 첫 카드 표시. 카드 이미지·이름·정역·한 줄 해석·"AI 생성" 표시. 역방향 설정(AS-F-059)을 따른다 | 08 문서 3.4절, 3.7절, 8.2절 |
| AS-F-042 | 주간·월간 운세 | 신규 · P1 | 주간: 7일 흐름 요약(0크레딧). 월간: 이달 월운과 원국의 합·충(AS-F-056)으로 분야별 흐름 + 날짜 캘린더(5크레딧, 제안). 월초 알림 | 월운 간지가 엔진 값과 같다. 날짜를 못 박은 사건 예언 0건(6.5절 :303) | 08 문서 3.3절, 09 문서 4.10절 |
| AS-F-043 | 신년 운세 책 | 확장(2절 :44 연간 운세) · D-33 | 4.2절 :116 연간 운세 리포트(50크레딧, 12섹션)를 "신년 운세 책"으로 연다: 올해 키워드 3개, 분야별 흐름, 월별 에너지 캘린더 12개월, 실천 과제와 회고 질문. 12월 이전 출시(제안) | 장 12개 생성, 월별 간지가 엔진 값과 일치. "삼재라 큰 사고" 같은 공포 문구 0건 | 08 문서 1.7절(12~2월 신년 특수), 6절 10항, 09 문서 4.10절 |
| AS-F-044 | 주제별 풀이 공통(6레이어 엔진) | 신규 · P1 | 주제 1종을 4~5장 책으로 만든다. 그래프 `astro.reading`에 주제 키를 넘기고, 엔진이 레이어별 값(10.4절)을 계산해 `chart`에 넣는다. 장마다 "근거 노트"와 "스스로 점검하기"(09 문서 3.3절). 격국·조후는 D-10(:345)에 따라 판정하지 않고 엔진 계산값(월지 십신, 출생 계절)만 쓴다. 15크레딧(제안) | 장마다 근거 노트 1개 이상과 점검 질문 2~3개. 본문 수치가 엔진 값과 100% 일치. 격국·용신 판정 문형 0건. 주제별 필수 문구 포함 | 09 문서 3절, 4절, AS-F-029(:82) |
| AS-F-045 | 연애운 | 신규 · P1 | 09 문서 4.1절 장 구성 5장. 근거 요소: 일지(배우자궁)와 일지 십신, 도화·홍염(보조 박스), 세운과 일지의 합·충 | 09 문서 4.1절 금지 표현 0건. 성 역할 고정 문장 0건(6.4절 차별 행). 도화·홍염은 "전통 상징" 박스 안에만 | 09 문서 4.1절, 2.1절 L2·L6·L8·L9 |
| AS-F-046 | 결혼·궁합(2인) | 확장(2절 :44 궁합) · D-33 | 보관함 대상 2명(또는 공유 링크로 응답한 친구, AS-F-070). 일간 생극, 일지 합·충·형, 십성 보완표, 두 사람의 운 그래프 겹쳐 보기. 25크레딧(4.2절 :117) | 점수·등급 표시 0건. "결혼하면 이혼" 같은 단정 0건. 제3자 동의(AS-F-004) 없는 대상 선택 불가 | 09 문서 4.2절, 2.1절 L1·L4·L5 |
| AS-F-047 | 이직·직장운 | 신규 · P1 | 09 문서 4.3절 장 구성 5장. 월지(사회궁)와 대운·세운의 합·충, 관성·식상 균형. 4장에 "옮긴다면 / 남는다면" 체크리스트 | 필수 문구("이직 결정은 경력, 재정, 시장 상황…") 장 1회 이상. "○월에 그만두세요" 같은 날짜 지시 0건 | 09 문서 4.3절, 2.2절 J3·J4·J5 |
| AS-F-048 | 진로 적성 | 신규 · P1 | 월지 십신, 보완 오행, 십신 → 팀 역할표(J6). MBTI는 선택 입력(4자, 저장은 대상 단위 제안)이고 비교 장만 붙는다 | MBTI 없이도 4장 생성. "의사가 될 운명" 같은 직업 단정 0건 | 09 문서 4.4절, 2.2절 J1·J2·J6, 2.6절 P3·P4 |
| AS-F-049 | 재물운 | 신규 · P1 (D-33) | "돈 그릇과 습관, 버는 방식, 새는 지점, 올해 흐름, 실천 체크리스트". 월별 그래프는 "에너지 흐름"이라고 표시 | 필수 문구("투자 판단은 금융 전문가와…") 표지 다음 쪽과 4장에. 종목·코인·부동산·매매 시점 0건(6.4절 :275) | 09 문서 4.5절, 2.3절 W1·W4 |
| AS-F-050 | 학업운 | 신규 · P1 | 인성형/식상형 배움 스타일, 집중 시간, 올해 공부 흐름, 학습 계획 템플릿. 미성년 대상 프로필이면 겁주는 표현 차단을 한 단계 강하게 적용 | "합격/불합격" 예측 0건. 14세 미만 대상은 법정대리인 등록(6.1절 :243)만 | 09 문서 4.6절, 2.5절 |
| AS-F-051 | 대인관계 | 신규 · P1 | 십신 관계 지도, 돕는 사람·부딪히는 사람 유형, 갈등 반응 패턴, 올해 관계 흐름 | 띠로 사람을 멀리하라는 문장 0건, 실존 인물 지목 0건 | 09 문서 4.7절, 2.6절 P1·P3·P5 |
| AS-F-052 | 이사·택일 | 신규 · P1 | 올해 움직이기 편한 달(전통 해석), 전통 방위, 현실 체크. 첫 장에 "근거가 약한 전통 해석" 표시 | "이 날 아니면 우환" 0건. 날짜 변경을 조건으로 한 추가 결제 0건 | 09 문서 4.8절 |
| AS-F-053 | 건강 주의(의료 아님) | 신규 · Phase 2 (D-33) | 오행 균형과 생활 리듬, 계절 기질과 컨디션 관리 팁, "몸이 보내는 신호는 의사에게". 법무 검토 뒤 연다 | 장 첫머리 고정 문구 100%. 질병명·장기 이름·발병 시기·치료 권유 0건. 타로 결합 없음 | 09 문서 4.9절, 6.3절 :265 |
| AS-F-054 | 올해·이달 흐름 | 신규 · P1 | 주제 리포트형(4장): 키워드 3개, 분야별 흐름, 월별 캘린더, 실천 과제. 신년 운세 책(AS-F-043)의 축약판 | 월별 간지 엔진 일치. "대흉" 0건 | 09 문서 4.10절 |
| AS-F-055 | 만세력·명식 조회 | 신규 · P1 | 날짜(양·음력)를 넣으면 그날의 년·월·일·시 간지와 절기를 보여 준다(브라우저 엔진, 입력 서버 미전송, AS-F-007과 같은 방식). 보관함 대상을 고르면 명식표·오행 막대·십신·지장간 표 | 골든 테스트(AS-F-006) 통과 엔진만 사용. 입력 변경 후 100ms 안에 갱신. 명식표는 HTML `table` | 08 문서 1.1절, 1.4절, AS-F-006·007 |
| AS-F-056 | 대운·세운 타임라인 확장 | 확장(AS-F-008) · P1 | 대운(기존) 아래에 세운 10년, 월운 12개월을 더한다. 원국과의 합·충·형 표시(엔진 확장). 현재 구간 강조, 읽기 전용 | 세운·월운 간지와 합·충 결과가 골든 테스트(추가 30건, 제안)와 일치. 사건 예언 문장 없음(표만) | 09 문서 3.2절, AS-F-008(:61) |
| AS-F-057 | 타로 스프레드 라이브러리 | 신규 · P1 | 20종(제안): 원카드, 예/아니오, 3카드(과거/현재/미래, D-11 :346), 상황/장애/조언, 2지선다, 관계(내 마음/상대 마음/관계를 위해 할 일), 켈틱크로스(10장), 월간, 연간 12하우스 등. "재회" 대신 "관계 회복" 이름 | 스프레드마다 자리 이름·자리 의미가 있다. 스프레드 정의는 코드 상수 또는 표(10.5절, 03장 9.7절)로 하나만 둔다 | 08 문서 3.5절, 3.7절, 8.2절 |
| AS-F-058 | 덱 선택과 78장 | 확장(AS-F-010) · P1 (D-29) | 메이저 22장(기존)에서 78장으로 확장. 덱 1종(자체 제작, 제안)으로 시작하고 덱 선택 칸을 둔다. 해설집 RAG(AS-F-030)에 마이너 56장 정·역 해설 추가 | 덱마다 이용 허락 근거가 기록된 것만 노출. 78장 정·역 해설 156항목 검수 완료 | 08 문서 3.5절 덱 라이선스 시사점, AS-F-030(:83) |
| AS-F-059 | 역방향 on/off | 신규 · P1 | 설정과 리딩 시작에서 고른다. 끄면 모든 카드 정방향으로 뽑고 해석도 정방향만 쓴다 | 끔 상태에서 역방향 카드 0장. 리딩 기록에 설정값 저장 | 08 문서 3.5절, 8.2절 |
| AS-F-060 | 질문 템플릿 | 신규 · P1 | 주제별 예시 질문(연애, 일, 관계, 나)을 칩으로 고른다. 질문은 300자(제안, 기존 200자 :216은 리딩 PDF에 유지). 예/아니오형 질문은 "무엇을 하면 좋을까"형으로 바꾸도록 안내 | 질문 칩 1개 이상 선택 또는 직접 입력. 민감 정보 안내 문구 표시 | 08 문서 3.8절(Tarotap 300자), 8.2절 |
| AS-F-061 | 뽑기 연출 | 확장(AS-F-010) · P1 | 섞기 → 부채꼴 펼치기 → 직접 고르기 또는 자동 고르기. 카드 뒤집기는 사용자가 눌러야 움직인다. reduced-motion이면 즉시 표시 | 키보드로 고를 수 있다(03장 6절 :434). reduced-motion 즉시 표시(:437). 같은 카드 중복 선택 불가 | 08 문서 3.5절, 3.7절, 03장 4.1절 :241-242 |
| AS-F-062 | 재질문 쿨다운 | 신규 · P1 | 같은 질문(정규화 해시)을 24시간 안에 다시 뽑으면 막고 "이전 리딩 심화 질문"으로 안내 | 24시간 안 같은 해시 재뽑기 409와 이전 리딩 링크. 심화 질문은 채팅 턴 단가(4.7절 :180) | 08 문서 7절 2항 |
| AS-F-063 | 카드 도감·학습 | 신규 · P1(퀴즈 Phase 2) | 78장 정·역 의미, 키워드, 상징. 위키(AS-F-031) 타로 분류 페이지를 그대로 쓰고 따로 원고를 만들지 않는다. 내가 뽑은 횟수 표시 | 도감 항목이 `published` 위키 페이지와 1:1. 출처·"AI가 정리하고 운영자가 검수한 문서" 표시 | 08 문서 3.5절, 3.7절, AS-F-031(:84) |
| AS-F-064 | 타로 일기 | 신규 · P1 | 리딩마다 메모·감정 태그·제목·태그. 7일 뒤 "실제로 어땠나" 회고 알림(선택). 메모는 암호화 저장 | 메모 평문 저장 0건. 리딩 삭제 시 일기 함께 삭제. 무료 사용자 일기 개수 제한 없음 | 08 문서 3.5절(저널 제한 반발), 7절 3항 |
| AS-F-065 | 패턴 리포트(Mirror형) | 신규 · Phase 2 | 월간·연간 자주 나온 카드, 수트, 역방향 비율. 10크레딧(제안) | 수치는 저장된 리딩 기록 집계만 | 08 문서 3.5절, 8.2절 |
| AS-F-066 | 사주×타로 통합 질문 리딩 | 신규 · P1 | 질문 하나에 사주(일간, 오행 점수, 십신, 올해 세운)와 타로 스프레드 결과를 함께 풀어 "내 사주에서 이 카드의 의미"를 덧붙인다. 화면 리딩 10크레딧(제안), 책은 통합 리딩 30크레딧(:64) | 사주 근거와 카드 근거가 각각 각주로 보인다. 용신 판정 문형 0건 | 08 문서 8.2절, 09 문서 2.7절 M4, 4절 타로 결합 |
| AS-F-067 | 해석자 캐릭터 선택 | 신규 · P1 (D-28) | 문체만 다른 해석자 2종(제안): 차분한 해설가(기본), 다독이는 선녀(위로형). 근거·금지 규칙·수치는 같다. 캐릭터 이름·그림은 자체 제작하고 경쟁사 캐릭터를 흉내 내지 않는다 | 같은 입력에 캐릭터만 바꾸면 근거 노트와 수치가 같다. 머리말·맺음말만 달라진다 | 08 문서 1.6절, 2.5절, 09 문서 5.1절 |
| AS-F-068 | 리포트 서재 | 신규 · P1 | 만든 PDF 책을 책장 모양으로 모은다. 제목·태그 편집, 묶음(가족 사주책 등), 다시 받기(7일 서명 URL, AS-F-016) | 30일 뒤에도 다시 받기 성공. 리딩 히스토리와 같은 데이터(새 저장소 없음) | 08 문서 7절 1·3항, AS-F-016 |
| AS-F-069 | 가족·지인 프로필 그룹 | 확장(AS-F-003) · P1 | 보관함 대상을 그룹(가족, 친구 등)과 즐겨찾기로 묶는다. 상한은 기존 20명(:160) 그대로, 슬롯을 팔지 않는다 | 그룹 삭제 시 대상은 남는다. 제3자 동의 규칙(AS-F-004) 그대로 | 08 문서 1.1절, 3.2절, 6절 7항 |
| AS-F-070 | 친구 궁합 공유 링크 | 신규 · P1 | 공유자가 링크를 만들면 친구가 링크에서 로그인 후 자기 정보를 직접 넣고 동의한다. 결과는 두 사람 모두 보고, 상대의 생년월일 원문은 서로 보이지 않는다. 링크 7일 만료, 1회 응답 | 친구 동의 기록 없이 궁합 생성 0건. 공유자 화면에 친구 생년월일 0건. 만료 링크 410 | 08 문서 6절 8항, 5절 7항, AS-F-004 |
| AS-F-071 | 알림·출석 | 신규 · P1 | 오늘의 카드 알림 시간, 월초 운세, 시즌(입춘·초파일·추석·신년), 타로 일기 회고 알림. 출석은 스탬프와 연속 기록만(보상 크레딧 없음, 제안) | 알림 끄기 한 번에 가능. 야간(21~08시) 마케팅 알림 0건(제안, 법무 확인). 출석 보상으로 지급된 크레딧 0 | 08 문서 1.1절, 2.5절 3항, 6절 3항 |
| AS-F-072 | 해석 근거·참고 연구 공개 | 신규 · P1 | 09 문서 2절의 A·B 등급 서지를 주제별로 보여 준다. C 등급은 원문 확인 전까지 숨긴다. "명리학이 과학적으로 입증되었다는 뜻이 아니다" 문장 고정 | 화면과 PDF 부록에 C 등급 0건. "박사가 감수", "입증" 문구 0건 | 09 문서 1.2절, 6절, 8절 |
| AS-F-073 | AI 생성·면책 표시 확장 | 확장(AS-F-038) · P1 | 오늘의 운세·카드, 주제 리포트, 타로 화면 리딩에 "AI 생성" 칩. 책 표지 안쪽 고정 문구(09 문서 6절) | 새 결과 화면 100%에 표시. PDF 표지 안쪽 문구 100% | 08 문서 5절 1항, 6.2절 :253-254 |
| AS-F-074 | 청약철회 제한 표시와 미리보기 | 신규 · P1 | 책을 만들기 전 목차와 샘플 1장을 무료로 보여 주고, 확인 버튼 옆에 "만들기 시작 후에는 사용한 크레딧을 돌려받을 수 없습니다(생성 실패 제외)"를 표시하고 동의를 기록한다 | 미리보기 없이 생성 0건. 동의 기록 없는 생성 0건. 생성 실패는 기존 자동 환불(AS-F-012) | 08 문서 5절 5항, 09 문서 8절, 4.5절 :150 |
| AS-F-075 | 건강한 사용 안내 | 신규 · P1 | 하루 리딩 10회(제안)를 넘기면 "오늘은 충분히 물어보셨어요" 안내를 한 번 보인다(막지는 않음). 흉한 해석 바로 뒤에 결제 버튼을 두지 않는다 | 안내 노출 로그. 흉운 문단 다음 화면 요소에 결제 버튼 0건 | 08 문서 7절 4항, 09 문서 8절 |
| AS-F-076 | 전문가 상담 연결 | 신규 · Phase 2 이후 (D-30) | 검수된 상담사, 30초 단위 과금, 상담 기록 저장, 굿·부적·초 권유 금지 약관 | 금지 조항 약관 동의 없는 상담사 등록 0건 | 08 문서 1.7절, 3.3절, 5절 8항 |
| AS-F-077 | 커스텀 스프레드 빌더 | 신규 · Phase 2 | 자리 수(1~10)와 자리 이름·의미를 직접 정의 | 자리 의미 없는 스프레드 저장 불가 | 08 문서 3.5절 |
| AS-F-078 | 타로 연감 PDF | 신규 · Phase 2 | 1년치 리딩, 일기, 패턴, 사주 세운 해설을 한 권으로. 50크레딧(제안) | 연감에 들어간 리딩 수와 기록 수가 같다 | 08 문서 7절 1항, 8.2절 |
| AS-F-079 | 모바일 하단 탭 | 신규 · P1 (D-27) | 1024px 미만에서 하단 탭 5개(03장 9.5절). 좌측 GNB 서랍은 그대로 | 하단 탭이 채팅 패널·스테퍼 확인 버튼을 가리지 않는다 | 08 문서 8.1절, 03장 6절 :438 |

### 10.4 주제별 풀이 체계

#### 10.4.1 6레이어 해석 엔진

정본은 09 문서 3절이다. LLM은 엔진이 계산한 값을 문장으로 풀기만 한다(D-10 :345, AS-F-029 :82).

| 레이어 | P1 엔진 입력(결정적 계산) | 하지 않는 것 | 09 문서 |
|---|---|---|---|
| 억부 | 오행 점수, 십신 분포(AS-F-006) | 엔진 규칙 없는 신강·신약 판정 | 3.1절, 3.2절 |
| 격국 | 월지 간지와 월지 십신 | 격국 이름·격국용신 판정(D-10 Phase 2) | 3.2절 |
| 조후 | 출생 계절, 오행 한난조습 표시 | 조후용신 판정(D-10 Phase 2) | 3.2절 |
| 궁위 | 4주 자리와 각 자리 간지·십신(일지 = 배우자궁, 월지 = 사회궁) | - | 3.1절 |
| 운 | 대운(기존), 세운·월운 간지, 원국과의 합·충·형(AS-F-056) | 날짜를 못 박은 사건 예언 | 3.2절 |
| 신살(보조) | 도화·홍염·역마 표 조회 | 신살로 길흉 단정. 본문이 아닌 "전통 상징" 박스에만 | 3.1절 |

#### 10.4.2 주제 × 근거 요소 × 장 구성

레이어 가중치 표시: 주 = 주된 근거, 보 = 보조, - = 쓰지 않음. 가중치는 (제안)이며 평가셋으로 조정한다.

| 주제(AS-F) | 억부 | 격국 | 조후 | 궁위 | 운 | 신살 | 근거 요소 | 장 구성 | 근거 연구 | 09 문서 |
|---|---|---|---|---|---|---|---|---|---|---|
| 연애운(045) | 보 | - | - | 주 | 주 | 보 | 일지와 일지 십신, 세운과 일지의 합·충, 도화·홍염 | 연애 기질 / 끌리는 사람 / 매력 표현 / 올해 인연 흐름 / 스스로 점검 | L2, L6, L8, L9 | 4.1절 |
| 결혼·궁합(046) | 보 | - | - | 주 | 주 | - | 두 일간 생극, 일지 합·충·형, 십성 보완, 운 겹쳐 보기 | 기본 결 / 채워 주는 부분 / 부딪히는 지점과 대화법 / 함께 넘을 시기 / 점검 질문 10 | L1, L3, L4, L5, L7 | 4.2절 |
| 이직·직장운(047) | 보 | 주 | 보 | 주 | 주 | - | 월지와 대운·세운 합·충, 관성·식상 균형 | 일하는 방식 / 지금 직장과 나 / 변화 신호 시기 / 옮긴다면·남는다면 / 현실 조건 | J3, J4, J5, J7 | 4.3절 |
| 진로 적성(048) | 보 | 주 | 보 | 보 | - | - | 월지 십신, 보완 오행, 십신 역할표, MBTI(선택) | 일의 결 / 힘이 나는 분야 / 팀 역할 / MBTI 비교 / 실천 과제 | J1, J2, J6, P3, P4 | 4.4절 |
| 재물운(049) | 주 | 보 | - | 보 | 주 | - | 재성 강약, 식상생재, 비겁(지출) | 돈 그릇과 습관 / 버는 방식 / 새는 지점 / 올해 흐름 / 체크리스트 | W1, W2, W3, W4 | 4.5절 |
| 학업운(050) | 보 | - | 주 | - | 주 | - | 인성·식상, 조후(집중 리듬), 세운 인성 | 배움 스타일 / 집중 시간 / 올해 공부 흐름 / 계획 템플릿 | S1, S2 | 4.6절 |
| 대인관계(051) | 주 | - | - | 보 | 보 | - | 십신 관계 지도, 지지 합·충 | 관계 지도 / 돕는 사람·부딪히는 사람 / 갈등 반응 / 올해 관계 흐름 | P1, P3, P5 | 4.7절 |
| 이사·택일(052) | - | - | - | - | 주 | 보 | 세운·월운과 원국 합·충, 역마 | 움직이기 편한 달 / 전통 방위 / 현실 체크 | 실증 논문 없음(미확인) | 4.8절 |
| 건강 주의(053) | 보 | - | 주 | - | 보 | - | 오행 태과·불급, 한난조습 | 오행 균형과 생활 리듬 / 컨디션 관리 팁 / 의사 안내 | H1, H3 | 4.9절 |
| 올해·이달 흐름(054) | 보 | - | - | - | 주 | - | 세운·월운과 원국 생극·합충, 운의 계절 | 키워드 3개 / 분야별 흐름 / 월별 캘린더 / 실천 과제 | M1, M2, M4, M5 | 4.10절 |

- 모든 주제의 장 끝에 "근거 노트"와 "스스로 점검하기"를 붙인다(09 문서 3.3절).
- 주제별 금지 표현과 필수 문구는 09 문서 4절을 compliance 규칙 파일(`packages/astro-report/rules/banned.json`, AS-F-038 :91)에 주제 키별로 더한다(제안).
- 리포트 부록 "참고한 연구"에는 A·B 등급만 넣는다(09 문서 6절).

### 10.5 요금·크레딧 (제안)

4.2절 단가와 4.3절 크레딧팩은 바꾸지 않는다. 새 기능 단가는 모두 (제안)이며 4.2절과 같은 코드 상수(`apps/astro-ai/src/server/pricing.ts`)에 더한다.

| 작업 | 크레딧 | 단계 | 맞춘 기준 |
|---|---|---|---|
| 오늘의 운세, 주간 운세 | 0 | P1 | 리텐션 무료(08 문서 6절 1·3항) |
| 오늘의 카드(하루 1장) | 0 | P1 | 08 문서 8.2절 |
| 월간 운세(화면) | 5 | P1 | 4.2절 :115 재생성과 같은 소액 단위 |
| 주제별 풀이 책(1주제, 4~5장) | 15 | P1 | 4.2절 :112 사주 리딩과 같은 단가 |
| 결혼·궁합 책(2인) | 25 | D-33 | 4.2절 :117 궁합 분석 그대로 |
| 친구 궁합 공유 링크 | 공유자 25(친구가 응답해 생성이 시작될 때 차감), 친구 0 | P1 | 궁합 단가 그대로. 응답이 없으면 차감 없음 |
| 신년 운세 책(12섹션) | 50 | D-33 | 4.2절 :116 연간 운세 그대로 |
| 타로 화면 리딩: 원카드 / 3장 / 5~7장 / 켈틱크로스 10장 | 3 / 8 / 12 / 15 | P1 | 4.7절 :180 채팅 턴(3)보다 크고 4.2절 :113 타로 3카드 책(20)보다 작게 |
| 타로 리딩을 책으로 만들기(3장) | 20 | MVP 유지 | 4.2절 :113. 3장을 넘는 스프레드의 책은 Phase 2 |
| 사주×타로 통합 질문(화면) | 10 | P1 | 책은 4.2절 :114 통합 리딩 30 |
| 리딩 후 심화 질문 | 턴당 3 선차감, 정산 1~5 | MVP 유지 | 4.7절 :180 |
| 만세력 조회, 대운·세운 타임라인, 카드 도감, 타로 일기, 서재, 근거 페이지, 해석자 선택 | 0 | P1 | 소장형 정체성(4.2절 :118과 같은 이유) |
| 패턴 리포트 | 10 | Phase 2 | 제안 |
| 타로 연감 PDF | 50 | Phase 2 | 연간 운세와 같은 단가 |
| 전문가 상담 | 30초 단위, 단가 (미정) | Phase 2 이후 | 08 문서 1.7절 크몽 30초 단위 |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 만료 | 크레딧은 만료하지 않는다(4.4절 :142 유지). 앱 인앱결제로 판 크레딧도 같다 | 08 문서 5절 4항(Apple 3.1.1) |
| 단일 가격표 | 같은 상품에 가격을 하나만 둔다. 웹·앱 가격이 다르면 이유를 고지한다 | 08 문서 7절 5항 |
| 무료 맛보기 | 책 상품은 목차와 샘플 1장을 무료로 보여 준다(AS-F-074, D-31) | 08 문서 6절 1항 |
| 재뽑기 | 같은 질문 24시간 안 재뽑기는 판매하지 않는다(AS-F-062) | 08 문서 7절 2항 |
| 구독 | Phase 2 유지(2절 :43). 월 운세 구독을 열 때는 다크패턴 규정(09 문서 8절)을 따른다 | 09 문서 8절 |
| 출석 보상 | 크레딧을 주지 않는다(제안). 의존을 부추기지 않고 원장 남용을 막는다 | 08 문서 7절 4항 |

### 10.6 리텐션·KPI 추가

| 장치 | 내용 | 근거 |
|---|---|---|
| 오늘의 카드 + 알림 시간 | 하루 1장 무료, 알림 시간 사용자 지정 | 08 문서 3.1절, 3.4절 |
| 주간·월간 흐름 알림 | 월초 "이달 키워드" + 원카드 질문 | 09 문서 4.10절 |
| 시즌 캘린더 | 신년(12~2월), 입춘, 초파일, 추석. 삼재는 공포 문구 없이 | 08 문서 1.7절, 2.5절 3항 |
| 타로 일기 회고 | 7일 뒤 "실제로 어땠나" 알림(선택) | 08 문서 8.2절 |
| 서재 | 만든 책이 쌓이는 자리. 다시 받기 무료 | 08 문서 7절 3항 |
| 친구 궁합 링크 | 친구가 자기 정보로 응답 → 친구 가입 | 08 문서 6절 8항 |
| 출석 스탬프 | 연속 기록 표시만(보상 없음) | 08 문서 1.1절 |

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| 오늘의 카드 7일 재방문율 | 25%(제안) | 첫 오늘의 카드 뒤 7일 안에 다시 뽑은 사용자 / 첫 뽑기 사용자 | 월 |
| 주 2회 이상 방문 사용자 비율 | 20%(제안) | 주간 방문일 2일 이상 사용자 / 주간 활성 사용자 | 주 |
| 주제별 풀이 첫 구매 전환 | 8%(제안) | 주제 리포트 1건 이상 사용자 / 오늘 메뉴 이용자 | 3개월 |
| 타로 일기 작성률 | 30%(제안) | 메모 1개 이상인 타로 리딩 / 완료된 타로 리딩 | 월 |
| 친구 궁합 링크 응답률 | 20%(제안) | 응답 완료 링크 / 발급 링크 | 월 |
| 링크 응답 → 가입 전환 | 15%(제안) | 링크로 가입한 사용자 / 링크 응답 시작 | 월 |
| 알림 허용률 | 40%(제안) | 알림 1개 이상 켠 사용자 / 활성 사용자 | 월 |
| 서재 재열람률 | 20%(제안) | 생성 30일 뒤 다시 연 책 / 30일 지난 책 | 월 |
| 하루 리딩 10회 초과 사용자 비율(감시 지표) | 2% 이하(제안, 낮을수록 좋음) | 하루 리딩 10회 초과 사용자 / 일간 활성 사용자 | 주 |
| 금지 문구 출고 | 0건 | compliance 통과 뒤 사후 샘플 검사 | 월 |
| 청약철회 분쟁 | 0건 | CS 태그 | 월 |

7절 KPI는 그대로 두고 이 표를 더한다.

### 10.7 법·표시 추가

6장(:231 이후)은 그대로 두고 아래를 더한다. 조문 원문을 확인하지 못한 항목은 출시 전 법무 확인이 필요하다(08 문서 5절, 09 문서 8절).

| 항목 | 이 기획의 처리 | 출처 |
|---|---|---|
| AI 기본법 제31조(생성형 AI 표시, 2026-01-22 시행) | 오늘의 운세·카드, 주제 리포트, 타로 화면 리딩, 통합 질문 결과에 "AI 생성" 칩. 책 표지 안쪽 고정 문구 "이 책은 전통 명리학의 해석 체계를 AI가 정리한 참고 자료입니다. 미래를 보장하거나 예언하지 않습니다." 기존 판권면·채팅·낭독 표시(6.2절 :254) 유지. 과태료 수준은 두 문서의 표현이 달라 확인 필요 | 08 문서 5절 1항, 09 문서 6절, 8절 |
| 앱스토어 인앱결제·크레딧 만료 | 앱을 내면 디지털 콘텐츠·크레딧은 인앱결제(Apple 3.1.1). 크레딧은 만료하지 않고 복원 수단을 둔다(4.4절 :142와 같다). 웹 PG와 앱 가격이 다르면 고지. 신규 심사 4.3(포화 장르)에 "사주×타로 책 + 타로 기록 연감" 차별점을 심사 노트로 쓴다 | 08 문서 5절 3항, 4항 |
| 청약철회 제한 표시 | 책 생성 전 목차·샘플 미리보기 → 철회 제한 문구와 동의 → 생성(AS-F-074). 표시 의무 이행의 증명 책임이 사업자에게 있으므로 동의 기록을 남긴다. 결제(팩) 환불은 4.5절 그대로이며 사용한 크레딧은 환불 대상이 아니다(:150) | 08 문서 5절 5항, 09 문서 8절 |
| 공포 마케팅·단정 금지 | 흉운 해석 바로 뒤 결제 버튼 금지, 삼재·흉살·재회 확률 상품 없음, 굿·부적·액막이 판매 없음, 적중률·순위·이용자 수 광고 없음. 6.4절 :273-276 금지 문구에 주제별 금지 표현(09 문서 4절)을 더한다 | 08 문서 5절 2항, 09 문서 8절 공포 마케팅 행 |
| 표시광고(논문 인용 문구) | 쓸 수 있는 문구: "명리학 연구 논문을 참고해 구성한 해석" + 참고문헌 공개. 쓰지 않는 문구: "박사가 직접 감수"(사실이 아니면), "대학 연구로 입증된 사주", "적중률 98%" | 09 문서 8절 표시광고법 행, 2.10절 |
| 의료·투자 | 건강 주의는 Phase 2이고 법무 검토 뒤 연다(D-33). 재물운은 태도·습관 범위와 고정 문구. 6.3절 :265와 충돌하는 부분은 D-33으로 정한다 | 09 문서 4.5절, 4.9절, 8절 건강 행 |
| 미성년자 | 가입은 14세 이상(제안, 텔링 사례). 14세 미만 대상은 법정대리인 등록만(6.1절 :243). 미성년자 결제 취소 가능성(민법 제5조)을 약관과 환불 규정에 반영. 연령 등급을 정직하게 기재(Apple 2.3.6, 4.7.5). 성인 상품을 만들지 않는다 | 08 문서 5절 6항 |
| 다크패턴 | 추가 풀이 결제 팝업 반복 금지, 구독(Phase 2) 해지 버튼 한 번에 찾기, 무료→유료 전환 별도 고지 | 09 문서 8절 다크패턴 행 |
| 친구 공유와 제3자 정보 | 친구가 자기 정보를 직접 넣고 동의한다. 공유자에게 친구의 생년월일 원문을 보이지 않는다(AS-F-070) | 08 문서 5절 7항, AS-F-004 |
| 상담 연결(Phase 2 이후) | 굿·부적·초 판매 권유 금지 조항을 약관에 둔다 | 08 문서 5절 8항 |

### 10.8 결정 대기 (D-26~D-33)

결정 전에는 각 항목의 기본값(제안)으로 03장 9장과 디자인 시안을 둔다.

| ID | 결정 | 선택지 | 권고와 이 기획의 가정 | 확정 시점 |
|---|---|---|---|---|
| D-26 | 확장 GNB 채택 | (a) 03장 9장 34개 메뉴 채택. 배포 화면에는 출시된 단계의 메뉴만 보이고, 시안에는 배지(P1·Phase 2)로 모두 보인다 (b) 03장 8장 7개 유지 + "주제별 풀이" 묶음만 추가 (c) 보류 | (a)(제안). 승인 전까지 03장 8장과 CLAUDE.md 9절(:136, :138)이 정본이다 | 대표 검토 직후 |
| D-27 | 모바일 하단 탭 | (a) 1024px 미만에 하단 탭 5개(오늘·풀이·타로·서재·나) + 좌측 서랍 유지 (b) 하단 탭 없이 서랍만(03장 8.6절) | (a)(제안). 경쟁사 앱이 하단 탭을 쓴다(08 문서 8.1절). 하단 탭이 채팅 시트와 스테퍼 확인 버튼을 가리지 않는지 시안에서 확인 | AS-06-040(디자인 사람 검토) |
| D-28 | 해석자 캐릭터 수 | (a) 2종(차분한 해설가, 다독이는 선녀) P1 (b) 3종 P1(직설형 도령 포함) (c) Phase 2로 미룸 | (a)(제안). 근거·금지 규칙·수치는 같고 머리말·맺음말과 문체만 다르다. 직설형은 단정 문장 위험이 커 평가셋 통과 뒤 Phase 2 | 해설집 원고(AS-F-030) 착수 전 |
| D-29 | 타로 덱 라이선스와 78장 | (a) 자체 제작 덱 1종(78장) (b) 1909·1910 RWS 계열 이미지 사용(국내 이용 범위 법무 확인 후) (c) 메이저 22장 유지 | (a)(제안). RWS 계열의 이용 가능 범위는 (미확인)이다(08 문서 3.5절). 자체 덱이 나오기 전에는 (c)로 둔다 | 덱 제작 계약 전 |
| D-30 | 전문가 상담 도입 시점 | (a) Phase 2 이후 검토 (b) P1에 제휴 링크만 (c) 도입하지 않음 | (a)(제안). 상담사 검수, 30초 과금, 기록 저장, 굿·부적 권유 금지 약관이 먼저다(08 문서 1.7절, 5절 8항). Sanctuary의 가용성·가격 불만(08 문서 3.3절)을 피한다 | Phase 2 기획 때 |
| D-31 | 무료 맛보기 범위 | (a) 오늘의 운세·카드 무료 + 책 상품 목차와 샘플 1장 무료 (b) (a) + 주제별 풀이 1장 무료(가입 1회) (c) 데모(AS-F-024)만 | (a)(제안). 청약철회 제한 표시의 전제(08 문서 5절 5항)이자 퍼널(08 문서 6절 1항). (b)는 전환 데이터를 본 뒤 | AS-F-074 착수 전 |
| D-32 | 연화선녀 대상 확인 | (a) 대표가 본 서비스의 URL·앱 이름·스크린샷을 받아 08 문서 2절을 다시 쓴다 (b) 확인 전까지 "정서적 위로형 해석자"만 반영 | (b)로 진행하고 (a)를 요청한다(제안). 1차 출처로 확인되는 서비스가 없다(08 문서 2.1절). 가장 가까운 AI 페르소나 사례는 청월당 "연화무녀"다(08 문서 2.3절). 특정 무속인이나 경쟁 서비스 캐릭터를 흉내 내지 않는다 | 대표 회신 직후 |
| D-33 | 주제 범위와 단계 | (a) 궁합·신년 운세를 P1로 앞당김, 재물운 P1(태도·습관 범위, 고정 문구), 건강 주의 Phase 2(법무 검토 후) (b) 2절 그대로(궁합·연간 Phase 2), 재물·건강 주제 제외(6.3절 :265, 07장 P-06 :93 그대로) (c) 모두 P1 | (a)(제안). 신년 특수(12~2월, 08 문서 1.7절)에 맞추고, 재물은 6.4절 :275 대체 문구("재물에 대한 태도와 관리 습관")와 같은 범위로 둔다. 건강은 의료 오인 위험(09 문서 8절) 때문에 뒤로 둔다 | 법무 검토 요청 전 |

| 결정 | 기본값과 다르게 정하면 고칠 곳 |
|---|---|
| D-26 (b)·(c) | 03장 9.2절 메뉴 표, 9.6절, 디자인 config `groups`·`footer`·`menus` |
| D-27 (b) | 03장 9.5절, AS-F-079 |
| D-28 (b)·(c) | AS-F-067, 03장 9.3절 해석자 선택 행, 10.5절 |
| D-29 (b)·(c) | AS-F-058, 03장 9.3절 카드 도감·타로 리딩 행 |
| D-30 (b)·(c) | AS-F-076, 03장 9.2절 전문가 상담 행 |
| D-31 (b)·(c) | AS-F-074, 10.5절 무료 맛보기 행 |
| D-32 (a) | 08 문서 2절, AS-F-067 |
| D-33 (b)·(c) | 10.2절, AS-F-043·046·049·053, 10.5절, 03장 9.2절 배지 |
