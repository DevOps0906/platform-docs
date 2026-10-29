# COMMON_MODULES_ROADMAP: 공용 비즈니스 모듈 확장 제안 (검토용)

작성일 2026-10-15. 상태: **제안**(대표님 결정 전). 지금의 공용 코어(`SHARED_MODULES.md` 1~20장: 인증, 조직, 크레딧, 결제, 잡, 저장소, 감사, AI 계층, 음성, 로그인 단계)는 "플랫폼 기반"입니다. 이 문서는 그 위에 여러 제품이 같이 쓸 **업무 기능 모듈**(리드·퍼널, CRM, LMS, 예약·ERP, 구글 시트 연동, 공용 챗봇)과 꼭 있어야 할 기반 모듈(알림, 분석, 운영 콘솔 등)을 제안합니다. 결정되면 각 모듈을 `SHARED_MODULES.md`에 장으로 올리고, 제품별 `06_AGENT_PLAN.md` 공용 모듈 요청에 반영합니다.

## 0. 요약과 추천안

| 순위 | 모듈 | 한 줄 | 쓰는 제품(지금 기획 기준) | 시작 시점 |
|---|---|---|---|---|
| 1 | **notify** 알림 | 이메일·카카오 알림톡·SMS·인앱을 한 함수로. 템플릿, 수신 동의, 발송 기록 | 12개 제품이 각자 알림을 적어 둠 | 공용 코어 직후(필수) |
| 2 | **funnel** 리드·폼·퍼널 | 폼 → 리드 저장 → 자동 응답 → 담당자 알림 → CRM 넘김, UTM 출처 추적 | website-floria 문의 폼, microweb-studio 문의, arch-studio 사전예약, 전 제품 랜딩 | 1차 |
| 3 | **chat-widget** Dify 공용 챗봇 | 로그인 어시스턴트·방문자 상담·리드 수집 상담 3가지 모드를 위젯 1개로 | AI 계층을 쓰는 전 제품 | 1차 |
| 4 | **sheets-sync** 구글 시트 연동 | 리드·주문·출석을 고객 시트로 내보내기, 시트를 가격표·FAQ 원본으로 읽기 | funnel, crm, admin-suite, microweb-studio | 1차(내보내기만) |
| 5 | **analytics** 이벤트·전환 분석 | 제품 이벤트, 퍼널 전환, 광고 출처를 한 규격으로 | 랜딩이 있는 11개 제품 | 1차(외부 도구 연결만) |
| 6 | **crm** | 연락처·회사·거래 파이프라인·활동·할 일 | nomad-docs(CRM형 워크스페이스), microweb-studio(제작 주문), website-floria, arch-studio | 2차 |
| 7 | **ops-console** 운영 콘솔 | 사용자 조회, 크레딧 조정, 환불, 잡 재실행, 감사 열람 | 13개 제품이 각자 `/admin` 화면을 기획 | 2차 |
| 8 | **support** 문의함 | 폼·챗봇 이관·이메일 문의를 티켓으로, 담당자 배정 | funnel, chat-widget과 묶음 | 2차 |
| 9 | **lms** | 강좌·차시·수강·진도·퀴즈·수료증·드립 공개 | study-note, flora-publishing(강의·멤버십 확장), 바이브코딩 교육 | 3차 |
| 10 | **booking** 예약·자원 | 자원·가용 시간·예약(중복 금지)·리마인더·예약금 | admin-suite hms(병원 자체 구현), arch-studio 상담, microweb·website-floria 상담 | 3차 |
| 11 | **growth** 실험·쿠폰·추천 | 기능 플래그, A/B 실험, 쿠폰, 추천 코드 | flora 헤드라인 실험(PB-06-063), 결제 있는 제품 | 4차 |
| 12 | **cms** 콘텐츠 블록 | 공지·FAQ·블로그·랜딩 블록, SEO 메타, 사이트맵 | 랜딩이 있는 제품 | 4차 |
| 13 | **compliance** 법정 표기·동의·라벨 | 정책 문서 버전, 동의 기록, 사업자·법정 표기 프로필, 광고·AI 표시 라벨(privacy-center 흡수) | 15개 전부 | 1차 |
| 14 | **media** 미디어 라이브러리 | 업로드·크기별 사본·대체 텍스트·저작권·사용처 | 이미지를 쓰는 제품 9개 이상 | 1차 |
| 15 | **editorial** 콘텐츠 워크플로 | 초안 → 검토 → 승인 → 예약 게시, 수정 이력, AI 초안 사람 승인 | nomad-blog, local-news, flora·toon·website-floria 후보 | 3차 |
| 16 | **community** 댓글·방명록 | 댓글·방명록·신고·임시조치·금칙어 | microweb-studio, local-news, 후보 4개 | 4차 |
| 17 | **search** 한국어 검색 | 색인·필터·공개 범위 | local-news, nomad-docs 등 후보 5개 | 6차(local-news와 함께) |
| 18 | **membership** 최종 이용자·구독 | 고객사의 고객(독자·수강생), 등급, 정기 구독·후원, 페이월 | local-news, flora·study-note·toon 후보 | 6차(local-news와 함께) |
| 19 | **ads** 광고 | 슬롯·캠페인·소재 검수·노출 집계·외부망 태그 | local-news, live-poll·toon·nomad-blog 후보 | 6차(local-news와 함께) |
| - | ERP | 범용 ERP 모듈은 만들지 않음(4.8절). admin-suite ERP를 제품으로 쓰고, 필요한 조각은 booking + 결제(코어)로 | - | 보류 |

13~19번은 local-news 기획에서 꺼낸 모듈이다(2026-10-15 추가, 대표님 승인 범위: 7개 전부, 각 제품 문서는 적용표만). 기획서는 `common-modules/` 폴더, 개발서는 `docs/develop/_shared/modules/`, 15개 제품 적용표는 `common-modules/README.md` 1장.

**추천안**: 개발 전에 노코드로 리드·챗봇·시트 흐름을 1~2주 검증하고(5장 Phase 0), 결과가 나오면 **notify → funnel → chat-widget → sheets-sync(내보내기)**를 flora-publishing과 함께 첫 묶음으로 만듭니다. 이 4개는 모든 제품의 매출 입구(문의·사전예약·상담)를 담당하고 재사용 제품 수가 가장 많습니다. CRM·LMS·예약은 각각 쓰는 제품이 실제 개발에 들어갈 때 그 제품 안에서 먼저 만들고 꺼냅니다("두 번째 제품이 쓸 때 공용화" 원칙). 이 모듈 묶음은 대표님의 NOMAD Funnel Engine 구상(패턴 A 인바운드 리드 + CRM, B 예약·자원·ERP, C 교육·LMS)과 그대로 겹치므로, Funnel Engine을 이 모듈들의 첫 번째 "판매 제품"으로 삼는 것을 함께 권합니다(6장).

## 1. 문제

| 관찰 | 근거 | 생기는 일 |
|---|---|---|
| 알림을 12개 제품이 각자 적음 | `grep "알림" products/*/01_PRD.md` 12개 제품 | 이메일 제공자·알림톡 발신 프로필·수신 동의·발송 기록이 제품마다 달라진다 |
| 문의·리드·퍼널을 7개 제품이 언급 | website-floria(문의 폼 백엔드가 없던 원본), microweb-studio(문의 → 제작 주문 → 게시 추적), arch-studio(사전예약), nomad-docs(파이프라인 lead 단계), live-poll, stock-dashboard, sceneflow | 리드가 여러 테이블에 흩어지고 광고 출처(UTM)를 비교할 수 없다 |
| CRM형 화면을 2개 제품이 따로 설계 | nomad-docs DC-F-047(파이프라인 보드, 거래처 360, 활동 타임라인), admin-suite ERP 거래처 | 같은 연락처·활동 모델을 두 번 만든다 |
| 운영자 화면을 13개 제품이 각자 기획 | `products/*/03_SCREENS_UX.md`의 `/admin` 행 | 크레딧 조정·환불·감사 열람의 권한 규칙이 제품마다 어긋날 위험(보안) |
| 구글 시트 연동 기획 0건 | `grep "Google Sheets"` 결과 없음 | 고객이 가장 먼저 요구하는 "엑셀/시트로 받기"가 빠져 있다 |
| 챗봇 규격은 있으나 위젯·모드가 제품별 | `AI_ARCHITECTURE.md` 2~3장, `develop/_shared/dify/README.md` 5장 | 방문자 상담(website-floria)과 로그인 어시스턴트가 다른 UI·다른 흐름으로 만들어진다 |

## 2. 전략: 무엇을 공용으로 만들까

| 원칙 | 내용 |
|---|---|
| 두 번째 사용 때 공용화 | 처음 쓰는 제품 안 `src/modules/<모듈>/`에 만들고, 두 번째 제품이 쓸 때 패키지로 꺼낸다. 처음부터 범용으로 설계하지 않는다. 예외(제안 CMX-1): 13~19번은 계약을 먼저 정했으므로 첫 적용 제품이 처음부터 패키지로 만든다(MVP 범위는 그 제품이 쓰는 만큼) |
| 데이터 정본은 DB | 시트·HubSpot·Dify는 사본이거나 화면이다. 조직 데이터의 정본은 Supabase(RLS) |
| 같은 경계 규칙 | 모든 모듈은 `SHARED_MODULES.md` 18장(재정의 금지, service_role 서버만, 멱등 키, 실패 숨기기 금지)과 `SECURITY_BASELINE.md`를 따른다 |
| 외부 도구 우선 검토 | 분석(PostHog·GA4), 이메일 발송(Resend·SES), 알림톡(솔라피·NHN Cloud 등 비즈메시지 대행사)은 직접 만들지 않고 어댑터만 둔다 |
| 노코드로 먼저 검증 | n8n·Make·구글 시트·Tally·Dify 웹앱으로 흐름을 먼저 돌려 보고, 실제로 쓰이는 흐름만 코드로 옮긴다 |

평가 기준(5점 만점, 제안):

| 모듈 | 재사용 제품 수 | 매출 기여 | 개발 난이도(낮을수록 5) | 노코드 검증 쉬움 | 합계 |
|---|---|---|---|---|---|
| notify | 5 | 4 | 4 | 3 | 16 |
| funnel | 4 | 5 | 4 | 5 | 18 |
| chat-widget | 5 | 4 | 3 | 4 | 16 |
| sheets-sync | 3 | 3 | 4 | 5 | 15 |
| analytics | 5 | 4 | 5 | 4 | 18 |
| crm | 3 | 4 | 2 | 3 | 12 |
| ops-console | 5 | 2 | 3 | 1 | 11 |
| support | 3 | 3 | 3 | 3 | 12 |
| lms | 2 | 4 | 2 | 3 | 11 |
| booking | 3 | 3 | 3 | 3 | 12 |
| growth | 3 | 3 | 3 | 2 | 11 |
| cms | 3 | 2 | 3 | 4 | 12 |

analytics는 점수가 높지만 직접 만드는 부분이 얇아(외부 도구 + 이벤트 규격) 1차에 같이 넣습니다.

## 3. DB 배치 (제안)

모듈러 통합 DB에서 코어(`0000~0099`)와 제품(`1000~2599`) 사이의 빈 범위 `0100~0999`를 공용 비즈니스 모듈에 줍니다. 모놀리스 제품은 `MONOLITH_CORE_LITE.sql`처럼 쓰는 모듈만 `public`으로 변환해 넣습니다(`DB_CONVENTIONS.md` 12장 규칙).

| 범위 | 스키마 | 모듈 |
|---|---|---|
| 0100~0149 | `notify` | 알림 |
| 0150~0199 | `compliance` | 법정 표기·동의·라벨(2026-10-15 추가) |
| 0200~0249 | `funnel` | 리드·폼·퍼널 |
| 0250~0299 | `media` | 미디어(추가) |
| 0300~0349 | `crm` | CRM |
| 0350~0399 | `community` | 댓글·신고(추가) |
| 0400~0449 | `sync` | 외부 시트·연동 작업 |
| 0450~0499 | `search` | 검색(추가) |
| 0500~0549 | `lms` | 강좌·수강 |
| 0550~0599 | `membership` | 최종 이용자·구독(추가) |
| 0600~0649 | `booking` | 예약·자원 |
| 0650~0699 | `ads` | 광고(추가, local-news R-9 해결) |
| 0700~0749 | `support` | 문의함 |
| 0750~0799 | `editorial` | 콘텐츠 워크플로(추가) |
| 0800~0849 | `cms` | 콘텐츠 블록 |
| 0850~0899 | (예비) | - |
| 0900~0949 | `growth` | 플래그·실험·쿠폰·추천 |
| 0950~0999 | (예비) | - |

2026-10-15: 기존 100 단위 범위를 앞 50개로 줄이고 뒤 50개에 local-news 유래 모듈을 넣었다(조각 파일이 아직 없어 영향 없음, 제안 CMX-2). 의존 순서(media → editorial·community·ads)가 번호 순서와 맞는다.

`erp`는 이미 admin-suite가 `1600`에서 쓰므로 공용 모듈 이름으로 쓰지 않습니다. chat-widget, analytics, ops-console은 새 스키마 없이 코어 표(`ai_*`, `audit_log` 등)를 씁니다. 모든 모듈 표는 `org_id`·`app_id`를 갖고 코어 RLS 헬퍼(`is_org_member` 등)를 씁니다.

## 4. 모듈별 설계 요약

각 모듈은 MVP(1차에 만들 것)와 확장(나중)을 나눕니다. 표 이름은 제안입니다.

### 4.1 notify (알림, 필수)

| 항목 | 내용 |
|---|---|
| 목적 | 제품 코드가 `notify.send({ template, to, data, channel })` 하나만 부른다. 채널 선택·재시도·수신 동의·발송 기록은 모듈이 한다 |
| 채널 | 이메일(Resend 또는 Amazon SES, 제안), 카카오 알림톡(비즈메시지 대행사 경유, 발신 프로필·템플릿 사전 검수 필요), SMS(알림톡 실패 시 대체), 인앱(벨 아이콘), 웹 푸시(확장) |
| 표 | `notify.templates`(키, 채널별 본문, 버전, 알림톡 템플릿 코드), `notify.preferences`(사용자·채널·주제별 수신 동의), `notify.messages`(발송 기록, 상태, 제공자 메시지 id, 실패 사유), `notify.inbox`(인앱) |
| 흐름 | 요청 → 수신 동의 확인(광고성은 별도 동의, 야간 21~08시 광고 발송 금지 확인, 미확인: 법무 확인) → `core.jobs` 큐 `notify.send` → 제공자 호출 → 웹훅으로 도달 상태 갱신 |
| MVP | 이메일 + 알림톡 + 인앱, 템플릿 10개(가입 환영, 결제 완료, 결제 실패, 작업 완료, 초대, 리드 접수 확인, 담당자 새 리드 알림, 예약 확인·리마인더, 비밀번호 재설정은 Supabase 메일 유지) |
| 확장 | 웹 푸시, 요약 메일(일·주간), 발송 A/B |
| 실패 | 제공자 오류는 잡 재시도 3회 → `failed` + 운영 알림. 알림톡 실패 시 SMS 대체는 템플릿에 명시한 경우만 |
| 위험 | 알림톡은 템플릿 검수에 시간이 걸린다. 광고성 메시지 규정(정보통신망법)은 법무 확인 전 "정보성"만 보낸다 |

### 4.2 funnel (리드·폼·퍼널)

| 항목 | 내용 |
|---|---|
| 목적 | 랜딩 → 폼(또는 챗봇) → 리드 → 자동 응답·리드 마그넷 전달 → 담당자 알림 → CRM. 모든 제품의 매출 입구 |
| 표 | `funnel.forms`(필드 정의 JSON, 동의 문구 버전, 스팸 방지 설정), `funnel.submissions`(원본 제출, IP 해시), `funnel.leads`(연락처, 동의 기록, 상태 new·contacted·qualified·won·lost, 점수), `funnel.touches`(UTM source·medium·campaign·content·term, referrer, 랜딩 경로, 첫·마지막 접점), `funnel.sequences`(자동 응답 단계, notify 템플릿 연결) |
| 화면 | 폼 빌더(필드 끌어놓기, 미리보기), 리드 목록(B 패턴), 리드 상세(G 패턴), 퍼널 보드(D 패턴: 단계별 칸반), 출처 리포트(L 패턴) — 패턴 코드는 `docs/design-module/_design-guide/DASHBOARD_PATTERNS.md` |
| 공개 API | `POST /api/funnel/submit`(로그인 없음, 레이트 리밋 `anon:<app>:<ip 해시>`, 허니팟·Turnstile, 동의 체크 필수), 임베드 스크립트(`<script>` 1줄로 외부 사이트 폼) |
| 연결 | notify(자동 응답·담당자 알림), sheets-sync(시트로 내보내기), crm(qualified 리드 → 연락처·거래), analytics(전환 이벤트), chat-widget(대화 중 리드 수집) |
| MVP | 폼 1종(이름·연락처·문의), 리드 목록·상세, UTM 저장, 자동 응답 메일 1개, 담당자 알림톡, 시트 내보내기 |
| 확장 | 다단계 폼, 리드 점수 규칙, 드립 시퀀스, 리드 마그넷(전자책 PDF 자동 발송: flora 렌더와 연결), 웨비나 등록 |
| 개인정보 | 수집 목적·보관 기간·제3자 제공 여부를 폼마다 표시하고 동의 문구 버전을 리드에 저장. 미동의 제출은 저장하지 않는다 |

### 4.3 chat-widget (Dify 공용 챗봇)

규격은 이미 `AI_ARCHITECTURE.md` 2~3장(대화 매핑, 서명 토큰, 방문자 쿠키)과 `docs/develop/_shared/dify/README.md`(제품별 Chatflow)에 있습니다. 공용 모듈로 더할 것은 **화면 위젯 1개, 모드 3개, Dify 앱 템플릿, 리드·상담 이관 연결**입니다.

| 모드 | 누가 | 지식 | 결과 | 쓰는 제품 |
|---|---|---|---|---|
| assistant | 로그인 사용자 | 조직 RAG(FastAPI), 제품 기능 도움말 | 답변 + 출처, 제품 화면 이동 링크 | AI 계층을 쓰는 전 제품 |
| visitor | 비로그인 방문자 | 제품 공통 FAQ·요금·이용 안내(Dify 외부 지식 API, 조직 데이터 없음) | 답변, 가입·체험 유도 | 랜딩이 있는 제품, website-floria 방문자 상담 |
| lead | 비로그인 방문자 | visitor + 상담 시나리오 | 대화 중 "상담 신청" 의도면 위젯이 **구조화된 폼**(이름·연락처·동의)을 띄워 `funnel.submit`으로 저장, 사람 상담 요청이면 support 티켓 | website-floria, microweb-studio, arch-studio, Funnel Engine |

| 구성 | 내용 |
|---|---|
| `@nomad/chat-widget` | React 위젯: 런처 버튼, 패널(375px에서 전체 화면 시트), 스트리밍(POST + ReadableStream), 출처 칩, 좋아요·싫어요 피드백, 상담원 연결 버튼, 한도·오류 상태(403·429·503), 접근성(`aria-live`). 디자인 토큰만 사용 |
| 서버 | 기존 ai-gateway `/api/ai/chat` 재사용. 모드는 서버가 정한다(클라이언트 값 무시): 로그인 세션이면 assistant, 방문자 쿠키면 visitor·lead |
| Dify 앱 템플릿 | `dify-templates/assistant.yml`, `visitor.yml`, `lead.yml` 공통 골격(시작 → 질문 분류 → HTTP 요청 노드 `/tools/answer` → 응답). 제품은 앱 이름·안내 문구·FAQ 지식 연결만 바꾼다. DSL에 키를 넣지 않는다 |
| 리드 수집 원칙 | LLM이 연락처를 대화에서 뽑아 저장하지 않는다. 의도 신호(`intent=lead_capture`)만 응답에 싣고, 저장은 사용자가 위젯 폼에서 직접 입력·동의한 값만(개인정보 동의 명확성) |
| 비용 통제 | 방문자 모드는 운영자 조직 예산, `rate_limit_hit`(IP 해시·방문자 키), 대화당 턴 상한, 오픈소스 모델 우선 라우팅(`AI_ARCHITECTURE.md` 7장) |
| 운영 | Dify 로그 보존 30일, 싫어요 피드백 → 주간 FAQ 개선 목록, 평가셋 30문항(금지 문구·범위 밖 질문) |
| 하지 않는 것 | Dify 기본 웹 임베드(iframe·공개 앱 토큰)를 운영에 쓰지 않는다. 브라우저가 Dify를 직접 부르게 되기 때문이다. 단, 5장 Phase 0 노코드 검증에서 조직 데이터 없는 FAQ 챗봇으로만 잠깐 쓴다 |

### 4.4 sheets-sync (구글 시트 연동)

| 항목 | 내용 |
|---|---|
| 용도 | (1) 내보내기: 리드·주문·출석·예약을 고객이 지정한 시트에 한 행씩 추가(가장 많이 요구됨) (2) 읽기: 운영자가 시트로 관리하는 가격표·FAQ·상품 목록을 주기적으로 가져오기 (3) 일괄 가져오기: 초기 데이터 이전 |
| 원칙 | DB가 정본, 시트는 사본. 1차는 단방향(DB → 시트)만. 양방향은 충돌 규칙이 필요해 확장으로 미룬다 |
| 인증 방식 비교 | (a) 사용자 OAuth + `drive.file` 범위(앱이 만들었거나 사용자가 고른 파일만, **비민감 범위라 기본 확인만**) (b) 사용자 OAuth + `spreadsheets` 범위(모든 시트, **민감 범위라 추가 검증**) (c) 서비스 계정 + 사용자가 시트를 서비스 계정 이메일에 공유 (d) n8n·Make 시나리오 |
| 권고 | 고객용은 **(a) `drive.file` + Google Picker로 시트 선택**. 운영자 내부용은 (c). 로그인용 Google 클라이언트와 시트 연동용 클라이언트는 나눈다(로그인 동의 화면을 기본 범위로 유지, sceneflow의 채널 연동 분리와 같은 이유) |
| 저장 | 연동 토큰은 코어 oauth 모듈(`create/consume_oauth_state`, `encrypted_credentials`, `SHARED_MODULES.md` 7장)에 암호화 저장 |
| 표 | `sync.connections`(조직, 대상 시트 id, 시트 탭, 열 매핑, 자격증명 id), `sync.runs`(실행 기록, 행 수, 오류) |
| 실행 | 이벤트(리드 생성 등) → `core.jobs` 큐 `sync.sheets` → 묶어서 `spreadsheets.values.append`. 한도: 프로젝트당 분당 읽기·쓰기 각 300회, 사용자당 분당 60회, 요청 180초 제한, 권장 페이로드 2MB 이하. 429면 지수 백오프(최대 32~64초) 후 재시도 |
| 화면 | 설정 → 연동 → 구글 시트: 연결, 시트 선택, 열 매핑 미리보기, 마지막 동기화·오류 |
| 근거 | [Sheets API 사용 한도](https://developers.google.com/workspace/sheets/api/limits), [Sheets API 범위](https://developers.google.com/workspace/sheets/api/scopes), [values.append](https://developers.google.com/workspace/sheets/api/reference/rest/v4/spreadsheets.values/append)(세 문서 모두 2026-10-15 열람 확인) |
| 확장 | 양방향(시트 수정 → DB, 행 id 열 + 수정 시각 비교), 엑셀 파일 내보내기, Airtable·Notion 어댑터 |

### 4.5 analytics (이벤트·전환 분석)

| 항목 | 내용 |
|---|---|
| 방식 | 직접 만들지 않는다. 외부 도구(PostHog 또는 GA4, 결정 M-D3) + 얇은 래퍼 `@nomad/analytics` |
| 이벤트 규격 | `<영역>.<대상>.<동작>`(예: `funnel.form.submitted`, `auth.signup.completed`, `billing.checkout.succeeded`). 공통 속성 `app_id`, `org_id`(해시), `plan_code`, UTM |
| 서버 이벤트 | 결제·가입 같은 핵심 전환은 클라이언트가 아니라 서버에서 보낸다(광고 차단기 영향 없음) |
| 개인정보 | 이메일·이름을 이벤트에 넣지 않는다. 쿠키 동의 배너(제안)와 함께 |
| 연결 | funnel의 `touches`와 같은 UTM 규칙으로 광고 성과 → 리드 → 매출을 잇는다 |

### 4.6 crm

| 항목 | 내용 |
|---|---|
| 기준 구현 | nomad-docs DC-F-047(파이프라인 보드, 거래처 360, 활동 타임라인, 커맨드 팔레트)을 먼저 만들고 꺼낸다 |
| 표 | `crm.contacts`, `crm.companies`, `crm.deals`(파이프라인·단계·금액·예상 마감), `crm.pipelines`(조직별 단계 정의), `crm.activities`(메모·통화·메일·미팅, 타임라인), `crm.tasks`, `crm.tags`, `crm.custom_fields`(조직별 필드 정의, 값은 jsonb + 정의 검증) |
| 화면 | 연락처 목록(B), 상세 360(G), 파이프라인(D), 내 할 일, 저장된 보기 |
| 연결 | funnel(qualified 리드 → 연락처+거래), notify(할 일 알림), sheets-sync, HubSpot 어댑터(nomad-docs 기존 계획) |
| MVP | 연락처·거래·활동·파이프라인 1개 |
| 확장 | 메일 연동(받은 편지함 연결), 자동화 규칙(단계 이동 시 알림), 견적서(nomad-docs 문서 생성과 연결) |

### 4.7 lms

| 항목 | 내용 |
|---|---|
| 기준 구현 | study-note(수강생·강사, 강의 필기·교재)와 flora-publishing의 "전자책 → 강의·멤버십" 확장 |
| 표 | `lms.courses`, `lms.modules`, `lms.lessons`(영상·글·PDF·퀴즈), `lms.enrollments`(결제·초대·무료), `lms.progress`(차시별 완료·시청 위치), `lms.quizzes`·`lms.attempts`, `lms.certificates`(수료증 PDF는 공용 WeasyPrint 렌더), `lms.cohorts`(기수, 드립 공개 일정) |
| 결제 | 코어 Toss + 엔타이틀먼트(강좌 단위 권한). 크레딧과 섞지 않는다 |
| AI | study-note 위키·RAG를 강좌 자료에 적용(강좌별 컬렉션), 질문 챗봇은 chat-widget assistant 모드 |
| 영상 | 직접 스트리밍하지 않는다. 외부 호스팅(Vimeo·Cloudflare Stream·Mux 등, 결정 M-D4) 서명 URL만 |
| 사업 연결 | 바이브코딩 교육 과정, 정부지원 교육사업 운영(출석·수료 기록이 증빙이 된다) |

### 4.8 ERP는 어떻게 할까

| 선택지 | 장점 | 단점 | 판단 |
|---|---|---|---|
| (a) 범용 ERP 공용 모듈 | 모든 제품에 재고·주문·회계 | 범위가 끝없이 커지고 쓰는 제품이 적다 | 권하지 않음 |
| (b) admin-suite ERP를 제품으로 판매·사용 | 이미 기획·SQL 완료(`1600_erp.sql`) | 다른 제품에 바로 붙이기 어렵다 | **기본** |
| (c) 필요한 조각만 공용: booking(4.9) + 주문·청구(코어 Toss `payment_orders`) + 재고 차감 RPC 패턴 | 작고 재사용 가능 | 회계·세무는 없음 | **함께 권고** |

Funnel Engine 패턴 B(예약·자원·ERP)도 (c)로 충분합니다. 회계·세금계산서는 외부 서비스 연동(확장)으로 둡니다.

### 4.9 booking (예약·자원)

| 항목 | 내용 |
|---|---|
| 표 | `booking.resources`(사람·방·장비), `booking.availability`(요일·시간 규칙, 예외일), `booking.bookings`(자원, `tstzrange`, 상태), `booking.holds`(결제 대기 임시 점유 10분) |
| 핵심 규칙 | 같은 자원의 겹치는 예약은 DB 제약으로 막는다(`btree_gist` + `exclude using gist (resource_id with =, during with &&)`, KST 경계는 서버 계산) |
| 연결 | notify(확인·전날 리마인더·노쇼), 결제(예약금), funnel(상담 예약 폼), 캘린더 내보내기(ICS, Google Calendar는 확장) |
| 쓰는 곳 | arch-studio 건축주 상담, microweb·website-floria 상담, Funnel Engine B. admin-suite hms는 의료정보 격리 때문에 자체 구현 유지(같은 설계 규칙만 공유) |

### 4.10 기반 모듈 추가 추천

| 모듈 | 왜 필수인가 | MVP |
|---|---|---|
| ops-console | 13개 제품이 운영자 화면을 따로 만들면 크레딧 조정·환불·원고 열람 같은 위험한 권한이 제품마다 달라진다. flora 운영 콘솔(PB-06-062: `platform_admin`만, 조회마다 감사, 원가 필드는 운영자 API에만)을 기준으로 꺼낸다 | 사용자 조회, 조직·엔타이틀먼트, 크레딧 조정(감사 필수), 잡 재실행, 감사 열람 |
| support | 폼 문의·챗봇 이관·이메일 문의가 한곳에 모여야 응답 누락이 없다 | 티켓, 담당자 배정, 상태, 메모, 답장(notify) |
| privacy-center(→ compliance로 흡수, 2026-10-15) | 개인정보 열람·정정·삭제 요청, 마케팅 수신 동의 관리, 탈퇴 시 데이터 처리를 제품마다 다르게 만들면 법적 위험 | 동의 이력 화면, 탈퇴 요청 → `purge_organization` 흐름, 데이터 내보내기(JSON·CSV) |
| growth | 가격·헤드라인 실험과 쿠폰은 매출에 바로 영향 | 기능 플래그, 쿠폰 코드(Toss 금액 차감), 추천 코드(코어 affiliate와 연결) |
| cms | 공지·FAQ·블로그를 배포 없이 고치려면 필요. 챗봇 visitor 모드의 FAQ 원본으로도 쓴다 | 공지·FAQ·페이지, SEO 메타, 사이트맵 |
| multi-tenant theming | 화이트라벨(고객사 로고·색에 맞춰 플랫폼을 바꾸는 맞춤 개발)은 이미 공용 기준으로 두기로 정했다. 위 모듈의 화면이 모두 디자인 토큰만 쓰면 그대로 적용된다 | 테마 토큰 세트, 조직별 로고·도메인 |
| i18n | 4개 제품이 다국어를 언급 | 메시지 파일 규격, 날짜·통화 형식(낮은 우선순위) |

### 4.11 local-news에서 꺼낸 모듈과 기존 모듈 보강 (2026-10-15)

신규 7개는 모듈별 기획서가 정본이다: [compliance](common-modules/compliance.md), [media](common-modules/media.md), [editorial](common-modules/editorial.md), [community](common-modules/community.md), [search](common-modules/search.md), [membership](common-modules/membership.md), [ads](common-modules/ads.md). 기존 모듈 4개는 local-news 설계로 아래를 보강한다.

| 기존 모듈 | local-news에서 더하는 것 | 출처 |
|---|---|---|
| notify | (1) 뉴스레터 목록·이중 동의 구독(확인 메일, 동의 증빙은 compliance `consents`) (2) 발송 회차(issue: 본문, 대상 목록, 예약, 발송 통계 오픈·클릭) (3) 웹 푸시 구독(VAPID, 브라우저별 endpoint, 만료 정리) (4) 한 번 클릭 수신 거부(`List-Unsubscribe`, `List-Unsubscribe-Post` 헤더) (5) 광고성 메일 제목 `(광고)` 표기·야간 발송 금지는 compliance `has_consent`·라벨로 판정. 표 추가: `notify.lists`, `notify.list_subscriptions`, `notify.issues`, `notify.push_subscriptions` | local-news M4(`newsletter_lists`, `newsletter_subscriptions`, `newsletter_issues`, `push_subscriptions`), 요청 R-8 |
| analytics | 콘텐츠 이벤트 규격 추가: `content.entry.viewed`(서버 수집, editorial 조회 집계와 같은 봇 필터), `ads.creative.impressed`·`.clicked`(ads 집계와 별도로 외부 도구 전송은 선택), 지원사업·광고주 리포트용 내보내기(CSV) 패턴 | local-news M8 |
| cms | (1) 블록 본문 JSON 규격(문단·소제목·사진(media id)·인용·표·임베드·구분선)을 editorial과 공유, 블록 렌더러는 cms가 소유 (2) SEO 생성기: 일반 사이트맵, RSS 2.0, JSON-LD(Article·BreadcrumbList·Organization), OG 이미지(media `og_1200x630`), canonical (3) 테넌트별 `robots.txt`와 AI 크롤러 허용·차단 설정 | local-news M1(블록 에디터)·M6(배포·SEO). 뉴스 사이트맵·NewsArticle·포털 전송은 local-news에 남김 |
| tenancy(Multi-tenant Theming) | (1) **최종 이용자와 조직 멤버 분리**: 고객사의 고객은 membership `end_users`, 조직 멤버로 넣지 않는다 (2) 테넌트 커스텀 도메인 활성화 때 로그인 Redirect URL 개별 등록 잡(와일드카드는 플랫폼 소유 서브도메인만) (3) 해석 실패·비활성 도메인은 플랫폼 브랜드로 콘텐츠를 보이지 않는 오류 화면 (4) 공개 콘텐츠는 anon 키 서버 클라이언트로 읽어 ISR 캐시 공유 | local-news 02장 10절, 07장 6절, 요청 R-4 |

## 5. 실행 로드맵 (린 순서)

| Phase | 기간(제안) | 할 일 | 끝나는 조건 |
|---|---|---|---|
| 0 노코드 검증 | 1~2주, 개발 0 | 전자책 리드 마그넷 랜딩 1개: 폼(Tally 또는 구글 폼) → 구글 시트 → n8n → 자동 응답 메일·알림톡 → 담당자 알림. Dify 웹앱으로 FAQ 챗봇(조직 데이터 없음). UTM 붙인 광고·SNS 유입 | 리드 50건, 출처별 전환율, 챗봇 질문 상위 20개 |
| 1 입구 모듈 | flora 개발과 함께 | notify v1, funnel v1, chat-widget v1(assistant·visitor), sheets-sync v1(내보내기), analytics 래퍼 | flora 랜딩·온보딩에서 동작, 두 번째 제품(website-floria 또는 microweb)이 패키지로 적용 |
| 2 관리 모듈 | nomad-docs 개발과 함께 | crm v1, support v1, ops-console v1, chat-widget lead 모드 | 리드 → 거래 → 계약 흐름, 운영 콘솔 2개 제품 적용 |
| 3 교육·예약 | study-note·arch-studio 개발과 함께 | lms v1, booking v1 | 강좌 판매 1건, 상담 예약 1건 |
| 4 성장 | 출시 후 | growth, cms, privacy-center 확장, sheets 양방향 | 실험 1건 결과 |

local-news 유래 7개의 차례: compliance는 Phase 1(website-floria·study-note와 함께), media는 flora-publishing과, editorial은 nomad-blog와, community는 microweb-studio와, search·membership·ads는 local-news(또는 먼저 채택한 제품)와 함께 만든다(`docs/develop/_shared/modules/README.md` 3장).

Phase 0은 지금 바로 할 수 있고, 그 결과가 Phase 1의 필드·템플릿·문구를 정합니다.

## 6. 수익화와 확장

| 기회 | 내용 |
|---|---|
| NOMAD Funnel Engine을 첫 판매 제품으로 | 패턴 A(funnel + crm + notify + chat-widget lead), B(booking + 결제), C(lms)가 위 모듈의 조합이다. 업종 스킨(테마)만 바꿔 소상공인·학원·클리닉에 구독형으로 판다. 웹/앱 에이전시 사업의 납품 기본 패키지로도 쓴다 |
| 에이전시 납품 단가 | 웹사이트 납품에 "문의 폼 + 리드 시트 + 알림톡 + 상담 챗봇"을 옵션 상품으로 묶는다(가격은 `Price_Plans/`에서 정함) |
| 콘텐츠·교육 | "공용 모듈로 SaaS 14개를 만드는 법" 강의·전자책(바이브코딩 커리큘럼과 연결). lms 모듈의 첫 고객이 된다 |
| 정부지원사업 | 공용 모듈 구조(재사용률, 개발 기간 단축)를 사업계획서의 기술 차별성 근거로 쓴다. 지원 사업명·요건은 공고마다 다르므로 신청 시 확인 |
| AI 에이전트 | chat-widget lead 모드 + crm + notify가 "상담 → 견적 → 예약 → 후속 연락"을 자동으로 처리하는 영업 에이전트의 기반이 된다 |

## 7. 결정 필요

| ID | 결정 | 선택지 | 권고 |
|---|---|---|---|
| M-D1 | 이 로드맵 채택 범위 | (a) 1차 4개(notify, funnel, chat-widget, sheets-sync) + analytics만 확정 (b) 12개 전부 확정 | (a). 나머지는 쓰는 제품이 생길 때 결정 |
| M-D2 | 공용 모듈 배포 방식 | 인증 모듈과 같게(`develop/_shared/auth/README.md` AUTH-D2) | 비공개 npm(GitHub Packages) `@nomad/<모듈>` |
| M-D3 | 분석 도구 | PostHog(제품 분석·퍼널·세션 기록) / GA4(광고 연동) / 둘 다 | PostHog 주, GA4는 광고 전환용 최소 연결(제안, 요금은 구현 시 확인) |
| M-D4 | LMS 영상 호스팅 | Vimeo / Cloudflare Stream / Mux / YouTube 비공개 | lms 착수 때 비용·DRM 비교 |
| M-D5 | 알림톡 대행사 | 솔라피 / NHN Cloud / 기타 | notify 착수 때 단가·API 비교(미확인) |
| M-D6 | 시트 연동 범위 | `drive.file`(권고) / `spreadsheets` | `drive.file` |
| M-D7 | local-news 유래 7개 관련 결정 | CMX-1(공용화 시점), CMX-2(번호 재배정), CMX-3(검색 엔진), CMX-4(최종 이용자 결제 수취) | `common-modules/README.md` 6장 |

## 8. 채택되면 반영할 곳

| 문서 | 반영 |
|---|---|
| `SHARED_MODULES.md` | 채택한 모듈마다 장 추가(소유·소비·인터페이스·코어 SQL·실패 동작) |
| `DB_CONVENTIONS.md` 2장 | 3장의 번호 범위 |
| `_supabase-modular/migrations/` | `0100_notify.sql` 등 조각, 모놀리스 변환 |
| 각 제품 `06_AGENT_PLAN.md` | 공용 모듈 요청 표에 소비 행, 기준 구현 제품은 작업 행 |
| `docs/develop/_shared/` | 모듈별 설치·운영 지시서(인증 지시서와 같은 형식) |
| `Price_Plans/` | 모듈 기반 옵션 상품 가격 |
