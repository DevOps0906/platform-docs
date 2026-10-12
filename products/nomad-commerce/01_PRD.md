# 01 PRD: NOMAD Commerce

표기: 원본·리뷰에 근거가 없는 수치와 정책은 "제안"으로 쓰고 이유를 단다. 외부 사실(API 존재, 약관)을 확인하지 않았으면 "미확인". 리뷰 경로 `docs/reviews/`, 분석 경로 `docs/products/00_MERGE_ANALYSIS.md`(이하 "분석").

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
| 입력 보조: 음성 STT, URL 벤치마킹 | MVP(P1, 플랜 게이팅) | 분석:788-789 |
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
| 7 마켓 API 승인 | 셀러 본인이 쿠팡 Wing Open API 키, 네이버 커머스API센터 애플리케이션을 발급(미확인: 솔루션사 등록 필요 여부) → 8장 결정 | 8장 |
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

## 4. 요금과 크레딧

### 4.1 플랜 (정본, 확정 결정 8)

가격은 V.2(`Nomad-AI-Factory_V.2/PRD.md:296-301`), 월 크레딧은 sellingstudio(`sellingstudio/PRD.md:155-158`)를 플랜별로 옮겼다.

| 코드 | 가격(월) | 월 크레딧 | 가입 크레딧 | 이월 | 주요 features |
|---|---|---|---|---|---|
| `free` | 0원 | 15 | 0 | 없음 | 상품 30, 계정 1, 유형 설득형, 10슬롯, 동시 1, ZIP |
| `starter` | 29,000원 | 150 | 0 | 없음 | 상품 300, 계정 3, 유형 3종, 10/15슬롯, 동시 1, 엑셀, URL·음성 입력 |
| `pro` | 69,000원 | 350 | 0 | 없음 | 상품 2,000, 계정 10, 동시 2, 고화질 모델 |
| `enterprise` | 149,000원 | 550 | 0 | 없음 | 상품·계정 무제한, 동시 5, 최고 화질, API 접근(Phase 2) |

연간 결제(월 x 10, `PRD.md:303`)와 Add-on(`PRD.md:304`)은 Phase 2. 이월(SS PRO 50%, ENT 100%, `sellingstudio/PRD.md:157-158`)은 core `plans.carry_over`가 boolean이라 MVP는 이월 없음(8장 결정). 모듈러 `seed.sql` 샘플(`_supabase-modular/seed.sql:37`, `:84-89`)과 다른 값(market_slots 8/20, starter의 market_api 없음 등)은 이 표가 정본이며 seed 갱신을 06장 6절로 요청한다. 모놀리스 `supabase/monolith/seed.sql`은 이 표와 같다.

### 4.2 크레딧 단가

| 작업 | 크레딧 | 근거 |
|---|---|---|
| 상세페이지 10슬롯 | 9 | SS 기본(6장) 5 + 추가 장당 1 x 4(`sellingstudio/PRD.md:55-56`) |
| 상세페이지 15슬롯 | 14 | 같은 공식 |
| 단일 슬롯 재생성 | 1 | SS 이미지 1장 추가 +1 |
| 단일 슬롯 고화질 재생성 | 3 | +1 + 고화질 +2(`:59`) |
| URL 벤치마킹 | 2 | `:57` |
| 음성 입력 STT | 1 | `:58` |
| 상품명·키워드 추천 3종 | 1 | `:61` |
| AI 자동완성(카테고리/고시/태그) 1회 | 1 | 제안: LLM 1회 비용이 키워드 추천과 같은 급 |
| 아마존 상품 가져오기 1건 | 1 | 제안: 서드파티 API 건당 과금(미확인 단가)을 흡수 |
| 편집 후 compliance LLM 재판정 | 1 | `_platform-core/SHARED_MODULES.md` 13장. 생성 시 1회 판정은 상세페이지 단가에 포함 |
| 엑셀 가져오기, 엑셀/ZIP 내보내기, 마켓 업로드 | 0 | 제안: 외부 AI 비용 없음. 플랜 한도(상품 수, 계정 슬롯)로 과금 |

### 4.3 원가와 마진(제안, 분석 G "슬롯당 원가")

| 항목 | 10슬롯 설득형 기준 | 근거 |
|---|---|---|
| AI 씬 3장(T-2, D-1, D-3) | flux-dev $0.075 / flux-pro $0.12 / ultra $0.18 | `sellingstudio/PRD.md:27-29` |
| 누끼 1장 | $0.001 | `:30` |
| 인포그래픽·법적고지 6장 | Puppeteer, 외부 비용 0 | `MARKET_IMAGE_SPEC.md:16` |
| LLM(스토리라인, 카피, 판정) | 약 $0.05(제안, 미확인) | 토큰 단가 미확인 |
| 합계 | 약 $0.13~0.23 = 180~330원(환율 1,400원 가정) | |
| 매출(9크레딧) | starter 1,740원 / pro 1,775원 / enterprise 2,435원 | 플랜가 / 월 크레딧 |

엔터프라이즈의 크레딧당 단가(271원)가 프로(197원)보다 비싸다. 8장 결정 1.

### 4.4 `core.plans.features` 키 해석 (서버만 읽음)

| 키 | 타입 | 의미 | 없을 때 | 집행 위치 |
|---|---|---|---|---|
| `products` | int | 삭제되지 않은 상품 수 상한, -1 무제한 | 0 | 트리거 `products_enforce_quota`(CM002) |
| `market_slots` | int | active 마켓 계정 수 상한 | 1 | 트리거 `market_accounts_enforce`(CM003) |
| `detail_types` | text[] | 허용 유형 | `["persuasive"]` | Route Handler 403 |
| `slot_sets` | int[] | 허용 슬롯 세트 | `[10]` | Route Handler 403 |
| `concurrency` | int | 동시 generating 상세페이지 수 | 1 | 디스패처 |
| `market_api` | text[] | API 업로드 허용 마켓 | `[]` | 트리거 `market_uploads_gate`(CM007) |
| `excel_export` / `zip_export` | bool | 내보내기 허용 | false / true | 트리거 `export_files_gate`(CM007) |
| `url_benchmark` / `voice_input` | bool | 입력 보조 | false | Route Handler 403 |
| `image_quality` | text | draft(flux-schnell) / standard(flux-dev) / pro(flux-pro) / ultra(flux-pro-ultra) | draft | 워커 모델 선택 |
| `api_access` | bool | 외부 API 키 발급(Phase 2) | false | Route Handler |

### 4.5 크레딧팩과 구독 정책

| 코드 | 크레딧 | 가격 | 근거 |
|---|---|---|---|
| `pack_50` | 50 | 10,000원 | `sellingstudio/PRD.md:160` |
| `pack_120` | 120 | 20,000원 | 같은 줄 |
| `pack_200` | 200 | 30,000원 | 같은 줄 |

| 정책 | 내용 |
|---|---|
| 구독 상태 | core `apply_subscription_transition`(trialing/active/past_due/canceled/expired) |
| 업그레이드 | 즉시 적용, 남은 기간 차액 일할 결제, 새 플랜 월 크레딧 즉시 지급(제안: 사용자가 바로 쓰기를 기대) |
| 다운그레이드 | 다음 결제일 적용. 한도 초과 상품·계정은 삭제하지 않고 신규 추가만 막힌다(트리거가 신규만 검사) |
| 결제 실패 | past_due → 1/3/7일 재시도 → canceled(`CORE_SPEC.md` 5.3 제안값) |
| 환불 | 구독 첫 결제 후 7일 이내 미사용(크레딧 사용 0)이면 전액(제안: 전자상거래법 청약철회 기간 7일과 맞춤). 크레딧팩은 미사용분만 |
| 알려진 코어 결함 | `confirm_payment_order` 금액 불일치 시 주문이 failed로 남지 않는다(`DB_CONVENTIONS.md` 13.2). 제품은 PM001을 받으면 Route Handler가 운영 알림 + Toss 취소를 호출하고 주문 상태에 의존하지 않는다 |

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
| 레이트 리밋 | 생성 API 조직당 60회/분, 로그인 IP당 10회/10분, 웹훅 600회/분 | `SECURITY_BASELINE.md` 8장 |
| 가용성 | 월 99.5%(웹), 워커 장애 시 잡은 대기 후 재개 | 제안 |
| 브라우저 | 최신 Chrome/Edge/Safari, 375px 이상 | 제안 |

## 6. 법, 개인정보, 금지 문구

| 항목 | 내용 |
|---|---|
| 개인정보 | 수집: 이메일, 이름, 결제 요약(카드 마스킹), 셀러 사업자 연락처·반품지 주소(템플릿), 마켓 계정 식별자. 목적: 서비스 제공·결제·마켓 등록. 보존: 탈퇴 후 30일 유예 뒤 purge(`SECURITY_BASELINE.md` 12장), 결제기록은 전자상거래법상 5년. 암호화: 마켓 API 키·시크릿(`encrypted_credentials`), 빌링키(`billing_keys`). 삭제: 조직 soft delete → 30일 → `purge_organization` |
| 제3자 제공 | 상품 정보·이미지·카피를 LLM(OpenRouter 경유 제공자), fal(이미지), 아마존 상품 데이터 공급자, 쿠팡·네이버(업로드)에 보낸다. 개인정보는 보내지 않는다(반품지 주소는 마켓 업로드 시에만 해당 마켓으로). 처리방침에 제공자 목록 고지 |
| 약관/고지 | 이용약관, 개인정보처리방침, "AI 생성물은 셀러가 검수 후 게시하며 게시 책임은 셀러에게 있다" 안내, 생성 이미지에 대한 권리(상업 이용 가능 여부는 fal 모델 약관 확인, 미확인) |
| AI 생성 표시 | 결과물 화면과 다운로드에 "AI로 생성된 이미지 포함" 메타 표기. 상세페이지 본문 삽입 여부는 마켓 정책 확인 후(미확인) |
| 제휴/광고 | commerce는 제휴 링크를 다루지 않는다(확정 결정 12). 대가성 문구 규칙 해당 없음 |
| 플랫폼 약관 | 쿠팡 Wing·네이버 커머스 API는 셀러 본인 키로 호출. 아마존은 직접 스크래핑 금지(약관), 서드파티 공급자 약관 확인. URL 벤치마킹은 공개 페이지 1회 조회만, 결과는 분석 요약만 저장(원문 저장 금지) |
| 법률 검토 필요 문안(출시 전) | (1) 청약철회·교환·반품 안내와 제한 사유 4코드, (2) 건강기능식품 표시(L-1 슬롯: 인정 제품의 표시사항 / 일반식품의 "질병 예방·치료 효능 표시 금지" 안내), (3) 해외구매대행 고지(수입식품 등 구매대행업 신고 요건), (4) 상품정보제공고시 자동완성 결과 책임 안내 |
| 자동 삽입 금지 | "단순 변심 반품 불가", "이 제품은 건강기능식품이 아닙니다"(실제 건기식이면 허위), AI 생성 후기·평점·"전문가 추천"(`docs/reviews/Nomad-AI-Factory_V.2.md:48-49`) |
| 금지 문구(제품 마케팅과 생성 콘텐츠 공통) | 가상 후기(존재하지 않는 고객 후기·평점), 허위 수치(원본 랜딩의 "2,847+ 셀러", "120만 상품", "재구독률 94%" 같은 미검증 숫자), 보장 표현("100% 통과", "반려 없음", "매출 보장"), 의료·건강 단정("치료", "면역력 강화 효과 확정"), 타사 상표 오용(쿠팡·네이버 로고를 제휴처럼 표시) |
| 규제 특례 | 건강기능식품법 표시·광고 규정, 식품표시광고법, 전자상거래법 청약철회. 금지어 사전은 법률 검토 뒤 확정 |

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

목표치는 모두 제안(베타 데이터로 재설정).

## 8. 열린 결정

| # | 항목 | 선택지 | 권고 |
|---|---|---|---|
| 1 | 엔터프라이즈 크레딧 | (a) 550 유지(크레딧 단가가 pro보다 비쌈) (b) 1,100으로 상향 (c) MVP에서 엔터 미판매 | (c) 후 (b). V.2 리뷰도 엔터를 MVP 보류로 둠(`docs/reviews/Nomad-AI-Factory_V.2.md:124`) |
| 2 | 이월 | (a) 없음 (b) SS 규칙(pro 50%, ent 100%) 지원을 코어에 요청 | (a). 코어 변경 필요 |
| 3 | Free 체험량 | (a) 월 15(10슬롯 1건) (b) 가입 크레딧 30 추가 | (b). 첫 생성 KPI에 필요 |
| 4 | 아마존 데이터 공급자 | Rainforest API, Keepa 등(미확인) | 단가·약관 비교 후 1곳 |
| 5 | 네이버 커머스 API 형태 | 셀러 직접 발급 / 솔루션사 등록(미확인) | 출시 2주 전까지 확인. 막히면 엑셀/ZIP으로 출시 |
| 6 | 코드 베이스 | (a) sellingstudio 확장(D-5-1 권장) (b) 모노레포 `apps/nomad-commerce`로 이식 | (b): 공용 packages를 쓰기 위해 sellingstudio 코드를 모노레포로 옮김(06장) |
| 7 | 모놀리스 스키마 | `public` | 사용자 확인 대기 |
| 8 | 연간 플랜·Add-on | Phase 2 | 연간은 `billing_interval='year'` 별도 코드 |
