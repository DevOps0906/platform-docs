# 01 PRD: 신비로운AI

표기: "제안"은 원본 문서와 리뷰에 근거가 없어 이 문서가 새로 정한 값이다. 근거 경로의 `AA/`는 `Astro AI/기획안/`, `FD/`는 `FortuneDocs/`다.

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
| 이메일 + Google 로그인 | MVP | `docs/products/00_MERGE_ANALYSIS.md:308` |
| 프로필 보관함(본인, 가족, 지인) + 제3자 동의 | MVP | `docs/products/00_MERGE_ANALYSIS.md:310` |
| 만세력 엔진(로컬 절기 테이블) + 원국 프리뷰 + 대운 타임라인 | MVP | `docs/products/00_MERGE_ANALYSIS.md:317-320` |
| 사주 리딩, 타로 3카드 리딩, 통합 리딩 | MVP | 확정 결정 7, `docs/products/00_MERGE_ANALYSIS.md:322-323` |
| A4 책자형 PDF(WeasyPrint 공용 렌더), 테마 2종, 테마 변경 재생성 | MVP | `docs/products/00_MERGE_ANALYSIS.md:333-336` |
| 이메일 발송(서명 URL) + 대시보드 Realtime | MVP | `docs/products/00_MERGE_ANALYSIS.md:344-346` |
| 크레딧팩 4종 Toss 일반결제 | MVP | 확정 결정 7, `docs/products/00_MERGE_ANALYSIS.md:355-356` |
| 실패 자동 환불, 관리자 수동 환불 | MVP | `docs/products/00_MERGE_ANALYSIS.md:358` |
| 최소 어드민(유저 조회, 결제·환불, 크레딧 조정, 발송 모니터) | MVP | `docs/products/00_MERGE_ANALYSIS.md:366` |
| 랜딩 + GEO(JSON-LD, `/llms.txt`), 비회원 Live Demo(LLM 미사용) | MVP | `docs/products/00_MERGE_ANALYSIS.md:367-370` |
| 구독 플랜(Basic/Pro/Master) + 빌링키 + 연간 20% 할인 | Phase 2 | `docs/products/00_MERGE_ANALYSIS.md:354`, `:357` |
| 궁합(2인), 연간 운세(12섹션) | Phase 2 | `docs/products/00_MERGE_ANALYSIS.md:324-325` |
| 카카오 알림톡 | Phase 2 | `docs/products/00_MERGE_ANALYSIS.md:345` |
| ePub | Phase 2 | `docs/products/00_MERGE_ANALYSIS.md:334` |
| 템플릿 마켓플레이스, 크리에이터 대시보드 | Phase 3 이후(현 단계 폐기) | `docs/products/00_MERGE_ANALYSIS.md:362-363`, 확정 결정 7 |
| 멀티버티컬, 기업 API, 다국어 | 폐기(현 단계) | `docs/products/00_MERGE_ANALYSIS.md:371-373` |

## 3. 기능 요구사항과 수용 기준

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| AS-F-001 | 가입/로그인 | 통합 | 이메일+비밀번호, Google OAuth(Supabase Auth). 가입 폼은 `signup_app='astro'`를 보낸다. 매직링크와 Apple은 넣지 않는다 | 가입 직후 `session_context('astro')`가 `entitled=true`, `plan_code='starter'`를 돌려준다 | `docs/products/_platform-core/CORE_SPEC.md:78`, `docs/products/00_MERGE_ANALYSIS.md:308` |
| AS-F-002 | 환영 크레딧 30 | 신규(공백 8) | 이메일 인증 완료 또는 Google 로그인 확인 뒤 서버가 `grant_credits(30, 멱등 키 signup:<org>:astro)`를 1회 호출한다(제안: 가입 트리거 시점은 이메일 인증 전이라 반복 수령을 막지 못함). 같은 IP 해시에서 하루 가입 3회 초과 시 지급 보류(제안) | 미인증 계정 잔액 0, 인증 후 30. 같은 조직에 2번 호출해도 원장 1행 | `AA/공통/PRD.md:31`, `docs/reviews/FortuneDocs.md:51`, `docs/products/00_MERGE_ANALYSIS.md:448` |
| AS-F-003 | 프로필 보관함 CRUD | 유지(FD) | 대상: 호칭(20자), 관계(본인/가족/연인/친구/기타), 성별(필수), 생년월일, 생시 또는 "모름", 양력/음력, 윤달, 자시 방식, 출생지(시·군 목록 → 경도). 조직당 본인 1명, 전체 20명(제안, `features.max_subjects`) | 21번째 등록은 409. 성별 없이 저장 불가. 본인 2명 등록 불가 | `FD/PRD.MD:50`, `:55`, `docs/reviews/FortuneDocs.md:41-42` |
| AS-F-004 | 제3자 정보 동의 | 신규(공백 6) | 관계가 본인이 아니면 "이 사람에게 정보 제공 동의를 받았거나 법정대리인입니다" 체크와 약관 버전을 저장(`subjects.third_party_consent_at`, `consents.kind='third_party_birth'`) | 체크 없이 가족 등록 시 400. DB 제약(`subjects_consent_check`)도 거부 | `docs/reviews/FortuneDocs.md:50`, `docs/products/00_MERGE_ANALYSIS.md:415` |
| AS-F-005 | 생년월일시 암호화 | 디벨롭 | 이름과 생년월일시(원문 입력)는 서버에서 AES-256-GCM으로 암호화해 `*_ciphertext`에만 저장. 키는 환경변수 `ASTRO_PII_KEY_V<n>` | DB 덤프에 실명·생년월일 평문 0건. 사용자 세션으로 암호문 컬럼 SELECT 시 42501 | `AA/공통/PRD.md:117`, `docs/products/_platform-core/SECURITY_BASELINE.md:12장` |
| AS-F-006 | 만세력 엔진 | 디벨롭 | `packages/saju-engine` 순수 함수. 입춘 기준 년주, 절입 시각 기준 월주, 일주(율리우스일), 시주(일간 기준), 자시 방식 2종, 생시 모름(삼주), 한국 서머타임(1948~1960, 1987~1988 해당 기간), 진태양시(경도 보정, 기본 127.0), 음력·윤달 변환(1900~2100 테이블), 십신, 오행 점수, 대운 순역행과 대운수 | 골든 테스트 100건(절기 경계 ±1시간 30, 입춘 경계 15, 자시 20, 서머타임 10, 윤달 10, 일반 15) 전부 통과. KASI 대조 배치에서 불일치 0 | `docs/reviews/FortuneDocs.md:40-42`, `:97`, `docs/products/00_MERGE_ANALYSIS.md:317`, `:410` |
| AS-F-007 | 원국 프리뷰 | 유지(FD) | 입력 즉시 4주 8자를 오행 색 카드로 표시. 엔진을 브라우저에서 실행(입력이 서버로 가지 않음). 金은 테두리형, 水는 밝은 테두리로 다크 배경 대비 확보 | 입력 변경 후 100ms 안에 갱신. 대비 3:1 이상(비텍스트 요소) | `FD/PRD.MD:56`, `docs/reviews/FortuneDocs.md:55` |
| AS-F-008 | 대운 타임라인 | 유지(FD) | 대운 8~10구간(10년 단위), 현재 구간 강조, 읽기 전용 | 대운 시작 나이가 엔진 결과와 같다 | `FD/PRD.MD:80` |
| AS-F-009 | 사주 리딩 | 통합 | 15cr. 6장 구성: 타고난 기질(일간), 오행 균형과 보완 습관, 일과 재능(십신), 관계와 소통, 대운 흐름, 올해의 흐름과 질문 답변. 본문 2,500자 이상, 호칭 3회 이상 | 생성물 zod 검증 통과, 글자 수와 호칭 횟수 충족, 금지 표현 0건 | `AA/공통/PRD.md:40`, `:71-72`, `docs/reviews/FortuneDocs.md:103` |
| AS-F-010 | 타로 3카드 리딩 | 유지(AA) | 20cr. 메이저 아르카나 22장, 정/역방향. 펼친 카드에서 3장 선택(과거/현재/미래 자리, 제안). 섞기와 정역 방향은 브라우저 `crypto.getRandomValues`, 서버는 0~21 중복 없음만 검증. 4장 구성, 2,000자 이상(제안) | 같은 카드 2장 선택 불가. 질문 200자 초과 불가 | `AA/공통/PRD.md:41`, `:67`, `AA/대시보드/PRD_DASHBOARD.md:28-29` |
| AS-F-011 | 통합 리딩 | 유지(AA) | 30cr. 사주 6장 + 타로 연결 2장, 4,000자 이상 | 사주·타로 각 수용 기준 + 4,000자 | `AA/공통/PRD.md:42`, `:68`, `:72` |
| AS-F-012 | 리딩 상태 머신 | 신규(공백 4) | `queued → generating → rendering → completed`, `failed`, `canceled`. 전이는 DB 트리거가 강제. 실패하면 `fail_job`이 자동 환불, 대기 중 취소는 `cancel_reading`이 환불 | 생성 실패 리딩 100%가 환불 원장 행을 가진다. 원장 drift 0 | `docs/reviews/Astro_AI.md:50`, `:73`, 05장 3절 |
| AS-F-013 | PDF 렌더 | 통합 | 공용 WeasyPrint 서비스(`services/render-weasyprint`)로 A4 렌더. Noto CJK 포함, `url_fetcher`는 자체 Storage만 | 한글·한자 누락 0. 외부 URL 참조 HTML은 렌더 거부 | `docs/products/_platform-core/SHARED_MODULES.md:251-275` |
| AS-F-014 | 테마 | 유지(AA) | MVP 2종(`mystical-dark`, `oracle-gold`). `ThemeConfig → CSS 변수` 변환기 1개. 사용자 업로드 테마 없음 | 같은 리딩을 두 테마로 렌더했을 때 본문 텍스트가 같다 | `docs/products/00_MERGE_ANALYSIS.md:336`, `docs/reviews/Astro_AI.md:87` |
| AS-F-015 | 테마 변경 재생성 | 유지(AA) | 5cr. 본문은 다시 생성하지 않고 렌더만 새로 한다(`reading_renders`) | 재생성 후 이전 PDF도 히스토리에서 받을 수 있다 | `AA/공통/PRD.md:45` |
| AS-F-016 | PDF 보관과 재다운로드 | 신규(공백 9) | PDF와 본문은 사용자가 삭제하거나 탈퇴 후 30일이 지날 때까지 보관(제안: 소장형 정체성). 다운로드는 7일 서명 URL을 요청 때마다 새로 발급하며 무료. 원본 "24시간 삭제"는 적용하지 않는다 | 생성 30일 뒤에도 다운로드 성공. 발급 URL은 7일 뒤 만료 | `docs/reviews/Astro_AI.md:55`, `docs/products/00_MERGE_ANALYSIS.md:338`, `:416` |
| AS-F-017 | 이메일 발송 | 유지(AA) | Resend. PDF 첨부가 아니라 서명 URL 링크(제안: 첨부는 메일함 보존 기간을 통제할 수 없음). outbox 재시도 5분 간격 3회. 설정에서 이메일 발송 끌 수 있음 | 3회 실패 시 `dead`, 어드민 모니터에 표시, 사용자 재발송 가능(일 3회, 제안) | `AA/공통/PRD.md:82`, `:86`, `docs/reviews/Astro_AI.md:85` |
| AS-F-018 | 진행률 | 디벨롭 | `readings` 행 `postgres_changes` 구독(RLS 적용). broadcast 채널 없음 | 다른 조직 사용자는 진행 이벤트를 받지 못한다 | `docs/reviews/Astro_AI.md:60`, `:84` |
| AS-F-019 | 크레딧팩 결제 | 디벨롭 | Toss 결제창 → successUrl → 서버 confirm → `confirm_payment_order` 금액 대조 → 멱등 지급. 웹훅은 상태 동기화만 | 같은 결제를 2번 confirm해도 지급 1회. 금액 변조 시 지급 0 | `docs/reviews/Astro_AI.md:53`, `:75`, `docs/products/_platform-core/CORE_SPEC.md:210-221` |
| AS-F-020 | 결제 환불 | 유지(AA) + 신규 | 어드민 환불 모달(사유 필수) → Toss 취소 API → 미사용 크레딧 조정 → 감사 로그 | 사유 없이 환불 불가. 환불 1건당 `audit_log` 1행 | `AA/대시보드/PRD_DASHBOARD.md:124`, `docs/products/00_MERGE_ANALYSIS.md:358` |
| AS-F-021 | 대시보드 | 통합 | 홈, 보관함, 리딩 시작, 히스토리(발송 상태 포함), 크레딧, 설정 | 03장 1절 화면이 모두 서버 가드 뒤에 있다 | `docs/products/00_MERGE_ANALYSIS.md:365` |
| AS-F-022 | 최소 어드민 | 디벨롭 | `platform_admin`만. 유저 조회, 결제·환불, 크레딧 지급(사유 필수), 발송 모니터·강제 재발송. 모든 쓰기는 서버에서 역할 재검증 + 감사 | 일반 사용자의 `/api/admin/*` 호출은 403 | `docs/reviews/Astro_AI.md:52`, `:102`, `:131` |
| AS-F-023 | 랜딩 + GEO | 유지(AA) | 03장 4절 구성. JSON-LD는 WebSite, Product(크레딧팩), FAQPage만. `aggregateRating`, `Review`는 실제 후기 수집 전까지 넣지 않음 | 빌드 산출물에 `aggregateRating` 문자열 0건 | `docs/reviews/Astro_AI.md:54`, `:76` |
| AS-F-024 | 비회원 Live Demo | 디벨롭 | 생년월일시 입력 → 엔진으로 일간·오행 강약 기반 키워드 3개(LLM 미사용). IP 해시당 하루 3회(`core.rate_limit_hit`). 입력은 저장하지 않음 | 4번째 호출 429. LLM 호출 로그 0 | `AA/랜딩페이지/CLAUDE_LANDING.md:256-277`, `docs/reviews/Astro_AI.md:86`, `:133` |
| AS-F-025 | 레이트 리밋 | 신규(공백 8) | 리딩 생성 조직당 10회/분, 진행 중 리딩 조직당 3건(제안: 단가 30cr 작업의 동시 남용 방지), 다운로드 URL 발급 60회/시간 | 초과 시 429와 재시도 시각 | `docs/products/_platform-core/SECURITY_BASELINE.md:8장` |
| AS-F-026 | 보관함 대상 삭제 | 신규(공백 6) | 대상 삭제 시 그 대상의 리딩, 렌더, 발송 기록, PDF 파일을 함께 지운다. 동의 기록은 대상 참조만 끊고 남긴다(증빙) | 삭제 후 Storage에서 해당 PDF 0개(24시간 내), 리딩 0행 | `docs/reviews/FortuneDocs.md:50` |
| AS-F-027 | 탈퇴와 데이터 내보내기 | 신규(공백 6) | 탈퇴 = 조직 soft delete → 30일 유예 → `purge_organization` + Storage 삭제. 내보내기 = 보관함과 리딩 본문 JSON + PDF 링크 | 유예 중 로그인 시 복구 안내. 30일 뒤 조직 행 0 | `docs/products/_platform-core/SECURITY_BASELINE.md:12장` |
| AS-F-028 | 프롬프트 가이드 | 신규(공백 7) | 현대적 재해석 사전, 장 구성과 분량, 금지 표현(5장 3절과 6절), 수치는 엔진 입력만 사용, 이름은 `{{호칭}}` 토큰 | 사전 항목 30개 이상(제안), 금지 표현 검사 규칙과 일치 | `FD/PRD.MD:61`, `docs/reviews/FortuneDocs.md:47`, `:103` |

## 4. 요금과 크레딧

정본은 Astro AI 단가표다(확정 결정 8). MVP는 크레딧팩 일회 결제만 판다(확정 결정 7, `docs/products/00_MERGE_ANALYSIS.md:446`).

### 4.1 플랜

| 코드 | 가격 | 월 크레딧 | 가입 크레딧 | 이월 | 범위 | 근거 |
|---|---|---|---|---|---|---|
| `starter` | 0원 | 0 | 30(1회, 지급 시점은 AS-F-002) | 해당 없음(pack 버킷) | MVP 기본 플랜 | `AA/공통/PRD.md:31` |
| `basic` | 9,900원/월 | 200 | 0 | 안 함(제안) | Phase 2 | `AA/공통/PRD.md:32` |
| `pro` | 29,900원/월 | 700 | 0 | 안 함(제안) | Phase 2 | `AA/공통/PRD.md:33` |
| `master` | 69,900원/월 | "무제한" → 월 3,000cr 공정 사용 한도(제안: 통합 리딩 100건, 원가 상한 확보) | 0 | 안 함 | Phase 2 | `AA/공통/PRD.md:34`, `docs/reviews/Astro_AI.md:62` |

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

단가는 코드 상수(`apps/astro-ai/src/server/pricing.ts`)로 둔다. 원본의 `credits_config` 테이블(`AA/공통/CLAUDE.md:267`)은 만들지 않는다. 코어 `priceOf`가 제품 단가표를 주입받는 구조(`docs/products/_platform-core/SHARED_MODULES.md:121-125`)를 따르기 때문이다.

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
| 차감 시점 | 리딩 생성 요청을 받은 Route Handler가 잡을 만들기 전에 `consume_credits`(멱등 키 `consume:astro:<request_id>`) | `docs/products/_platform-core/CORE_SPEC.md:172-181` |
| 자동 환불 | 잡 최종 실패 → `fail_job`이 원 차감 전액 환불. 대기 중 취소 → `cancel_reading`이 환불 | `docs/products/_platform-core/CORE_SPEC.md:180-181` |
| 환불하지 않는 경우 | PDF까지 완료된 뒤 사용자가 내용에 불만이 있는 경우(어드민 판단으로 수동 지급만 가능) | 제안 |
| 차감 순서 | plan 버킷 → pack 버킷(코어 규칙). MVP는 pack만 있다 | `docs/products/_platform-core/CORE_SPEC.md:168` |
| 만료 | 팩 크레딧은 만료하지 않는다(제안: 유효기간을 두면 약관과 표시 의무가 늘어남) | 제안 |
| 가입 크레딧 | 30, 조직당 1회, 이메일 인증 또는 Google 로그인 뒤 | AS-F-002 |

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

모듈러 seed의 `{"readings":["saju","tarot"],"pdf_themes":2}`(`docs/products/_supabase-modular/seed.sql:34`)는 옛 값이었고, 2026-10-13에 모놀리스 seed와 일치하도록 갱신되었다(06장 6절 R-2 해결).

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
| 렌더 타임아웃 | 120초 | `docs/products/_platform-core/SHARED_MODULES.md:261` |
| LLM 타임아웃 | 장당 60초, 장 재시도 1회, 잡 재시도 1회(`max_attempts=2`) | `docs/products/_platform-core/SHARED_MODULES.md:207`, `docs/reviews/FortuneDocs.md:102` |
| 입력 상한 | 질문 200자, 호칭 20자, 보관함 20명 | `AA/대시보드/PRD_DASHBOARD.md:29`, 제안 |
| PDF 크기 | 리딩당 10MB 이하(제안: 폰트 서브셋 임베딩) | 제안 |
| 레이트 리밋 | 로그인/가입 IP당 10회/10분, 리딩 생성 조직당 10회/분 + 진행 중 3건, Live Demo IP당 3회/일, 다운로드 URL 60회/시간, Toss 웹훅 600회/분 | `docs/products/_platform-core/SECURITY_BASELINE.md:8장`, 제안 |
| 보존 기간 | 6장 1절 표 | 공백 9 |

## 6. 법, 개인정보, 금지 문구

### 6.1 개인정보

| 항목 | 내용 |
|---|---|
| 수집 항목(회원) | 이메일, 표시 이름, 로그인 제공자, 결제 내역(Toss 결제키, 금액. 카드번호는 받지 않음), 접속 IP 해시 |
| 수집 항목(대상) | 호칭, 관계, 성별, 생년월일, 생시(선택), 양/음력, 윤달, 자시 방식, 출생 시·군(선택), 실명(선택, PDF 표지용) |
| 목적 | 사주 원국 계산, 리포트 생성과 전달, 결제와 환불, 부정 이용 방지 |
| 암호화 | `subjects.name_ciphertext`, `subjects.birth_ciphertext`, `readings.question_ciphertext`, `deliveries.recipient_ciphertext`(AES-256-GCM, `ASTRO_PII_KEY_V<n>`). 원국 스냅샷(`readings.chart`)은 렌더에 필요해 평문 jsonb로 두되 RLS와 대상 삭제 연쇄로 보호한다 |
| 보존 | 대상 정보: 사용자가 삭제할 때까지 / 리딩 본문과 PDF: 삭제 또는 탈퇴 후 30일 / 동의 기록: 탈퇴 후 1년(제안: 분쟁 증빙) / 발송 기록: 1년(제안) / 결제 기록: 5년(전자상거래법상 대금결제 기록, 코어 purge와 충돌하므로 06장 6절 코어 요청) / Live Demo 입력: 저장하지 않음 |
| 삭제 절차 | 대상 삭제: 즉시 DB 삭제 + Storage 파일 24시간 내 삭제. 탈퇴: 조직 soft delete → 30일 → `purge_organization` |
| 제3자(가족·지인) 정보 | 등록 시 "정보주체 동의 또는 법정대리인" 확인 체크를 필수로 받고 약관 버전과 함께 `consents`에 남긴다. 14세 미만 아동의 정보는 법정대리인만 등록하도록 안내(제안) |
| 제3자 제공·처리위탁 | LLM(Anthropic, OpenRouter): 호칭 토큰, 성별, 원국 수치, 대운 나이, 타로 카드, 질문만 보낸다. 실명과 생년월일 원문은 보내지 않는다(실명은 PDF 렌더 시점에 템플릿이 넣는다). Resend: 수신 이메일. Toss: 결제 정보. Supabase/Railway/Vercel: 호스팅 |
| 국외 이전 | LLM 제공자와 호스팅이 국외 서버이므로 개인정보처리방침에 이전 국가, 항목, 목적, 보유 기간을 적고 가입 시 `overseas_transfer` 동의를 받는다(미확인: 각 사업자의 리전 정책) |

### 6.2 약관과 고지

| 항목 | 내용 |
|---|---|
| 이용약관, 개인정보처리방침, 환불 규정 | `/legal/terms`, `/legal/privacy`, `/legal/refund`. 가입 화면에서 필수 동의 2개(`terms_required`, `privacy_required`) |
| 점술 서비스 면책 | 모든 리포트 첫 장과 랜딩 하단: "이 리포트는 명리학과 타로의 전통 해석을 AI가 재구성한 참고용 콘텐츠이며 의료, 법률, 투자 판단을 대신하지 않습니다"(`docs/reviews/Astro_AI.md:61`) |
| AI 생성 표시 | PDF 판권면과 대시보드 결과 화면에 "AI가 생성한 해설" 표시 |
| 저작권 | 리포트는 사용자가 개인적으로 소장·공유할 수 있다. 상업적 재판매 금지. 테마 디자인과 템플릿의 저작권은 운영사에 있다 |
| 통신판매업 정보 | 사업자 상호, 대표자, 사업자등록번호, 통신판매업 신고번호, 주소, 연락처를 푸터에 표시(`AA/랜딩페이지/PRD_LANDING.md:82`). 신고번호는 미확인 |
| 마케팅 수신 | 선택 동의(`marketing_email`), 기본 해제. 카카오 알림톡(Phase 2)은 휴대폰 번호 수집 동의, 발신 프로필, 템플릿 심사가 선행 조건(`docs/reviews/Astro_AI.md:61`) |

### 6.3 제휴/광고, 플랫폼 약관, 규제 특례

| 항목 | 내용 |
|---|---|
| 제휴/광고 | 해당 없음. affiliate 모듈을 쓰지 않는다(소비 제품은 video, blog, `docs/products/_platform-core/SHARED_MODULES.md:44`) |
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

금지 표현은 프롬프트 지시와 생성 후 규칙 검사(`packages/astro-report/rules/banned.json`, 한글은 `\b` 대신 형태 경계 규칙, `docs/products/00_MERGE_ANALYSIS.md:786`) 두 단계로 막는다. 검사에 걸린 장은 1회 재생성하고, 다시 걸리면 잡을 실패시켜 환불한다.

## 7. KPI

원본 KPI(`AA/공통/PRD.md:129-136`) 중 MVP 범위에 맞는 것만 남기고, 마켓·구독 지표는 Phase 2로 미룬다.

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
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

분석 B-5(`docs/products/00_MERGE_ANALYSIS.md:426-474`)의 8개 항목 중 확정 결정으로 닫힌 것은 아키텍처(결정 3), 타로 포함(결정 7), 수익 모델 MVP(결정 7, 8), 범위(결정 7), 서비스명(결정 10)이다. 남은 항목과 이 기획에서 새로 생긴 항목은 아래와 같다. 각 항목의 "이 기획의 가정"으로 01~07장을 썼다.

| ID | 결정 | 선택지 | 권고와 이 기획의 가정 |
|---|---|---|---|
| D-1 | 제품 정체성(B-5 #1) | (a) 30초 즉시 리딩 + 3채널 (b) 소장형 책 (c) 소장형 책자 + 이메일·대시보드 | (c). 랜딩 메시지와 PDF 보관 정책(AS-F-016)이 이 가정을 따른다 |
| D-2 | LLM(B-5 #5) | (a) Claude 단일 (b) 3사 체인 (c) Claude + OpenRouter 폴백 | (c). 코어 LLM 게이트웨이 기본 동작과 같다(`docs/products/_platform-core/SHARED_MODULES.md:204`) |
| D-3 | 가입 크레딧 양과 지급 시점(B-5 #4) | (a) 30cr 가입 즉시 (b) 30cr 이메일 인증·Google 확인 뒤 (c) FD식 3cr | (b). 모놀리스 seed의 `signup_credits=0`과 `features.welcome_credits=30`이 이 가정이다. 모듈러 seed도 2026-10-13부터 같은 값이다 |
| D-4 | 만세력 데이터 소스(B-5 #6) | (a) KASI 실시간 (b) 로컬 절기 테이블 + KASI 검증 (c) 외부 라이브러리 | (b). 라이브러리를 쓰더라도 골든 테스트 통과가 조건 |
| D-5 | 리포트·PDF 보관 기간 | (a) 계정 존속 기간 (b) 1년 (c) 원본 24시간 삭제 | (a). (c)는 다른 프로젝트 잔재(`docs/reviews/Astro_AI.md:55`) |
| D-6 | 결제 환불 규정 | 4.5절 초안 | 법무 확인 후 확정 |
| D-7 | Master 공정 사용 한도(Phase 2) | 월 3,000cr / 리딩 100건 / 다른 값 | 월 3,000cr(제안) |
| D-8 | 테마 팔레트 | 원본 보라 토큰 유지 / 주제 기반 재추출 | 재추출(03장 4절). 테마 키 이름은 원본을 유지 |
| D-9 | 배포 DB와 모놀리스 스키마 | 모듈러 `astro` / 모놀리스 `public` | 모듈러 기본. 모놀리스 `public`은 코어 축소판을 따른 것이며 확정 대기 |
| D-10 | 용신·격국 판정 | (a) MVP에서 엔진 규칙으로 판정 (b) MVP는 "보완 오행"으로 대체, 판정은 Phase 2 엔진 사양에서 | (b). LLM이 판정하게 두지 않는다(`docs/reviews/FortuneDocs.md:47`) |
| D-11 | 타로 자리 의미 | 과거/현재/미래 / 상황/장애/조언 | 과거/현재/미래(제안) |
