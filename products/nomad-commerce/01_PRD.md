# 01 PRD: NOMAD Commerce

표기: 원본·리뷰에 근거가 없는 수치와 정책은 "제안"으로 쓰고 이유를 단다. 외부 사실(API 존재, 약관)을 확인하지 않았으면 "미확인". 리뷰 경로 `docs/reviews/`, 분석 경로 `docs/products/00_MERGE_ANALYSIS.md`(이하 "분석").

2026-10-13 개정: 확정 결정 13~17(`docs/products/00_MERGE_ANALYSIS.md:21-25`)에 따라 AI 계층(상품 스펙·마켓 규칙 RAG, 마켓 규칙 위키, LangGraph 상세페이지 생성 그래프, Dify 셀러 어시스턴트 채팅), 음성(상품 설명 음성 입력, 쇼츠 내레이션, 음성 대화), 상용/오픈소스 모델 이원화와 국외 이전 동의, 3D 히어로를 MVP에 넣었다. 설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `docs/products/_design-guide/HERO_3D.md`, `DESIGN_SYSTEM.md`이고 이 문서는 제품 요구만 정한다. 이 개정으로 기존 LLM 호출 경로(OpenRouter 단일 게이트웨이를 워커·Route Handler에서 직접 호출)와 fal whisper STT는 FastAPI 모델 라우터와 `packages/core-voice` 어댑터로 대체됐다(02장 3절, 5절). 쇼츠 영상 렌더 엔진은 nomad-video 소유이고 commerce는 워커 API만 호출한다(확정 결정 6).

## 1. 페르소나와 핵심 과제

| 페르소나 | 상황 | 목표 | 좌절 | 근거 |
|---|---|---|---|---|
| 부업 셀러 "민지"(32세, 직장인) | 퇴근 후 2시간만 쓴다. 위탁 도매(오너클랜) 엑셀을 받아 쿠팡에 올린다 | 하루 5개 상품을 상세페이지까지 완성해 등록 | 상세페이지 한 장 만드는 데 1시간, 쿠팡 반려 사유를 모른다 | `Nomad-AI-Factory_V.2/PRD.md:19` |
| 다마켓 셀러 "준호"(38세, 전업) | 쿠팡·스마트스토어 계정 3개를 운영. 같은 상품을 마켓마다 다른 규격으로 다시 만든다 | 한 번 입력해 두 마켓에 규격 맞춰 동시 등록 | 마켓마다 이미지 폭·분할 규칙이 달라 실수, 플레이오토 엑셀 수작업 | `Nomad-AI-Factory_V.2/PRD.md:20`, `sellingstudio/PRD.md:91-103` |
| 건기식 구매대행 소싱러 "수아"(41세) | 아마존 영양제를 구매대행한다 | 금지어 위반 없이 상세페이지와 고시를 완성 | 금지어로 상품이 내려가고, 고지 문구를 무엇을 써야 하는지 모른다 | `Nomad-AI-Factory_V.2/PRD.md:21` |

| 핵심 과제 | 성공 기준 |
|---|---|
| J1. 소싱한 상품을 상품DB로 빠르게 모은다 | 아마존 URL/ASIN 1건 30초 이내, 엑셀 500행 2분 이내 가져오기(5장) |
| J2. 상품 하나로 마켓 규격에 맞는 상세페이지를 만든다 | 10슬롯 생성 p95 4분 이내, 금지어 FAIL 0건으로 발행 가능 |
| J3. 두 마켓에 올리거나 엑셀/ZIP으로 내보낸다 | 업로드 성공률 95% 이상(7장), 마켓 API 승인 전에도 엑셀/ZIP으로 등록 가능 |

## 2. 범위: MVP와 Phase

| 기능 | 범위 | 근거 |
|---|---|---|
| 이메일 + Google/Kakao 로그인, 1인 1워크스페이스 | MVP | 확정 결정 5, 분석:760 |
| 아마존 ASIN/URL 가져오기(서드파티 상품 데이터 API, 직접 스크래핑 금지) | MVP | 분석:775, `docs/reviews/Nomad-AI-Factory_V.2.md:123` |
| 엑셀 가져오기 2종(오너클랜, 자유 양식 + 컬럼 매핑) | MVP | 분석:777 |
| 엑셀 도매꾹·온채널·아마존 CSV 파서 | Phase 2 | 분석:777 "MVP는 2종" |
| 상품DB 목록, 수동 등록·편집, 일괄 선택 | MVP | 분석:778 |
| 상세페이지 유형 3종(설득형/정보형/감성형), 10슬롯·15슬롯 | MVP | 분석:792, 793 |
| 유형 5종(리뷰형/스토리/비교/프로모션/세트) | Phase 2. 리뷰형은 셀러가 실제 리뷰 데이터를 입력한 경우에만 | 분석:792, `docs/reviews/Nomad-AI-Factory_V.2.md:69` |
| 개별 생성 + 다중 생성(큐) | MVP | `docs/reviews/Nomad-AI-Factory_V.2.md:123` |
| 이미지로 생성(사용자 이미지 슬롯 매핑) | Phase 2 | 같은 줄 "이미지로 생성 모드는 보류" |
| 입력 보조: 상품명·키워드 추천, Vision 분석 | MVP | 분석:785, 788 |
| 입력 보조: 상품 설명 음성 입력(STT, `packages/core-voice`), URL 벤치마킹 | MVP(P1, 플랜 게이팅) | 분석:788-789, 확정 결정 16 |
| 셀러 어시스턴트 채팅(마켓 규칙 질문, 내 상품·업로드 실패 원인 질문), 제품별 Dify 채팅 앱 | MVP | 확정 결정 13, 14(`docs/products/00_MERGE_ANALYSIS.md:21-22`) |
| 마켓 규칙 위키(쿠팡·스마트스토어), 마켓 규칙·상품 스펙 RAG | MVP | 확정 결정 13, `docs/products/_platform-core/LLM_WIKI.md:37-47` |
| 상세페이지 생성 그래프 `commerce.detail_page`(정보 추출 → 규칙 검색 → 카피 → 금지어 → 마켓 변환 → compliance), 보조 그래프 `commerce.assist` | MVP | 확정 결정 13 |
| 음성 대화, 쇼츠 내레이션 음성(TTS) 생성 | MVP. 쇼츠 영상 렌더와 결합은 Phase 2(nomad-video 워커 API) | 확정 결정 16(`docs/products/00_MERGE_ANALYSIS.md:24`), 확정 결정 6 |
| 상용/오픈소스 모델 이원화, 온보딩 국외 이전 동의 | MVP | 확정 결정 17, `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| 3D 히어로(랜딩) | MVP | 확정 결정 15, `docs/products/_design-guide/HERO_3D.md:85` |
| 비회원 AI 상담(랜딩 채팅) | Phase 2 | 제안: 비로그인 상담은 운영자 예산과 강한 레이트 리밋이 필요하다(`docs/products/_platform-core/AI_ARCHITECTURE.md:130`) |
| 금지어 필터 + compliance 게이트 | MVP | 분석:786, C-6(분석:963) |
| 인라인 편집, 단일 슬롯 재생성 | MVP | 분석:799 |
| 마켓 이미지 변환/분할/검증(쿠팡, 스마트스토어) | MVP | 분석:797 |
| 와디즈·11번가 이미지 규격 출력(ZIP만) | Phase 2 | 분석:824 |
| 엑셀(플레이오토 호환)/ZIP 내보내기 | MVP | 확정 결정 7, 분석:800 |
| 쿠팡 Wing·스마트스토어 커머스 API 등록(다계정 슬롯) | MVP | 확정 결정 7, 분석:821-822 |
| 배송·반품 템플릿, 등록 폼(2개 마켓 필드) | MVP | 분석:825 |
| 환율 위젯(USD) + 마진 계산기 | MVP(5통화는 Phase 2) | 분석:768, `docs/reviews/Nomad-AI-Factory_V.2.md:123` |
| Toss 구독(빌링키) + 크레딧팩 | MVP | 확정 결정 4, 8 |
| 대시보드 KPI(실데이터) | MVP | 분석:767 |
| 지마켓·옥션(ESM)·11번가·롯데온·카페24·아임웹 | Phase 2 | 분석:823 |
| 상품 쇼츠 15/30/50초(video 워커 API 호출), 음원 라이브러리 | Phase 2 | 분석:810, C-6(분석:956, 964) |
| 카드뉴스 | Phase 2 | 분석:809 |
| SNS 배포(video 소유 업로더 소비), 설명란 상품 URL 삽입 | Phase 2 | 확정 결정 7, 분석:811-812 |
| 자동화 캔버스(automation-core 노드), n8n/Make 웹훅 | Phase 2 | 분석:834-835 |
| GEO JSON-LD(카페24/아임웹만 의미) | Phase 2 | 분석:801 |
| Capacitor 모바일 앱 | Phase 2(MVP 이후) | 확정 결정 9 |
| 외부용 API Key(엔터) | Phase 2 | 분석:837 |
| TOP100/데이터랩 트렌드 | Phase 2(데이터 출처 확정 후) | 분석:769 |
| 판매관리(주문/정산/CS) | Phase 3 | 분석:827 |
| 브랜드킷/분석 대시보드 | Phase 3 | 분석:803 |
| 블로그 원고·발행 | 범위 밖(nomad-blog 소유) | 확정 결정 1 |
| 제휴 링크·쿠팡파트너스 | 범위 밖(core affiliate + video/blog) | 확정 결정 12, 분석:957 |

## 3. 기능 요구사항과 수용 기준

### 3.1 플랫폼

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| CM-F-001 | 로그인/가입 | 유지(SS) | Supabase Auth 이메일 + Google + Kakao. 가입 시 `signup_app='commerce'`. 콜백 `next`는 `/`로 시작하는 내부 경로만, origin은 `NEXT_PUBLIC_APP_URL` 고정 | `next=//evil.com`이면 `/dashboard`로 보낸다. 가입 직후 `session_context('commerce').entitled=true`, plan_code `free` | 분석:760, `docs/reviews/sellingstudio.md:64` |
| CM-F-002 | 역할·플랜 판정 | 디벨롭 | 역할은 `core.org_members.role`, 플랜은 `core.entitled_plan_code`. 쿠키·요청 바디로 판정하지 않는다 | 쿠키 `nomad_role=SUPER_ADMIN`을 넣어도 관리자 화면 403 | 분석:761, `docs/reviews/nomad-ai-commerce.md:58` |
| CM-F-003 | 크레딧 과금 | 통합+디벨롭 | 모든 유료 작업은 서버가 `consume_credits` 선차감 → 작업 → 실패 시 환불. 단가는 4.2절 | 잔액 8에서 10슬롯(9) 요청 시 402, 잡 0건. 실패 잡은 원장에 refund 행 1개 | 분석:762, `_platform-core/CORE_SPEC.md` 4.3 |
| CM-F-004 | 플랜 한도 DB 집행 | 신규 | 상품 수, 마켓 계정 슬롯, 마켓 API 허용, 엑셀 내보내기를 트리거가 강제(`05_DATA_MODEL.md` 2장) | Free 조직의 31번째 상품 INSERT는 CM002. 브라우저에서 직접 INSERT해도 같다 | `docs/reviews/Nomad-AI-Factory_V.2.md:45` |
| CM-F-005 | 결제 | 통합 | Toss 빌링키 구독(starter/pro/enterprise), 크레딧팩 일반결제. 승인 정본은 confirm 경로 | 결제 E2E(Toss 테스트 키)에서 구독 후 엔타이틀먼트 plan_code 변경, 크레딧 지급 1회 | 확정 결정 4, `_platform-core/CORE_SPEC.md` 5장 |
| CM-F-006 | 월 크레딧 지급과 소진 알림 | 디벨롭 | 지급은 core `run_monthly_credit_grants`. 소진 알림 50/80/90%: 워커 크론이 1시간마다 계산해 인앱 알림 + 이메일 1회씩(같은 기간 중복 없음) | 150크레딧 중 120 소진 시 80% 알림 1건 | `sellingstudio/PRD.md:63`, 분석:764 |
| CM-F-007 | 대시보드 KPI | 디벨롭 | 오늘 생성 수, 생성 중, 이번 달 업로드 성공/실패, 크레딧 잔액, USD 환율. 전부 실데이터 | 목 상수 0건(코드 검색) | 분석:767 |
| CM-F-008 | 환율·마진 | 디벨롭 | 한국수출입은행 API를 평일 1회 캐시(`exchange_rates`). 마진 = (판매가 − 원가환산 − 예상 관부가세 − 배송비) / 판매가. 관부가세 기본 10%, 배송비 기본 3,000원(사용자 수정) | 환율 API 실패 시 마지막 값과 날짜를 표시하고 "기준일" 경고. LLM 추정 환율 0건 | 분석:768, `Nomad-AI-Factory_V.2/MARKET_REGISTER_FORM.md:73-80` |

### 3.2 소싱과 상품DB

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| CM-F-010 | 아마존 가져오기 | 디벨롭 | URL에서 ASIN만 추출(정규식, 서버가 URL을 fetch하지 않음) → 서드파티 상품 데이터 API 호출 → 제목·브랜드·가격·이미지·불릿 저장. 허용 도메인 amazon.com/.co.jp/.de/.co.uk/.ca. 원문 HTML 저장 안 함 | `http://169.254.169.254/`를 넣으면 400, 외부 요청 0건. 같은 ASIN 재가져오기는 기존 상품 반환(`products_source_uniq`) | 분석:775, `docs/reviews/nomad-ai-commerce.md:59` |
| CM-F-011 | 엑셀 가져오기 | 통합 | `.xlsx/.xls/.csv` 10MB, 2,000행 상한(제안: 플랜 최대 상품 수와 같은 규모). 오너클랜 고정 매핑, 자유 양식은 컬럼 매핑 UI. 행별 오류를 `import_batches.errors`에 | 500행 중 3행 오류면 497행 생성, 오류 3건 표시. 상품 수 한도 초과분은 skipped | `Nomad-AI-Factory_V.2/CLAUDE.md:553-575` |
| CM-F-012 | 상품DB | 디벨롭 | 목록(가상 스크롤), 필터(소싱처/상태/건기식), 일괄 선택 → 상세페이지 생성·내보내기·보관. 수동 등록. 판매가 10원 단위 | 2,000행에서 스크롤 60fps 목표, 첫 페이지 1초 이내 | 분석:778, `MARKET_REGISTER_FORM.md:87` |
| CM-F-013 | 건기식 표시 상태 | 신규 | 건기식 카테고리 상품은 `health_food_status`(인정 건강기능식품/일반식품/모름)를 셀러가 선택해야 L-1 슬롯을 만든다 | "모름"이면 L-1 슬롯 생성 차단 + WARN | `docs/reviews/Nomad-AI-Factory_V.2.md:49` |

### 3.3 AI 상세페이지

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| CM-F-020 | 슬롯 정본 | 디벨롭 | `MARKET_IMAGE_SPEC.md` 18슬롯(T-1~5, D-1~10, L-1~3)이 정본. 필수 슬롯은 T-1(마켓 대표), L-3(마무리) 2개(제안: V.2의 `D-1` 필수는 educational 기본값에 D-1이 없어 생성 버튼이 막히는 모순, 리뷰 V2 #7). 10장 기본값은 유형별 기본 슬롯(`MARKET_IMAGE_SPEC.md:534-543`), 15장은 `:135-149` | 유형별 기본값만으로 생성 버튼 활성. 필수 누락은 DB CHECK(23514) | `docs/reviews/Nomad-AI-Factory_V.2.md:50`, 분석:793 |
| CM-F-021 | 유형 자동 추천 | 디벨롭 | `recommendPageType` 로직(`DETAIL_PAGE_SYSTEM.md:178-195`) 중 MVP 3종으로 매핑: persuasion→persuasive, educational→informative, lifestyle→emotional, 나머지→persuasive | 건기식·아마존·5만원 이상 상품 → 정보형 추천 | 분석:792 |
| CM-F-022 | 생성 파이프라인 8단계(정본) | 디벨롭 | 아래 3.6절 표. 워커가 실행, 진행률은 `core.jobs` + `detail_page_slots` Realtime | 탭을 닫고 다시 열어도 같은 진행률. 새로고침 후 복원 | `docs/reviews/Nomad-AI-Factory_V.2.md:44,51` |
| CM-F-023 | 개별·다중 생성 | 디벨롭 | 다중은 최대 50개(제안: 디스패처 1회 처리량과 원장 행 수를 제한). 플랜 동시 생성 수(free/starter 1, pro 2, enterprise 5)를 넘는 요청은 `waiting`으로 대기 | Pro에서 5건 요청 시 동시에 2건만 generating | `Nomad-AI-Factory_V.2/PRD.md:111`, `:296-301` |
| CM-F-024 | 이미지 엔진 | 통합 | AI 씬: fal Flux(플랜별 모델, 서버 결정). 누끼: fal birefnet 1개. 인포그래픽·법적고지: Puppeteer. 한글 카피: Sharp 후합성. AI에 한글 텍스트 생성 요청 금지 | free가 요청 바디로 모델을 바꿔도 무시 | 분석:791, 795, `MARKET_IMAGE_SPEC.md:10-16`, `docs/reviews/sellingstudio.md:60` |
| CM-F-025 | 금지어·compliance 게이트 | 디벨롭 | 1단계 규칙(`banned_words`, 한글 경계 매칭) + 2단계 LLM 판정. FAIL → 업로드/내보내기 차단, WARN → 사용자 확인(RPC, 감사 기록) 후 진행 | FAIL 페이지로 업로드 INSERT 시 CM004, 미확인 WARN은 CM005 | SHARED_MODULES 13장, 분석:786 |
| CM-F-026 | 인라인 편집·재생성 | 디벨롭 | 텍스트 편집은 서버가 sanitize 후 저장하고 규칙 검사 재실행. 단일 슬롯 재생성 1크레딧, 고화질 3크레딧 | 편집 후 금지어가 들어가면 verdict가 fail로 바뀐다 | `sellingstudio/PRD.md:105-109` |
| CM-F-027 | 리뷰형 차단 | 신규 | AI가 후기·평점·"전문가 추천"을 만들지 않는다. 리뷰형(Phase 2)은 셀러가 입력한 실제 리뷰(출처, 날짜)만 렌더 | 프롬프트에 후기 생성 지시 0건, 별점 배너 템플릿 없음 | `docs/reviews/Nomad-AI-Factory_V.2.md:48` |

### 3.4 내보내기와 마켓 업로드

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| CM-F-030 | 마켓 변환 | 디벨롭 | 쿠팡 썸네일 1000x1000 JPG 흰배경 5MB, 상세 1000px 2,800px 분할 20장, 스마트스토어 상세 860px 4,800px 분할. 마스터에서만 파생 | 단위 테스트: 6,000px 상세가 쿠팡 3장으로 분할, 각 2,800px 이하 | `MARKET_IMAGE_SPEC.md:21-56`, `:271-272` |
| CM-F-031 | ZIP 내보내기 | 디벨롭 | 마켓별 폴더(`coupang/`, `smartstore/`) + 슬롯 순번 파일명. `exports` 버킷, 서명 URL 7일 | 100개 상세페이지 ZIP 5분 이내(제안) | `sellingstudio/PRD.md:103` |
| CM-F-032 | 엑셀(플레이오토 호환) | 디벨롭 | 쿠팡 시트 4개(기본/이미지+상세/옵션/검색태그), 스마트스토어 시트 4개(기본/배송/이미지+상세/옵션+태그). 실제 컬럼명은 플레이오토 양식 확보 후 확정(미확인) | Starter 이상만. Free 요청은 CM007 → 403 | `sellingstudio/PRD.md:91-96` |
| CM-F-033 | 마켓 계정 | 통합+디벨롭 | 계정 추가 시 키를 `core.encrypted_credentials`에 AES-256-GCM 저장, 화면에는 끝 4자리만. 저장 직후 검증 호출 | 응답·로그·DB 어디에도 평문 키 0건 | 분석:821, `docs/reviews/nomad-ai-commerce.md:60` |
| CM-F-034 | 등록 폼 | 디벨롭 | 6-Step을 쿠팡·스마트스토어 필드로 축소: 상품정보/가격·옵션/배송/반품/고시/검토. 완성도 = 필수 필드 채움 비율(`MARKET_REGISTER_FORM.md:442-455`), 서버 계산 | 완성도 100% 미만 마켓은 업로드 버튼 비활성, 서버도 거부 | 분석:825 |
| CM-F-035 | 배송·반품 템플릿 | 디벨롭 | 청약철회 기간 7일 이상(DB CHECK), 교환·반품 제한은 법정 예외 코드 4종만 선택, 자유 문구 불가. "단순 변심 반품 불가" 기본 템플릿 없음 | `return_window_days=3` 저장 시 23514 | `docs/reviews/Nomad-AI-Factory_V.2.md:49` |
| CM-F-036 | 쿠팡 반품비 가이드 | 유지 | 상품가 2만원 이하 2,500원, 2만~4만원 5,000원, 4만원 초과 5,000~8,000원 범위 안내(자동 적용 아님, 미확인: 쿠팡 현행 상한) | 상한 초과 입력 시 경고 표시 | `MARKET_REGISTER_FORM.md:232-240` |
| CM-F-037 | 업로드 실행 | 디벨롭 | 상품 x 계정 단위 잡. 상태 queued→validating→uploading→submitted→approved/rejected. 실패 사유 표시, 재시도 | 같은 요청 재전송 시 업로드 1건(멱등 키) | 분석:826, `docs/reviews/nomad-ai-commerce.md:69` |

### 3.5 신규/기획 공백 채움(분석 D-2 G, D-4)

| 공백 | 이 문서의 결정 | 위치 |
|---|---|---|
| 1 문서 충돌 결정표 | 슬롯 18개 정본, 필수 T-1·L-3, 10/15장 기본값, 파이프라인 8단계 이름과 진행률(3.6), 플랜 4종(4장), 스택 버전(02장 1절: @xyflow/react 12, proxy.ts) | 이 문서, 02장 |
| 2 백엔드 실행 모델 | `detail_pages` + `core.jobs` + 디스패처 + Node 워커 | 02장 4절 |
| 3 사용량 집행 지점 | Route Handler 선차감 + DB 트리거 한도 | CM-F-003/004 |
| 4 자격증명 암호화 | core `encrypted_credentials`, 키 `CREDENTIALS_KEY_V<n>` | 02장 8절, 05장 |
| 5 RLS·슈퍼어드민 | 05장 4절. 플랫폼 운영자는 service_role 관리 도구로만(제품 테이블 SELECT 정책에 넣지 않음) | 05장 |
| 6 아마존 데이터 공급자·SSRF | 서드파티 API(후보 Rainforest API, Keepa: 미확인), URL fetch 없음 | CM-F-010, 8장 |
| 7 마켓 API 승인 | 셀러 본인이 쿠팡 Wing Open API 키, 네이버 커머스API센터 애플리케이션을 발급(미확인: 솔루션사 등록 필요 여부) → 8장 D-5 | 8장 |
| 8 Toss 빌링·상태 전이·일할·Add-on·월 초기화 | 상태 전이는 core. 업그레이드 즉시 적용 + 차액 일할 결제(제안), 다운그레이드는 다음 결제일, Add-on은 Phase 2, 월 초기화는 core 크론 | 4.5절 |
| 9 판매관리 | Phase 3. 요구사항은 그때 새로 작성 | 2장 |
| 10 법률 검토 | 6장 표의 4개 문안을 출시 전 외부 검토 | 6장 |
| 11 Capacitor | MVP 이후. 배포 URL 원격 셸 + `CAP_SERVER_URL` 환경 분리 | 확정 결정 9 |
| 12 생성과 차감 한 흐름 | 생성 요청 Route Handler 1개가 차감·`detail_pages` INSERT·디스패처 대기 등록을 한다. 클라이언트는 차감 API를 따로 부르지 않는다 | 04장 2절 |
| G 슬롯 원가와 마진 | 4.3절 | 4.3절 |

### 3.6 파이프라인 8단계 정본

V.2 PRD(`PRD.md:243-251`), DETAIL(`DETAIL_PAGE_SYSTEM.md:360-437`), CLAUDE 진행률이 서로 달랐다(리뷰 V2 #8). 아래로 통일한다. `detail_pages.current_phase` CHECK 값과 같다.

| # | phase | 표시 문구 | 진행률 끝 | 내용 |
|---|---|---|---|---|
| 1 | `prepare` | 상품 정보 정리 중 | 10 | 상품 로드, 번역(LLM translate), 불릿 5개 추출 |
| 2 | `storyline` | 스토리라인 생성 중 | 25 | 슬롯별 장면·카피·프롬프트 JSON(zod 검증) |
| 3 | `copy` | 상품명·설명 작성 중 | 35 | 상품명 3안, 4단 설명(훅/설명/근거/CTA) |
| 4 | `images` | 슬롯 이미지 생성 중 (n/N) | 75 | 35 + 40 x 완료/전체. 슬롯별 render_method |
| 5 | `compose` | 한글 카피 합성 중 | 82 | Sharp 텍스트 합성 |
| 6 | `verify` | 품질·금지어 검사 중 | 88 | 해상도·비율·용량 검증, compliance 2단계 |
| 7 | `convert` | 마켓 규격 변환 중 | 97 | 마켓별 변환·분할 → `market_images` |
| 8 | `assemble` | 완료 | 100 | HTML 조립(sanitize), `detail_pages.status=ready` |

2026-10-13 변경: 1~3단계(`prepare`, `storyline`, `copy`)의 텍스트 생성은 워커가 LLM을 직접 부르지 않고 FastAPI 그래프 `commerce.detail_page`(CM-F-043)를 실행한 결과를 쓴다. 단계 이름과 진행률 구간은 그대로다. 6단계 `verify`의 compliance 판정은 그래프 `compliance` 노드가 낸 verdict를 쓰고, 워커는 이미지·합성 결과의 규격 검증과 최종 HTML에 대한 규칙 재검사(같은 `banned_words` 매처)만 한다. 이미지 합성 뒤에 텍스트가 바뀌는 경로는 없다(편집은 CM-F-026).

### 3.7 AI·음성 기능 (2026-10-13)

설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`다. 제품 기능 키와 기본 체인은 02장 5.1절, 그래프 노드는 02장 5.2절, 화면은 03장 3.1절·2.6~2.10절, API는 04장 2.1절이다. CM-F-025·026의 LLM 판정(2단계 판정, 편집 후 재판정)은 아래 그래프의 `compliance` 노드(`mode=compliance_only` 포함)가 맡는다.

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| CM-F-040 | 상품 스펙 RAG | 신규 | 셀러 조직의 컬렉션 `commerce-products`(kind `rag`)에 상품 행(제목, 불릿, 속성, 건기식 상태)을 문서로 만들어 색인하고, 셀러가 올린 스펙 시트(md, txt, csv, xlsx 2MB 이하. PDF는 구현 시 확인)도 색인한다. 임베딩은 오픈소스(`commerce.knowledge`, 대체 없음). 검색은 `match_ai_chunks`(org·app 강제)로 그래프 `retrieve` 노드와 채팅 모드 `product`가 한다. 색인은 비동기 잡이라 상품 등록·생성 흐름을 막지 않는다 | 평가셋 30문항(제안)에서 상위 8개 안 정답 청크 재현율 0.8 이상(제안). 다른 조직 컬렉션을 주면 42501. 색인 실패가 상세페이지 생성을 막지 않는다(그래프는 상품 행 원문으로 대체). 상품 삭제 30일 뒤 문서·청크도 삭제(상품 purge와 같은 시점) | `docs/products/_platform-core/AI_ARCHITECTURE.md:94-107` |
| CM-F-041 | 마켓 규칙 RAG | 신규 | 운영자 조직(`COMMERCE_KNOWLEDGE_ORG_ID`)의 컬렉션 `commerce-rules`(kind `rag`)에 쿠팡·스마트스토어 상품 등록 규칙(상품명 구성, 이미지 규격, 상품정보제공고시 유형, 대표 반려 사유), 금지어·표시광고 지침을 색인한다. 원고는 운영자가 작성·검수하고 항목마다 마켓, 기준일, 출처(공식 가이드 문서명. 확인하지 못한 출처는 "출처 확인 필요")를 메타데이터로 둔다. 조직 구분 없는 제품 공통 지식이라 Dify에는 외부 지식 API(`/dify/retrieval`)로만 노출하고 그래프·`/tools/answer`는 FastAPI 안에서 같은 컬렉션을 검색한다 | 평가셋 40문항(제안) 재현율@8 0.8 이상(제안). 외부 지식 API 응답에 셀러 조직 데이터 0. 원고 항목마다 마켓·기준일·검수자·검수일. 기준일 6개월(제안)을 넘긴 항목은 lint가 낡음 표시 | `docs/products/_platform-core/AI_ARCHITECTURE.md:58-66`, `:94-107` |
| CM-F-042 | 마켓 규칙 위키 | 신규 | 규칙 원고를 원본으로 위키 ingest가 `concept`(용어: 상품명 규칙, 고시 유형, 반려 코드), `topic`(마켓별 규칙: `markets/coupang/*`, `markets/smartstore/*`, `rules/banned-words`, `rules/health-food`, `rules/images`), `index` 페이지를 만든다(운영자 조직, app `commerce`). 새 페이지는 `draft`로 만들고 운영자가 검수해 `published`로 바꾼다. 운영자가 고친 블록은 `<!-- owner:user -->`로 표시해 ingest가 덮어쓰지 않고, 저장은 `expected_version` 낙관적 잠금, 문서 1건당 갱신 페이지는 5개까지(`docs/products/_platform-core/LLM_WIKI.md:30-31`, `:47`). 공개 화면 `/wiki`(공개 범위는 D-9). 주 1회 lint(모순, 낡음, 고아, 깨진 링크, 출처 없는 주장) | 공개 화면에 `draft` 페이지 0. 페이지마다 "출처"와 "기준일"과 "AI가 정리하고 운영자가 검수한 문서" 표시. 마켓 정책은 바뀔 수 있다는 안내문. 출시 시 lint 깨진 링크 0 | `docs/products/_platform-core/LLM_WIKI.md:12-47` |
| CM-F-043 | 상세페이지 생성 그래프 `commerce.detail_page` | 디벨롭 | FastAPI(`apps/api`)의 LangGraph 그래프 6노드: `extract`(상품 정보 추출: 상품 행·첨부 스펙·Vision 속성을 zod/pydantic 스키마의 구조화 입력으로 정리, 번역, 불릿 5개) → `retrieve`(규칙 검색: 대상 마켓별 규칙·금지어 지침·상품 스펙 청크) → `copy`(스토리라인, 슬롯별 카피·이미지 프롬프트, 상품명 3안, 4단 설명) → `banned_check`(금지어: `banned_words` 기본+조직 사전을 같은 매처 규칙 파일로 검사, 걸린 슬롯만 `copy` 1회 재작성) → `convert`(마켓 형식 변환: 마켓별 상품명 글자 수·구성, 고시 항목, 설명 길이를 `market_text`로) → `compliance`(마지막 필수 노드: 규칙 + LLM 판정으로 verdict `pass/warn/fail`와 issues). 이미지 생성·합성·마켓 이미지 변환은 그래프 밖 워커가 한다. 워커가 잡 토큰으로 실행을 요청한다(02장 4절). 후기·평점·"전문가 추천" 생성 금지(CM-F-027) | 생성 1건당 `core.ai_runs` 1행(graph=`commerce.detail_page`, `job_id`, `credit_ledger_id`=상세페이지 원장)과 노드별 `ai_run_steps`. 상품 행에 없는 가격·용량·성분 수치 0(입력 수치와 대조). 후기·평점 문형 검출 0. 재작성 후에도 FAIL 항목이 남으면 verdict `fail`. 그래프 최종 실패 시 상세페이지 `failed` + 환불 원장 1행. 평가셋 20건(제안)을 상용·오픈소스 경로 모두 통과 | `docs/products/_platform-core/AI_ARCHITECTURE.md:109-119`, `docs/reviews/Nomad-AI-Factory_V.2.md:48` |
| CM-F-044 | 보조 AI 그래프 `commerce.assist` | 디벨롭 | 입력 보조를 한 그래프로 모은다: 작업 `names`(상품명 3안·키워드), `autofill`(카테고리·고시·태그 제안), `benchmark`(공개 페이지 요약), `vision`(상품 이미지 속성), `voice_structure`(음성 텍스트 → 상품 필드), `shorts_script`(쇼츠 스크립트). 노드 `input_check` → `generate` → `validate`(스키마, 실패 시 1회 재요청) → `compliance`(금지어 규칙). Route Handler가 서명 토큰으로 실행하고 결과를 기다린다(최대 30초). 정액 크레딧(4.2절). 기존 입력 보조(상품명·키워드, 자동완성, URL 벤치마킹 요약, Vision)의 LLM 호출을 대체한다 | 스키마 검증 실패 2회면 오류 + 환불 1행. 생성물에 금지어 FAIL 0(재작성 또는 경고). 요청 바디의 모델·제공자 값은 무시 | `docs/products/_platform-core/AI_ARCHITECTURE.md:109-119` |
| CM-F-045 | 셀러 어시스턴트 채팅 | 신규 | 로그인 사용자 전용. 대시보드 채팅 패널과 상세페이지·업로드 이력의 "이것에 대해 묻기". 모드 `rules`(마켓 규칙·금지어·반려 사유 질문: 위키 + `commerce-rules` 근거)와 모드 `product`(내 상품·상세페이지·업로드 실패 원인: 대화 시작 때 `product_id`/`detail_page_id`/`upload_id`를 묶고 FastAPI가 같은 조직인지 매번 대조, 근거는 상품 행 + 상품 스펙 청크 + 업로드 `error_*` 요약). 스트리밍, 답변마다 출처와 규칙 기준일, "AI가 생성한 답변" 표시. 메시지 1,000자, 대화당 50턴(제안). 마켓 계정 키·사업자등록번호 입력은 마스킹. 크레딧은 턴 선차감 후 정산(4.6절). 채팅은 조언만 하고 업로드·결제·키 등록 같은 실행을 하지 않는다 | 답변에 출처 1개 이상 또는 "근거 자료를 찾지 못했습니다". 평가셋 30문항(제안)에서 승인·반려 보장 문형과 법률 단정 문형 0. 응답이 전달되지 않은 턴은 선차감 전액 환불. 잔액 부족 402(`CR001`). Dify 장애 시 `/tools/answer-direct`로 답한다. 다른 사용자 대화 id로 이어 쓰면 404, 다른 조직 `product_id` 바인딩 403 | `docs/products/_platform-core/AI_ARCHITECTURE.md:44-56`, `:121-130` |
| CM-F-046 | 음성 대화 | 신규 | 채팅 패널의 마이크 버튼(누르고 말하기). 발화 최대 60초(제안). STT(`voice_chat`, 오픈소스 우선) → 변환 텍스트 미리보기·수정 → 전송 → 답변 → "읽어 주기"(TTS, ElevenLabs 우선, 자동 재생 기본 꺼짐). 녹음 원본은 저장하지 않는다. 첫 사용 때 음성 처리 고지 확인(6.1절). 플랜 `features.voice_chat` | 60초가 되면 녹음 자동 중지. `voice_jobs.store_audio=false` 100%. 마이크 권한을 거부해도 텍스트 채팅 정상. 고지 확인 없이 STT 호출 시 403 `VOICE_CONSENT_REQUIRED` | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:40-48`, `:85-95`, `:106-110` |
| CM-F-047 | 상품 설명 음성 입력 | 디벨롭 | 기존 입력 보조 "음성 STT"(fal whisper)를 대체한다. 상품 등록 화면과 생성 모달에서 마이크 → STT(`product_voice`, 오픈소스 우선, 120초·10MB 이하) → 변환 텍스트 수정 → 보조 그래프 작업 `voice_structure`(상품명 후보, 특징 불릿, 속성, 용도)로 구조화 → 상품 폼에 채움(저장 전 사용자 확인). 녹음 원본은 저장하지 않는다. 플랜 `features.voice_input`(starter 이상) 유지 | 고지 확인 없이 STT 403. `store_audio=false` 100%. 120초 또는 10MB 초과 413 `VOICE_TOO_LONG`. 플랜 밖 403 `CM007`. 구조화 결과가 상품 폼 zod 스키마를 통과한 필드만 채운다. STT·구조화 실패 시 환불 1행 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:85-95`, `docs/reviews/sellingstudio.md:58` |
| CM-F-048 | 쇼츠 내레이션 음성 | 신규 | 상품 또는 상세페이지를 골라 보조 그래프 작업 `shorts_script`로 15/30/50초 분량 스크립트(글자 수 약 90/170/280자, 제안; 상한 600자)를 만들고, 사용자가 고친 뒤(금지어·광고 규칙 검사) TTS(`shorts_narration`)로 mp3를 만든다. 보이스는 ElevenLabs 기본 1종 + 오픈소스 1종(D-12). 작업 도중 다른 제공자로 대체하지 않고(같은 목소리), 시작 전 ElevenLabs를 쓸 수 없으면(국외 이전 미동의, 비활성) 처음부터 오픈소스 보이스로 만든다. 파일은 `exports/<org_id>/commerce/narration/<product_id>/<hash16>.mp3`(`hash16` = 스크립트·보이스·제공자 해시 앞 16자)에 저장하고 같은 요청은 기존 파일을 돌려준다. 영상 렌더·결합은 Phase 2에 nomad-video 워커 API로 이 파일 경로를 넘긴다(CM-06-038). 타인 목소리 복제(클로닝)는 제공하지 않는다 | 한 내레이션의 `ai_usage` 제공자가 모두 같고 `voice_jobs.fallback_from` null. 실패 시 파일 미생성 + 선차감 전액 환불. 같은 스크립트·보이스 재요청은 추가 차감 0. 스크립트 600자 초과 422. 금지어 FAIL 스크립트는 TTS 단계에서 거부. 플랜 `features.shorts_narration` | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:47`, `:80`, 확정 결정 6 |
| CM-F-049 | AI 라우팅과 국외 이전 동의 | 신규 | 가입 직후 온보딩에서 "AI 처리 방식"을 고른다: 상용 AI 사용(국외 이전 동의) 또는 국내 오픈소스만. 동의하면 `core.set_ai_cross_border_ack(org, true, 고지문 버전)`을 호출하고(owner/admin), 설정에서 언제든 철회한다. 기능별 기본 체인은 02장 5.1절(seed와 일치). 동의가 없으면 모든 AI·음성 기능이 오픈소스 제공자만 쓴다. 이미지 생성(fal)은 라우팅 체인 밖이며 D-15 | 미동의 조직의 `ai_usage.provider_id`에 상용 제공자 0. 철회 직후 다음 요청부터 상용 0. 고지문 버전이 `ai_org_settings.cross_border_notice`와 감사 `ai.cross_border.ack`에 같게 남는다 | `docs/products/_platform-core/AI_ARCHITECTURE.md:86`, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:553-575` |
| CM-F-050 | AI 크레딧 선차감·정산 | 신규 | 채팅 턴·STT·TTS·내레이션은 시작 때 예상 크레딧을 `consume_credits`로 선차감하고, 끝나면 실제 사용량으로 정산한다(차액 추가 차감 또는 `refund_credits`). 상세페이지 그래프와 보조 그래프 작업은 4.2절 정액 차감에 묶고 정산 차액이 없다(4.6절) | 1시간 넘게 지난 `ai_usage` 중 `settled_at is null` 0행. 같은 멱등 키 재요청 시 차감 1회. 원장 drift 0 | `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130` |
| CM-F-051 | AI 출력 규칙(생성물·채팅·내레이션·위키) | 신규 | 6절 금지 문구와 6.1절 AI 대화 규칙을 그래프 compliance 노드와 `/tools/answer` 후처리에 같은 규칙 파일(`packages/commerce-compliance/rules/*.json`, 금지어 사전은 `banned_words`와 같은 출처)로 적용한다. 승인·반려 보장, 법률 단정, 질병 효능 단정은 거절하거나 완곡하게 바꾸고 전문가·마켓 공지 확인을 안내한다 | 채팅 평가셋 30문항(제안) 위반 0. 그래프 평가셋 20건에서 금지 문형 0 | `docs/products/_platform-core/AI_ARCHITECTURE.md:117`, 6절 |
| CM-F-052 | 3D 히어로 | 신규 | 랜딩 히어로: PC·태블릿은 상품 상자가 열리며 상세페이지 패널로 펼쳐지고 마켓 진열대에 놓이는 풀 3D, 모바일은 상자 열림만 있는 가벼운 3D, WebGL 미지원·저사양·`prefers-reduced-motion`은 정지 이미지(03장 4.5절) | `HERO_3D.md` 4절 수용 기준 전부: 기기별 3종 동작, 3D 번들+에셋 PC·태블릿 1MB/모바일 300KB 이하, LCP 2.5초, 제목·입력·CTA가 3D 전에 보이고 키보드로 사용 가능, 3종 스크린샷 고문 검토 통과 | `docs/products/_design-guide/HERO_3D.md:5-75`, `:85` |

## 4. 요금과 크레딧

### 4.1 플랜 (정본, 확정 결정 8)

가격은 V.2(`Nomad-AI-Factory_V.2/PRD.md:296-301`), 월 크레딧은 sellingstudio(`sellingstudio/PRD.md:155-158`)를 플랜별로 옮겼다. 모든 가격은 원화, VAT 포함이다(B2C SaaS 기본, `docs/Price_Plans/_common/PRICING_PRINCIPLES.md` 7장, 2026-10-14 결정). 2026-10-14 가격 정책 판정으로 Free 가입 크레딧 30(D-3 (b)), `enterprise` 월 900 크레딧·상품 10,000·계정 30·초기 미판매(D-1), 크레딧팩 단가 조정(4.5절)을 반영했다. 단계별 인상 계획은 `docs/Price_Plans/nomad-commerce/PRICE_PLAN.md` 6장.

| 코드 | 가격(월, VAT 포함) | 월 크레딧 | 가입 크레딧 | 이월 | 주요 features |
|---|---|---|---|---|---|
| `free` | 0원 | 15 | 30 | 없음 | 상품 30, 계정 1, 유형 설득형, 10슬롯, 동시 1, ZIP |
| `starter` | 29,000원 | 150 | 0 | 없음 | 상품 300, 계정 3, 유형 3종, 10/15슬롯, 동시 1, 엑셀, URL·음성 입력 |
| `pro` | 69,000원 | 350 | 0 | 없음 | 상품 2,000, 계정 10, 동시 2, 고화질 모델 |
| `enterprise` | 149,000원 | 900 | 0 | 없음 | 상품 10,000, 계정 30, 동시 5, 최고 화질, API 접근(Phase 2). 초기 미판매(`is_active=false`, D-1), 중기 게이트 통과 후 판매 |

연간 결제(월 x 10, `PRD.md:303`)와 Add-on(`PRD.md:304`)은 Phase 2. 이월(SS PRO 50%, ENT 100%, `sellingstudio/PRD.md:157-158`)은 core `plans.carry_over`가 boolean이라 MVP는 이월 없음(8장 결정). 모듈러 `seed.sql`은 2026-10-13에 이 표(모놀리스 seed)와 같은 값으로 맞춰졌다. 모놀리스 `supabase/monolith/seed.sql`은 이 표와 같다.

### 4.2 크레딧 단가

| 작업 | 크레딧 | 근거 |
|---|---|---|
| 상세페이지 10슬롯 | 9 | SS 기본(6장) 5 + 추가 장당 1 x 4(`sellingstudio/PRD.md:55-56`) |
| 상세페이지 15슬롯 | 14 | 같은 공식 |
| 단일 슬롯 재생성 | 1 | SS 이미지 1장 추가 +1 |
| 단일 슬롯 고화질 재생성 | 3 | +1 + 고화질 +2(`:59`) |
| URL 벤치마킹 | 2 | `:57` |
| 음성 입력 STT | 4.6절(제공자별: 오픈소스 1, ElevenLabs 최대 6) | SS 기본 1(`sellingstudio/PRD.md:58`)을 음성 제공자 이원화로 대체 |
| 상품명·키워드 추천 3종 | 1 | `:61` |
| AI 자동완성(카테고리/고시/태그) 1회 | 1 | 제안: LLM 1회 비용이 키워드 추천과 같은 급 |
| 아마존 상품 가져오기 1건 | 1 | 제안: 서드파티 API 건당 과금(미확인 단가)을 흡수 |
| 편집 후 compliance LLM 재판정 | 1 | `_platform-core/SHARED_MODULES.md` 13장. 생성 시 1회 판정은 상세페이지 단가에 포함 |
| 엑셀 가져오기, 엑셀/ZIP 내보내기, 마켓 업로드 | 0 | 제안: 외부 AI 비용 없음. 플랜 한도(상품 수, 계정 슬롯)로 과금 |

AI 계층 도입(2026-10-13) 뒤에도 위 단가는 바꾸지 않는다. 그래프(`commerce.detail_page`, `commerce.assist`) 호출 비용은 이 정액에 포함되고, 채팅·음성은 4.6절이 따로 정한다.

### 4.3 원가와 마진(제안, 분석 G "슬롯당 원가")

| 항목 | 10슬롯 설득형 기준 | 근거 |
|---|---|---|
| AI 씬 3장(T-2, D-1, D-3) | flux-dev $0.075 / flux-pro $0.12 / ultra $0.18 | `sellingstudio/PRD.md:27-29` |
| 누끼 1장 | $0.001 | `:30` |
| 인포그래픽·법적고지 6장 | Puppeteer, 외부 비용 0 | `MARKET_IMAGE_SPEC.md:16` |
| LLM(스토리라인, 카피, 판정) | 약 $0.05(제안, 미확인) | 토큰 단가 미확인 |
| 합계 | 약 $0.13~0.23 = 180~330원(환율 1,400원 가정) | |
| 매출(9크레딧) | starter 1,740원 / pro 1,775원 / enterprise 1,490원 | 플랜가 / 월 크레딧(enterprise 900 기준) |

엔터프라이즈의 크레딧당 단가가 550 크레딧일 때 271원으로 프로(197원)보다 비쌌다. 2026-10-14 900 크레딧(크레딧당 약 166원)으로 고쳐 역전을 없앴다. ultra 화질 330원/건으로 전부 써도 매출총이익률 약 70%다(`docs/Price_Plans/nomad-commerce/PRICE_PLAN.md` 3장). 1,100(D-1 (b))은 약 64%라 쓰지 않는다. 8장 D-1.

그래프 도입으로 규칙 검색·금지어 재작성·마켓 변환이 더해져 LLM 항목은 약 $0.06~0.08(제안, 미확인)로 늘 수 있다. 오픈소스 경로(국외 이전 미동의)는 GPU 원가 기준으로 더 낮다. 구현 뒤 `core.ai_usage`(run_id)로 실제 원가를 확인해 정액을 재검토한다.

### 4.4 `core.plans.features` 키 해석 (서버만 읽음)

| 키 | 타입 | 의미 | 없을 때 | 집행 위치 |
|---|---|---|---|---|
| `products` | int | 삭제되지 않은 상품 수 상한, -1 무제한(판매 플랜에는 쓰지 않는다. enterprise 10,000) | 0 | 트리거 `products_enforce_quota`(CM002) |
| `market_slots` | int | active 마켓 계정 수 상한(enterprise 30) | 1 | 트리거 `market_accounts_enforce`(CM003) |
| `detail_types` | text[] | 허용 유형 | `["persuasive"]` | Route Handler 403 |
| `slot_sets` | int[] | 허용 슬롯 세트 | `[10]` | Route Handler 403 |
| `concurrency` | int | 동시 generating 상세페이지 수 | 1 | 디스패처 |
| `market_api` | text[] | API 업로드 허용 마켓 | `[]` | 트리거 `market_uploads_gate`(CM007) |
| `excel_export` / `zip_export` | bool | 내보내기 허용 | false / true | 트리거 `export_files_gate`(CM007) |
| `url_benchmark` / `voice_input` | bool | 입력 보조(`voice_input` = 상품 설명 음성 입력 STT) | false | Route Handler 403 |
| `ai_chat` | bool | 셀러 어시스턴트 채팅(텍스트) 허용 | true | Route Handler 403 |
| `ai_chat_turns_per_day` | int | 사용자당 하루 채팅 턴 상한(공정 사용) | 20 | Route Handler 429 `AI_DAILY_LIMIT` |
| `voice_chat` | bool | 음성 대화 허용 | false | Route Handler 403 |
| `shorts_narration` | bool | 쇼츠 내레이션 음성 허용 | false | Route Handler 403 |
| `image_quality` | text | draft(flux-schnell) / standard(flux-dev) / pro(flux-pro) / ultra(flux-pro-ultra) | draft | 워커 모델 선택 |
| `api_access` | bool | 외부 API 키 발급(Phase 2) | false | Route Handler |

AI 키 4개(`ai_chat`, `ai_chat_turns_per_day`, `voice_chat`, `shorts_narration`)는 2026-10-13에 추가했다. 플랜별 값은 free(true, 20, false, false), starter·pro(true, 200, true, true), enterprise(true, 500, true, true)다(제안). 모놀리스는 `supabase/monolith/seed.sql`의 플랜 행에, 모듈러는 `docs/products/_supabase-modular/migrations/1400_commerce.sql:1045-1051`(20.2절)의 병합 UPDATE에 있다(모듈러 `seed.sql` 반영은 06장 6.1절 R-1).

### 4.5 크레딧팩과 구독 정책

| 코드 | 크레딧 | 가격(VAT 포함) | 크레딧당 | 근거 |
|---|---|---|---|---|
| `pack_50` | 50 | 10,000원 | 200원 | `sellingstudio/PRD.md:160` |
| `pack_120` | 120 | 23,900원 | 약 199원 | 2026-10-14 결정(이전 20,000원) |
| `pack_200` | 200 | 39,900원 | 약 200원 | 2026-10-14 결정(이전 30,000원) |

팩 단가 근거(2026-10-14): 소멸 없는 팩의 크레딧당 단가가 구독(starter 약 193원, pro 약 197원)보다 싸면 구독을 잠식한다. 팩 3종을 크레딧당 약 199~200원으로 맞춰 모든 구독보다 비싸게 둔다. 그래도 상세페이지 1건(9크레딧) 약 1,800원으로 국내 경쟁 도구(건당 약 5,000원)보다 낮다(`docs/Price_Plans/nomad-commerce/PRICE_PLAN.md` 4장, 10장 CM-P-6).

| 정책 | 내용 |
|---|---|
| 구독 상태 | core `apply_subscription_transition`(trialing/active/past_due/canceled/expired) |
| 업그레이드 | 즉시 적용, 남은 기간 차액 일할 결제, 새 플랜 월 크레딧 즉시 지급(제안: 사용자가 바로 쓰기를 기대) |
| 다운그레이드 | 다음 결제일 적용. 한도 초과 상품·계정은 삭제하지 않고 신규 추가만 막힌다(트리거가 신규만 검사) |
| 결제 실패 | past_due → 1/3/7일 재시도 → canceled(`CORE_SPEC.md` 5.3 제안값) |
| 환불 | 구독 첫 결제 후 7일 이내 미사용(크레딧 사용 0)이면 전액(제안: 전자상거래법 청약철회 기간 7일과 맞춤). 크레딧팩은 미사용분만 |
| 결제 실패 기록(코어 수정 반영, 2026-10-13) | `confirm_payment_order` 금액 불일치는 `PM001`(계약 불변). 제품은 PM001을 받으면 Route Handler가 별도 호출로 `fail_payment_order(order_id, 'amount_mismatch', {...})`를 부른 뒤 운영 알림 + Toss 취소를 호출한다 |

### 4.6 AI·음성 크레딧 단가 (2026-10-13, 제안)

4.2절 단가와 4.5절 크레딧팩은 이 절에서 바꾸지 않는다(팩 가격은 2026-10-14 가격 정책으로 따로 조정). 제공자 단가는 코어 seed `core.ai_model_prices`(`docs/products/_supabase-modular/seed.sql:243-262`: LLM 상용 1k 입력 1cr·출력 4cr, 오픈소스 0.2·0.5cr, STT ElevenLabs 3cr/분·오픈소스 0.5cr/분, TTS ElevenLabs 5cr/천 자·오픈소스 1cr/천 자, 모두 제안값)이고, 이 표는 그 값을 commerce 기능에 적용한 것이다. 계산 상수는 `apps/nomad-commerce/lib/ai/pricing.ts`(4.2절과 같은 이유로 코드 상수). 선차감과 정산 규칙은 `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130`, 음성 단가는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104`를 따른다.

| 작업 | 선차감(예상) | 정산 | 상용 경로 예 | 오픈소스 경로 예 | 멱등 키 |
|---|---|---|---|---|---|
| 상세페이지 생성(그래프 포함) | 9 / 14(정액) | 차액 없음. 그래프 `ai_usage`에 원가만 기록하고 실행 끝에 `settled_at`을 채운다. 별도 `run:<id>` 차감을 하지 않는다 | 카피 모델 상용 우선 | `oss-llm` | `consume:commerce:<request_id>` |
| 보조 AI 정액 작업(상품명·키워드 1, 자동완성 1, URL 벤치마킹 2, Vision 단독 1, 쇼츠 스크립트 1, 편집 후 compliance 재판정 1) | 4.2절 그대로 | 차액 없음(위와 같은 방식) | 저비용 모델 우선 | `oss-llm` | `consume:commerce:<request_id>` |
| 셀러 어시스턴트 채팅 1턴(텍스트) | 3 | 실제 토큰 × 단가 + Dify 보조 노드 오버헤드 0.5, 올림. 최소 1, 상한 5(초과분은 운영사 부담) | 규칙 질문 약 2~3, 상품 근거 질문 약 4~5(상한) | 약 1~2 | `conv:<id>:turn:<n>` |
| 음성 대화 STT(60초 이하) | 녹음 길이 기준 올림: 오픈소스 1, ElevenLabs 3 | 실제 `audio_seconds` | 3 | 1 | `voice:<voice_job_id>` |
| 상품 설명 음성 입력 STT(120초 이하) | 분 단위 올림 × 단가(오픈소스 0.5, ElevenLabs 3), 최소 1 | 실제 `audio_seconds`. 구조화(`voice_structure`)는 포함 | 120초 6 | 120초 1 | `voice:<voice_job_id>` |
| 답변 읽어 주기 TTS | 답변 글자 수 × 단가, 천 자 단위 올림 | 실제 `characters` | 600자 답변 5 | 600자 답변 1 | `voice:<voice_job_id>` |
| 쇼츠 내레이션 TTS | 스크립트 글자 수 × 단가, 천 자 단위 올림(600자 상한이라 1천 자 이하) | 실제 `characters` | 5 | 1 | `voice:<voice_job_id>`(= 요청 `request_id`) |
| 내레이션 재생·재다운로드, 같은 스크립트 재요청 | 0 | - | - | - | - |
| 위키 열람 | 0 | - | - | - | - |
| 상품 스펙 색인 | 사용자 과금 없음(운영사 부담. 조직별 월 색인 상한은 D-11) | 사용량 기록 | - | - | `run:<id>` |
| 마켓 규칙 색인, 위키 ingest·lint | 사용자 과금 없음. 운영자 조직 지갑에서 사용량 차감 | 사용량 | - | - | `run:<id>` |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 경로별 단가 | 국외 이전에 동의하지 않은 조직은 체인에 오픈소스만 남으므로 오픈소스 단가가 자동 적용된다. 화면은 실제로 고른 경로의 예상치를 보여 준다 | `docs/products/_supabase-modular/migrations/0008_core_ai.sql:452-460` |
| 실패 환불 | 사용자에게 결과가 전달되지 않은 실패는 선차감 전액 환불. 내레이션은 어느 단계든 실패하면 파일을 만들지 않고 전액 환불 | `docs/products/_platform-core/AI_ARCHITECTURE.md:129` |
| 정산 시점 | 응답·작업 종료 직후 정산. 스트림이 끊기면 선차감을 남기고 정산 잡이 `settled_at is null` 행을 5분 주기로 처리(제안) | `docs/products/_platform-core/AI_ARCHITECTURE.md:128` |
| 표시 | 보내기 전 "약 3크레딧(정산 후 1~5)", 내레이션 버튼에 예상치, 정산 결과는 메시지 아래와 원장 표에 | 제안 |
| 공정 사용 | 사용자당 하루 `features.ai_chat_turns_per_day`턴(free 20, starter·pro 200, enterprise 500) | 제안 |
| Free 플랜 | 월 15크레딧(첫 달은 가입 30 추가)이라 채팅 5턴이면 월 지급분이 소진된다. 채팅 무료 제공은 D-10 | 제안 |

## 5. 비기능 요구사항

| 항목 | 값 | 근거 |
|---|---|---|
| 페이지 응답(대시보드, 목록) | p95 1.5초 | 제안 |
| 생성 요청 API 응답 | p95 800ms(잡 등록까지) | 제안 |
| 10슬롯 생성 | p50 165초, p95 240초 | `DETAIL_PAGE_SYSTEM.md:438-443` |
| 15슬롯 생성 | p95 300초 | 같은 표 + 여유 |
| 슬롯 이미지 호출 타임아웃 | fal 30초 제출, 웹훅 미도착 30분 → 실패·환불 | `sellingstudio/PRD.md:180`, SHARED_MODULES 9장 |
| 재시도 | 잡 3회 지수 백오프, 이미지 3회 | `sellingstudio/PRD.md:180` |
| 워커 동시성 | 컨테이너당 detail 4, upload 8, export 2(제안) | Puppeteer 메모리 |
| 업로드 파일 | 상품 이미지 10MB, 엑셀 10MB, 2,000행 | 제안 |
| 보존 | 생성 이미지·마켓 변환본: 상품 삭제 시 30일 뒤 purge. 내보내기 파일 7일. 엑셀 원본 30일. 실패 업로드 응답 요약 1년 | 제안 |
| 그래프 실행(`commerce.detail_page`) | 10슬롯 기준 p95 60초 이하(전체 p95 240초에 포함), 타임아웃 120초 | 제안 |
| 보조 AI(`commerce.assist`) 응답 | p95 12초 이하, 타임아웃 30초 | 제안 |
| 채팅 첫 표시 | 규칙 질문 p95 4초, 상품 근거 질문 p95 10초 이하(HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 표시) | 제안 |
| 채팅 턴 완료 | p95 15초 이하 | 제안 |
| STT | 60초 발화 p95 5초, 120초 발화 p95 8초 이하 | 제안: 오픈소스 GPU 서버 기준, 구현 시 확인 |
| TTS | 첫 오디오 p95 2초, 쇼츠 내레이션(600자) 생성 p95 20초 이하 | 제안 |
| AI 레이트 리밋 | 채팅 사용자당 20턴/분 + 하루 `ai_chat_turns_per_day`, STT 사용자당 10회/분, 내레이션 조직당 10회/시간, 보조 AI는 생성 API 조직당 60회/분에 포함, 잡 토큰 발급 120회/분 | 제안: `docs/products/_platform-core/SECURITY_BASELINE.md:143-155` 기준 |
| AI 입력 상한 | 채팅 메시지 1,000자, 대화당 50턴, 음성 대화 60초·5MB, 상품 설명 음성 입력 120초·10MB, 쇼츠 스크립트 600자 | 제안 |
| AI 기록 보존 | Dify 대화 로그 30일, `core.ai_messages`는 대화 삭제 또는 탈퇴 후 30일, 상품 스펙 청크는 상품 purge와 같은 시점 | `docs/products/_platform-core/AI_ARCHITECTURE.md:69`(제안 30일) |
| 3D 히어로 | 3D 번들+에셋 PC·태블릿 1MB, 모바일 300KB 이하, 60fps / 30fps 이상, LCP 2.5초 | `docs/products/_design-guide/HERO_3D.md:32-41` |
| 레이트 리밋 | 생성 API 조직당 60회/분, 로그인 IP당 10회/10분, 웹훅 600회/분 | `SECURITY_BASELINE.md` 8장 |
| 가용성 | 월 99.5%(웹), 워커 장애 시 잡은 대기 후 재개 | 제안 |
| 브라우저 | 최신 Chrome/Edge/Safari, 375px 이상 | 제안 |

## 6. 법, 개인정보, 금지 문구

| 항목 | 내용 |
|---|---|
| 개인정보 | 수집: 이메일, 이름, 결제 요약(카드 마스킹), 셀러 사업자 연락처·반품지 주소(템플릿), 마켓 계정 식별자. 목적: 서비스 제공·결제·마켓 등록. 보존: 탈퇴 후 30일 유예 뒤 purge(`SECURITY_BASELINE.md` 12장), 결제기록은 전자상거래법상 5년. 암호화: 마켓 API 키·시크릿(`encrypted_credentials`), 빌링키(`billing_keys`). 삭제: 조직 soft delete → 30일 → `purge_organization` |
| 제3자 제공 | 상품 정보·이미지·카피·채팅 메시지를 상용 AI 제공자(LLM: Anthropic, OpenAI, Google, OpenRouter / 음성: ElevenLabs)에는 국외 이전에 동의한 조직의 요청에만 보낸다(6.1절). 이미지 생성은 fal에 보낸다(라우팅 체인 밖, D-15). 그 밖에 아마존 상품 데이터 공급자, 쿠팡·네이버(업로드)로 보낸다. 오픈소스 LLM·임베딩·음성 서버와 Dify는 운영사가 자체 운영한다(서버 위치·위탁 여부 구현 시 확인). 개인정보는 보내지 않는다(반품지 주소는 마켓 업로드 시에만 해당 마켓으로). 처리방침에 제공자 목록과 이전 국가 고지 |
| 약관/고지 | 이용약관, 개인정보처리방침, "AI 생성물은 셀러가 검수 후 게시하며 게시 책임은 셀러에게 있다" 안내, 생성 이미지에 대한 권리(상업 이용 가능 여부는 fal 모델 약관 확인, 미확인) |
| AI 생성 표시 | 결과물 화면과 다운로드에 "AI로 생성된 이미지 포함" 메타 표기. 상세페이지 본문 삽입 여부는 마켓 정책 확인 후(미확인, D-17). 채팅 답변마다 "AI가 생성한 답변", 내레이션 플레이어와 다운로드 화면에 "AI가 생성한 음성입니다"(파일 안에는 안내 음성을 넣지 않는다. 쇼츠에 게시할 때의 AI 음성 표시는 게시 채널 정책에 따라 셀러가 한다, 미확인), 위키 페이지에 "AI가 정리하고 운영자가 검수한 문서". 다른 모델로 대체된 답변은 "다른 AI 모델로 답했습니다" 표시 |
| 제휴/광고 | commerce는 제휴 링크를 다루지 않는다(확정 결정 12). 대가성 문구 규칙 해당 없음 |
| 플랫폼 약관 | 쿠팡 Wing·네이버 커머스 API는 셀러 본인 키로 호출. 아마존은 직접 스크래핑 금지(약관), 서드파티 공급자 약관 확인. URL 벤치마킹은 공개 페이지 1회 조회만, 결과는 분석 요약만 저장(원문 저장 금지) |
| 법률 검토 필요 문안(출시 전) | (1) 청약철회·교환·반품 안내와 제한 사유 4코드, (2) 건강기능식품 표시(L-1 슬롯: 인정 제품의 표시사항 / 일반식품의 "질병 예방·치료 효능 표시 금지" 안내), (3) 해외구매대행 고지(수입식품 등 구매대행업 신고 요건), (4) 상품정보제공고시 자동완성 결과 책임 안내, (5) AI 고지문(국외 이전 동의 고지, 음성 처리 고지, AI 생성물·채팅 답변 면책과 마켓 정책 기준일 안내) |
| 자동 삽입 금지 | "단순 변심 반품 불가", "이 제품은 건강기능식품이 아닙니다"(실제 건기식이면 허위), AI 생성 후기·평점·"전문가 추천"(`docs/reviews/Nomad-AI-Factory_V.2.md:48-49`) |
| 금지 문구(제품 마케팅과 생성 콘텐츠 공통) | 가상 후기(존재하지 않는 고객 후기·평점), 허위 수치(원본 랜딩의 "2,847+ 셀러", "120만 상품", "재구독률 94%" 같은 미검증 숫자), 보장 표현("100% 통과", "반려 없음", "매출 보장"), 의료·건강 단정("치료", "면역력 강화 효과 확정"), 타사 상표 오용(쿠팡·네이버 로고를 제휴처럼 표시) |
| 규제 특례 | 건강기능식품법 표시·광고 규정, 식품표시광고법, 전자상거래법 청약철회. 금지어 사전은 법률 검토 뒤 확정 |

### 6.1 AI·음성 개인정보 판단과 대화 규칙 (2026-10-13)

| 항목 | 판단 | 이유와 처리 |
|---|---|---|
| 상품 정보(상품명, 가격, 이미지, 스펙) | 개인정보가 아니다. 오픈소스 강제는 두지 않고(`force_open_source=false`) 국외 이전 동의로 통제한다 | 상세페이지 품질이 제품 핵심이라 상용 모델 우선. 동의가 없는 조직은 `resolve_ai_route`가 상용을 자동으로 걸러 낸다(`docs/products/_supabase-modular/migrations/0008_core_ai.sql:452-456`) |
| 공급자 자료 저작권 | 업로드한 스펙 시트·이미지의 권리는 셀러에게 있다 | 약관에 "업로드 자료에 대한 권리 보유" 조항. 소싱 자료를 AI가 학습에 쓰지 않도록 상용 제공자 약관(학습 미사용)을 구현 시 확인 |
| 셀러 연락처·반품지 주소·마켓 키·사업자등록번호 | AI 요청에 넣지 않는다 | 그래프 입력 스키마에 이 필드가 없고, 채팅은 보내기 전 서버가 마켓 키 형식·사업자번호·전화번호·이메일·계좌번호 형식을 마스킹한다(제안). 입력란에 "마켓 API 키, 사업자등록번호, 계좌·카드 번호를 적지 마세요" 안내 |
| 상품 이미지 속 인물 | 공급자 이미지에 모델 사진이 있을 수 있다(초상·개인정보 가능성) | Vision은 상품 속성만 뽑고 인물 식별을 요청하지 않는다. 국외 이전 동의 조직만 상용 Vision 사용. 법무 확인 필요(구현 시 확인) |
| 음성 | 상품 설명을 말하는 목소리는 본인 음성이다. 주변 사람 목소리가 함께 인식될 수 있다 | 음성 처리 고지에 "주변 소리가 함께 인식될 수 있음"을 넣는다. 녹음 원본은 저장하지 않으므로(`store_audio=false`) `third_party_notice` 동의 기록은 필요 없다. 녹음을 저장하는 기능을 나중에 넣으면 그때 `voice_jobs.consent_kind`를 쓴다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:94-95`) |
| 내레이션 보이스 | 타인 목소리 복제를 제공하지 않는다 | 퍼블리시티권 위험(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:80`) |
| Dify 보조 노드 | 조직을 알 수 없어 동의를 확인할 수 없다 | `dify.aux`는 오픈소스 강제(`force_open_source=true`, 02장 5절) |

| 고지·동의 | 시점 | 기록 |
|---|---|---|
| 상용 AI 국외 이전 | 가입 직후 온보딩, 설정에서 변경 | `core.set_ai_cross_border_ack`가 `ai_org_settings`에 고지문 버전을 남기고 감사 `ai.cross_border.ack`/`revoke`를 쓴다(`docs/products/_supabase-modular/migrations/0008_core_ai.sql:553-575`). commerce는 동의 테이블을 따로 두지 않고 이 기록이 증빙이다(05장 6절) |
| 음성 처리 고지(녹음) | 첫 마이크 사용 직전. 녹음 목적, 원본 미저장, 주변 소리 인식, 상용 제공자 사용 시 국외 이전 | 감사 `ai.voice_notice.ack`(`core.write_audit`, 대상 사용자, `after.notice_version`). Route Handler가 현재 고지문 버전의 확인 행이 없으면 403 `VOICE_CONSENT_REQUIRED` |
| AI 생성 표시 | 결과·채팅·내레이션·위키 | 6절 표 |

AI 대화 추가 규칙(6절 금지 문구에 더해 생성물·채팅·내레이션에 적용):

| 분류 | 금지 | 대신 |
|---|---|---|
| 승인·반려 보장 | "이대로 올리면 승인됩니다", "반려되지 않습니다", "쿠팡 규정 통과" | "위키 기준일(○○)의 규칙으로는 문제 항목이 발견되지 않았습니다. 최종 승인은 마켓 심사를 따릅니다" |
| 법률 단정 | "합법입니다", "표시광고법에 문제 없습니다" | 법적 판단은 전문가 확인을 안내한다 |
| 효능 단정 | 질병 예방·치료 효능, "면역력 강화 확정" 같은 건기식 문구 | 금지어 사전의 대체어(`replacement`)와 인정 제품의 표시사항 안내 |
| 가상 후기·평점 | 존재하지 않는 고객 후기, 별점, "전문가 추천" | 생성하지 않는다(CM-F-027) |
| 근거 없는 규정 단정 | 위키·규칙 근거 없이 마켓 규정을 단정 | "근거 자료를 찾지 못했습니다"와 마켓 공식 공지 확인 안내 |
| 기준일 | 낡은 규칙을 최신처럼 안내 | 규칙 답변에는 근거 페이지의 기준일을 붙이고, 6개월(제안)이 지난 페이지는 "오래된 정보일 수 있음"을 붙인다 |
| 키·계정 요구 | 채팅에서 API 키·비밀번호를 묻기 | 묻지 않는다. 키는 설정 화면의 vault 입력으로만 받는다 |
| 타사 상표 | 쿠팡·네이버 로고·상표를 제휴처럼 표시 | 사용하지 않는다 |

## 7. KPI

| 지표 | 목표 | 측정 | 기간 |
|---|---|---|---|
| 가입 → 첫 상세페이지 완료 | 40% | `detail_pages.status=ready` 첫 행 / 가입 | 가입 후 7일 |
| 생성 성공률 | 95% | ready / (ready + failed) | 주간 |
| 10슬롯 p95 생성 시간 | 240초 이하 | `finished_at - started_at` | 주간 |
| 업로드 성공률 | 95% | approved+submitted / 전체 업로드 | 주간 |
| compliance FAIL 후 수정 완료 | 70% | FAIL 페이지 중 이후 ready+pass | 월간 |
| 무료 → 유료 전환 | 5% | starter 이상 구독 / 활성 free 조직 | 월간 |
| 유료 이탈 | 월 8% 이하 | canceled / active | 월간 |
| 크레딧 원장 drift | 0 | `credit_ledger_reconciliation` | 일간 |

| AI 채팅 사용률 | 활성 조직의 25%(제안) | `core.ai_conversations` 1개 이상 사용자 / 활성 조직 | 3개월 |
| 답변 출처 표시율 | 95% 이상(제안) | `ai_messages.citations`가 빈 배열이 아닌 assistant 메시지 비율 | 월 |
| 금지어 재작성 성공률 | 80% 이상(제안) | 그래프 `banned_check`에서 걸린 슬롯 중 1회 재작성 뒤 통과한 비율(`ai_run_steps`) | 월 |
| 음성 입력 사용률 | starter 이상 조직의 15%(제안) | `voice_jobs`(feature `product_voice`) 1건 이상 조직 / starter 이상 조직 | 3개월 |
| 내레이션 생성 성공률 | 98% 이상(제안) | `voice_jobs`(feature `shorts_narration`) succeeded / 전체 | 월 |

목표치는 모두 제안(베타 데이터로 재설정).

## 8. 열린 결정

| ID | 항목 | 선택지 | 권고 |
|---|---|---|---|
| D-1 | 엔터프라이즈 크레딧 | (a) 550 유지(크레딧 단가가 pro보다 비쌈) (b) 1,100으로 상향 (c) MVP에서 엔터 미판매 | 결정됨(2026-10-14, Price_Plans 반영): (c) 초기 미판매(`is_active=false`) 후 중기에 900 크레딧으로 판매. (b) 1,100은 매출총이익률 약 64%라 쓰지 않는다(`docs/Price_Plans/nomad-commerce/PRICE_PLAN.md` 10장 CM-P-4). 상품·계정 무제한은 10,000·30으로(CM-P-5). V.2 리뷰도 엔터를 MVP 보류로 둠(`docs/reviews/Nomad-AI-Factory_V.2.md:124`) |
| D-2 | 이월 | (a) 없음 (b) SS 규칙(pro 50%, ent 100%) 지원을 코어에 요청 | (a). 코어 변경 필요 |
| D-3 | Free 체험량 | (a) 월 15(10슬롯 1건) (b) 가입 크레딧 30 추가 | 결정됨(2026-10-14, Price_Plans 반영): (b) 가입 크레딧 30. 첫 생성 KPI에 필요 |
| D-4 | 아마존 데이터 공급자 | Rainforest API, Keepa 등(미확인) | 단가·약관 비교 후 1곳 |
| D-5 | 네이버 커머스 API 형태 | 셀러 직접 발급 / 솔루션사 등록(미확인) | 출시 2주 전까지 확인. 막히면 엑셀/ZIP으로 출시 |
| D-6 | 코드 베이스 | (a) sellingstudio 확장(분석 D-5-1 권장) (b) 모노레포 `apps/nomad-commerce`로 이식 | (b): 공용 packages를 쓰기 위해 sellingstudio 코드를 모노레포로 옮김(06장) |
| D-7 | 모놀리스 스키마 | `public` | 사용자 확인 대기 |
| D-8 | 연간 플랜·Add-on | Phase 2 | 연간은 `billing_interval='year'` 별도 코드. 2026-10-14 가격 정책: 중기 단계 계획으로 확정(`docs/Price_Plans/nomad-commerce/PRICE_PLAN.md` 6.2절, CM-P-8) |
| D-9 | 마켓 규칙 위키 공개 범위와 원고 출처 | (a) 공개(SEO) + 운영자 검수 (b) 로그인 셀러만. 마켓 가이드 인용 범위와 약관상 재배포 허용 여부는 미확인 | (a)(제안). 원고는 요약·재구성하고 원문을 전재하지 않으며 항목마다 출처·기준일·검수자를 남긴다. 공개 위키는 `published`만 |
| D-10 | AI 채팅 무료 제공 | (a) 무료 없음(턴 선차감, Free 하루 20턴 상한) (b) Free 월 N턴 무료 | (a)(제안). (b)는 전환 효과를 본 뒤 결정 |
| D-11 | 상품 스펙 RAG 색인 대상과 상한 | 색인 필드(상품 행만 / 업로드 스펙 시트 포함), 조직별 월 색인 문서 상한, 보존 | 상품 행 + 스펙 시트(md, txt, csv, xlsx), 조직당 활성 문서는 플랜 상품 수 한도와 같게, 월 업로드 20건(제안). 공급자 자료 저작권은 셀러 책임 |
| D-12 | 쇼츠 내레이션 MVP 범위, 보이스, ElevenLabs 데이터 보관 | (a) MVP는 스크립트 + 음성 mp3까지, 영상 결합은 Phase 2 (b) MVP에 video 워커 연동 포함. 보이스: ElevenLabs 기본 1종 + 오픈소스 1종 vs 사용자 선택. ElevenLabs 입력 보관·학습 사용·제로 리텐션 | (a), 보이스 고정 2종. 보이스 id는 환경변수(02장 8절). 오픈소스 보이스는 `VOICE_ARCHITECTURE.md` 4.1절 후보 중 코드·가중치 라이선스와 한국어 품질을 확인해 고른다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:63-73`). 생성 음성 상업 이용 조건과 데이터 보관 조건은 ElevenLabs 계약으로 구현 시 확인(`:81-83`) |
| D-13 | 채팅 화면 레퍼런스 Astryx | 존재·라이선스 확인 후 패턴만 사용 / 확인 실패 시 Primer + shadcn/ui 패턴 | 확인 전까지 미확인(`docs/products/_design-guide/DESIGN_SYSTEM.md:11`). CM-06-041에서 확인 결과를 기록 |
| D-14 | 워커의 그래프 호출 방식과 인증 | (a) 워커가 1~3단계에서 FastAPI 그래프를 호출하고, 인증은 Next.js 잡 토큰 발급 엔드포인트(`/api/internal/ai-token`) (b) 그래프가 이미지 단계까지 소유(Python으로 이미지 엔진 재구현) (c) 워커에 서명 개인키 배포 | (a)(제안). 개인키는 Next.js에만 둔다는 코어 규칙(`docs/products/_platform-core/SECURITY_BASELINE.md:284`)을 지킨다. 코어 표준화 요청 06장 6.1절 R-3 |
| D-15 | 이미지 생성(fal)과 국외 이전 동의 | (a) fal은 라우팅 체인 밖의 처리 위탁으로 보고 이용약관·처리방침 고지로 처리(동의와 무관하게 사용) (b) 국외 이전 미동의 조직은 AI 씬 이미지 비활성(인포그래픽·법적고지 슬롯만 가능) (c) 국내 이미지 생성 오픈소스 서버 도입 | (a)(제안) + 법무 확인. 이미지 제공자는 `core.ai_providers`의 kind에 없어 `resolve_ai_route`가 걸러 내지 못한다 |
| D-16 | Vision(이미지 분석)의 오픈소스 경로 | 오픈소스 멀티모달 모델을 공용 서버에서 서빙하는지 | 서빙하지 않으면 국외 이전 미동의 조직은 Vision을 끄고 수동 속성 입력을 안내한다(구현 시 확인) |
| D-17 | AI 생성물 표시의 마켓 정책 | 쿠팡·스마트스토어가 AI 생성 이미지·문구의 표기를 요구하는지, 상세페이지 본문 삽입 여부 | 확인 전까지 결과 화면·다운로드 메타 표기만(미확인). 출시 2주 전까지 확인 |
