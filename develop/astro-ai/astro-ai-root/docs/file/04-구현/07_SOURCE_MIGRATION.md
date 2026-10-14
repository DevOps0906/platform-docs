# 07 원본 이식과 폐기: 신비로운AI

두 원본 모두 코드가 없고 기획 문서만 있다(`docs/reference/reviews/Astro_AI.md:3`, `docs/reference/reviews/FortuneDocs.md:3`). 그래서 "이식"은 요구사항·수치·구조를 이 기획서와 새 코드로 옮기는 것을 뜻한다. 경로 표기: `AA/`는 `Astro AI/기획안/`, `FD/`는 `FortuneDocs/`.

AI 관련 원본 자산(2026-10-13 점검): 원본의 AI 사용은 Claude API 단일 호출(`AA/공통/CLAUDE.md:17`), Claude Skill 모듈 디렉토리(`AA/공통/CLAUDE.md:44-47`), FD의 3사 역할 분담(`FD/PRD.MD:39-41`)뿐이다. OpenRouter 폴백은 원본이 아니라 분석(`docs/reference/00_MERGE_ANALYSIS.md:337`)에서 나왔다. RAG, 위키, Dify, 음성, 3D는 원본에 없어 모두 신규다(원본 랜딩의 canvas 별자리 파티클은 3D가 아니라 P-26으로 폐기). 아래 표의 AI 행이 이 자산들의 대응이다.

## 1. 원본별 자산 분류

### 1.1 Astro AI

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `AA/공통/PRD.md` 2장 요금·단가·크레딧팩 | 기획만 | 이식 | 01장 4절, 모놀리스 `seed.sql` | 확정 결정 8 |
| `AA/공통/PRD.md` 3.1 리딩 엔진·품질 기준 | 기획만 | 이식(수치), 디벨롭(엔진) | 01장 AS-F-006, 009~011 | `:65-72` |
| `AA/공통/PRD.md` 3.2~3.3 PDF·발송 | 기획만 | 이식(WeasyPrint, Resend, 재시도), 폐기(카카오는 Phase 2) | 02장 4절, 05장 2.5절 | `:74-87` |
| `AA/공통/PRD.md` 3.4 마켓플레이스 | 기획만 | 폐기 | 3절 P-03 | `:89-94` |
| `AA/공통/PRD.md` 4~5장 비기능·KPI | 기획만 | 이식(수치 정리) | 01장 5절, 7절 | `:106-136` |
| `AA/공통/PRD.md` 6장 아키텍처 | 기획만 | 폐기(Edge Function) | 02장 머리 결정표 | `:142-152` |
| `AA/공통/PRD.md` 7장 멀티버티컬 | 기획만 | 폐기 | 3절 P-06 | `:156-164` |
| `AA/공통/CLAUDE.md` 스택·폴더·금지사항 | 기획만 | 참고(스택), 디벨롭(크레딧·웹훅·RLS 규칙) | `CLAUDE.md`, 02장 1절 | `:7-271` |
| `AA/공통/CLAUDE.md` AI 스택(Claude API `claude-sonnet-4-6` 단일) | 기획만 | 디벨롭 | 02장 1절 LLM 행(FastAPI 라우터 체인의 첫 순위 Claude), 모델 id는 `core.ai_model_prices` 행 | `:17`, 확정 결정 17 |
| `AA/공통/CLAUDE.md` `skills/`(Claude Skill 모듈: reading, delivery, marketplace) | 기획만 | 폐기(대체) | reading → 그래프 `astro.reading`(02장 5.2절), delivery → 워커 outbox, marketplace → P-03. 3절 P-27 | `:44-47`, `AA/공통/PRD.md:71` |
| `AA/공통/PRD.md` 6장 FastAPI(Railway) → Claude API → WeasyPrint | 기획만 | 디벨롭 | FastAPI는 AI 서비스(`apps/api`, 그래프·RAG·위키)로, PDF는 공용 렌더 서비스로 나눔 | `:142-152`, 확정 결정 3, 13 |
| `AA/공통/CLAUDE.md` `CLAUDE_API_KEY`("FastAPI 서버에서만") | 기획만 | 이식(원칙) | LLM 키는 FastAPI 전용(02장 8절). 원본 원칙과 같다 | `:241` |
| `AA/공통/DESIGN.md` Taste 4종·ThemeConfig | 기획만 | 이식(2종, 타입 구조), 디벨롭(팔레트 재추출) | 03장 4.3절, `astro.themes` | `:44-85` |
| `AA/공통/GEO.md` | 기획만 | 이식(JSON-LD 구조, `/llms.txt`, 블로그 주제), 폐기(가상 평점, 다국어 문구) | 03장 4.4절 | `:38-218` |
| `AA/공통/ROADMAP.md` | 기획만 | 참고 | 06장 웨이브로 대체 | `:6-148` |
| `AA/대시보드/PRD_DASHBOARD.md` 사용자 6탭 | 기획만 | 통합(5화면으로 축소) | 03장 1절 | `:17-55` |
| `AA/대시보드/PRD_DASHBOARD.md` 크리에이터 6탭 | 기획만 | 폐기 | 3절 P-04 | `:59-92` |
| `AA/대시보드/PRD_DASHBOARD.md` 어드민 6탭 | 기획만 | 디벨롭(최소 어드민) | 01장 AS-F-022 | `:96-125` |
| `AA/대시보드/CLAUDE_DASHBOARD.md` Sidebar·KPICard·DataTable·Zustand 스토어 | 기획만 | 참고(구조), 폐기(broadcast, approveTemplate) | 03장 3절 | `:60-219` |
| `AA/대시보드/DESIGN_DASHBOARD.md` | 기획만 | 참고(빈 상태·진행 바·반응형) | 03장 5~6절 | `:181-228` |
| `AA/랜딩페이지/PRD_LANDING.md` 11섹션 | 기획만 | 통합(7섹션으로 축소), 폐기(후기·카운터·파티클·페인포인트) | 03장 4절 | `:16-83` |
| `AA/랜딩페이지/CLAUDE_LANDING.md` SSR 분리·성능 체크리스트·Live Demo | 기획만 | 이식(성능 체크리스트, 데모 흐름), 폐기(파티클·카운터 코드, v3 config) | AS-06-023, AS-06-024 | `:39-291` |
| `AA/랜딩페이지/DESIGN_LANDING.md` | 기획만 | 참고만(색·파티클은 폐기) | 03장 4.4절 | `:7-185` |
| `AA/멀티버티컬_템플릿/*.md` | 기획만 | 폐기(보류 아카이브) | 3절 P-06, P-15 | `docs/reference/00_MERGE_ANALYSIS.md:402` |

### 1.2 FortuneDocs

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `FD/PRD.MD` 1장 포지셔닝("평생 사주를 한 권의 책으로") | 기획만 | 이식 | README 1장, 03장 4.2절 | `:15` |
| `FD/PRD.MD` 2.2 KASI + `lib/astrology.ts` | 기획만 | 디벨롭(로컬 엔진, KASI 검증용) | `packages/saju-engine` | `:31-32` |
| `FD/PRD.MD` 2.2 QuickChart | 기획만 | 폐기 | 3절 P-11 | `:33` |
| `FD/PRD.MD` 2.3 Vercel AI SDK 3사 | 기획만 | 폐기 | 3절 P-09 | `:35-41` |
| `FD/PRD.MD` 2.3 3사 역할 분담(ChatGPT 격국·용신 판별, Claude 스토리텔링, Gemini 장문) | 기획만 | 폐기(역할 분담), 디벨롭(3사를 같은 작업의 대체 체인으로) | 02장 5.1절. 격국·용신 LLM 판별 금지(01장 D-10, 3절 P-28) | `:39-41` |
| `FD/PRD.MD` 6장 `api/generate/route.ts`(Vercel AI SDK Multi-LLM 스위칭) | 기획만 | 폐기 | FastAPI 라우터와 그래프(02장 5절) | `:156` |
| `FD/PRD.MD` 3.1 다중 프로필 보관함 | 기획만 | 이식 | `astro.subjects`, 03장 | `:50` |
| `FD/PRD.MD` 3.1 매직링크, 가입 3크레딧 | 기획만 | 폐기(매직링크 연기), 결정 대기(크레딧 양) | 01장 D-3 | `:49`, `:51` |
| `FD/PRD.MD` 3.2 입력 모델, 원국 프리뷰 | 기획만 | 이식(+ 생시 모름, 출생지) | 05장 2.2절, AS-F-007 | `:55-56` |
| `FD/PRD.MD` 3.3 구조화 JSON, 현대적 재해석 | 기획만 | 디벨롭(장 스키마, 수치 제외) | 04장 4절, AS-06-011 | `:58-73` |
| `FD/PRD.MD` 3.4 대운 타임라인 | 기획만 | 이식 | AS-F-008 | `:80` |
| `FD/PRD.MD` 3.5 Puppeteer PDF | 기획만 | 폐기 | 3절 P-02 | `:84` |
| `FD/PRD.MD` 3.5 ePub | 기획만 | 이식(Phase 2) | AS-06-035 | `:85` |
| `FD/PRD.MD` 4장 RLS, GEO | 기획만 | 디벨롭(RLS 재설계), 통합(GEO는 AA 기준) | 05장 4절 | `:93`, `:97` |
| `FD/PRD.MD` 5장 DDL | 기획만 | 폐기(재설계) | `1100_astro.sql` | `:103-143` |
| `FD/PRD.MD` 6장 디렉토리 트리, 해설서 편집 화면 | 기획만 | 폐기 | 3절 P-01, P-10 | `:150-175` |
| `FD/CLAUDE.MD` | 기획만 | 폐기(PRD 중복, 잔재) | 3절 P-14 | `docs/reference/reviews/FortuneDocs.md:28` |

## 2. 이식 자산 상세

| 이식 자산 | 고칠 점 |
|---|---|
| 크레딧 단가와 팩 | 보너스는 `credit_packs.credits`에 합산(코어에 보너스 컬럼 없음). 단가는 `credits_config` 테이블이 아니라 코드 상수(`AA/공통/CLAUDE.md:267`과 다름, 01장 4.2절) |
| 리딩 품질 기준(2,500/4,000자, 이름 3회) | 이름 대신 `{{호칭}}` 토큰을 세고, 실명은 렌더 시점에 넣는다(LLM에 실명 미전송) |
| WeasyPrint 렌더(`AA/공통/CLAUDE.md:159-176`) | 제품 FastAPI가 아니라 공용 렌더 서비스 호출. 폰트 경로 하드코딩 대신 컨테이너 기동 검사. `url_fetcher` 제한. "원본 24시간 삭제"와 "로컬 저장 금지" 중 뒤만 유지 |
| Toss 결제(`AA/공통/CLAUDE.md:186-208`) | 웹훅 지급을 confirm 경로로 바꾸고 `toss-signature` 가정을 미확인으로 둠 |
| RLS(`AA/공통/CLAUDE.md:213-226`) | `FOR ALL` 정책을 SELECT 전용 + 서버 쓰기로. 역할은 core `platform_role`로 |
| 발송 재시도(pg_cron 5분 3회) | `astro.deliveries` outbox + `claim_due_deliveries`/`finish_delivery` |
| 리딩 스토어(`AA/대시보드/CLAUDE_DASHBOARD.md:158-187`) | 단계 `analyzing → pdf → email → kakao`를 `queued → generating → rendering → completed`로, broadcast를 `postgres_changes`로 |
| Live Demo(`AA/랜딩페이지/CLAUDE_LANDING.md:256-277`) | 키워드를 엔진 규칙으로, IP 제한을 `core.rate_limit_hit` 영속 버킷으로. 화살표 기호 키워드("재물운 ↑") 대신 문장형 |
| Taste 4종 | MVP 2종. 키 유지, 팔레트는 03장 4.3절 원칙으로 재추출, 컴포넌트 hex 하드코딩 금지 |
| FD 입력 모델 | `gender NOT NULL`, 윤달·자시·생시 모름·경도 추가, 원문은 암호화 |
| FD 오행 색 규칙 | 金·水 테두리 규칙 추가, 범례와 함께만 사용 |
| FD 현대적 재해석 원칙 | 사전으로 구체화(AS-06-011), 의료·투자 단정 금지 규칙과 함께 |
| AA GEO JSON-LD | `aggregateRating`, `Review` 제거, Product는 크레딧팩 offers로, 다국어 문구 제거 |
| Claude 단일 호출(`AA/공통/CLAUDE.md:17`) | 모델 id 하드코딩을 없애고 `core.ai_model_prices` 행 + 라우터 체인(`astro.reading`: Claude → ChatGPT → Gemini → 오픈소스)으로. 분석의 OpenRouter 폴백(`docs/reference/00_MERGE_ANALYSIS.md:337`)은 플랫폼 제공자 `openrouter`로 남지만 astro 기본 체인에는 넣지 않는다(같은 모델의 중복 경로이고 국외 이전 제공자만 늘어난다) |
| Claude Skill 기반 개인화(`AA/공통/PRD.md:71`) | 스킬 파일 대신 그래프 노드와 언어 중립 프롬프트 파일(`packages/astro-report/prompts/`). "이름·질문 3회 이상 언급"은 `{{호칭}}` 3회 이상 + 질문 반영 규칙으로 바꾸고 compliance 노드가 검사 |
| FD 3사 체인(`FD/PRD.MD:39-41`) | 역할 분담 없이 같은 작업의 대체 순서로만 쓴다. 국외 이전에 동의하지 않은 조직은 오픈소스만 |
| 원본 랜딩 v3 설정(`AA/랜딩페이지/CLAUDE_LANDING.md:178`) | Tailwind CSS v4 `@theme` 토큰(P-13, 03장 3.2절) |

## 3. 폐기 목록과 사유

분석 B-2 "폐기"와 B-3 "버려지는 것"(`docs/reference/00_MERGE_ANALYSIS.md:307-406`)을 빠짐없이 옮겼다.

| ID | 폐기 항목 | 출처 | 사유 |
|---|---|---|---|
| P-01 | FD 해설서 편집 화면 | `FD/PRD.MD:163`, `docs/reference/00_MERGE_ANALYSIS.md:337` | 편집 범위가 정의되지 않았고 사주 리포트를 편집할 필요가 적음 |
| P-02 | Puppeteer(AA 테마 미리보기, FD PDF) | `AA/공통/PRD.md:91`, `FD/PRD.MD:84`, `docs/reference/00_MERGE_ANALYSIS.md:342`, `:386` | 실제 PDF(WeasyPrint)와 렌더러가 달라 결과 불일치, Vercel 서버리스·Edge에서 동작 안 함. 미리보기는 렌더 서비스 첫 페이지 이미지로 대체 |
| P-03 | 템플릿 마켓플레이스(업로드, 검수, 구매, 정산 70/30, 리뷰) | `AA/공통/PRD.md:47-50`, `:89-94`, `docs/reference/00_MERGE_ANALYSIS.md:367` | 업로드 JSON이 렌더러에 들어가는 보안 문제, 검수 권한 문제, 통신판매중개·원천징수 법무. Phase 3 이후 재기획 |
| P-04 | 크리에이터 대시보드 6탭, `creator` 역할 | `AA/대시보드/PRD_DASHBOARD.md:59-92`, `docs/reference/00_MERGE_ANALYSIS.md:314`, `:368` | 마켓과 함께 보류 |
| P-05 | 가상 평점·후기·카운터(`aggregateRating 4.9`, 후기 12개, "12,470+") | `AA/공통/GEO.md:70-73`, `AA/랜딩페이지/PRD_LANDING.md:69-72`, `AA/공통/DESIGN.md:111`, `docs/reference/00_MERGE_ANALYSIS.md:373` | 근거 없는 수치는 검색엔진 정책 위반, 표시광고법 위험 |
| P-06 | 멀티버티컬(재테크, 건강, 학습, 연애)과 템플릿 문서 2개 | `AA/공통/PRD.md:156-164`, `AA/멀티버티컬_템플릿/`, `docs/reference/00_MERGE_ANALYSIS.md:376`, `:402` | 건강·재테크는 의료법·유사투자자문 규제 대상. 연애AI만 이후 재검토. 문서는 아카이브 |
| P-07 | 기업 API/화이트라벨 | `AA/공통/PRD.md:23`, `docs/reference/00_MERGE_ANALYSIS.md:377` | 기능 정의가 없음 |
| P-08 | 다국어(KO/JA/EN) | `AA/공통/GEO.md:62`, `docs/reference/00_MERGE_ANALYSIS.md:378`, `:404` | v1은 한국어 전용 |
| P-09 | FD Vercel AI SDK 3사 역할 분담 체인과 `response_format` | `FD/PRD.MD:35-41`, `docs/reference/00_MERGE_ANALYSIS.md:387` | OpenAI 전용 파라미터, 체인/선택 불명확, 일관성과 비용 추적이 어려움 |
| P-10 | FD "Pure JavaScript, Edge 런타임" 원칙, Next 14, 단일 `supabaseClient.ts`, 디렉토리 트리 | `FD/CLAUDE.MD:13`, `FD/PRD.MD:150-175`, `docs/reference/00_MERGE_ANALYSIS.md:388` | 워크스페이스 표준(Next 16, SSR 클라이언트 3종)과 불일치, Edge에서 PDF·ePub 불가 |
| P-11 | QuickChart 외부 API | `FD/PRD.MD:33`, `docs/reference/00_MERGE_ANALYSIS.md:390` | 렌더 시 외부 네트워크 의존, 사용자 데이터를 제3자로 전송. 인라인 SVG로 대체 |
| P-12 | KASI 음력 간지를 그대로 쓰는 방식 | `FD/PRD.MD:31`, `docs/reference/00_MERGE_ANALYSIS.md:389` | 사주는 입춘·절기 기준이라 규칙이 다름. KASI는 검증용 |
| P-13 | AA 랜딩 예시의 Tailwind v3식 `tailwind.config.ts` | `docs/reference/reviews/Astro_AI.md:66`, `docs/reference/00_MERGE_ANALYSIS.md:391` | Tailwind v4는 CSS 테마 토큰 방식 |
| P-14 | 문서 잔재: FD `PRD.MD` 1~7행 챗봇 응답, `CLAUDE.MD`의 `[cite: 3]`와 닫히지 않은 코드펜스, 두 문서의 DDL·트리 중복 | `FD/PRD.MD:1-7`, `docs/reference/reviews/FortuneDocs.md:27-28`, `:56`, `docs/reference/00_MERGE_ANALYSIS.md:401` | 구현 지침이 아니며 동기화 위험 |
| P-15 | AA `CLAUDE_TEMPLATE.md` 5절 `generateReading`(Next에서 차감·호출·PDF·발송, `max_tokens: 4096` 단일 호출) | `AA/멀티버티컬_템플릿/CLAUDE_TEMPLATE.md:117-145`, `docs/reference/00_MERGE_ANALYSIS.md:394` | 공통 CLAUDE.md와 모순, 분량·시간 목표 동시 달성 불가 |
| P-16 | FD 스키마에서 LLM이 `five_elements` 점수 생성 | `FD/PRD.MD:66`, `docs/reference/00_MERGE_ANALYSIS.md:395` | 엔진 계산값과 중복·불일치 |
| P-17 | AA broadcast 진행률 채널 | `AA/대시보드/CLAUDE_DASHBOARD.md:176-182`, `docs/reference/00_MERGE_ANALYSIS.md:396` | 채널 인가 없음. `postgres_changes` + RLS로 대체 |
| P-18 | 웹훅 중심 결제 처리 | `AA/공통/CLAUDE.md:186-208`, `docs/reference/00_MERGE_ANALYSIS.md:396` | confirm API 누락, 서명 헤더 미보장 |
| P-19 | AA `approveTemplate`/`rejectTemplate` 예시 | `AA/대시보드/CLAUDE_DASHBOARD.md:219-243`, `docs/reference/00_MERGE_ANALYSIS.md:397` | role 확인 없이 service_role 업데이트 |
| P-20 | "Taste 외 하드코딩 금지"와 hex 하드코딩 예시 공존 | `docs/reference/reviews/Astro_AI.md:58`, `docs/reference/00_MERGE_ANALYSIS.md:398` | 모순. 토큰 CSS 변수만 사용 |
| P-21 | "원본 영상 24시간 삭제" 문구와 "PDF 원본 24시간 삭제" | `AA/공통/PRD.md:118`, `AA/공통/CLAUDE.md:182`, `docs/reference/00_MERGE_ANALYSIS.md:403` | 다른 프로젝트 잔재, 히스토리 재다운로드와 모순. 01장 AS-F-016으로 대체 |
| P-22 | Storybook 스냅샷 | `AA/공통/CLAUDE.md:256`, `docs/reference/00_MERGE_ANALYSIS.md:380` | 솔로 개발 단계에서 비용 대비 효과 낮음 |
| P-23 | Apple 로그인(연기) | `AA/공통/ROADMAP.md:15`, `docs/reference/00_MERGE_ANALYSIS.md:313`, `:404` | MVP 범위 축소 |
| P-24 | 매직링크 로그인(연기) | `FD/PRD.MD:49`, `docs/reference/00_MERGE_ANALYSIS.md:313` | 무료 크레딧 반복 수령 문제 |
| P-25 | Supabase Edge Function 단계 | `AA/공통/PRD.md:145`, `AA/공통/CLAUDE.md:143`, `docs/reference/00_MERGE_ANALYSIS.md:385` | Vercel 서버와 역할 중복, 크레딧·AI 키 위치 모순 |
| P-26 | 원본 랜딩의 canvas 별자리 파티클, 라이브 카운터, 페인포인트 카드 6개, 로고 마퀴 | `AA/랜딩페이지/PRD_LANDING.md:25-42` | 디자인 가이드 생성형 기본값과 피할 인상(`docs/file/03-설계/디자인/REFERENCES.md:65`). 로고 마퀴는 제휴 근거 없는 로고 노출 위험 |

AI 계층 도입(2026-10-13)으로 생긴 추가 폐기. 분석 B-2 목록 밖이라 따로 번호를 붙인다.

| ID | 폐기 항목 | 출처 | 사유 |
|---|---|---|---|
| P-27 | AA `skills/` Claude Skill 모듈 디렉토리(reading, delivery, marketplace) | `AA/공통/CLAUDE.md:44-47` | 스킬 파일은 런타임 계약이 아니다. 리딩은 그래프 `astro.reading`과 프롬프트 파일, 발송은 워커 outbox로 대체 |
| P-28 | FD "ChatGPT가 격국·용신 판별" | `FD/PRD.MD:39` | 명리 판정을 LLM에 맡기면 엔진과 결과가 갈린다(01장 D-10) |

## 4. 복사 금지 결함

`docs/file/03-설계/공용코어/SECURITY_BASELINE.md` 14장 중 해당 항목과 이 제품 고유 결함이다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 크레딧 RPC EXECUTE 미회수 | `docs/reference/00_MERGE_ANALYSIS.md:521`, `docs/reference/reviews/FortuneDocs.md:78` | 브라우저에서 크레딧 지급 | 코어 RPC(service_role 전용), 스모크로 42501 확인 |
| 비원자 차감(읽고 → 빼고 → 쓰기) | `:481`, `docs/reference/reviews/Astro_AI.md:93` | 동시 요청 음수 잔액 | `core.consume_credits` |
| 웹훅 서명 미검증, 웹훅만으로 지급 | `AA/공통/CLAUDE.md:186-208` | 위조 결제 | confirm 경로 + 웹훅 재조회 |
| orderId 파싱으로 대상 추출, 클라이언트 금액 신뢰 | `docs/file/03-설계/공용코어/SHARED_MODULES.md:145` | 금액 위조 | `payment_orders` 선저장 |
| `FOR ALL` 정책(`fortune_books`, `readings`, `templates`) | `FD/PRD.MD:141-142`, `AA/공통/CLAUDE.md:217-222` | 크레딧 없이 리포트 생성, 셀프 변경 | SELECT 전용 + guard 트리거 |
| 가입 트리거 없이 FK 의존 | `docs/reference/reviews/FortuneDocs.md:44` | 가입 직후 INSERT 실패 | 코어 `handle_new_user` |
| role 확인 없는 service_role 서버 액션 | `AA/대시보드/CLAUDE_DASHBOARD.md:222-243` | 누구나 승인 | `requireSession` + `platform_role` 재검증 후 admin 클라이언트 |
| 인가 없는 broadcast 채널 | `AA/대시보드/CLAUDE_DASHBOARD.md:176-182` | 타인 진행 상황 구독 | `postgres_changes` + RLS |
| 업로드 JSON → CSS → 렌더러(SSRF, 파일 읽기) | `docs/reference/reviews/Astro_AI.md:51` | 서버 파일 읽기 | 사용자 테마 없음, 변환기 화이트리스트, `url_fetcher` 제한 |
| 사용자 데이터를 제3자 렌더러(QuickChart)로 전송 | `FD/PRD.MD:33` | 개인정보 유출 | 인라인 SVG |
| 생년월일시·이름 평문 저장 | `FD/PRD.MD:113-122` | 유출 시 민감정보 노출 | 앱 계층 AES-256-GCM, 암호문 컬럼 GRANT 없음 |
| 메모리/서버리스 IP 제한 | `AA/랜딩페이지/CLAUDE_LANDING.md:274-275` | 인스턴스마다 초기화 | `core.rate_limit_hit` |
| 장애를 mock 응답이나 일반 토스트로 숨기기 | `AA/공통/CLAUDE.md:129-134` | 실패·환불 여부를 모름 | 01장 AS-F-012 상태와 환불 표시 |
| `.env` 실키 커밋 | `docs/reference/00_MERGE_ANALYSIS.md:203` | 키 유출 | 원본에 코드 없음. 신규 저장소에서 `.env*` gitignore와 CI 비밀 검사 |
| 한글에 `\b` 금지어 매칭 | `docs/reference/00_MERGE_ANALYSIS.md:791` | 필터 무효 | 금지 표현 규칙의 한글 경계 처리 |
| LLM·음성 키를 브라우저·Vercel·워커에 두기 | `AA/공통/CLAUDE.md:241`(원본은 FastAPI 전용으로 맞음) | 키 유출, 비용 남용 | LLM 키는 FastAPI 전용, ElevenLabs 키와 토큰 개인키는 Next.js 서버 전용 |
| 브라우저에서 Dify·FastAPI·AI 제공자 직접 호출 | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:299` | 인증·과금 우회 | `/api/ai/*`, `/api/voice/*` |
| Dify 입력에 토큰·org·개인정보 | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:285` | Dify 로그에 평문으로 남음 | 대화 매핑(`platform_conversation_id`, `dify_user`) |
| 생년월일 원문·실명을 AI 제공자에 전송 | 01장 6.5절 | 국외 이전, 개인 식별 | 엔진 수치와 `{{호칭}}` 토큰만 |
| LLM이 격국·용신 판정 또는 수치 생성 | `FD/PRD.MD:39`, `:66` | 엔진과 불일치 | 엔진 값 주입 + compliance 노드 |
| 클라이언트가 보낸 임의 텍스트를 TTS | 제안 | 음성 생성 남용, 과금 우회 | DB의 assistant 메시지와 리딩 본문만 낭독 |
| 낭독 도중 다른 제공자로 대체 | `docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:47` | 목소리가 바뀜 | 대체 금지, 실패 + 환불 |
| 3D 재질에 토큰 밖 색, 별 파티클·황도 기호 | `docs/file/03-설계/디자인/HERO_3D.md:52-53` | 피할 인상 | 03장 4.5절 토큰 표 |
| "Tailwind로"만 지시해 v3 설정 생성 | `docs/file/03-설계/디자인/DESIGN_SYSTEM.md:23` | v3 설정 혼입 | 지시와 문서에 Tailwind CSS v4 명시, `tailwind.config.js` 금지 |

## 5. 아카이브 절차

| 단계 | 내용 |
|---|---|
| 1 | 신규 저장소 생성 후 `archive/astro-ai-plan/`(AA 13개 문서), `archive/fortunedocs-plan/`(FD 2개)로 원본을 읽기 전용 복사. 원본 폴더 `Astro AI/`, `FortuneDocs/`는 이번 단계에서 옮기거나 지우지 않는다 |
| 2 | 아카이브 README에 "정본은 `docs/file/`" 한 줄과 폐기 목록(3절) 링크 |
| 3 | 멀티버티컬 템플릿 문서 2개는 `archive/astro-ai-plan/멀티버티컬_템플릿/`에 보류 표시 |
| 4 | 키 재발급: 두 원본에 코드·`.env`가 없어 해당 없음. 원본 문서의 도메인(`shinbiroune.ai`, `AA/공통/GEO.md:133`)과 운영자 이메일은 사용 전 소유 확인(미확인) |
| 5 | zip 중복: 해당 없음(두 원본에 zip 없음) |
| 6 | AS-06-031에서 위 체크리스트 완료를 PR로 기록 |

## 6. 인증 단계 복사 금지 (2026-10-14 추가, 확정 결정 22)

두 원본(Astro AI, FortuneDocs)에는 코드가 없어 쿠키 역할 Mock이나 콜백 구현이 없다(5절 4단계). 아래는 다른 원본에서 확인된 결함을 신규 구현에 들이지 않기 위한 행이다. 허용되는 Mock은 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 2장(로컬 시드 계정으로 실제 JWT를 받는 로그인)뿐이다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 쿠키 역할 Mock(`mock-auth.ts`, `mock-login`, `nomad_role`·`nomad_plan` 쿠키, `dev-user` 우회) | `D:/WorkSpace/platform/docs/products/nomad-blog/07_SOURCE_MIGRATION.md:88`, `D:/WorkSpace/platform/docs/products/nomad-commerce/07_SOURCE_MIGRATION.md:96` | 권한 위조, 프로덕션 노출 | `AUTH_ROADMAP.md` 2장 로컬 시드 계정 Mock(`isMockAuthAllowed()`, 배포 환경 404), 권한은 `session_context`만 |
| 콜백 `next` 무검증 리다이렉트 | `AUTH_ROADMAP.md` 3.2절 5번, `docs/file/03-설계/공용코어/SECURITY_BASELINE.md` 17장 | 오픈 리다이렉트, 피싱 | `/`로 시작하고 `//`·`@`·`\` 없는 경로만, origin 고정(04장 8절) |
| 기능 코드의 `if (mock)`·`AUTH_MODE` 분기, 페르소나 이메일로 권한 분기 | `AUTH_ROADMAP.md` 0장 불변 조건, 2.5절 | Mock과 실제 로그인의 동작이 갈려 Mock 단계 검증이 무의미해진다 | 분기는 `src/lib/auth/`·로그인 화면·콜백에만(AS-06-032 CI 검사) |
| 환영 크레딧을 가입 트리거나 제공자별 코드에서 지급 | 01장 AS-F-002, D-3 | 인증 전 지급으로 반복 수령, 제공자마다 규칙이 갈림 | 인증 확인 뒤 서버 함수 1개(`src/server/welcome-credits.ts`, 멱등 키 `signup:<org>:astro`)를 이메일·Google·카카오·네이버가 함께 쓴다 |
