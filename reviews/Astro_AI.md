# Astro AI 기획 리뷰

리뷰 일자: 2026-10-12 / 대상 경로: `D:\WorkSpace\platform\Astro AI\기획안` (13개 문서 전수 확인) / 코드: 없음 (`Astro AI` 폴더에는 `기획안` 하위 문서만 존재)

## 1. 프로젝트 개요

- 한 줄 설명: 서비스명 "신비로운AI". 생년월일시와 타로 선택을 입력받아 Claude로 사주·타로 리딩을 생성하고, WeasyPrint PDF로 렌더링해 이메일·카카오 알림톡·대시보드 3채널로 발송하는 크레딧 과금형 SaaS. 크리에이터가 PDF 테마(ThemeConfig JSON)를 판매하는 마켓플레이스와, 같은 골격을 재테크/건강/학습/연애 버티컬로 복제하는 멀티버티컬 전략을 포함한다.
- 기획 의도: "점집 가기 싫은데 운세는 궁금한" 20~40대에게 30초 안에 소장 가능한 PDF 리포트를 제공하고, 크레딧 구독(₩9,900~₩69,900)과 템플릿 수수료(30%)로 수익화.
- 대상 사용자: 일반 사용자(20~40대), 크리에이터(디자이너·타로 전문가), 기업/에이전시(API·화이트라벨, 문서상 언급만 있음).

| 영역 | 제안된 기술 |
|---|---|
| 프론트 | Next.js 16.2.7 App Router, Tailwind v4, Shadcn UI, Zustand, Framer Motion, Recharts, Lucide |
| 백엔드 | Supabase Edge Function + FastAPI(Railway) 2단 구성, pg_cron 재시도 |
| DB/인증 | Supabase Postgres + RLS, Supabase Auth(이메일/Google/Apple), Storage, Realtime |
| AI/PDF | Claude API(`claude-sonnet-4-6`), WeasyPrint(Noto CJK), 미리보기용 Puppeteer |
| 발송/결제 | Resend, 카카오 알림톡, Toss Payments(일반결제 + 빌링키) |
| 인프라 | Vercel(FE), Railway(FastAPI, Puppeteer) |

- 기획 완성도: 약 55%
  - UI/디자인/랜딩 명세는 매우 구체적이다(섹션별 색상·px·애니메이션까지, 약 85%). 반면 DB 스키마, 사주 계산 사양(만세력), 결제 승인 흐름, 잡 오케스트레이션, 실패 시 환불 정책, 법적 요건은 거의 비어 있다(약 25%). 문서 간 아키텍처 모순이 다수 있어 그대로 구현에 투입하면 에이전트마다 다른 구조를 만들 위험이 크다.

## 2. 기획 문서 분석

| 문서 | 역할 | 비고 |
|---|---|---|
| `공통/PRD.md` | 제품 정의, 요금/크레딧 단가, 기능·비기능 요구, KPI, 아키텍처 개요, 버티컬 계획 | 체크리스트형. 데이터 모델 없음 |
| `공통/ROADMAP.md` | 8주 MVP 주차별 작업과 완료 기준, Phase 2 버티컬 일정, 기술부채 | 담당(FE/BE/DevOps) 다인 팀 전제 |
| `공통/CLAUDE.md` | 고정 기술 스택, 폴더 구조, Taste-Skill 규칙, 크레딧/PDF/웹훅/RLS/환경변수 규칙, 금지사항 | 구현 규칙의 기준 문서 |
| `공통/DESIGN.md` | 컬러 토큰, Taste 4종, ThemeConfig 타입, 타이포/컴포넌트/애니메이션/반응형 | 컴포넌트 예시가 hex 하드코딩 |
| `공통/GEO.md` | AI 검색 최적화: 키워드, JSON-LD, `/llms.txt`, 블로그 전략, 측정 | 출시 전 가상 평점·후기 수치 포함 |
| `대시보드/PRD_DASHBOARD.md` | 사용자 6탭 / 크리에이터 6탭 / 어드민 6탭 요구사항 | 19개 화면 |
| `대시보드/CLAUDE_DASHBOARD.md` | 라우트 트리, Sidebar variant, KPICard/DataTable 인터페이스, 리딩 Zustand 스토어, 검수 Server Action | 권한 검사 누락 예시 |
| `대시보드/DESIGN_DASHBOARD.md` | 레이아웃, 역할별 사이드바 색, KPI/테이블/뱃지/진행바/빈 상태 | 라이트 대시보드 |
| `랜딩페이지/PRD_LANDING.md` | 11섹션 요구와 수용기준, 전환 목표, SEO/GEO, 성능 | |
| `랜딩페이지/CLAUDE_LANDING.md` | 컴포넌트 트리, SSR 분리, 파티클/카운터/마퀴 코드, Live Demo API | Tailwind v3식 config 예시 |
| `랜딩페이지/DESIGN_LANDING.md` | 섹션별 컬러 맵, GNB/Hero/Pain/Pricing 상세, 반응형 | |
| `멀티버티컬_템플릿/PRD_TEMPLATE.md` | `{{변수}}` 치환형 PRD, Skill 명세 양식, 버티컬 체크리스트 | |
| `멀티버티컬_템플릿/CLAUDE_TEMPLATE.md` | 버티컬용 CLAUDE.md 템플릿, `generateReading` 호출 패턴 | 공통 CLAUDE.md와 아키텍처 상충 |

요구사항 구조 요약: 문서는 "공통(PRD/CLAUDE/DESIGN) -> 영역별(대시보드/랜딩) 오버라이드 -> 버티컬 템플릿" 3계층이며, 영역 문서가 공통 문서보다 우선한다고 명시한다. 핵심 사용자 흐름은 "가입(30cr) -> 리딩 유형 선택 -> 입력 -> 크레딧 차감 -> Claude 생성 -> PDF -> 3채널 발송 -> 히스토리"이고, 부가 흐름은 크레딧/구독 결제, 크리에이터 등록-검수-판매-정산, 어드민 운영이다.

## 3. 기획상의 문제점

| # | 심각도 | 분류 | 위치(파일명:섹션) | 내용 |
|---|---|---|---|---|
| 1 | 높음 | 모순 | `공통/PRD.md:6`, `공통/CLAUDE.md:§5,§9,§11`, `멀티버티컬_템플릿/CLAUDE_TEMPLATE.md:§5` | 생성 경로가 문서마다 다르다. PRD는 Next -> Edge Function -> FastAPI -> Claude, CLAUDE.md는 크레딧 차감을 Edge Function에서만 하고 `CLAUDE_API_KEY`는 FastAPI 전용, 템플릿은 Next의 `src/lib/skills/reading.ts`에서 차감·Anthropic 호출·PDF·발송을 한 함수로 순차 실행 |
| 2 | 높음 | 누락 | 전체 | DB 스키마/ERD가 없다. `readings`, `templates`, `delivery_logs`, `purchased_templates`, `subscriptions`, `credits_config` 등 이름만 등장하고 컬럼·관계·상태값·인덱스가 정의되지 않음 |
| 3 | 높음 | 누락 | `공통/PRD.md:§3.1`, `대시보드/PRD_DASHBOARD.md:§2.2` | 만세력 사양 부재. 음력/양력 구분, 성별(대운 순·역행 결정), 출생 시 모름, 절기 기준 월주, 자시 처리, 출생지 경도 보정이 입력 폼에 없음. 사주 정확도의 근간이 정의되지 않음 |
| 4 | 높음 | 누락 | `공통/CLAUDE.md:§5`, `공통/PRD.md:§3.3` | "차감 성공 후에만 생성"만 있고 생성·PDF 실패 시 크레딧 환불/재시도 정책, 잡 상태 머신, 멱등 키가 없음. 차감 후 실패하면 유저 크레딧이 소실됨 |
| 5 | 높음 | 보안 | `공통/PRD.md:§3.4`, `공통/CLAUDE.md:§6` | 크리에이터 업로드 ThemeConfig JSON이 CSS로 변환되어 WeasyPrint/Puppeteer에 들어간다. `url()`, `@import`, `file://` 등을 통한 서버 파일 읽기·SSRF 가능성에 대한 스키마 검증·URL fetcher 차단 규칙이 없음 |
| 6 | 높음 | 보안 | `대시보드/CLAUDE_DASHBOARD.md:§7` | `approveTemplate`/`rejectTemplate` Server Action이 호출자 role 확인 없이 service_role 클라이언트로 업데이트하는 예시. 그대로 구현되면 로그인 사용자 누구나 검수 승인 가능 |
| 7 | 높음 | 기술리스크 | `공통/CLAUDE.md:§7`, `공통/ROADMAP.md:WEEK 5,7` | 결제 흐름이 웹훅 중심으로만 기술됨. Toss 일반결제는 클라이언트 성공 리다이렉트 후 서버의 결제 승인(confirm) API 호출이 필수이고, 일반 결제 웹훅은 문서의 `toss-signature` 같은 서명 헤더가 보장되지 않으므로(공식 문서 확인 필요) 승인 API + 결제 조회 재검증 기반으로 재설계해야 함 |
| 8 | 높음 | 보안 | `공통/GEO.md:§3.2`, `랜딩페이지/PRD_LANDING.md:§2 SEC-09`, `공통/DESIGN.md:§3` | 출시 전 `aggregateRating 4.9 / reviewCount 1240`, 후기 12개, 카운터 "12,470+"를 구조화 데이터와 랜딩에 넣도록 기획됨. 실제 근거 없는 평점·후기는 검색엔진 정책 위반 및 표시광고법상 기만 광고 위험 |
| 9 | 중간 | 모순 | `공통/CLAUDE.md:§6`, `공통/PRD.md:§4.2`, `대시보드/PRD_DASHBOARD.md:§2.3` | "원본 24시간 내 자동 삭제" vs 서명 URL 7일 vs 히스토리 다운로드·재생성(5cr). 무엇을 언제 지우는지 불명확. PRD 4.2의 "원본 영상"은 다른 프로젝트 문서의 잔재로 보임 |
| 10 | 중간 | 모순 | `공통/PRD.md:§3.3,§4.1`, `대시보드/DESIGN_DASHBOARD.md:§6` | 시간 목표가 서로 다름: AI p95 30초 + PDF p95 15초 + 발송 p95 30초인데 랜딩은 "PDF를 30초 안에", 발송은 "결제 완료 후 30초"(리딩은 결제가 아니라 크레딧 차감 시점). 재시도 5분 간격과 30초 목표의 관계도 미정 |
| 11 | 중간 | 기술리스크 | `멀티버티컬_템플릿/CLAUDE_TEMPLATE.md:§5`, `공통/GEO.md:§4` | 통합 4,000자, 연간 리포트 PDF 30페이지를 `max_tokens: 4096` 단일 호출로 생성하는 예시. 분량·시간 목표를 동시에 만족하기 어려워 섹션 분할 병렬 생성 또는 스트리밍 설계가 필요 |
| 12 | 중간 | 모순 | `공통/CLAUDE.md:§3,§11`, `공통/DESIGN.md:§4`, `대시보드/CLAUDE_DASHBOARD.md:§2` | "Taste 파일 외 색상 하드코딩 금지"인데 DESIGN/대시보드 예시 전부가 `bg-[#8B5CF6]` 등 hex 하드코딩. 또 Taste는 `src/themes/*.ts` 정적 파일인데 마켓 테마는 런타임 업로드 JSON이라 저장 위치(DB/Storage)가 정의되지 않음 |
| 13 | 중간 | 모순 | `공통/CLAUDE.md:§8,§11` | RLS를 사용자 직접 접근 기준으로 설계하면서 "클라이언트에서 직접 DB 쿼리 금지(Edge Function 경유 필수)". 대시보드 문서는 SSR 페이지와 Realtime 구독(클라이언트 직접)을 사용. 데이터 접근 원칙이 하나로 정해지지 않음 |
| 14 | 중간 | 보안 | `대시보드/CLAUDE_DASHBOARD.md:§5` | 진행률을 `reading:${readingId}` broadcast 채널로 전달. 채널 인가(private channel/RLS)가 없어 ID만 알면 타인의 진행 상황 구독 가능. 누가 broadcast하는지(FastAPI?)도 미정 |
| 15 | 중간 | 누락 | `공통/PRD.md:§3.3`, `랜딩페이지/PRD_LANDING.md:§2 SEC-11` | 카카오 알림톡은 휴대폰 번호 수집·수신 동의, 발신 프로필, 템플릿 사전 심사가 필요하나 입력 항목·동의 절차·심사 일정이 없음. 개인정보 처리방침, 점술 서비스 면책 고지도 누락 |
| 16 | 중간 | 모호성 | `공통/PRD.md:§2.1`, `랜딩페이지/CLAUDE_LANDING.md:§5` | Master "무제한"의 공정 사용 한도가 없어 Claude 원가가 상한 없이 증가 가능. 비회원 Live Demo의 IP당 3회 제한은 서버리스에서 저장소(예: Redis)가 정의되지 않음 |
| 17 | 중간 | 범위과다 | `공통/ROADMAP.md:Phase 1` | 8주 안에 화면 19개 + 랜딩 11섹션 + 마켓플레이스·검수·정산 + 빌링키 구독 + 3채널 발송 + E2E. 담당 FE/BE/DevOps 팀 전제인데 실제 인력 계획이 없음. 크리에이터 정산은 원천징수·통신판매중개 등 법무 검토도 필요 |
| 18 | 낮음 | 모순 | `공통/GEO.md:§3.2`, `대시보드/PRD_DASHBOARD.md:§5` | GEO Product 설명은 "KO/JA/EN 다국어 PDF 발송", 대시보드는 v1 한국어 전용 |
| 19 | 낮음 | 누락 | `공통/PRD.md:§2.2`, `대시보드/PRD_DASHBOARD.md:§2.2` | 궁합(25cr, 2인 입력)과 연간 운세(50cr)는 단가표에만 있고 리딩 선택 UI는 사주/타로/통합 3종뿐 |
| 20 | 낮음 | 기술리스크 | `공통/PRD.md:§3.4`, `랜딩페이지/CLAUDE_LANDING.md:§3.4` | 미리보기는 Puppeteer, 실제 PDF는 WeasyPrint로 렌더러가 달라 결과가 불일치. 랜딩 예시는 Tailwind v4에서 쓰지 않는 `tailwind.config.ts` 방식 |
| 21 | 낮음 | 범위과다 | `공통/PRD.md:§7` | 건강AI "처방 리포트", 재테크AI "분석 리포트"는 의료법·유사투자자문 규제 대상이 될 수 있어 "카피만 교체"로는 확장 불가 |

심각도 높음 상세:

- #1 아키텍처 모순: 구현 에이전트가 어느 문서를 먼저 읽느냐에 따라 Edge Function, Next 서버, FastAPI 중 다른 곳에 크레딧·AI 로직을 넣게 된다. 크레딧과 AI 키의 위치는 보안 경계 그 자체이므로 구현 전에 하나로 확정하고 나머지 문서를 고쳐야 한다.
- #2, #3 데이터와 도메인 사양 부재: 테이블 정의와 만세력 규칙은 모든 화면·API·PDF의 입력이다. 특히 성별과 음/양력이 없으면 대운 계산 자체가 불가능하므로, 폼과 스키마를 확정하기 전에 사주 엔진 사양서(골든 테스트 케이스 포함)를 먼저 만들어야 한다.
- #4 환불 정책 부재: 선차감 구조에서 Claude 타임아웃·PDF 렌더 실패는 흔하게 발생한다. `consume -> job(failed) -> refund`를 하나의 상태 머신으로 정의하지 않으면 CS 비용과 결제 분쟁이 바로 발생한다.
- #5, #6 템플릿 업로드와 검수 권한: 마켓플레이스는 외부 입력을 서버 렌더러에 넣는 유일한 경로이고, 검수 승인은 판매 노출을 결정한다. JSON 스키마 화이트리스트(색상 hex, 폰트 목록, enum만 허용)와 Server Action 내부 role 재검증을 필수 규칙으로 문서에 명시해야 한다.
- #7 결제 승인 흐름: 웹훅만 믿고 크레딧을 지급하면 승인 누락·위조 위험이 있다. "결제창 -> successUrl -> 서버 confirm API -> 금액·orderId 대조 -> add_credits(멱등)" 순서를 기준으로 하고 웹훅은 보조 동기화로 써야 한다.
- #8 가상 평점·후기: GEO 전략의 핵심 수단이 허위 데이터에 기대고 있다. 출시 시점에는 실측 수치만 쓰거나 해당 블록을 숨기는 조건부 렌더링으로 바꿔야 한다.

## 4. 효율적 구현 전략

### 4.1 권장 아키텍처 (단순화)

- 호출 경로를 하나로 확정: `Next.js(Route Handler/Server Action)`에서 인증, 입력 검증(zod), 크레딧 RPC 차감, `readings` 행 생성(status=queued)까지 처리. Supabase Edge Function 단계는 제거한다(Vercel과 기능 중복, 디버깅 지점만 늘어남).
- 생성 워커는 FastAPI(Railway) 1개: Next가 HMAC 서명 요청으로 잡을 넘기거나 워커가 `readings`를 폴링. 워커가 Claude 호출(섹션 분할 병렬), Jinja 템플릿 + WeasyPrint 렌더, Storage 업로드, 상태 갱신, 실패 시 `refund_credits` 호출까지 담당. Claude 키는 워커에만 둔다.
- 진행률은 broadcast 대신 `readings` 행의 `postgres_changes` 구독(RLS로 본인 행만)으로 처리해 인가 문제를 없앤다.
- 발송은 `delivery_logs`를 outbox 테이블로 사용: 워커가 행을 만들고, 발송기가 처리, pg_cron(또는 워커 스케줄러)이 실패 건만 재시도.
- 만세력 계산은 결정적 코드(TS 모듈)로 분리해 Next에서 계산 후 워커에 원국 데이터를 넘긴다. 같은 모듈로 Live Demo 키워드를 LLM 없이 만들어 비회원 비용을 0으로 만든다.
- 테마: 기본 Taste는 `src/themes/*.ts`, 마켓 테마는 `themes` 테이블(jsonb, 검증된 스키마)로 저장하고 둘 다 같은 `ThemeConfig -> CSS 변수` 변환기를 거친다. 미리보기는 WeasyPrint로 렌더한 PDF 첫 페이지를 이미지로 변환해 Puppeteer를 없앤다.

### 4.2 재사용할 기존 프로젝트/모듈

| 재사용 대상 | 가져올 것 | 주의점 |
|---|---|---|
| `Nomad-BlogStudio` (1순위 베이스) | Taste-Skill 구조(`themes/*.ts`, `skills/`), 거의 동일한 다크 컬러 토큰(`#13131A`, `#1A1A26`, `#F8F8FF`, `#A0A0B8`), `(marketing)`/`(dashboard)` 라우트 그룹, `src/lib/supabase/{client,server,middleware}.ts`, `src/lib/billing/credits.ts`, `api/billing/{checkout,confirm}`, `api/webhooks/toss`, `consume_credits`/`refund_credits` RPC(`supabase/migrations/002_rpc_functions.sql`) | 기존 리뷰 없음. `consume_credits`가 잔액 확인 후 갱신을 행 잠금 없이 수행하고 `security definer`인데 호출자 검증이 없음(`002_rpc_functions.sql:6-27`). `FOR UPDATE` 또는 단일 조건부 UPDATE와 `auth.uid()` 검사로 수정 후 사용. 조직(org) 기반 모델이라 기업/에이전시 확장에 유리 |
| `sellingstudio` | Next 16 `proxy.ts` 세션 갱신·라우트 보호, 잡 테이블 + 웹훅 + Realtime 뷰어 패턴(리딩 진행률에 그대로 대응), 가입 트리거 포함 `profiles` 마이그레이션, 전 라우트 zod 검증 관례 | 리뷰(`docs/reviews/sellingstudio.md`)에서 지적된 크레딧 read-then-write, fal 웹훅 서명 미검증은 가져오지 말 것 |
| `NOMAD Shorts Maker` | Toss Payments SDK 연동부, `deduct_credits`/`add_credits` RPC 명명(본 기획과 동일), Railway Python 워커 구성(`workers/*.py`, `requirements.txt`) -> FastAPI 워커 골격 | 리뷰(`docs/reviews/NOMAD_Shorts_Maker.md`)상 RPC 권한 결함과 결제 경로 2개 공존 문제가 있음. 코드 복사 전 해당 항목 수정 |
| `Hospital` | `src/lib/permissions.ts`의 역할-페이지 매트릭스와 `proxy.ts` 역할별 리다이렉트 -> user/creator/admin 분기, Recharts KPI 카드, `Database` 제네릭 타입 적용 방식 | 리뷰상 RLS 미구현, 평문 비밀번호 게이트는 제외 |
| `FortuneDocs` (기획만 존재) | 동일 도메인(만세력 기반 사주 PDF) 기획. KASI(한국천문연구원) API로 음양력·간지 도출, `lib/astrology.ts` 오행/십신 연산, 오행 차트 이미지 아이디어 | 두 기획이 같은 시장을 겨냥하므로 하나로 통합하거나 만세력 엔진을 공용 패키지로 만드는 결정을 먼저 할 것 |
| `basic-master-module` | create-next-app 수준(Next 16.2.4 + Tailwind v4, 의존성 3개)이라 가치 낮음 | BlogStudio를 베이스로 쓰면 불필요 |

### 4.3 MVP 범위 축소안

- 포함(MVP): 사주 기본, 타로 3카드, 통합 리딩 / 기본 테마 2종(mystical-dark, oracle-gold) / 이메일 + 대시보드 2채널 / 크레딧 팩 일반결제 / 사용자 대시보드 4탭(홈, 리딩, 히스토리, 크레딧) / 최소 어드민(유저 조회, 결제·환불, 크레딧 조정, 발송 로그) / 랜딩 11섹션(실측 수치만) / Live Demo(LLM 미사용).
- 연기(Phase 2): 카카오 알림톡(심사 기간 병행 준비), 빌링키 정기구독과 Master 플랜, 궁합·연간 운세, 템플릿 마켓플레이스·크리에이터 대시보드·정산, Apple 로그인, Storybook.
- 제거 또는 재검토: Supabase Edge Function 단계, Puppeteer, 가상 평점·후기, 건강/재테크 버티컬(법무 검토 전).

### 4.4 단계별 로드맵

| 단계 | 기간 | 내용 | 완료 기준 |
|---|---|---|---|
| 0. 설계 확정 | 1주 | 아키텍처 단일화, ERD·RLS, 리딩 잡 상태 머신, 결제 시퀀스, 만세력 사양과 골든 케이스 100건, 문서 모순 정리(PRD v1.1) | 문서 간 충돌 0건, 마이그레이션 초안 |
| 1. 코어 파이프라인 | 3주 | BlogStudio 기반 골격, 크레딧 RPC, Toss 일반결제, 만세력 엔진, FastAPI 워커(Claude + WeasyPrint), 리딩 플로우 UI, 이메일 발송 | 입력 -> PDF 수신 E2E, 실패 시 자동 환불 확인 |
| 2. 출시 준비 | 2~3주 | 사용자 대시보드 나머지, 최소 어드민, 랜딩·SEO/GEO, Live Demo, Playwright 핵심 5플로우, 개인정보처리방침 | 베타 100명 오픈 |
| 3. 수익 확장 | 4주 | 빌링키 구독, 카카오 알림톡, 궁합·연간 운세, 마켓플레이스(검수·정산 포함) | 크리에이터 10명 파일럿 |
| 4. 버티컬 | 버티컬당 3~4주 | 연애AI 등 규제 부담 낮은 버티컬부터 Taste/Skill 교체 | 법무 검토 통과 |

## 5. 구현 작업 목록 및 권장 모델

| # | 작업 | 우선순위 | 규모 | 권장 모델 | 이유 |
|---|---|---|---|---|---|
| 1 | 아키텍처 단일화 결정과 문서 정리: Edge Function 제거, 크레딧·Claude 키 위치 확정, 3장 #1/#9/#10/#12/#13 모순 해소한 PRD/CLAUDE v1.1 작성 | P0 | M | Fable 5.1 | 기획안만 있는 프로젝트의 설계, 보안 경계 결정 |
| 2 | ERD와 Supabase 마이그레이션: `profiles(role)`, `readings`(상태 머신), `credit_ledger`, `credit_packages`, `payments`, `delivery_logs`, `themes`, `templates` + 전 테이블 RLS | P0 | L | Fable 5.1 | 데이터 모델 설계, 실수 시 데이터·권한 사고 |
| 3 | 프로젝트 골격: Nomad-BlogStudio 구조 복제, Next 16 `proxy.ts` + Hospital식 역할 매트릭스, Supabase 클라이언트, 타입 생성, 공통 레이아웃(Sidebar variant) | P0 | M | Opus 5.5 | 1·2번 결정 이후 명확한 이식 작업 |
| 4 | 크레딧 RPC 재작성: 행 잠금 차감, `auth.uid()` 검증, 멱등 키, `refund_credits`, 원장 기록 | P0 | M | Fable 5.1 | 돈과 직결, 동시성 처리 |
| 5 | Toss 일반결제: checkout -> successUrl -> confirm API -> 금액·orderId 대조 -> 멱등 지급, 웹훅은 재조회 기반 보조 동기화 | P0 | M | Fable 5.1 | 결제 로직, 외부 사양 확인 필요 |
| 6 | 만세력·사주 엔진 TS 모듈: 음/양력, 절기 월주, 자시·시 모름, 성별 대운, 오행 집계 + 골든 테스트 100건 | P0 | L | Fable 5.1 | 도메인 정확도가 제품 신뢰의 핵심, 원인 불명 오류 가능성 높음 |
| 7 | FastAPI 워커: HMAC 잡 수신, Claude 섹션 분할 병렬 생성, Jinja + WeasyPrint(Noto CJK, url fetcher 차단), Storage 업로드, 상태 갱신, 실패 시 환불 | P0 | L | Opus 5.5 | 설계 확정 후 API 연동 중심 구현 |
| 8 | 테마 시스템: ThemeConfig 스키마(zod + pydantic), Taste 2종, ThemeConfig -> CSS 변수 변환기, PDF 커버/본문 템플릿 | P1 | M | Sonnet 5.5 | 스타일·반복 작업, 스키마는 1번에서 확정 |
| 9 | 리딩 시작 플로우: 유형 선택, SajuForm(음양력·성별·시 모름), TarotPicker, ProgressTracker(`postgres_changes`), 완료 화면, 크레딧 부족 모달 | P0 | M | Opus 5.5 | 상태관리 + Realtime 연동 |
| 10 | 발송 파이프라인: Resend 이메일(서명 URL), `delivery_logs` outbox, pg_cron 재시도 3회, 재발송 API | P1 | M | Opus 5.5 | 외부 API 연동 + 재시도 로직 |
| 11 | 사용자 대시보드 홈·히스토리·크레딧·발송내역 탭, 공통 KPICard/DataTable/SlideOver/EmptyState | P1 | M | Sonnet 5.5 | 반복 컴포넌트·UI |
| 12 | 최소 어드민: 유저 조회, 결제 조회·환불(사유 필수), 크레딧 조정 감사 로그, 발송 모니터. 모든 Server Action에서 role 재검증 | P1 | M | Opus 5.5 | 권한 패턴은 3번에서 확정, 중간 규모 기능 |
| 13 | 랜딩 11섹션 + JSON-LD/`llms.txt`/OG, 가상 평점·후기·카운터 제거(실측값 조건부 렌더링), reduced-motion | P1 | M | Sonnet 5.5 | UI·문구 중심 |
| 14 | Live Demo API: 만세력 모듈 기반 키워드(LLM 미사용), Upstash 등 영속 rate limit | P1 | S | Opus 5.5 | 남용·비용 방지 로직 |
| 15 | Playwright 핵심 5플로우(가입, 결제, 리딩 생성, 실패 환불, 어드민 환불) + Lighthouse CI | P2 | M | Opus 5.5 | 테스트 설계 |

## 6. 종합 평가

- 실현 가능성: 중간. 디자인·화면 명세는 바로 구현 가능할 만큼 상세하고 재사용할 자산(BlogStudio, sellingstudio, Shorts Maker)이 많지만, 아키텍처 모순과 데이터·만세력·결제·환불 사양 공백 때문에 원안대로 8주에 전 범위를 내는 것은 비현실적이다. 4.3의 축소 MVP는 1주 설계 + 5~6주 구현으로 가능하다고 판단한다.
- 강점: (1) 랜딩·대시보드 UI 명세가 매우 구체적이고 일관된 디자인 토큰을 가짐 (2) Taste-Skill 분리와 버티컬 템플릿으로 확장 구조가 사전에 설계됨 (3) 크레딧 트랜잭션, 웹훅 멱등성, RLS, 금지사항 등 보안 의식이 문서화됨.
- 약점: (1) 문서 간 아키텍처·데이터 접근 원칙 모순 (2) ERD, 만세력, 환불, 결제 승인 등 백엔드 핵심 사양 공백 (3) 범위 과다와 가상 사회적 증거 등 출시·법무 리스크.
- 모델별 비율(15개 작업 기준): Fable 5.1 33% (5개) / Opus 5.5 47% (7개) / Sonnet 5.5 20% (3개).
- 권장 진행 순서: 1단계 설계 확정(작업 1, 2, 6의 사양) -> 2단계 코어(3, 4, 5, 6, 7, 9, 10) -> 3단계 출시 준비(8, 11, 12, 13, 14, 15) -> 이후 Phase 3 수익 확장.
- 주 담당 모델: Fable 5.1. 작업 수는 Opus가 가장 많지만, 이 프로젝트의 성패는 코드량이 아니라 0단계에서 아키텍처를 하나로 확정하고 ERD·크레딧·결제·만세력 사양을 정확히 세우는 데 달려 있다. 이 결정들은 모두 돈과 데이터에 직결되고 문서 간 모순을 해석해야 하는 작업이라, 템플릿 기준상 "기획안만 있는 프로젝트의 설계와 초기 골격"에 해당한다. Fable이 설계와 P0 보안·결제 작업을 맡고, 확정된 사양을 Opus가 구현하고, UI 반복 작업을 Sonnet이 맡는 구성이 비용 대비 가장 안전하다.
