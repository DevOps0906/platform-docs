# Nomad-AI-Factory_V.2 기획 리뷰

리뷰 일자: 2026-10-12 / 대상 경로: `D:\WorkSpace\platform\Nomad-AI-Factory_V.2` (코드 없음, 기획 문서 10개, 약 265KB) / 비교 참조: v1 코드 `D:\WorkSpace\platform\nomad-ai-factory`, v1 리뷰 `docs/reference/reviews/nomad-ai-factory.md`

## 1. 프로젝트 개요

- 기획 의도: 아마존과 국내 도매처(오너클랜, 도매꾹, 온채널)에서 상품을 소싱해 상품DB에 저장하고, AI로 상세페이지 이미지 10~15장, 쇼츠, 카드뉴스를 만든 뒤 8개 이커머스 채널(쿠팡, 스마트스토어, 지마켓, 옥션, 11번가, 롯데온, 카페24, 아임웹)과 5개 SNS 채널(유튜브, 인스타그램, 페이스북, 쓰레드, 틱톡)에 배포하는 멀티테넌트 구독형 SaaS다(`PRD.md:§1`). 건강기능식품 구매대행의 금지어와 법적 고지 자동화를 차별점으로 내세운다.
- 대상 사용자: 부업 셀러, 여러 마켓을 운영하는 중급 셀러, 건기식 전문 소싱러, SNS 커머스 셀러, 에이전시(`PRD.md:§2` JTBD 표 5개 세그먼트).
- 제안된 기술 스택

| 영역 | 제안 스택 | 비고 |
|------|-----------|------|
| 프론트 | Next.js 16.2.7 App Router, React 19, Tailwind v4, shadcn/ui, Zustand 5, TanStack Query v5, @xyflow/react, react-window | `CLAUDE.md:§1`. 랜딩 문서는 Framer Motion, react-hook-form을 추가로 지시 |
| 백엔드 | Next.js Route Handler(SSE 스트림), Puppeteer, Sharp | 별도 워커나 큐 없음 |
| DB/인증 | Supabase(Postgres, RLS, Auth, Storage, Realtime) | 스키마는 컬럼 나열 수준(`PRD.md:§8`) |
| AI | OpenRouter, GPT-4o, DALL-E 3, Flux Pro(fal), Remove.bg, DeepL, ElevenLabs | 이미지와 텍스트 공급자 6곳 이상 |
| 외부 연동 | 마켓 API 8종, SNS API 5종, n8n, Make, TossPayments, 한국수출입은행 환율, 네이버 데이터랩 | 대부분 심사나 승인이 필요한 API |
| 디자인 | Google Stitch로 화면 18개를 만든 뒤 Claude Code로 변환 | `STITCH_UI_DESIGN_PLAN.md:§2` |

- 기획 완성도: 약 60%.
  - 근거: UI/UX 쪽은 디자인 토큰, 컴포넌트 상태, 빈 상태, 오류 문구, 접근성, 키보드 맵까지 거의 구현 직전 수준으로 정의되어 있다(90% 이상). 상세페이지 유형 8종, 슬롯 체계, 마켓 이미지 규격, 등록 폼 필드도 구체적이다. 반면 백엔드 실행 모델(장시간 작업, 워커, 재시도), 시크릿 저장 방식, RLS 상세 정책, 결제 웹훅과 구독 상태 전이, 아마존 데이터 수집 방법, 마켓과 SNS API 승인 절차, 법적 검토는 비어 있거나 한 줄로만 적혀 있다(30% 이하).

## 2. 기획 문서 분석

| 문서 | 역할 | 크기 | 평가 |
|------|------|------|------|
| `PRD.md` | 제품 정의, JTBD, IA(메뉴 트리), 플랜 가격, DB 스키마 컬럼, 18단계 로드맵 | 19KB | 범위 정의의 기준 문서. 스키마와 로드맵은 개요 수준 |
| `CLAUDE.md` | 개발 규칙, 스택 버전, 폴더 구조, env 목록, Supabase/Route Handler/SSE/큐 스토어 예제 코드, MVP 체크리스트 | 27KB | 실제 구현 지침. 예제 코드에 결함이 있음(3장) |
| `DETAIL_PAGE_SYSTEM.md` | 상세페이지 유형 8종, 유형별 슬롯, 자동 추천 로직, 스토리라인 프롬프트, 8단계 파이프라인, GEO JSON-LD, 금지어 필터 | 20KB | 도메인 핵심 자산. 법적 리스크 요소가 섞여 있음 |
| `MARKET_IMAGE_SPEC.md` | 마켓별 썸네일/상세 이미지 규격, 슬롯(T/D/L) 정의, Sharp 변환과 Puppeteer 렌더러 코드, 규격 위반 감지 | 25KB | 구현 가치가 가장 높은 문서. 슬롯 수 정의가 다른 문서와 다름 |
| `MARKET_REGISTER_FORM.md` | 6-Step 등록 위자드, 마켓별 배송/반품/고시 필드, 완성도 계산, 배송 템플릿 JSON | 22KB | 필드 수준까지 구체적. 반품과 고시 문구에 법적 문제 |
| `DESIGN.md` | 디자인 토큰, 컴포넌트, 레이아웃, 화면별 UI, UX 카피, 접근성 | 27KB | `MASTER_SPEC`과 토큰이 완전히 같음(중복) |
| `NOMAD_AI_FACTORY_MASTER_SPEC.md` | DESIGN.md를 심화한 컴포넌트 스펙, 화면 핸드오프, UX 카피 전체, 접근성, 모션, QA 체크리스트 | 22KB | 제목과 달리 "마스터 스펙"이 아니라 디자인 심화 문서. 이름이 오해를 부름 |
| `DESIGN_FOR_STITCH.md` | Stitch 업로드용 디자인 시스템 요약 | 8KB | 문서 제목이 `# DESIGN.md`로 되어 있어 DESIGN.md와 혼동됨 |
| `STITCH_UI_DESIGN_PLAN.md` | Stitch 작업 순서, 화면 18개 프롬프트, 반응형, Claude Code 전달 프롬프트 | 56KB | 가장 큰 문서지만 대부분 다른 문서를 프롬프트 형태로 다시 적은 내용 |
| `LANDING_PAGE_STITCH_PROMPT.md` | 랜딩 11개 섹션 프롬프트와 Next.js 변환 지시 | 39KB | 가격, 수치, 후기가 PRD와 다르고 허위 표시 위험이 있음 |

요구사항 구조 요약: 요구사항은 "소싱 -> 상품DB(draft) -> 상세페이지 3-Mode 생성(개별/이미지/다중) -> 8단계 파이프라인 -> 마켓 6-Step 배포"라는 핵심 흐름 하나와, 이 흐름 바깥에 붙은 7개 확장 축(카드뉴스, 쇼츠, SNS 5채널, 판매관리, 자동화 3-Mode, 트렌드 TOP100, Vector DB/GEO)으로 이루어져 있다. 문서 10개 중 4개(DESIGN, MASTER_SPEC, DESIGN_FOR_STITCH, STITCH_UI_DESIGN_PLAN)는 디자인을 각각 다른 형식으로 다시 쓴 것이고, 같은 사실(슬롯 구성, 파이프라인 단계, 플랜 가격)이 3~4곳에 따로 적혀 있다. 그래서 문서 사이의 모순이 아래처럼 체계적으로 생긴다. `STITCH_UI_DESIGN_PLAN.md:1322`은 "총 파일 8개"라고 적고 있으나 실제로는 10개여서, 문서 세트 자체가 갱신되지 않았다.

## 3. 기획상의 문제점

| # | 심각도 | 분류 | 위치(파일명:섹션) | 내용 |
|---|--------|------|-------------------|------|
| 1 | 높음 | 기술리스크 | `CLAUDE.md:§8-9`, `PRD.md:§6.4`, `DETAIL_PAGE_SYSTEM.md:§5` | 상세페이지 1건이 80~240초 걸리는데 Route Handler의 SSE 스트림 안에서 Puppeteer, Sharp, DALL-E를 동기로 실행한다. 서버리스 실행 시간과 메모리 한도, Puppeteer 바이너리 문제로 배포 환경에서 동작하지 않는다. 큐는 브라우저의 Zustand 루프(`startQueue`)가 구동하므로 탭을 닫거나 새로고침하면 큐가 멈춘다. 그런데 `MASTER_SPEC:PART 3`은 "닫아도 백그라운드에서 계속 진행", "새로고침 시 SSE 재연결로 복원"이라고 약속한다. `detail_page_generation_jobs` 테이블은 정의만 있고 예제 코드에서는 쓰이지 않는다 |
| 2 | 높음 | 보안 | `CLAUDE.md:§5,§8`, `PRD.md:§7` | 플랜 한도(월 생성 수, 동시 처리 수)를 서버 Route Handler에서 집행하는 설계가 없다. `PLAN_GENERATION_LIMITS`와 `maxConcurrent`는 클라이언트 스토어 상수이고, §5 템플릿은 `plan`을 읽기만 하며 사용량 차감이나 원자성은 다루지 않는다. v1 리뷰의 #2(클라이언트 측 한도 판단)와 sellingstudio의 비원자 크레딧 차감 문제가 그대로 재발할 구조다 |
| 3 | 높음 | 모순 | `CLAUDE.md:§3` vs `PRD.md:§8` | 멀티테넌트라서 사용자마다 마켓 계정을 쓰는데(`market_accounts.api_key_enc`, `slot_no`), env에는 `COUPANG_ACCESS_KEY`, `NAVER_COMMERCE_CLIENT_ID`, `N8N_INSTANCE_URL`, `MAKE_API_KEY`가 단일 값으로 들어 있다. 어느 키로 누구의 상품을 올리는지 정의되지 않았고, `_enc` 컬럼의 암호화 방식(Vault, pgsodium, 앱 레벨 AES)과 키 관리도 정해지지 않았다 |
| 4 | 높음 | 보안 | `PRD.md:§8` RLS 주석 | "전 테이블 공통 `USING (user_id = auth.uid())`"는 성립하지 않는다. `users`는 `id`가 키이고, `categories`, `banned_words`, `exchange_rates`는 전역 테이블이며, `market_uploads`에는 `user_id`가 없다. `WITH CHECK`가 없고, `users.role`과 `users.plan`을 사용자가 직접 UPDATE하지 못하게 막는 정책이 없어 스스로 `SUPER_ADMIN`이나 `enterprise`로 올릴 수 있다. 슈퍼어드민의 전체 조회 방식(service_role인지 정책인지)도 정의되지 않았다 |
| 5 | 높음 | 보안 | `DETAIL_PAGE_SYSTEM.md:§1 유형2`(49-50행), `LANDING_PAGE_STITCH_PROMPT.md:섹션03,08` | 리뷰형 상세페이지가 "★4.8 / 2,847개" 평점 배너, "사용자 프로필+리뷰+실사진", "전문가 추천"을 AI로 생성하도록 설계되어 있다. 출시 전 랜딩에도 "2,847+ 셀러", "120만 상품", 실명처럼 보이는 후기 6개, "재구독률 94%"가 들어 있다. 표시광고법과 전자상거래법상 거짓·기만 광고에 해당할 수 있고, 마켓 정책 위반으로 리스팅이 삭제될 수 있다 |
| 6 | 높음 | 보안 | `MARKET_REGISTER_FORM.md:§6, §7`(241-244, 274, 282행) | (a) "단순 변심 반품 불가"를 기본 템플릿으로 자동 삽입한다. 해외구매대행도 전자상거래법상 청약철회(7일) 대상이므로 위법 소지가 있다. (b) 건기식 상품에 "이 제품은 건강기능식품이 아닙니다"를 자동 삽입한다. 실제 건기식이면 사실과 다른 표시가 되고, 건기식 구매대행에 필요한 수입식품 등 구매대행업 신고 요건은 다루지 않았다. 법률 검토를 받기 전에는 자동 삽입 기능을 만들면 안 된다 |
| 7 | 높음 | 모순 | `PRD.md:§6.3`(227-228행) vs `MARKET_IMAGE_SPEC.md:§4-5, §11` vs `CLAUDE.md:§2` | 10장 기본 구성이 PRD는 `T-1,T-2,D-1,D-2,D-3,D-5,D-7,L-1,L-2,L-3`, IMAGE_SPEC은 `T-1,T-2,D-1,D-2,D-3,D-5,D-7,D-8,D-9,L-3`로 다르다. 15장 구성도 PRD 기준으로 세면 16장이고, IMAGE_SPEC "15슬롯 전체 정의"는 실제로 T5+D10+L3=18슬롯이다. `MANDATORY_SLOTS=['T-1','D-1','L-3']`(546행)인데 educational 기본 슬롯에는 D-1이 없어서, 기본값만으로는 생성 버튼이 비활성화된다 |
| 8 | 중간 | 모순 | `PRD.md:§6.4` vs `DETAIL_PAGE_SYSTEM.md:§5` vs `CLAUDE.md:§9` | 8단계 파이프라인이 세 문서에서 서로 다르다. PHASE 3이 PRD에서는 "프롬프트 정제", DETAIL에서는 "상품명 최적화"이고, CLAUDE의 진행률(88%)은 "금지어 검사"인데 DETAIL에서는 "품질 검증"이다. 한글 합성 위치도 PRD는 PHASE 5, DETAIL은 PHASE 5B-2다. 진행률과 단계명을 SSE와 UI 문구에 그대로 쓰기 때문에 정본 하나를 정해야 한다 |
| 9 | 중간 | 모순 | `PRD.md:§7`(301행), `STITCH_UI_DESIGN_PLAN.md:916` vs `LANDING_PAGE_STITCH_PROMPT.md:580` | 엔터 플랜이 PRD와 Stitch 계획에서는 149,000원/월인데 랜딩에서는 "별도 문의"다. 랜딩에만 "7일 환불 보장", "전담 CS 매니저", "커스텀 API"가 있고, 플랜 키도 `엔터`/`enterprise`/`Enterprise`로 섞여 쓰인다 |
| 10 | 중간 | 모순 | `PRD.md:§9` vs `CLAUDE.md:§17` | 우선순위가 반대다. PRD 로드맵은 카드뉴스, 쇼츠, SNS(Phase 4)를 마켓 배포 폼(Phase 5)보다 앞에 두었고, CLAUDE MVP는 쿠팡과 스마트스토어 배포를 Phase 1, 쇼츠와 SNS를 Phase 2에 두었다. 핵심 가치 흐름으로 보면 CLAUDE 쪽이 맞다 |
| 11 | 중간 | 기술리스크 | `CLAUDE.md:§1`(34행), `§0`(15행), `§16`(728행) | `@xyflow/react v11`이라는 버전은 없다(@xyflow/react는 v12부터, v11은 `reactflow` 패키지). "`<form>` 태그 금지"라고 해 놓고 shadcn `form`을 설치하며, 랜딩은 react-hook-form을 지시한다. "localStorage 금지(아티팩트 내부)"는 Claude 아티팩트용 규칙이 섞여 들어온 것으로 보인다. `lib/supabase/middleware.ts`는 Next 16의 `proxy.ts` 관례와 맞지 않는다 |
| 12 | 중간 | 기술리스크 | `CLAUDE.md:§8`(401행) | SSE 수신 코드가 청크 경계를 버퍼링하지 않고 `split('\n\n')` 뒤 바로 `JSON.parse`를 호출해, 이벤트가 두 청크로 나뉘면 예외가 난다. 진행률 -1(오류) 이벤트도 처리하지 않는다. 문서의 예제 코드가 그대로 복사될 가능성이 높으므로 수정이 필요하다 |
| 13 | 중간 | 누락 | `PRD.md:§6.1`, `MASTER_SPEC:PART 4`(309행) | 아마존 데이터를 어떻게 수집하는지 정의되지 않았다. PA-API는 판매 실적 요건이 있고, 직접 스크래핑은 약관 위반이며 차단된다("아마존 일시 차단" 오류 문구가 스크래핑을 전제한다). 쿠팡과 네이버 카테고리 TOP100도 공식 API가 없다. 서버가 사용자 URL을 fetch할 때의 SSRF 방어도 빠져 있다(nomad-ai-commerce, sellingstudio 리뷰에서 실제로 발생) |
| 14 | 중간 | 범위과다 | `PRD.md:§4, §6.6-6.7`, 판매관리 | 마켓 8개(카테고리 코드 체계와 인증 방식이 모두 다름), SNS 5개(Meta 앱 심사, TikTok 감사 필요), n8n, Make, React Flow, 주문·정산·CS 통합, Vector DB까지 1인 개발 기준 1년 이상 걸리는 범위다. 판매관리(주문 수집)는 마켓 8개의 주문 API를 따로 연동해야 하는데 요구사항은 메뉴 4줄뿐이다 |
| 15 | 중간 | 누락 | `PRD.md:§3, §7` | TossPayments 정기결제의 빌링키 발급, 웹훅 서명 검증, 결제 실패와 유예 기간, 업그레이드·다운그레이드 일할 계산, Add-on 과금, 월 사용량 초기화 시점이 정의되지 않았다. NOMAD Shorts Maker에서는 결제 경로 두 개가 서로 연결되지 않는 결함이 실제로 생겼다 |
| 16 | 낮음 | 모호성 | `DETAIL_PAGE_SYSTEM.md:§7`(483행), `§8` | JSON-LD의 `brand`가 상품 브랜드가 아니라 "NOMAD AI Factory"로 하드코딩되어 있다. 쿠팡과 스마트스토어 상세 HTML은 `<script>`를 제거하므로 GEO는 카페24와 아임웹에서만 의미가 있다. 금지어는 코드 상수인데 PRD에는 `banned_words` 테이블이 있어 출처가 둘이다. `REPLACEMENTS['효과']`는 금지어 목록에 없는 단어라 동작하지 않는다 |
| 17 | 낮음 | 모순 | `DESIGN.md:§6`(310행) vs `PRD.md:§4` | 대시보드 트렌드가 DESIGN에서는 "쿠팡 TOP10", PRD에서는 "TOP100"이다. DESIGN.md와 MASTER_SPEC은 색상 토큰 값이 100% 같은 중복 정의라서 한쪽만 고치면 어긋난다 |
| 18 | 낮음 | 기술리스크 | `CLAUDE.md:§3`, `PRD.md:§6.3` | DALL-E 3는 구세대 이미지 모델이라 gpt-image 계열이나 fal Flux로 바꾸는 것을 검토해야 한다. 텍스트 LLM은 OpenRouter, 이미지는 OpenAI 직접 호출, Flux는 fal로 공급자 계정이 늘어나 비용 추적이 어렵다. 슬롯당 원가와 플랜 가격의 마진 계산이 없다 |

### 심각도 높음 상세

**#1 장시간 생성 작업의 실행 모델 부재.** 문서는 생성 1건에 최대 4분이 걸린다고 스스로 추정하면서도 이 작업을 HTTP 요청 하나 안의 SSE로 처리하고, 큐는 브라우저가 돌린다. 이 구조로는 "백그라운드 계속", "새로고침 복원", "플랜별 동시 처리 수"를 하나도 보장할 수 없다. 작업은 `detail_page_generation_jobs` 테이블에 넣고 별도 워커 프로세스(Puppeteer와 Sharp가 동작하는 컨테이너)가 가져가 처리하며, 진행률은 테이블 갱신과 Supabase Realtime으로 전달해야 한다. 그러면 SSE와 Zustand 큐 루프는 필요 없어진다.

**#2, #3, #4 과금·시크릿·격리 경계.** v1에서 지적된 3대 보안 결함(공개 AI 프록시, 클라이언트 한도 판단, 키의 평문 저장)을 v2 문서는 "인증 체크 필수", "localStorage 금지", "`_enc` 컬럼" 같은 규칙으로만 막고, 실제 집행 지점은 설계하지 않았다. 결과적으로 사용량 원자 차감(RPC), 시크릿 암호화 키 관리, RLS 정책 세부(WITH CHECK, 역할 컬럼 보호, 전역 테이블 읽기 전용)가 모두 구현자의 판단에 맡겨져 있다. 형제 프로젝트 세 곳(sellingstudio, nomad-ai-commerce, NOMAD Shorts Maker)이 바로 이 지점에서 높음 등급 결함을 냈다.

**#5, #6 법적 리스크.** 가짜 후기·평점 생성, 반품 불가 일괄 고지, 건기식 부정 문구 자동 삽입은 사용자(셀러)에게 법적 책임을 넘기는 기능이다. 이 제품은 "금지어 위반으로 상품이 내려가는 불안"(`PRD.md:§2`)을 해결하겠다고 하면서, 정작 더 큰 위반을 자동화하고 있다. 리뷰형 슬롯은 셀러가 실제 리뷰 데이터를 입력한 경우에만 렌더링하고, 반품과 고지 문구는 법률 검토를 받은 문안으로 바꿔야 한다.

**#7 슬롯 정의 불일치.** 슬롯 코드는 UI(SlotGrid), 프롬프트(`selected_slots`), 이미지 엔진 선택, 마켓 변환에 모두 쓰이는 핵심 키인데, 정의가 세 가지로 갈려 있다. 구현 전에 `MARKET_IMAGE_SPEC.md`의 18슬롯과 유형별 기본값을 정본으로 정하고, PRD의 10장/15장 문구와 `MANDATORY_SLOTS`를 거기에 맞춰야 한다.

### v2 기획은 v1의 문제를 해결하는가

| v1 리뷰 문제 | v2 기획 대응 | 판정 |
|--------------|--------------|------|
| #1 인증 없는 공개 AI 프록시 | Route Handler 첫 줄에서 `getUser()` 필수(`CLAUDE.md:§5`), Express 제거 | 해결(설계 수준) |
| #2 클라이언트 측 한도와 사용량 기록 | 서버 집행 설계 없음. 한도가 클라이언트 스토어 상수로 남아 있음 | 미해결(3장 #2) |
| #3 외부 API 키 localStorage 저장 | localStorage 금지, `api_key_enc`, `access_token_enc` 컬럼 | 부분 해결. 암호화 방식과 키 관리 미정(3장 #3) |
| #4 스키마와 RLS가 저장소에 없음 | 테이블 18개 컬럼 정의, RLS 원칙 | 부분 해결. DDL, 마이그레이션, 정책 세부 없음(3장 #4) |
| #5 의존성 `latest` | Next 16.2.7 고정. 나머지는 `latest`, `5.x` | 부분 해결 |
| #6 AI Studio 템플릿 잔재 | 새 프로젝트로 시작하므로 해당 없음 | 해결 |
| #9 reactflow 버전 불일치 | `@xyflow/react v11`로 적어 또다시 버전 표기 오류 | 미해결(3장 #11) |
| #10 대시보드 목 데이터, 자동화 setTimeout | KPI 출처 테이블과 자동화 실행 엔진(`/api/automation/execute`) 설계가 비어 있음 | 미해결 |
| #16 환율을 LLM 추정값으로 사용 | 한국수출입은행 API, `exchange_rates` 캐시, `price-calculator.ts` | 해결 |
| 문서와 코드 불일치(PRD 2벌) | 이번에는 문서 10벌 사이에 모순(3장 #7~10) | 형태만 바뀌어 재발 |

### v1 코드 재사용과 폐기

v1은 Vite SPA + HashRouter + Express + `reactflow` v11이므로 v2(Next 16 App Router + Supabase SSR)에 그대로 올릴 수 없다. 저장소는 아카이브하고 아래 자산만 옮긴다.

| 구분 | v1 경로 | 처리 |
|------|---------|------|
| 이식 | `frontend/lib/ai/index.ts`(179줄) 리스팅 JSON 프롬프트, 톤·채널 가이드, 코드펜스 제거 파싱 | `src/lib/api/openrouter.ts`와 상품명 최적화 프롬프트(`/api/ai/optimize-title`)로 옮긴다. 파싱은 zod 스키마 검증으로 강화한다 |
| 이식 | `backend/server.js`(219줄) OpenRouter 모델 화이트리스트, `json_object` 모드, `max_tokens` 제한 | 서버 전용 `openrouter.ts` 래퍼의 기본값으로 쓴다. CORS `*`, IP 레이트리밋, `/api-proxy`는 버린다 |
| 이식(재작성) | `frontend/components/workflow/Canvas.tsx`(361줄) 위상 정렬 실행 순서, `nodes/` 6종 분류, `panels/NodeSettingsPanel.tsx` UX | Mode A(Phase 2)를 만들 때 @xyflow/react v12 API로 다시 작성한다. 노드 data의 평문 `apiKey`는 제거한다 |
| 참고 | `frontend/lib/stores/authStore.ts`(98줄) Supabase OAuth 이벤트 순서 주석 | Next SSR 콜백 라우트를 작성할 때 참고만 한다 |
| 이식 | `frontend/app/dashboard/sourcing/page.tsx`의 플랫폼·채널·톤 옵션 상수 | `src/constants/`로 분리한다 |
| 폐기 | `frontend/lib/supabase/usage.ts`(클라이언트 한도 체크), `components/settings/SettingsModal.tsx`(localStorage 키 저장), `vertex-ai-proxy-interceptor.js`, `pages/`, `contexts/`, `lib/actions`, `lib/media`, `lib/commerce`, Tailwind CDN 설정, `frontend/supabase/schema.sql`(구 스키마) | v2의 보안 경계와 스택에 맞지 않고, 일부는 이미 미사용 코드다 |

## 4. 효율적 구현 전략

### 권장 아키텍처

- 웹: Next.js 16(App Router, `proxy.ts`로 세션 갱신과 라우트 보호) + Supabase SSR. 모든 쓰기는 Route Handler나 Server Action에서 하고, 브라우저는 읽기와 Realtime 구독만 한다.
- 작업 실행: `jobs` 테이블(또는 pgmq) + 별도 Node 워커 컨테이너(Railway나 Fly 등). 워커가 Puppeteer, Sharp, 이미지 API를 실행하고 슬롯 단위로 진행률을 테이블에 기록하면 Realtime이 UI에 푸시한다. 동시 처리 수는 워커가 플랜 기준으로 `SELECT ... FOR UPDATE SKIP LOCKED`로 집행한다. Vercel에는 Puppeteer를 올리지 않는다.
- 과금: `consume_quota(user_id, kind, n)` RPC 하나로 한도 확인과 차감을 원자적으로 처리한다(security definer, anon과 authenticated에는 execute를 revoke). 작업이 실패하면 환불 RPC를 호출한다. Toss 웹훅은 서명을 검증하고 멱등 키를 쓴다.
- 시크릿: 마켓과 SNS 자격증명은 Supabase Vault 또는 앱 레벨 AES-256-GCM으로 암호화한다. 키가 없으면 폴백하지 않고 기동을 실패시킨다. 복호화는 워커와 서버에서만 한다.
- 정본 문서: 슬롯(`MARKET_IMAGE_SPEC`), 파이프라인 단계(새 `PIPELINE.md` 또는 DETAIL §5), 플랜(`PRD §7` + `plans.ts` 단일 상수)으로 사실 하나당 출처 하나만 둔다. DESIGN.md와 MASTER_SPEC은 토큰 정의를 한 곳에만 둔다.

### 재사용할 수 있는 기존 프로젝트와 모듈

| 출처 | 재사용 대상 | 주의점(기존 리뷰 근거) |
|------|-------------|------------------------|
| `basic-master-module` | Next 16.2.4 + React 19.2 + Tailwind v4 create-next-app 골격(app/, eslint, postcss) | 내용이 거의 없는 순수 템플릿이다. 시작점으로만 쓰고 Supabase, shadcn, proxy.ts는 추가해야 한다 |
| `sellingstudio` | `proxy.ts` 패턴, `lib/supabase/{client,server,admin}.ts`, `lib/llm/openrouter.ts`, `lib/image/fal.ts`, zod 입력 검증, 마이그레이션의 가입 트리거와 Realtime 설정, fal webhook과 Realtime 진행 뷰어 구조 | 크레딧 비원자 차감, webhook 무서명, `USING(true)` 정책, 외부 호출 타임아웃 없음은 그대로 가져오지 않는다 |
| `nomad-ai-commerce` | 같은 도메인(아마존 + 위탁 엑셀 + market_accounts + 금지어)의 화면 흐름 참고 | 코드 재사용 가치는 낮다. SSRF, 평문 키 노출, `\b` 한글 금지어 정규식 버그, 인메모리 잡이 있다 |
| `NOMAD Shorts Maker` | Phase 2의 SNS 업로더(`src/lib/platforms/{youtube,instagram,threads,tiktok}.ts`), `channels/oauth-manager.ts`, `lib/crypto.ts`(AES-GCM), BullMQ 큐 구조, Toss 결제 흐름 | `crypto.ts`의 0키 폴백 제거, 결제 경로 이중화와 `add_credits` 권한 결함, tsc 오류 21개를 먼저 고친 뒤 가져온다 |
| v1 `nomad-ai-factory` | 위 3장 표의 프롬프트, OpenRouter 패턴, 캔버스 설계 | 그 외 코드는 폐기 |

### MVP 범위 축소안

- 포함(MVP): 이메일과 소셜 로그인, 프리·스타터·프로 3개 플랜과 Toss 정기결제, 아마존 ASIN/URL 소싱(서드파티 상품 데이터 API를 쓰고 직접 스크래핑은 하지 않음), 엑셀 2종(오너클랜, 자유 양식 + 컬럼 매핑), 상품 목록, 상세페이지 유형 3종(설득형, 정보형, 감성형), 10슬롯, 개별 생성과 다중 생성(이미지로 생성 모드는 보류), 금지어 필터, 쿠팡과 스마트스토어 2채널 배포(6-Step 위자드를 두 마켓 필드로 축소), 환율 위젯(USD 1개 + 계산기).
- 보류(Phase 2 이후): 나머지 마켓 6개, 카드뉴스, 쇼츠, SNS 5채널, 자동화 3-Mode, 판매관리, TOP100 트렌드, Vector DB, 에이전시 다계정과 TEAM_MEMBER, 엔터 플랜.
- 제거 또는 재설계: 리뷰형의 AI 생성 후기와 평점, 반품 불가 자동 삽입, "건강기능식품이 아닙니다" 자동 삽입, 랜딩의 허위 수치와 후기.

### 단계별 로드맵

1. 0단계(1주): 문서 정본화(3장 #7~11 결정), 법적 문구 검토 의뢰, 아마존 데이터 공급자 선정, 쿠팡 Wing와 네이버 커머스 API 계정 승인 신청(승인 대기 기간을 고려해 가장 먼저 시작).
2. 1단계(2~3주): 골격, 스키마와 RLS, 인증, `consume_quota` RPC, 시크릿 저장, 잡 테이블과 워커 기동, 디자인 토큰과 레이아웃.
3. 2단계(3~4주): 소싱과 엑셀, 상품 목록, 상세페이지 파이프라인(스토리라인 -> Puppeteer 템플릿 -> 이미지 생성 -> Sharp 합성 -> 마켓 변환), 생성 모달과 큐 패널.
4. 3단계(2~3주): 쿠팡과 스마트스토어 배포 위자드, Toss 결제와 웹훅, 랜딩, 베타 출시.
5. 4단계 이후: 마켓 확장(지마켓·옥션은 ESM 하나로 묶음), 쇼츠와 SNS(Shorts Maker 모듈 이식), 자동화 Mode A, 판매관리.

## 5. 구현 작업 목록 및 권장 모델

| # | 작업 | 우선순위 | 규모 | 권장 모델 | 이유 |
|---|------|----------|------|-----------|------|
| 1 | 문서 충돌 결정표 작성과 반영: 슬롯 18개와 10/15장 기본값, `MANDATORY_SLOTS`, 파이프라인 8단계 명칭과 진행률, 플랜 4종 가격과 키, 스택 버전(@xyflow/react v12, proxy.ts, form 규칙)을 확정하고 PRD, CLAUDE, DETAIL, IMAGE_SPEC, LANDING을 일괄 수정. DESIGN.md와 MASTER_SPEC의 토큰 중복 제거 | P0 | M | Opus 5.5 | 문서 5~6개를 서로 맞춰야 하는 일관성 작업이다. 단순 문서화보다 판단이 많이 필요하다 |
| 2 | 멀티테넌트 데이터 모델과 RLS 마이그레이션 설계: `profiles`(role, plan은 사용자 UPDATE 불가), 테이블 18개 DDL, 테이블별 SELECT/INSERT/UPDATE 정책과 WITH CHECK, 전역 테이블 읽기 전용, `market_uploads.user_id` 추가, 슈퍼어드민 접근 방식, pgTAP 또는 SQL 정책 테스트 | P0 | L | Fable 5.1 | 데이터 격리와 권한 설계이며, 실수하면 테넌트 간 데이터가 유출된다 |
| 3 | 프로젝트 골격: `basic-master-module`을 복제해 Supabase SSR 클라이언트 3종, `proxy.ts`, shadcn 초기화, `(auth)`/`(dashboard)`/`(landing)` 라우트 그룹, Tailwind v4 `@theme` 디자인 토큰, Sidebar/TopBar 레이아웃, 의존성 버전 고정, `.env.example` 작성 | P0 | M | Sonnet 5.5 | 정해진 패턴을 따르는 보일러플레이트이고 sellingstudio에 참고 코드가 있다 |
| 4 | 사용량과 한도 서버 집행: `usage_ledger` 테이블, `consume_quota`와 `refund_quota` RPC(security definer, execute 권한 revoke), 생성·배포 Route Handler와 워커에서 원자 차감, 월 초기화, 동시성 테스트 | P0 | M | Fable 5.1 | 과금 로직이다. v1, sellingstudio, Shorts Maker에서 같은 지점이 반복해서 깨졌다 |
| 5 | 외부 자격증명 암호화 저장: 마켓 API 키와 SNS OAuth 토큰을 Vault 또는 AES-256-GCM(키가 없으면 기동 실패)으로 저장, 서버와 워커 전용 복호화 헬퍼, 토큰 갱신, 단일 env 마켓 키 제거 | P0 | M | Fable 5.1 | 보안에 민감한 시크릿 설계다 |
| 6 | 생성 작업 실행 기반: `detail_page_generation_jobs` 큐, 워커 컨테이너(Puppeteer와 Sharp, 한글 폰트 포함 Docker), `SKIP LOCKED` 기반 플랜별 동시성, 슬롯 단위 진행률과 재시도, Realtime 구독 UI. Zustand 큐 루프와 SSE 제거 | P0 | L | Fable 5.1 | 인프라와 아키텍처를 새로 설계해야 하고 여러 모듈에 걸친다 |
| 7 | 소싱: 아마존 상품 데이터 공급자 API 연동(ASIN/URL 정규화, SSRF 방지 허용 도메인 목록), SheetJS 엑셀 파서(오너클랜, 자유 양식 컬럼 매핑 UI), `products` 저장, 오류 문구 연결 | P1 | M | Opus 5.5 | API 연동과 파서 구현으로 범위가 분명한 중간 규모 기능이다 |
| 8 | 상세페이지 파이프라인 MVP: 스토리라인 프롬프트(OpenRouter + zod 출력 검증), 유형 3종 지시문, Puppeteer 슬롯 템플릿(D-2, D-5, D-7, L-1, L-3), 이미지 생성(fal Flux 또는 gpt-image), Sharp 한글 합성, `detail_pages` 조립 | P1 | L | Opus 5.5 | 스펙이 상세하게 주어진 기능 구현이다. 실행 기반(#6)을 만든 뒤 진행한다 |
| 9 | 마켓 이미지 변환과 검증: `THUMBNAIL_SPECS`/`DETAIL_IMAGE_SPECS` 상수화, `convertThumbnailForMarket`, 상세 이미지 자동 분할, 용량 압축, `validateThumbnail`, 단위 테스트 | P1 | S | Opus 5.5 | 규격 기반 변환이지만 마켓 반려와 직결되므로 테스트 설계까지 포함한다 |
| 10 | 금지어 필터 재작성: `banned_words` 테이블을 단일 출처로, 한글 경계를 고려한 매칭, 치환 문법 보정, 하이라이트 XSS 방지, 생성 텍스트와 Puppeteer 합성 텍스트 모두 검사, 테스트 | P1 | S | Opus 5.5 | 규칙 로직과 테스트. nomad-ai-commerce에서 같은 기능의 정규식 버그 전례가 있다 |
| 11 | 쿠팡 Wing와 스마트스토어 커머스 API 배포: HMAC 서명, 카테고리 매핑, 고시 정보, 반품비 상한 계산, 6-Step 위자드를 두 마켓 필드로 축소, `market_uploads` 이력과 실패 로그, 워커로 일괄 전송 | P1 | L | Opus 5.5 | 외부 API 연동 중심의 구현이다. 자격증명 처리는 #5 모듈을 쓴다 |
| 12 | TossPayments 정기결제: 빌링키 발급, 웹훅 서명 검증과 멱등 처리, 구독 상태 전이(active, past_due, canceled), 업그레이드와 다운그레이드, `profiles.plan` 서버 측 갱신 | P1 | M | Fable 5.1 | 결제 로직이며, Shorts Maker에서 결제 경로 분리 결함 전례가 있다 |
| 13 | 핵심 화면 구현: 상품 목록 DataTable(react-window, 일괄 작업 바), 상세페이지 생성 3-Mode 모달, 큐 패널, 빈 상태·오류·확인 문구, 접근성 속성. Stitch HTML을 컴포넌트로 변환 | P1 | L | Sonnet 5.5 | 반복적인 UI 작업이다. 스펙(MASTER_SPEC PART 2~5)이 매우 상세하다 |
| 14 | 컴플라이언스 문구 정비: 랜딩의 허위 수치와 후기를 "베타" 문구로 교체, 리뷰형 슬롯은 실제 리뷰 입력 시에만 활성화, 반품과 건기식 고지 문안을 법률 검토 문안으로 교체, JSON-LD `brand`를 상품 브랜드로 수정 | P0 | S | Sonnet 5.5 | 문구 수정 작업이다. 문안 자체는 외부 법률 검토가 필요하다 |
| 15 | Phase 2 확장 준비: NOMAD Shorts Maker의 SNS 업로더와 OAuth 매니저를 결함 수정 후 이식, 자동화 Mode A(v1 Canvas 설계를 @xyflow v12로 재작성, 미연결 노드 실행 차단, 서버 실행 엔진) | P2 | L | Opus 5.5 | 기존 모듈을 이식하고 연동하는 작업이며 범위가 정해져 있다 |

## 6. 종합 평가

- 실현 가능성: 문서에 적힌 전체 범위(마켓 8개, SNS 5개, 자동화 3-Mode, 판매관리)는 1인 또는 소규모 팀 기준으로 실현 가능성이 낮다. 4장의 MVP(아마존과 엑셀 -> 상세페이지 3유형 -> 쿠팡과 스마트스토어)로 줄이면 8~11주 안에 베타 출시가 가능하다. 성공 여부는 장시간 작업 워커, 서버 측 과금 집행, 마켓 API 승인 세 가지에 달려 있다.
- 강점: UI/UX, 접근성, 카피가 구현 직전 수준으로 정의되어 있다. 마켓별 이미지 규격과 등록 필드처럼 도메인 지식이 깊다. "AI 씬 + Puppeteer 인포그래픽 + Sharp 한글 합성"으로 렌더링 방식을 나눈 것은 기술적으로 옳은 판단이다.
- 약점: 같은 사실을 여러 문서에 따로 적어서 모순이 체계적으로 생긴다. 백엔드 실행 모델과 보안 집행 지점이 비어 있어 v1의 핵심 결함이 재발할 수 있다. 가짜 후기, 반품 불가, 건기식 부정 고지 같은 법적 리스크 기능이 핵심 흐름에 들어 있다.
- 모델별 비율(작업 15개 기준): Fable 5.1 33%(5건: #2, #4, #5, #6, #12) / Opus 5.5 47%(7건: #1, #7, #8, #9, #10, #11, #15) / Sonnet 5.5 20%(3건: #3, #13, #14)
- 권장 진행 순서: 1단계는 #1, #14(문서와 법적 리스크 정리) -> #2, #3, #4, #5, #6(보안과 실행 기반). 2단계는 #7, #8, #9, #10, #13(소싱부터 상세페이지 생성까지). 3단계는 #11, #12(배포와 결제), 그 뒤 #15.
- 주 담당 모델: **Fable 5.1**. 이 프로젝트는 코드 없이 기획만 있고, 기획에서 가장 약한 부분이 장시간 작업 실행 모델, 멀티테넌트 RLS, 원자적 사용량 차감, 시크릿 암호화, 정기결제처럼 실수 비용이 큰 아키텍처 결정이다. 형제 프로젝트 세 곳이 모두 이 지점에서 높음 등급 결함을 냈으므로, Fable 5.1이 0~1단계의 설계와 골격(스키마, RPC, 워커, 결제)을 맡아 경계를 고정해야 한다. 그 뒤 스펙이 상세한 파이프라인, 마켓 연동, 이미지 변환은 Opus 5.5에, 골격과 UI 변환, 문구 정비는 Sonnet 5.5에 넘기면 비용 대비 안전하다.
