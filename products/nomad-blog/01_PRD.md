# 01 PRD: NOMAD Blog

작성일 2026-10-12. 근거 표기는 `상대경로:줄번호`다. YSM 스냅샷 파일은 `[5f6d262] Youtube_shots_Maker/<경로>:줄`로 적는다(`git show 5f6d262:Youtube_shots_Maker/<경로>`). "제안"은 원본 문서·리뷰에 근거가 없어 이 문서가 정한 값이고, "미확인"은 외부 사실을 확인하지 않은 것이다.

2026-10-13 개정: 확정 결정 13~17(`docs/products/00_MERGE_ANALYSIS.md:21-25`)에 따라 AI 계층(브랜드·상품·제휴 캠페인 자료 RAG, 토픽·키워드 위키, LangGraph `blog.post_draft`, Dify 글쓰기 도우미 채팅), 음성(받아쓰기 초안, 음성 대화), 상용/오픈소스 모델 이원화와 국외 이전 동의, 3D 히어로를 MVP에 넣었다. 설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `docs/products/_design-guide/HERO_3D.md`, `DESIGN_SYSTEM.md`이고 이 문서는 제품 요구만 정한다. 네이버 브랜드커넥트 완전 자동 지원과 위험 동의(BL-F-030~035, 6.4절), 제휴 대가성 문구 규칙(BL-F-024, 6.3절)은 확정 결정 12 그대로이며 AI 계층이 약화하거나 우회하지 않는다. 새 기능 ID는 BL-F-051~061, 새 열린 결정은 D-13~D-20이다(기존 8절 #1~#12는 D-1~D-12와 같다).

## 1. 페르소나와 핵심 과제

| 페르소나 | 상황 | 목표 | 좌절 |
|---|---|---|---|
| 김지현(34, 직장인 부업 블로거) | 네이버 블로그 1개, 쿠팡파트너스 가입 3개월. 퇴근 후 1시간 안에 글 1편을 쓰려 한다 | 하루 1편을 꾸준히 올려 제휴 수익을 만든다 | 원고에 1~2시간이 걸리고, 대가성 문구를 빠뜨려 신고를 받을까 불안하다. 쿠팡 링크가 네이버에서 불이익을 받는다는 말을 듣고 어떻게 넣어야 할지 모른다 |
| 박성훈(41, 제휴 마케터) | 네이버·티스토리·워드프레스 블로그 3개와 계정 여러 개를 운영. 브랜드커넥트 캠페인에 매주 지원한다 | 같은 주제를 채널별로 나눠 예약 발행하고, 캠페인 지원을 자동화한다 | 채널마다 에디터에 복붙하고 태그를 다시 넣는다. 캠페인 공고를 매일 확인해 지원서를 손으로 쓴다 |
| 이수아(29, 1인 브랜드 운영자) | 자체 워드프레스 블로그에 정보성 글을 쌓아 검색 유입을 늘리려 한다 | SEO 기준을 맞춘 정보성 글을 주 3편 발행한다 | 키워드를 고르는 기준이 없고, 글이 광고처럼 보일까 걱정한다 |

| 핵심 과제 | 설명 |
|---|---|
| J1. 키워드에서 발행까지 15분 | 키워드 추천 → 원고 생성 → 편집 → 검사 → 발행을 한 화면 흐름으로 끝낸다 |
| J2. 법적으로 안전한 제휴 글 | 제휴 링크나 스폰서가 있는 글에는 대가성 문구가 반드시 글 상단에 들어간다. 사용자가 끌 수 없다 |
| J3. 여러 채널을 한 번에 | 하나의 원고를 여러 채널 계정에 즉시 또는 예약 발행하고, 결과를 한 곳에서 본다 |

## 2. 범위: MVP와 Phase

확정 결정 7은 blog의 MVP를 따로 정하지 않았다(`docs/products/00_MERGE_ANALYSIS.md:15`). 아래 범위는 확정 결정 1, 12와 분석 H절(`:626-633`)을 기준으로 한 제안이다.

| 기능 | 범위 | 근거 |
|---|---|---|
| 가입, 조직, 플랜, 크레딧, Toss 구독·크레딧팩 | MVP | 확정 결정 4, 5, `CORE_SPEC.md` 2~5장 |
| 키워드 추천, 제목 3안, 원고 생성(템플릿 5종, 빠름/고품질), 구간 다시쓰기, 태그 추천, SEO 점수 | MVP | `docs/products/00_MERGE_ANALYSIS.md:628-629` |
| TipTap 에디터(자동 저장, 미리보기, sanitize) | MVP | `:633` |
| 제휴 상품 검색·카드 삽입(쿠팡), 링크 수동 등록(텐핑, 네이버쇼핑 커넥트), 자동 추천 삽입 | MVP | 확정 결정 12 |
| 대가성 문구 자동 삽입(끌 수 없음) | MVP | 확정 결정 12 |
| 채널 연결과 발행: 네이버 블로그, 티스토리(Playwright), 워드프레스(REST) | MVP | 확정 결정 1, `:630-631` |
| 예약 발행과 캘린더 | MVP | `NOMAD Shorts Maker/src/lib/plans.ts:49`(Pro "스케줄 자동 발행") |
| 컴플라이언스 게이트(규칙 + LLM) | MVP | `SHARED_MODULES.md` 13장(blog는 발행 전) |
| 브랜드커넥트: 계정 연결, 위험 고지·동의, 캠페인 탐색, 지원서 자동 제출, 상태 동기화 | MVP | 확정 결정 12 |
| 제휴 클릭 통계 | MVP | 확정 결정 1(클릭 통계는 affiliate 모듈) |
| 인스타그램 카드 포스팅 | Phase 2 | `docs/products/00_MERGE_ANALYSIS.md:632`(Meta 업로더로 일원화, 업로더는 video 소유) |
| 반복 발행 시리즈(cron 표현식) | Phase 2 | `NOMAD Shorts Maker/src/skill/schedule-engine/cron-handler.ts:10-41` |
| 브랜드커넥트 무인 자동 지원 규칙(키워드·카테고리 조건으로 사람 확인 없이 지원) | Phase 2 | 확정 결정 12의 "완전 자동"을 단계적으로 연다(제안: 1단계에서 제출 성공률을 먼저 확인) |
| n8n/Make 브릿지, 발신 웹훅 | Phase 2 (Business) | `NOMAD Shorts Maker/src/lib/plans.ts:65`, `SHARED_MODULES.md` 12장 |
| AI 대표 이미지 생성(fal) | Phase 2 | 제안 |
| 외부 API 키 발급 | Phase 3 | `NOMAD Shorts Maker/src/lib/plans.ts:67` |
| 브랜드·상품·제휴 캠페인 자료 RAG(조직 컬렉션 `blog-materials`) | MVP | 확정 결정 13(`docs/products/00_MERGE_ANALYSIS.md:21`) |
| 토픽·키워드 위키(조직 제품 지식 위키) | MVP | 확정 결정 13, `docs/products/_platform-core/LLM_WIKI.md:37-47` |
| 리서치→초안→점검 LangGraph `blog.post_draft` + 발행 전 사람 승인 | MVP | 확정 결정 13, `docs/products/_platform-core/AI_ARCHITECTURE.md:109-119` |
| AI 글쓰기 도우미 채팅(제품별 Dify 앱 `blog-chat`) | MVP | 확정 결정 13, 14(`docs/products/00_MERGE_ANALYSIS.md:21-22`) |
| 음성 받아쓰기 초안, 채팅 음성 대화(STT, 답변 읽어 주기 TTS) | MVP | 확정 결정 16(`docs/products/00_MERGE_ANALYSIS.md:24`) |
| 상용/오픈소스 모델 이원화, 온보딩 국외 이전 동의 | MVP | 확정 결정 17(`docs/products/00_MERGE_ANALYSIS.md:25`), `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| 랜딩 3D 히어로(원고 시트가 접혀 블로그 채널 카드로 발행) | MVP | 확정 결정 15(`docs/products/00_MERGE_ANALYSIS.md:23`), `docs/products/_design-guide/HERO_3D.md:84` |
| 운영자 규정 해설집(표시광고·채널 가이드) 컬렉션과 공개 위키 | Phase 2 | 제안(D-18) |
| 비회원 랜딩 AI 상담 | Phase 2 | `docs/products/_platform-core/AI_ARCHITECTURE.md:130`(운영자 예산과 강한 레이트 리밋 필요) |
| 반복 시리즈(BL-F-050)의 무인 AI 초안 | Phase 2 | 사람 승인 면제는 D-20에서 결정 |
| 사용자 보이스 선택, 보이스 클로닝 | Phase 2 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:80` |

## 3. 기능 요구사항과 수용 기준

### 3.1 플랫폼

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| BL-F-001 | 가입과 부트스트랩 | 통합 | 가입 폼은 `signup_app='blog'`를 보낸다. 기존 사용자가 blog를 처음 열면 `bootstrap_app_for_org('blog')`를 호출한다 | 가입 직후 `session_context('blog')`가 `entitled=true`, `plan_code='free'`, `credit_balance=20`을 돌려준다 | `CORE_SPEC.md` 2.2절 |
| BL-F-002 | 플랜 게이팅과 월 발행 한도 | 신규 | 서버가 `plans.features`를 읽어 기능을 켠다(4.3절). 월 발행 한도는 `blog.monthly_post_usage(org)`로 센다. 한도는 KST 월 단위이고 실패·취소만 남은 원고는 세지 않는다 | Free 조직이 이번 달 11번째 원고를 발행 요청하면 402 `BL004`와 남은 한도 0이 보인다. 다음 달 1일 00:00 KST에 다시 10건이 열린다 | `NOMAD Shorts Maker/src/lib/plans.ts:25`, `:41`, `:60`, `CORE_SPEC.md` 3장 |
| BL-F-003 | 크레딧 선차감·환불 | 통합 | 모든 AI 호출은 `consume_credits` 선차감 후 실행하고 실패하면 환불한다. 잡은 `fail_job`이 자동 환불한다 | 원고 생성 잡이 LLM 오류로 최종 실패하면 원장에 refund 행 1개가 생기고 잔액이 차감 전으로 돌아온다 | `CORE_SPEC.md` 4.3절 |
| BL-F-004 | 구독과 크레딧팩 결제 | 통합 | Toss 일반결제(첫 구독, 팩)와 빌링키 정기결제. 주문 선저장, confirm 멱등 | 테스트 키로 Pro 결제 후 엔타이틀먼트가 pro로 바뀌고 월 크레딧 300이 지급된다. 같은 confirm을 두 번 보내도 지급은 1번이다 | `CORE_SPEC.md` 5장 |
| BL-F-005 | 대시보드 | 디벨롭 | 이번 달 발행 수/한도, 크레딧 잔액, 예약 7일, 실패·확인 필요 발행, 제휴 클릭 7일을 실데이터로 보여 준다. 더미 배열 금지 | 데이터가 0이면 0과 다음 행동 안내가 보인다. 가짜 수치가 보이지 않는다 | `docs/reviews/NOMAD_Shorts_Maker.md:94` |
| BL-F-006 | 감사 기록 | 신규 | 대가성 문구 편집, 위험 동의, 채널 연결 해제, 발행 취소, WARN 확인, 환불, 데이터 내보내기를 `audit_log`에 남긴다 | owner가 설정 > 활동 기록에서 위 행동의 시각, 행위자, 대상을 본다 | `SECURITY_BASELINE.md` 9장 |
| BL-F-007 | 데이터 내보내기 | 신규 | 원고를 Markdown/HTML ZIP으로 내려받는다(Storage `exports`, 서명 URL 7일) | 원고 100편 내보내기가 60초 안에 끝나고 링크가 7일 뒤 만료된다(제안) | `CORE_SPEC.md` 10장 |

### 3.2 원고 작성

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| BL-F-010 | 키워드 추천 | 유지 | 주제와 채널(네이버/티스토리/워드프레스)을 받아 키워드 10개(검색량·경쟁도·의도·이유)를 돌려준다. 검색량과 경쟁도는 LLM 추정이며 화면에 "AI 추정"으로 표시한다. 실패 시 단어 쪼개기 폴백을 하지 않고 오류와 환불을 보여 준다 | 추천 결과 각 행에 "AI 추정" 표시가 있다. LLM 오류 시 "키워드 추천에 실패했습니다. 크레딧 1을 돌려드렸습니다"가 보인다 | `NOMAD Shorts Maker/src/skill/ai-engine/keyword-recommender.ts:37-71`(폴백 `:60-70`은 폐기) |
| BL-F-011 | AI 원고 생성 | 통합 | 입력: 키워드, 템플릿(info 정보형 / compare 비교형 / guide 가이드형 / essay 감성형 / experience 체험형), 분량(짧게 1,000자 / 보통 2,000자 / 길게 3,500자), 어조, 모드(빠름/고품질), 제휴 자동 삽입 여부. 출력: 제목, 본문(TipTap JSON), 요약, 태그 10개 이하. 잡 `blog.generate`로 실행하고 진행률을 보여 준다(2026-10-13: 잡 안에서 BL-F-051 그래프 `blog.post_draft`를 호출한다) | 보통 분량 빠름 모드가 p95 60초 안에 끝난다(제안). 결과가 zod 스키마를 통과하지 못하면 1회 재시도 후 실패·환불한다 | `NOMAD Shorts Maker/src/skill/ai-engine/content-generator.ts:10-47`, `[5f6d262] Youtube_shots_Maker/backend/services/blog_writer.py:31-59`, `nomad-ai-factory/CLAUDE.md:242` |
| BL-F-012 | 체험형 템플릿 제한 | 신규 | experience 템플릿은 사용자가 쓴 실제 사용 메모(50자 이상)가 있어야 열린다. AI는 메모에 없는 경험·수치·만족도를 만들지 않는다. 다른 템플릿은 1인칭 구매·사용 경험 서술을 금지한다 | 메모 49자로 체험형을 고르면 생성 버튼이 비활성이고 "직접 사용해 본 내용을 50자 이상 적어 주세요"가 보인다. DB도 `posts_experience_check`로 거부한다 | 6.5절, `[5f6d262] Youtube_shots_Maker/backend/services/blog_writer.py:41`(가상 후기 요구 프롬프트, 폐기) |
| BL-F-013 | 제목 3안과 개요 | 유지 | 키워드로 제목 3안과 H2 개요를 만든다. 사용자가 고른 제목·개요로 원고를 생성한다 | 제목 3안이 각각 20~60자이고 키워드를 포함한다 | `NOMAD Shorts Maker/src/components/posts/AiGeneratePanel.tsx` |
| BL-F-014 | 구간 다시쓰기 | 신규 | 에디터에서 선택한 구간(최대 1,500자)을 지시문("더 짧게", "표로")에 따라 다시 쓴다. 원문은 실행 취소로 되돌린다 | 선택 없이 실행하면 버튼이 비활성이다. 다시쓰기 결과가 선택 구간만 바꾼다 | 제안(`docs/products/_design-guide/REFERENCES.md:117` 편집기 옆 보조 패널) |
| BL-F-015 | SEO 점수 | 유지 | 규칙 기반 점수(제목 키워드 20, 제목 길이 20~60자 15, 본문 1,000자 이상 20, 본문 키워드 20, 소제목 2개 이상 15, 이미지 10). 무료. 피드백 문구는 이모지 없이 | 같은 원고에 같은 점수가 나온다. 점수 게이지 대신 항목 체크리스트로 보인다 | `NOMAD Shorts Maker/src/skill/ai-engine/keyword-recommender.ts:73-103`, `REFERENCES.md:108`(점수 게이지 남발 회피) |
| BL-F-016 | 태그 추천 | 유지 | 제목과 본문 앞 500자로 태그 10개(네이버 태그 최대 10개 기준)를 추천. 실패 시 기본 해시태그 폴백 금지 | 추천 태그가 10개 이하이고 중복이 없다 | `NOMAD Shorts Maker/src/skill/ai-engine/hashtag-generator.ts:52-56`(폴백 폐기), `[5f6d262] Youtube_shots_Maker/backend/services/naver_blog.py:250` |
| BL-F-017 | 에디터와 자동 저장 | 디벨롭 | TipTap(StarterKit, Link, Image, Table, 제휴 카드 노드, 대가성 문구 잠금 노드). 입력 멈춤 2초 뒤 자동 저장, `version`으로 충돌 감지. 미리보기는 서버 렌더러 결과를 sanitize 후 보여 준다(`dangerouslySetInnerHTML` 직접 금지) | 두 탭에서 같은 원고를 고치면 늦게 저장한 쪽에 "다른 곳에서 수정됨, 최신 내용 불러오기" 안내가 뜬다. `<script>`를 붙여 넣어도 미리보기와 발행 HTML에 남지 않는다 | `docs/reviews/NOMAD_Shorts_Maker.md:106`, `NOMAD Shorts Maker/src/components/posts/MultiChannelEditor.tsx:316` |
| BL-F-018 | 대표 이미지 | 유지 | JPG/PNG/WebP 10MB 이하 업로드(Storage `org-files/<org>/blog/cover/<uuid>`). 원고 본문 이미지도 같은 규칙 | 11MB 업로드는 서버가 413으로 거부한다 | `NOMAD Shorts Maker/supabase/migrations/001_initial.sql:27`, `CORE_SPEC.md` 10장 |

### 3.3 제휴(affiliate 공용 모듈 소비)

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| BL-F-020 | 제휴 계정 연결 | 통합 | 쿠팡파트너스 Access/Secret 키를 `encrypted_credentials`에 저장하고 `affiliate_accounts`를 만든다(service_role). 텐핑·네이버쇼핑 커넥트는 파트너 ID와(있으면) 키를 저장한다 | 연결 후 설정 화면에 키는 마스킹(앞 4자리)으로만 보인다. DB에 평문 키 컬럼이 없다 | `SHARED_MODULES.md` 17장, `NOMAD Shorts Maker/src/skill/channel-api/coupang-client.ts:5-12` |
| BL-F-021 | 상품 검색과 카드 삽입 | 통합 | 에디터 제휴 탭에서 쿠팡 상품을 검색해 카드(상품명, 이미지, 가격, 버튼)를 원하는 위치에 넣는다. 삽입 시 `affiliate_links`(source_app blog, source_ref post id) + `blog.post_affiliate_links`를 만든다. 카드 가격 옆에 "작성 시점 가격, 변동될 수 있음"을 표시한다 | 카드 1개 삽입 후 매핑 행 1개와 단축 코드 1개가 생긴다. 같은 상품을 다시 넣으면 기존 링크를 재사용한다 | `NOMAD Shorts Maker/src/components/posts/CoupangLinkPanel.tsx`, `CORE_SPEC.md` 13장 |
| BL-F-022 | 텐핑·네이버쇼핑 커넥트 링크 | 디벨롭 | 공개 API 여부 미확인. MVP는 사용자가 제공자에서 발급한 제휴 URL을 붙여 넣어 등록한다(수동). API가 확인되면 어댑터로 검색·생성을 연다. Playwright 대체는 API가 없고 제공자 약관이 허용할 때만(제안: 확인 전 구현하지 않음) | 수동 등록 URL이 `https://`가 아니거나 제공자 도메인 허용 목록 밖이면 거부된다(허용 도메인 목록은 구현 시 제공자 문서로 확정, 미확인) | 확정 결정 12, `[5f6d262] Youtube_shots_Maker/backend/services/naver_shopping.py:1-10`(키 없으면 Mock, 폐기) |
| BL-F-023 | 제휴 자동 추천 삽입 | 신규 | 원고 생성 옵션 "제휴 상품 자동 넣기"(Pro 이상). LLM이 본문에서 상품 키워드 최대 3개를 뽑고, 연결된 제공자 검색 API로 각 1개 상품을 골라 카드로 넣는다. 위치: 도입부 뒤 1개, 결론 앞 1~2개. 사용자는 발행 전 카드를 지우거나 바꿀 수 있다 | 자동 삽입 카드는 `inserted_by='auto'`로 기록되고 에디터에 "자동으로 넣은 상품" 표시가 붙는다. 검색 결과가 없으면 카드 없이 원고만 만든다 | 확정 결정 12 |
| BL-F-024 | 대가성 문구 자동 삽입 | 신규 | 발행 렌더 시 원고의 제휴 매핑 제공자 집합(+ 브랜드커넥트 지원서가 연결된 원고는 naver_brandconnect)에 대해 `effective_disclosure(org, provider, 'blog_top')`을 가져와 중복 없이 본문 첫 블록으로 넣는다. 본문 글꼴 크기 이상, 접기·이미지화·흰 글씨 금지. 본문에 매핑 없는 제휴 도메인 링크가 있으면 같은 규칙으로 문구를 넣는다. 끄는 설정은 만들지 않는다. 편집은 owner/admin이 설정 화면에서 `upsert_affiliate_disclosure`로만 한다 | 제휴 카드 1개가 있는 원고를 발행하면 채널에 올라간 글의 첫 문단이 대가성 문구다. `post_publications.disclosure_included=false`인 채 발행 단계로 넘어가는 UPDATE는 DB가 23514로 거부한다 | 확정 결정 12, `CORE_SPEC.md` 13.3절, `05_DATA_MODEL.md` 2.4절 |
| BL-F-025 | 채널 x 제공자 정책 | 신규 | 네이버 블로그에 쿠팡 링크를 넣으면 경고("네이버 블로그는 외부 쇼핑 링크가 많은 글의 노출을 줄일 수 있습니다")를 보이고 사용자가 확인해야 발행된다. 확인은 원고별 감사 기록 | 경고 확인 없이 네이버 발행을 요청하면 409 `BL006`이 반환된다 | `NOMAD Shorts Maker/src/skill/playwright-engine/naver-blog-poster.ts:2`("네이버 블로그에는 쿠팡 링크 삽입 금지(외부링크 페널티)"). 경고 방식은 제안, 8장 열린 결정 1 |
| BL-F-026 | 링크 형식 | 신규 | 기본은 단축 링크 `https://<blog 도메인>/r/<code>`(클릭 기록). 채널 정책상 직접 링크가 필요하면 제휴 URL을 그대로 쓴다 | `/r/<code>`가 302로 제휴 URL에 보내고 `affiliate_clicks`에 1행이 생긴다 | `CORE_SPEC.md` 13.3절. 채널별 기본값은 8장 열린 결정 2 |
| BL-F-027 | 제휴 클릭 통계 | 디벨롭 | 링크·원고·제공자별 클릭(7일/30일)과 상위 원고. 수익·전환은 제공자 리포트 API가 확인된 제공자만 보여 주고, 없으면 "제공자 사이트에서 확인" 링크를 둔다 | 수익 열이 데이터 없이 0으로 채워지지 않는다(원본 `revenue` 컬럼은 갱신 경로가 없었다) | `NOMAD Shorts Maker/src/app/api/coupang/stats/route.ts:9-30`, `NOMAD Shorts Maker/supabase/migrations/001_initial.sql:59-61` |

### 3.4 네이버 브랜드커넥트(blog 소유)

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| BL-F-030 | 브랜드커넥트 계정 연결 | 신규 | 네이버 채널 연결에 쓴 자격증명을 공유해 `affiliate_accounts(provider='naver_brandconnect')`를 만든다(service_role). 별도 네이버 계정도 허용 | 연결 직후 상태는 "위험 동의 필요"이고 지원 버튼이 잠겨 있다 | `CORE_SPEC.md` 13.1절 |
| BL-F-031 | 위험 고지와 동의 | 신규 | 6.4절 고지문 전문을 보여 주고 owner/admin만 동의한다. 동의 = 고지문 끝까지 읽음 + 체크 3개 + "동의합니다" 입력 → `consent_brandconnect_risk(account)` + 고지문 버전 감사 기록. 고지문 버전이 바뀌면 재동의 전까지 지원 잡을 만들지 않는다. 철회하면 대기 중 지원 잡을 취소한다 | member가 동의 버튼을 누르면 403이다. 동의 없이 지원서를 만들면 core가 42501을 돌려준다. 철회 후 대기 지원 잡이 canceled로 바뀐다 | 확정 결정 12, `docs/products/_supabase-modular/migrations/0006_core_affiliate.sql:303-360` |
| BL-F-032 | 캠페인 탐색 | 디벨롭 | 잡 `brandconnect.scan`이 Playwright로 공개 캠페인 목록(제목, 브랜드, 마감, 보상)을 가져와 잡 결과로 돌려준다. 하루 최대 4회, 결과는 테이블에 저장하지 않는다(잡 결과 7일 보관, 제안). Mock 목록 금지 | 스캔 실패 시 빈 목록이 아니라 실패 사유("로그인이 필요합니다" 등)가 보인다 | `NOMAD Shorts Maker/src/skill/playwright-engine/brand-connect.ts:101-134`, `NOMAD Shorts Maker/src/app/api/brand-connect/recommend/route.ts:3-12`(Mock, 폐기) |
| BL-F-033 | 지원서 자동 제출 | 유지 | 사용자가 캠페인을 고르고 지원 메시지(템플릿 + AI 다듬기 선택)를 확인하면 `create_brandconnect_application` → 잡 `brandconnect.apply`가 Playwright로 제출한다. 사람 개입 없이 끝까지 진행하고, 상태는 draft → submitting → submitted / failed. 계정당 5건/시간, 20건/일(제안) | 제출 성공 시 `submitted_at`과 지원서 상태 "제출됨"이 보인다. 6번째 요청(1시간 내)은 429다. CAPTCHA가 나오면 failed + "네이버에 다시 로그인해 주세요" | 확정 결정 12, `SECURITY_BASELINE.md` 8장, `NOMAD Shorts Maker/src/skill/playwright-engine/brand-connect.ts:22-96` |
| BL-F-034 | 지원 상태 동기화 | 신규 | 잡 `brandconnect.sync`가 하루 1회 제출 건의 선정/미선정을 읽어 accepted/rejected로 바꾼다 | 선정되면 대시보드에 "선정된 캠페인 원고 쓰기" 행동이 생긴다 | 제안 |
| BL-F-035 | 선정 캠페인 원고 | 신규 | 원고에 지원서를 연결하면(`posts.brandconnect_application_id`) 제휴 링크가 없어도 naver_brandconnect 대가성 문구가 상단에 들어간다 | 연결된 원고는 문구 없이 발행 단계로 갈 수 없다(DB 불변식) | 확정 결정 12 |

### 3.5 채널과 발행

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| BL-F-040 | 워드프레스 연결 | 유지 | 사이트 URL(https만) + 사용자명 + 애플리케이션 비밀번호. 서버가 `/wp-json/wp/v2/users/me`로 검증한다. 호출 전 사설 IP·로컬 주소 차단, 리다이렉트 최대 2회, 응답 5MB 제한 | `http://`나 `https://127.0.0.1`을 넣으면 "공개 https 주소만 연결할 수 있습니다"가 보인다 | `NOMAD Shorts Maker/src/skill/channel-api/wordpress-client.ts:17-70`, `NOMAD Shorts Maker/src/app/api/accounts/[id]/connect/route.ts:39-48` |
| BL-F-041 | 네이버·티스토리 연결 | 디벨롭 | 계정 아이디·비밀번호 또는(Phase 2) 세션 쿠키 가져오기. 비밀은 `encrypted_credentials`에만. 연결 전에 owner/admin이 6.4절 "자동 게시 위험" 동의(`blog.consent_channel_automation_risk`). 연결 검증 잡 `blog.channel.verify`가 로그인해 세션 쿠키를 암호화 저장하고 blog_id를 확인한다 | 동의 전에는 "연결" 버튼이 잠겨 있다. 검증이 끝나면 상태 active와 세션 만료 예정일(로그인 후 7일, 제안)이 보인다. 세션 쿠키가 평문으로 저장되는 경로가 없다 | `NOMAD Shorts Maker/src/app/api/accounts/[id]/connect/route.ts:24-35`(세션 평문 저장, 결함), `NOMAD Shorts Maker/src/skill/playwright-engine/naver-login.ts:9-63` |
| BL-F-042 | 세션 재인증 | 디벨롭 | 발행·지원 잡이 로그인 페이지나 CAPTCHA를 만나면 채널 상태를 `needs_reauth`로 바꾸고 잡을 재시도 불가 실패로 끝낸다. CAPTCHA 우회·자동 풀이를 하지 않는다. 만료 2일 전 알림 | 세션 만료 상태에서 예약 발행 시각이 되면 발행이 failed("네이버 로그인이 만료되었습니다")가 되고 알림이 1회 간다 | `[5f6d262] Youtube_shots_Maker/backend/services/naver_blog.py:196-201` |
| BL-F-043 | 즉시 발행 | 통합 | 원고 1개를 채널 계정 N개에 발행 요청. 서버 순서: 엔타이틀먼트 → 월 한도 → 채널 한도 → 컴플라이언스 상태 → 채널 정책 경고 확인 → `post_publications` INSERT(DB 게이트) → `enqueue_job(blog.publish.<channel>)`. 요청마다 `request_id`로 멱등 | 같은 `request_id`로 두 번 요청해도 발행 행과 잡은 1개다. 같은 원고·같은 계정에 진행 중 발행이 있으면 409 | `NOMAD Shorts Maker/src/app/api/posts/[id]/publish/route.ts:168-279`(동기 Playwright, 결함), `05_DATA_MODEL.md` 3.2절 |
| BL-F-044 | 예약 발행과 캘린더 | 통합 | 예약 시각(10분 단위, 지금부터 최소 10분 뒤, 최대 90일 뒤, 제안)은 잡의 `run_after`로 넣는다. 캘린더는 월/주 보기, 채널 색 범례, 드래그로 시각 변경(시각 변경 = 기존 취소 + 새 예약) | 예약 시각 KST 09:00으로 넣은 발행이 09:00~09:05 사이에 시작된다 | `NOMAD Shorts Maker/src/skill/schedule-engine/queue-processor.ts:18-35`, `docs/products/_design-guide/REFERENCES.md:118` |
| BL-F-045 | 발행 결과 불확실 처리 | 신규 | 발행 버튼은 눌렀으나 결과 URL을 확인하지 못하면 `unconfirmed`로 두고 자동 재시도하지 않는다(중복 발행 방지). 사용자가 채널에서 확인 후 URL을 입력하거나 "올라가지 않음"을 고른다 | unconfirmed 건은 대시보드 "확인 필요"에 보이고, 자동 재시도 잡이 생기지 않는다 | `[5f6d262] Youtube_shots_Maker/backend/services/naver_blog.py:279-288`(불확실 URL을 성공으로 반환, 결함) |
| BL-F-046 | 재시도와 취소 | 디벨롭 | 발행 버튼을 누르기 전 단계의 실패(로그인 전 네트워크 오류 등)만 자동 재시도(최대 3회, 60초·120초·240초). 예약·대기 발행은 사용자가 취소할 수 있다 | 실행 중(publishing) 발행 취소 요청은 409 `BL002`다 | `CORE_SPEC.md` 9.1절 |
| BL-F-047 | 계정당 발행 간격 | 신규 | 같은 채널 계정의 연속 발행 간격 10분 이상, 하루 상한 네이버 5건·티스토리 5건·워드프레스 30건(제안). 브라우저 세션은 계정당 1개(`acquire_channel_lock`) | 같은 네이버 계정에 3건을 동시에 예약하면 10분 간격으로 순서대로 실행된다 | 제안(대량 자동 게시가 스팸 판정·계정 제한으로 이어지는 위험을 낮추기 위함) |
| BL-F-048 | 컴플라이언스 게이트 | 통합 | 발행 요청 전 "검사" 단계: 규칙 사전(무료) → LLM 판정(1크레딧). FAIL은 발행 불가 + 수정 가이드, WARN은 사용자 확인(`acknowledge_compliance_warning`, 감사) 후 진행. 원고를 고치면 검사 결과가 자동으로 무효가 된다. LLM 오류는 PASS가 아니라 WARN | 검사하지 않은 원고로 발행 행을 만들면 DB가 `BL003`으로 거부한다 | `SHARED_MODULES.md` 13장, `05_DATA_MODEL.md` 2.2절 |
| BL-F-049 | 인스타그램 카드 포스팅 | 통합(Phase 2) | video 소유 sns-uploader로 대표 이미지 + 캡션(제목, 태그, 대가성 문구 첫 줄) 게시 | Phase 2 | `SHARED_MODULES.md` 11장 |
| BL-F-050 | 반복 발행 시리즈 | 유지(Phase 2) | cron 표현식은 KST 기준으로 해석한다(원본은 서버 로컬 시간대) | Phase 2 | `NOMAD Shorts Maker/src/skill/schedule-engine/cron-handler.ts:10-41` |

### 3.6 분석 C-4 기획 공백의 처리

| 공백(`docs/products/00_MERGE_ANALYSIS.md:677-688`) | blog에서의 명세 위치 |
|---|---|
| 1 제품 경계 | README 2장(확정 결정 1, 12) |
| 2 Supabase 접근 3계층 | 02장 2절, `CLAUDE.md` 4장 |
| 3 단계 간 payload 계약, 실패·재시도·환불 | 04장 4절, 02장 4절 |
| 4 워커 런타임과 배포 | 02장 4절, 7절 |
| 5 가입 시 조직·무료 크레딧 | BL-F-001(코어) |
| 6 결제 | BL-F-004(코어), 4.5절 환불 |
| 7 OAuth nonce, 키 교체 | 05장 7절, 02장 8절 |
| 8 네이버 로그인 계정 연결 | 05장 7절(YSM #3), 8장 열린 결정 12 |
| 9 YouTube 업로드 | 해당 없음(video 소관) |
| 10 테스트/CI | 06장 7절 |

### 3.7 AI·음성·3D (2026-10-13, 확정 결정 13~17)

MVP 필수다. 정본 설계는 `docs/products/_platform-core/AI_ARCHITECTURE.md`(구조 `:5-23`, 대화 매핑 `:44-56`, 라우팅 `:73-92`, RAG `:94-107`, 그래프 `:109-119`, 크레딧 `:121-130`), `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`다. 제품 그래프와 기능별 라우팅 기본값은 02장 5절, 호출 계약은 04장 2.1·6절이다. 모든 AI·음성 기능은 텍스트·수동 입력만으로도 쓸 수 있어야 한다(음성은 대안, `VOICE_ARCHITECTURE.md:110`).

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| BL-F-051 | AI 초안 그래프 `blog.post_draft` | 디벨롭(BL-F-011 흡수) | FastAPI(`apps/api`)의 LangGraph 그래프 7노드. `keyword`(키워드 리서치: 주제와 선택 키워드에서 연관·롱테일 후보와 검색 의도를 추정, "AI 추정" 표시, 위키 토픽 페이지가 있으면 근거로 사용) → `retrieve`(조직 자료 컬렉션과 위키 검색, 출처 목록) → `draft`(템플릿 5종·분량·어조, 제목 3안과 개요, TipTap JSON, 체험형 제한 BL-F-012 유지) → `affiliate_check`(제휴 링크·대가성 점검: 매핑 없는 제휴 도메인 링크, 카드 수, `requires_disclosure` 계산, 자동 삽입 옵션이면 상품 키워드 추출까지만 하고 카드 삽입은 제품 서버가 BL-F-023 경로로 수행) → `seo_check`(BL-F-015 규칙, LLM 없음, 미충족 항목만 `draft` 1회 보강) → `compliance`(규칙 사전 + LLM 판정, 걸린 구간만 1회 재작성 후 재검사) → `approve`(사람 승인 interrupt, BL-F-052). 워커 `blog.generate` 잡이 잡 토큰으로 실행을 요청하고 결과 저장은 워커가 한다. 대가성 문구는 LLM이 쓰거나 지우지 않고 렌더러만 삽입한다(BL-F-024) | 생성 1건 = `core.ai_runs` 1행(graph `blog.post_draft`, `job_id`, `credit_ledger_id`)과 노드별 `ai_run_steps` 7행. 체험 메모 없는 원고에 1인칭 사용 경험 문장 0(평가셋 20건). 매핑 없는 제휴 도메인 링크가 본문에 있으면 `affiliate_check`가 경고를 남기고 `requires_disclosure=true`로 계산한다. `approve` 도달까지 p95 90초(빠름, 고품질 150초, 제안). 최종 실패(`approve` 도달 전) 시 원고 `failed` + 환불 원장 1행 | `docs/products/_platform-core/AI_ARCHITECTURE.md:109-119`, BL-F-011, BL-F-015, BL-F-024 |
| BL-F-052 | 발행 전 사람 승인 | 신규 | 그래프는 `approve` 노드에서 멈춘다(interrupt). 사용자는 "발행 전 확인" 화면에서 원고, 검사 결과(PASS/WARN/FAIL), 자료 출처, 제휴 카드, 대가성 문구 미리보기를 보고 승인한다(`POST /api/posts/:id/ai-approve`). 그래프로 만든 원고는 승인 없이 발행·예약할 수 없다. 승인 뒤 원고를 고치면 검사가 무효가 되고(BL-F-048) 다시 검사해야 발행된다. 승인은 감사 기록이다. 반복 시리즈(BL-F-050)의 무인 발행은 Phase 2 결정(D-20)이다 | 승인 전 `POST /api/posts/:id/publish`는 409 `AI_APPROVAL_REQUIRED`(예약 포함). 컴플라이언스 FAIL 원고의 승인 요청은 409 `BL003`. 감사 `blog.ai.draft_approved` 1행(행위자, 원고, run id). 사용자가 반려하면 run `canceled`, 원고는 보존 | `docs/products/_platform-core/AI_ARCHITECTURE.md:118`, BL-F-048 |
| BL-F-053 | 브랜드·상품·제휴 캠페인 자료 RAG | 신규 | 사용자가 브랜드 소개, 상품 설명서, 가격표, 캠페인 요강, 제휴 상품 정보, 과거 원고를 올린다(txt, md, pdf, 파일당 10MB 이하, 조직당 `features.rag_documents`개). 조직 컬렉션 `blog-materials`(kind rag, 임베딩 `oss-embed`)에 색인하고 그래프 `retrieve`와 채팅이 검색한다. 업로드 화면에 "개인정보·계약상 비공개 정보는 올리지 마세요" 안내와 "개인정보 포함" 체크(체크하면 `contains_pii=true`, 위키 ingest 대상에서 제외, 제안)를 둔다. 자료는 원고 본문에 그대로 복사하지 않고 사실 확인용 근거로만 쓴다. 자료 안의 지시는 따르지 않는다 | 문서 1건(10MB 이하) 색인 p95 120초(제안). 평가셋 30문항(제안)에서 상위 8개 안 정답 청크 재현율 0.8 이상. 다른 조직 컬렉션 검색 요청은 거부(42501). 한도 초과 업로드는 403 `PLAN_LIMIT`. 자료가 없어도 그래프는 동작하고 출처 없음을 표시한다 | `docs/products/_platform-core/AI_ARCHITECTURE.md:94-107` |
| BL-F-054 | 토픽·키워드 위키 | 신규 | 조직의 자료, 과거 원고, 키워드 리서치 결과를 위키 ingest가 `topic`(주제·키워드 클러스터: 검색 의도, 관련 키워드, 메모), `entity`(브랜드·상품), `concept`(SEO·표시광고 용어) 페이지로 정리한다. 새 페이지는 `draft`로 만들고 사용자가 검수해 `published`로 바꾼다. 사용자가 고친 블록은 사람 소유로 표시되어 ingest가 덮어쓰지 않고, 저장은 `expected_version` 낙관적 잠금, 문서 1건당 갱신 페이지는 5개까지, 주 1회 lint. 그래프 `keyword`·`retrieve`와 채팅이 근거로 쓰며 `draft` 페이지는 출처 칩에 "검수 전"을 표시한다. 조직 내부용이며 공개하지 않는다. Pro 이상(`features.product_wiki`) | 위키 화면에 draft/published/archived 구분. 사람 소유 블록은 ingest 뒤에도 그대로. 버전 충돌 409. 출처 없는 주장을 lint가 검출. 다른 조직 위키 0행. Free 조직의 ingest 요청은 403 `PLAN_REQUIRED`. 개인정보 포함 자료에서 만든 페이지 0 | `docs/products/_platform-core/LLM_WIKI.md:12-47` |
| BL-F-055 | AI 글쓰기 도우미 채팅 | 신규 | 에디터 보조 패널 "도우미" 탭과 `/assistant` 전체 화면. 작성 중 원고(`post_id`, 본문 앞 6,000자)와 자료·위키를 근거로 제목, 구성, 표현, SEO, 제휴 배치 질문에 답한다. 스트리밍, 답변마다 출처, "AI가 생성한 답변" 표시. 원고를 직접 바꾸지 않고 제안 문단을 사용자가 "에디터에 넣기"로 적용한다(실행 취소 가능, BL-F-014와 같음). 메시지 2,000자, 대화당 50턴(제안). 크레딧은 턴 선차감 후 정산(4.6절). 로그인 사용자 전용 | 답변에 출처 1개 이상 또는 "근거 자료를 찾지 못했습니다". 응답이 전달되지 않은 턴은 선차감 전액 환불. 잔액 부족 402 `CR001`. Dify 장애 시 `/tools/answer-direct`로 답한다. 다른 사용자의 대화 id로 이어 쓰면 404, 다른 조직 `post_id`는 403. 대화 평가셋 30문항(제안)에서 금지 응답(6.7절) 0 | `docs/products/_platform-core/AI_ARCHITECTURE.md:44-56`, `:121-130` |
| BL-F-056 | 음성 받아쓰기 초안 | 신규 | 에디터 마이크 버튼(누르고 말하기 / 토글)으로 말한 내용을 STT(기능 `dictation`, 오픈소스 우선)로 받아 변환 텍스트를 확인·수정한 뒤 커서 위치에 넣거나 "초안 메모"(생성 입력, 체험 메모 포함)로 쓴다. 한 번에 최대 5분·20MB(제안). 녹음 원본은 저장하지 않는다. 첫 사용 전 음성 처리 고지를 확인받는다(6.7절) | 5분에 도달하면 자동 중지. 이 제품의 `voice_jobs.store_audio=false` 100%. 고지 확인 없이 STT 호출 시 403 `VOICE_CONSENT_REQUIRED`. 마이크 권한을 거부해도 키보드 입력 정상. 받아쓴 텍스트를 체험 메모로 쓸 때도 BL-F-012의 50자 규칙을 적용. STT 실패 시 환불 1행 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:40-48`, `:85-95` |
| BL-F-057 | 음성 대화(채팅) | 신규 | 도우미 채팅의 마이크 버튼(기능 `voice_chat`): STT → 변환 텍스트 미리보기·수정 → 전송 → 답변 → "읽어 주기"(TTS, ElevenLabs 우선, 자동 재생 기본 꺼짐). 질문 발화 최대 60초(제안). TTS 입력은 DB의 assistant 메시지만 쓰고 임의 텍스트는 받지 않는다 | 60초에 도달하면 자동 중지, 초과 요청 413. 마이크 거부·미지원 브라우저에서 텍스트 채팅 정상. STT·TTS 실패 시 환불 1행. TTS 요청에 메시지 id 외 텍스트를 넣으면 400 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:106-110` |
| BL-F-058 | AI 라우팅과 국외 이전 동의 | 신규 | 이메일 인증 직후 온보딩 `/onboarding/ai`(기존 사용자는 AI 기능 첫 사용 직전)에서 "AI 처리 방식"을 고른다: 상용 AI 사용(국외 이전 동의) 또는 국내 오픈소스만. 동의하면 `core.set_ai_cross_border_ack(org, true, 고지문 버전)`과 감사 `blog.ai.cross_border_ack`를 함께 남기고 설정에서 철회한다. 동의 전에는 모든 AI·음성이 오픈소스 제공자만 쓴다. AI 기능만 선택 전 잠기고 발행 기능은 영향이 없다 | 미동의 조직의 `ai_usage.provider_id`에 상용 제공자 0. 철회 직후 다음 요청부터 상용 0. 고지문 버전이 `ai_org_settings.cross_border_notice`와 감사 메타에 같게 남는다. member가 동의를 바꾸면 403 | `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| BL-F-059 | AI 크레딧 선차감·정산 | 신규 | 그래프 실행, 채팅 턴, STT, TTS, 자료 색인, 위키 작업은 시작 때 예상 크레딧을 `consume_credits`로 선차감하고 끝나면 정산한다(차액 추가 차감 또는 `refund_credits`). 그래프는 정액 선차감에 묶는다. 단가는 4.6절 | 1시간 넘게 지난 `ai_usage` 중 `settled_at is null` 0행. 같은 멱등 키 재요청 시 차감 1회. 원장 drift 0. 사용자에게 결과가 전달되지 않은 실패는 전액 환불 | `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130` |
| BL-F-060 | AI 출력 규칙 | 신규 | 6.5절 금지 문구와 6.7절 대화 규칙을 그래프 `compliance` 노드, `/tools/answer` 후처리, 위키 ingest·query에 같은 규칙 파일(`packages/blog-rules/banned.json`)로 적용한다. 대가성 표기 회피, 가상 후기, 수익·순위 보장 요청은 정중히 거절하고 설정 화면이나 올바른 방법을 안내한다 | 규칙 평가셋 30문항(제안) 위반 0. 한글 경계 규칙 테스트 통과(`\b` 금지). 같은 규칙을 TS 컴플라이언스(BL-F-048)와 FastAPI가 읽는다 | `docs/products/_platform-core/AI_ARCHITECTURE.md:117`, 6.5절 |
| BL-F-061 | 3D 히어로 | 신규 | 랜딩 히어로: PC·태블릿은 원고 시트가 접혀 네이버·티스토리·워드프레스 채널 카드 3장으로 발행되는 풀 3D, 모바일은 시트 1장이 접히는 가벼운 3D, WebGL 미지원·저사양·`prefers-reduced-motion`은 정지 이미지(03장 4.6절) | `HERO_3D.md` 4절 수용 기준 전부: 기기 3종 동작, 3D 번들+에셋 PC·태블릿 1MB/모바일 300KB 이하, LCP 2.5초, 제목·입력·CTA가 3D 전에 보임·키보드 사용 가능, 3종 스크린샷 고문 검토 통과 | `docs/products/_design-guide/HERO_3D.md:5-75`, `:84` |

BL-F-006 감사 목록에 `blog.ai.cross_border_ack`, `blog.ai.draft_approved`, `blog.voice.notice_ack`, `blog.ai.document_delete`, `blog.wiki.publish`, `blog.wiki.edit`를 더한다. BL-F-043 서버 순서는 "컴플라이언스 상태" 다음에 "AI 승인 상태(그래프로 만든 원고)" 확인이 들어간다.

## 4. 요금과 크레딧

### 4.1 플랜

정본 출처: 확정 결정 8은 blog를 정하지 않았다(`docs/products/00_MERGE_ANALYSIS.md:16`). 가격과 월 발행 수는 CA 플랜(`NOMAD Shorts Maker/src/lib/plans.ts:18-71`)을 따른다. 월 크레딧은 CA에 없던 값이라 제안이다.

| 코드 | 가격(월) | 월 크레딧 | 가입 크레딧 | 이월 | 월 발행 | 채널 계정 | 주요 기능 |
|---|---|---|---|---|---|---|---|
| `free` | 0원 | 20(제안) | 0 | 없음 | 10건 | 2개 | 빠름 모드 AI, 제휴 카드 수동 삽입, 즉시 발행 |
| `pro` | 29,000원 | 300(제안) | 0 | 없음 | 50건 | 10개 | 고품질 모드, 제휴 자동 삽입, 브랜드커넥트, 예약 발행 |
| `business` | 99,000원 | 1,500(제안) | 0 | 없음 | 무제한 | 무제한 | Pro 전부 + 인스타그램(Phase 2), n8n/Make(Phase 2), 팀 5인(제안) |

월 크레딧 근거(제안): 발행 1건에 원고 생성 빠름 3 + 검사 1 = 4크레딧이 든다. Free 20은 AI 원고 5편(나머지 5건은 직접 쓴 원고), Pro 300은 50건 x 4 = 200에 키워드·다시쓰기 여유 100, Business 1,500은 약 300편이다. 이월 없음은 코어 기본(`carry_over=false`)이다.

### 4.2 크레딧 단가

| 작업(LLM purpose) | 크레딧 | 근거 |
|---|---|---|
| 키워드 추천 10개(`blog.keywords`) | 1 | 제안 |
| 제목 3안 + 개요(`blog.outline`) | 1 | 제안 |
| 원고 생성 빠름(`blog.draft`, fast) | 3 | 제안(보통 분량 2,000자 기준, 짧게·길게도 같은 값) |
| 원고 생성 고품질(`blog.draft`, quality) | 6 | 제안(고품질 모델 단가가 빠름의 약 2배라는 가정) |
| 제휴 자동 삽입용 상품 키워드 추출(`blog.product_extract`) | 1 | 제안 |
| 구간 다시쓰기(`blog.rewrite`) | 1 | 제안 |
| 태그 추천(`blog.tags`) | 1 | 제안 |
| 브랜드커넥트 지원 메시지 다듬기(`blog.bc_message`) | 1 | 제안 |
| 컴플라이언스 LLM 판정(`compliance`) | 1 | `SHARED_MODULES.md` 13장 |
| SEO 점수(규칙) | 0 | `NOMAD Shorts Maker/src/skill/ai-engine/keyword-recommender.ts:73-103`(LLM 미사용) |
| 발행, 예약, 채널 검증 | 0 | 월 발행 한도로 관리(`CORE_SPEC.md` 3장 한도형 기능) |
| 브랜드커넥트 스캔·지원 | 0 | `SHARED_MODULES.md` 17장(제안: 제휴 기능은 크레딧을 쓰지 않음) |
| AI 대표 이미지(Phase 2, fal) | 4 | 제안 |

### 4.3 `core.plans.features` 키 해석

| 키 | 타입 | 의미 | 서버 판정 위치 |
|---|---|---|---|
| `posts_per_month` | integer, -1 무제한 | KST 월 발행 원고 수(`blog.monthly_post_usage`) | 발행 요청 라우트 |
| `max_channel_accounts` | integer, -1 무제한 | revoked가 아닌 채널 계정 수 | 채널 연결 라우트 |
| `channel_types` | text[] | 연결 가능한 채널 | 채널 연결 라우트 |
| `ai_modes` | text[] | `fast`, `quality` | AI 라우트 |
| `affiliate` | boolean | 제휴 카드 수동 삽입 | 제휴 라우트 |
| `affiliate_auto_insert` | boolean | 원고 생성 시 자동 삽입 | 생성 라우트 |
| `brandconnect` | boolean | 브랜드커넥트 기능 | 브랜드커넥트 라우트 |
| `schedule` | boolean | 예약 발행 | 발행 요청 라우트 |
| `automation` | boolean | n8n/Make, 발신 웹훅(Phase 2) | 자동화 라우트 |
| `team_members` | integer | 조직 멤버 수 상한 | 초대 라우트 |
| `ai_chat` | boolean | AI 글쓰기 도우미 채팅 허용. 키가 없으면 true로 읽는다 | `/api/ai/chat` |
| `ai_chat_turns_per_day` | integer | 사용자당 하루 채팅 턴 상한(공정 사용). 키가 없으면 50. Free 50 / Pro 200 / Business 500(제안, D-19) | `/api/ai/chat` |
| `voice_chat` | boolean | 채팅 음성 대화 허용. 키가 없으면 true | `/api/voice/*` |
| `dictation` | boolean | 에디터 음성 받아쓰기 허용. 키가 없으면 true | `/api/voice/stt` |
| `rag_documents` | integer | 조직당 자료 문서 수 상한. 키가 없으면 10. Free 10 / Pro 100 / Business 1,000(제안) | 자료 업로드 라우트 |
| `product_wiki` | boolean | 토픽·키워드 위키 허용. 키가 없으면 false. Free false / Pro·Business true(제안) | 위키 라우트 |

모듈러 `seed.sql`은 2026-10-13에 모놀리스 seed와 같은 값(위 표)으로 맞춰졌다. AI 키 6개는 같은 날 추가했다: 모놀리스는 `supabase/monolith/seed.sql`의 플랜 3행에, 모듈러는 `docs/products/_supabase-modular/migrations/1300_blog.sql` 9.2절의 병합 UPDATE에 있다(모듈러 `seed.sql` 반영은 06장 6절 AI-R2). 서버는 안전을 위해 `max_channel_accounts`가 없으면 `channels`를 읽고 `channel_types`가 없으면 MVP 3채널을 허용한다(호환).

### 4.4 크레딧팩

| 코드 | 크레딧 | 가격 | 크레딧당 | 근거 |
|---|---|---|---|---|
| `pack_100` | 100 | 4,900원 | 49원 | 제안 |
| `pack_500` | 500 | 19,900원 | 39.8원 | 제안 |
| `pack_1500` | 1,500 | 49,000원 | 32.7원 | 제안 |

근거(제안): video 팩이 크레딧당 30~22원(`docs/products/_supabase-modular/seed.sql:63-66`)이다. blog 크레딧은 영상보다 원가가 작은 LLM 호출만 쓰지만 팩을 사는 사용자가 소량 구매자라는 점을 반영해 소량 팩 단가를 높게 두었다. 팩 크레딧은 pack 버킷이라 월 지급 만료와 무관하다.

### 4.5 환불(제안, 법률 검토 필요)

| 대상 | 규칙 |
|---|---|
| 구독 첫 결제 | 결제 후 7일 이내이고 그 결제 주기에 크레딧 사용 0, 발행 0이면 전액 환불. 그 외에는 해지 예약(현재 기간 끝까지 사용) |
| 정기 갱신 | 갱신 후 7일 이내이고 사용 0이면 전액 환불 |
| 크레딧팩 | 구매 후 7일 이내 미사용 팩만 전액 환불. 일부 사용 팩은 환불하지 않음 |
| 처리 | Toss 취소 API → `payments` 갱신 → 크레딧 조정(`CORE_SPEC.md` 5.4절, 코어에 `adjust_credits` 요청) → 감사 기록 |

### 4.6 AI·음성 크레딧 단가 (2026-10-13, 제안)

4.2절 단가와 4.4절 크레딧팩은 바꾸지 않는다. 4.2절의 LLM 작업은 FastAPI 라우터의 기능 키(`blog.assist`, `blog.post_draft`, `blog.compliance`)로 실행되며 크레딧 값은 그대로다. 제공자 단가는 코어 seed `core.ai_model_prices`(`docs/products/_supabase-modular/seed.sql:228-246`, 모두 제안값)이고 이 표는 그 값을 blog 기능에 적용한 것이다. 계산 상수는 `src/server/ai/pricing.ts`(4.2절과 같은 이유로 코드 상수). 선차감과 정산 규칙은 `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130`, 음성 단가는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104`를 따른다.

| 작업 | 선차감(예상) | 정산 | 상용 경로 예 | 오픈소스 경로 예 | 멱등 키 |
|---|---|---|---|---|---|
| AI 초안 그래프 빠름(`blog.post_draft`) | 5(= 키워드 1 + 초안 3 + 컴플라이언스 1). 제휴 자동 삽입 시 +1 | 정액, 차액 없음. `ai_usage`에 원가만 기록하고 `approve` 도달 때 `settled_at`을 채운다 | Claude 우선 | `oss-llm` | `consume:blog:<request_id>` |
| AI 초안 그래프 고품질 | 8(= 1 + 6 + 1). 제휴 자동 삽입 시 +1 | 같음 | 같음 | 같음 | 같음 |
| 글쓰기 도우미 채팅 1턴 | 3 | 실제 토큰 × 단가 + Dify 보조 노드 오버헤드 0.5, 올림. 최소 1, 상한 5(초과분은 운영사 부담) | 약 3~5 | 약 1~2 | `conv:<id>:turn:<n>` |
| 음성 받아쓰기 STT(5분 이하) | 녹음 길이 분 단위 올림 후 오픈소스 0.5cr/분, ElevenLabs 3cr/분(올림, 최소 1) | 실제 `audio_seconds` | 5분 15 | 5분 3 | `voice:<voice_job_id>` |
| 채팅 음성 질문 STT(60초 이하) | 오픈소스 1, ElevenLabs 3 | 실제 `audio_seconds` | 3 | 1 | `voice:<voice_job_id>` |
| 답변 읽어 주기 TTS | 답변 글자 수 × 단가, 천 자 단위 올림 | 실제 `characters` | 600자 답변 5 | 600자 답변 1 | `voice:<voice_job_id>` |
| 자료 색인(문서 1건) | 2(청크 200개 이하 기준, 초과 100청크마다 +1) | 정액 | 임베딩은 `oss-embed` 고정이라 경로 차이 없음 | 같음 | `run:<id>` |
| 위키 ingest(문서 1건, 갱신 페이지 최대 5) | 3 | 실제 사용량 | `wiki.ingest` oss 우선 | 약 1~3 | `run:<id>` |
| 위키 lint 수동 실행 | 2 | 실제 사용량 | - | - | `run:<id>` |
| 위키 주 1회 자동 lint | 사용자 과금 없음(Pro 이상 조직, 운영사 부담) | 사용량 | - | - | `run:<id>` |
| 단건 호출(키워드 단독, 제목·개요, 다시쓰기, 태그, 상품 키워드, 메시지 다듬기, 컴플라이언스 재검사) | 4.2절 그대로(각 1) | 정액 | - | - | `consume:blog:<request_id>` |
| 자료·위키 열람, 검색, SEO 점수 | 0 | - | - | - | - |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 경로별 단가 | 국외 이전에 동의하지 않은 조직은 체인에 오픈소스만 남으므로 오픈소스 단가가 자동 적용된다. 화면은 실제로 고른 경로의 예상치를 보여 준다 | `docs/products/_supabase-modular/migrations/0008_core_ai.sql:452-460` |
| 그래프 정액과 중복 방지 | 그래프 안의 키워드·초안·컴플라이언스 호출은 정액에 포함되어 따로 차감하지 않는다. 사용자가 원고를 고친 뒤 다시 검사하면 4.2절 컴플라이언스 1을 낸다 | 제안 |
| 실패 환불 | `approve` 도달 전 최종 실패(모든 제공자 실패, 스키마 불일치 재시도 소진)는 정액 전액 환불. 도달 뒤 반려는 환불하지 않는다(원고가 전달됨) | `docs/products/_platform-core/AI_ARCHITECTURE.md:129`, 제안 |
| 정산 시점 | 응답·작업 종료 직후. 스트림이 끊기면 선차감을 남기고 정산 잡이 `settled_at is null` 행을 5분 주기로 처리(제안) | `docs/products/_platform-core/AI_ARCHITECTURE.md:128` |
| 표시 | 보내기 전 "약 3크레딧(정산 후 1~5)", AI 버튼마다 예상 크레딧, 정산 결과는 메시지 아래와 원장 표에 | 제안 |
| 월 크레딧 영향 | 4.1절 근거(발행 1건 = 4크레딧)가 그래프 5크레딧으로 바뀐다. Free 20크레딧은 AI 원고 약 4편, Pro 300은 약 60편이다. 4.1절 숫자는 D-19 결정 전까지 유지한다 | 제안 |

## 5. 비기능 요구사항

| 항목 | 값 | 근거 |
|---|---|---|
| 페이지 응답(TTFB, 대시보드·목록) | p95 800ms 이하 | 제안 |
| 자동 저장 | 입력 멈춤 2초 뒤, 저장 p95 500ms | 제안 |
| 키워드·제목 동기 호출 | p95 15초, 타임아웃 60초 | `SHARED_MODULES.md` 8장(타임아웃 60초) |
| 원고 생성 잡 | 보통 분량 빠름 p95 60초, 고품질 p95 120초, 잡 타임아웃 180초 | 제안 |
| 발행 잡 | 워드프레스 30초, 네이버·티스토리 180초 타임아웃. 예약 시각 대비 시작 지연 5분 이내 | 제안 |
| 동시성 | 워커 컨테이너당 브라우저 컨텍스트 4개, 채널 계정당 1개 | 제안 |
| 재시도 | 발행 전 단계 실패만 3회(지수 백오프 60초 기준), 발행 버튼 이후 불확실은 재시도 없음 | `CORE_SPEC.md` 9.1절 + BL-F-045 |
| 원고 크기 | 제목 200자, 본문 JSON 500KB, 태그 30개(발행 시 채널 상한으로 자름) | `05_DATA_MODEL.md` 2.2절 |
| 업로드 | 이미지 10MB, JPG/PNG/WebP, 서버가 MIME 재검사 | `CORE_SPEC.md` 10장 |
| 레이트 리밋 | 생성 API 조직당 60회/분, `/r/[code]` IP 해시당 60회/분, 로그인 IP당 10회/10분, 브랜드커넥트 계정당 5건/시간 | `SECURITY_BASELINE.md` 8장 |
| 보존 | 원고: 삭제 시까지. 조직 삭제: 30일 유예 후 purge. 자격증명: 연결 해제 즉시 암호문 삭제. 클릭 로그 13개월(제안). 잡 결과(스캔 목록 등) 7일 뒤 결과 비움(제안). Playwright 실패 스크린샷 7일(제안) | `SECURITY_BASELINE.md` 12장 |
| 가용성 | 웹 99.5%/월, 예약 발행 성공률은 KPI로 관리 | 제안 |
| 감사 로그 보존 | 2년 | `CORE_SPEC.md` 11장(제안 값) |
| 채팅 첫 토큰 표시 | p95 3초 이하(Dify 경로는 HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 "근거를 찾는 중" 상태를 보인다, 제안) | 제안 |
| AI 초안 그래프 | `approve` 도달 p95 90초(빠름) / 150초(고품질), 잡 타임아웃 240초(기존 `blog.generate` 180초에서 연장, 제안). 조직당 동시 그래프 2개 | 제안 |
| 자료 색인 | 문서 1건(10MB 이하) p95 120초 | 제안 |
| STT 지연 | 받아쓰기 1분 분량 p95 10초 이하, 채팅 음성 질문 60초 분량 p95 8초 이하 | 제안 |
| TTS 첫 오디오 | p95 2초 이하 | 제안 |
| AI 레이트 리밋 | 채팅 사용자당 20턴/분 + 하루 `features.ai_chat_turns_per_day`, STT 사용자당 10회/분, 그래프 시작 조직당 10회/분(기존 생성 60회/분 안에서), 잡 토큰 발급 120회/분 | 제안: `docs/products/_platform-core/SECURITY_BASELINE.md:143-155` 기준 |
| AI 입력 상한 | 채팅 메시지 2,000자, 대화당 50턴, 받아쓰기 5분·20MB, 채팅 음성 질문 60초·5MB, 자료 파일 10MB·청크 1,000개 | 제안 |
| AI 기록 보존 | Dify 대화 로그 30일, `core.ai_messages`는 대화 삭제 또는 조직 삭제 후 30일, 자료 문서는 삭제 즉시 청크 포함 삭제 | `docs/products/_platform-core/AI_ARCHITECTURE.md:69`(제안 30일) |
| 3D 히어로 | 3D 번들+에셋 PC·태블릿 1MB, 모바일 300KB 이하, 60fps / 30fps 이상, LCP 2.5초 | `docs/products/_design-guide/HERO_3D.md:32-41` |

## 6. 법, 개인정보, 금지 문구

### 6.1 개인정보

| 항목 | 내용 |
|---|---|
| 수집 항목 | 계정: 이메일, 이름(표시명). 결제: Toss가 보관, 우리는 빌링키 암호문과 카드 마스킹만. 채널: 네이버/카카오(티스토리) 아이디·비밀번호 또는 세션 쿠키, 워드프레스 사용자명·애플리케이션 비밀번호, 블로그 주소. 제휴: 쿠팡파트너스 키, 파트너 ID. 콘텐츠: 원고, 체험 메모, 이미지. 로그: 감사 로그, 제휴 클릭(IP는 일 단위 솔트 해시만, 원문 IP 저장 금지) |
| 목적 | 원고 생성, 채널 발행, 제휴 링크 생성·통계, 브랜드커넥트 지원 대행, 결제와 고객 지원 |
| 암호화 대상 | `core.encrypted_credentials.ciphertext`(채널 계정 비밀번호, 세션 쿠키, 워드프레스 애플리케이션 비밀번호, 제휴 키), `core.billing_keys`. AES-256-GCM, 키는 환경변수 버전별(`SECURITY_BASELINE.md` 5장) |
| 보존과 삭제 | 연결 해제 → `revoke_credential`이 암호문을 즉시 비운다. 원고 삭제는 즉시 삭제, 조직 삭제는 soft delete 후 30일 뒤 purge. 결제 기록은 전자상거래법상 보존 기간(대금결제 5년)을 따른다 |
| 제3자 제공·처리 위탁 | LLM 제공자(2026-10-13 변경: Anthropic, OpenAI, Google, OpenRouter와 자체 운영 오픈소스 모델, 정본은 6.7절): 키워드, 원고 본문, 체험 메모, 지원 메시지, 자료 발췌. 국외 이전(미국 등) 고지 필요. 쿠팡파트너스 API: 검색어와 상품 URL. 네이버·티스토리·워드프레스: 발행 원고. Toss: 결제 정보. 체험 메모에 다른 사람의 개인정보를 쓰지 말라는 안내를 입력란에 둔다 |
| 로그 | 애플리케이션 로그에 비밀번호, 쿠키, 원고 전문을 남기지 않는다. Playwright 실패 스크린샷은 로그인 화면을 찍지 않고(입력 전 단계는 촬영 금지) 7일 뒤 삭제한다(제안) |

### 6.2 약관과 고지

| 항목 | 내용 |
|---|---|
| 이용약관 | 서비스가 사용자의 지시로 사용자 계정에 대신 로그인해 게시·지원한다는 점, 채널·제공자 약관 준수 책임이 계정 소유자에게 있다는 점, 자동화로 인한 노출 제한·계정 제한에 회사가 책임지지 않는 범위(법률 검토 필요) |
| 개인정보처리방침 | 6.1절 전부, 처리 위탁·국외 이전 목록 |
| 생성물 저작권과 책임 | AI 생성 원고의 사실 확인과 최종 게시 책임은 사용자에게 있다. 생성 직후 "발행 전에 사실과 수치를 확인하세요" 안내 |
| AI 생성 표시 | 글 하단에 "AI 도구를 활용해 작성한 글입니다" 표기를 기본으로 넣는다(제안). 사용자 해제 허용 여부는 인공지능 기본법의 표시 의무 적용 범위 확인 후 결정(미확인, 8장 열린 결정 5) |

### 6.3 제휴/광고(대가성 문구)

| 규칙 | 내용 | 근거 |
|---|---|---|
| 위치 | 제목 바로 아래 본문 첫 블록. 공정위 "추천·보증 등에 관한 표시·광고 심사지침"의 "제목 또는 본문 시작 부분" | `CORE_SPEC.md` 13.3절 |
| 끌 수 없음 | 제휴 매핑, 본문 내 제휴 도메인 링크, 브랜드커넥트 지원서 연결 중 하나라도 있으면 삽입. 설정 UI에 끄는 스위치를 두지 않는다. DB 불변식으로 막는다 | 확정 결정 12, `05_DATA_MODEL.md` 2.4절 |
| 편집 | owner/admin만, 10자 이상(core CHECK). 추가로 UI는 경제적 이해관계 단어("수수료", "원고료", "제공받", "광고") 중 하나를 포함해야 저장을 허용한다(제안) | `docs/products/_supabase-modular/migrations/0006_core_affiliate.sql:121` |
| 표시 방식 | 본문과 같은 크기 이상, 배경과 대비 4.5:1 이상, 이미지로만 넣지 않음, 접기·더보기 안에 넣지 않음 | 제안(심사지침의 "소비자가 쉽게 인식" 취지) |
| 기본 문구 | 쿠팡: 쿠팡 파트너스 고지 원문, 나머지: 심사지침 공통 문구 | `docs/products/_supabase-modular/seed.sql:117-131` |

### 6.4 플랫폼 약관 위험과 동의

네이버 블로그·티스토리 자동 게시와 네이버 브랜드커넥트 자동 지원은 공식 API가 아니라 Playwright로 사용자 계정에 로그인해 화면을 조작한다(`[5f6d262] Youtube_shots_Maker/CLAUDE.md:76` "공식 API 미제공 → Playwright 대체"). 네이버·카카오 약관과 운영정책의 자동화 관련 조항은 확인하지 않았다(미확인). 그래서 확인 전까지 "위반 가능성이 있다"는 전제로 고지와 동의를 받는다.

동의 흐름(채널 자동 게시와 브랜드커넥트 각각 따로 받는다):

| 단계 | 화면/동작 | 기록 |
|---|---|---|
| 1 | owner/admin만 동의 화면을 연다. member/viewer는 "관리자에게 요청하세요"만 보인다 | - |
| 2 | 아래 고지문 전문(버전 표시)을 스크롤 끝까지 읽어야 체크박스가 활성화된다 | - |
| 3 | 체크 3개: (a) 계정 제한·정지와 노출 제한 위험을 이해함 (b) 본인 소유 계정만 연결함 (c) 회사가 위 결과를 보상하지 않음을 이해함 | - |
| 4 | "동의합니다"를 직접 입력하고 동의 버튼 | 채널: `blog.consent_channel_automation_risk(account, version)`. 브랜드커넥트: `core.consent_brandconnect_risk(account)` + 서버 감사 `blog.brandconnect.risk_notice_ack {notice_version}` |
| 5 | 고지문 버전이 바뀌면 다음 자동 작업 전에 재동의를 요구한다 | 버전 비교 |
| 6 | 철회: 설정에서 언제든 철회. 대기 중 잡 취소, 이후 자동 작업 중단 | 감사 기록 |

고지문(버전 `bc-2026-10-v1`, 브랜드커넥트용. 채널용 `ch-2026-10-v1`은 "브랜드커넥트 지원"을 "블로그 글 자동 게시"로 바꾼 같은 구조):

```
네이버 브랜드커넥트 자동 지원 위험 안내

1. 이 기능은 네이버가 제공하는 공식 연동이 아닙니다. 서비스가 회원님의 네이버 계정으로
   로그인한 브라우저를 자동으로 조작해 캠페인을 찾고 지원서를 제출합니다.
2. 네이버 이용약관과 브랜드커넥트 운영정책은 자동화 프로그램 사용을 제한할 수 있습니다.
   이 때문에 다음 일이 생길 수 있습니다.
   - 브랜드커넥트 지원 제한, 활동 제한, 정산 보류
   - 네이버 계정 이용 제한 또는 정지
   - 블로그 글의 검색 노출 감소
3. 자동 지원은 계정당 1시간에 5건, 하루 20건으로 제한됩니다. 보안 문자(CAPTCHA)나 추가 인증이
   나오면 자동 작업을 멈추고 회원님께 다시 로그인을 요청합니다. 서비스는 보안 장치를 우회하지 않습니다.
4. 회원님 본인 소유의 계정만 연결해야 합니다.
5. 위 결과로 생긴 손해(수익 감소, 계정 제한 등)는 서비스가 보상하지 않습니다.
6. 언제든 설정에서 동의를 철회할 수 있으며, 철회하면 대기 중인 자동 지원이 모두 취소됩니다.
```

운영 원칙: CAPTCHA 자동 풀이, 봇 감지 우회 스크립트(입력값 직접 주입, 랜덤 마우스 이동, `AutomationControlled` 숨김), 프록시 순환을 쓰지 않는다(`NOMAD Shorts Maker/src/skill/playwright-engine/naver-login.ts:22`, `[5f6d262] Youtube_shots_Maker/backend/services/naver_blog.py:17-22`, `:155-170`은 복사 금지, 07장 4절).

### 6.5 금지 문구

| 대상 | 금지 | 대체 |
|---|---|---|
| 제품 마케팅(랜딩, 가격, 광고) | 미검증 사용자 수·생성 수·수익 통계(예: 원본 랜딩의 "128,470+ 생성"), "월 OO만원 수익 보장", "상위 노출 100%", "저품질 걱정 없음", 존재하지 않는 고객 후기·평점, "네이버 공식", "쿠팡 공식 파트너"처럼 제휴 관계를 오인하게 하는 표현 | 기능 설명과 실제 화면. 수치는 실데이터가 생긴 뒤 출처와 기간을 붙여서만 |
| 생성 원고 | 사용자 메모 없는 1인칭 구매·사용 경험("내돈내산", "직접 써 보니", "한 달 써 본 후기"), 지어낸 수치(만족도, 판매량, 할인율, 사용 기간), 가상 후기·별점, 의료·건강 효능 단정("완치", "효과 100%"), 금융 수익 보장, 타사 비방, 스폰서 원고의 "광고 아님" 표현 | 정보형 서술, 제공자 상품 정보 그대로 인용, 체험형은 사용자 메모 범위 안에서만 |
| 근거 | YSM 프롬프트가 "실사용 후기 (구체적 수치·비교 포함)", "내돈내산 솔직 리뷰 톤"을 요구했다(`[5f6d262] Youtube_shots_Maker/backend/services/blog_writer.py:41`, `:56`). 이 프롬프트는 복사하지 않는다 | |
| 검사 | 생성 프롬프트 금지 지시 + 컴플라이언스 규칙 사전(blog 추가분: 위 표현 목록) + LLM 판정 | `SHARED_MODULES.md` 13장 |

### 6.6 규제 특례

| 대상 | 규칙 |
|---|---|
| 건강기능식품, 의약품, 의료기기, 화장품 기능성 | 원고 키워드나 제휴 상품 카테고리가 해당하면 컴플라이언스가 WARN을 내고 "표시·광고 사전심의 대상일 수 있습니다" 안내(대상 범위 미확인) |
| 미성년자 | 만 14세 미만 가입 불가(제안). 제휴 수익 활동은 성인 대상 |
| 금융 상품 | 투자 수익 표현은 FAIL |

### 6.7 AI·음성 개인정보 판단과 대화 규칙 (2026-10-13)

| 항목 | 판단 | 이유와 처리 |
|---|---|---|
| 업로드 자료(브랜드·상품·캠페인) | 개인정보나 계약상 비공개 정보가 들어 있을 수 있다 | 업로드 화면에 "개인정보·비공개 계약 정보는 올리지 마세요" 안내와 "개인정보 포함" 체크(`contains_pii`). 임베딩은 어차피 `oss-embed`(02장 5.1절). 비공개 자료를 상용 AI로 보내도 되는지는 국외 이전 동의와 D-13으로 통제 |
| 체험 메모 | 사용자의 실제 경험이며 타인 정보가 들어갈 수 있다 | 입력란 안내 유지("다른 사람의 개인정보를 쓰지 마세요", 6.1절). 서버가 주민등록번호·전화번호·이메일·계좌번호 형식을 마스킹한 뒤 AI에 보낸다(제안) |
| 채널 비밀번호, 세션 쿠키, 워드프레스 애플리케이션 비밀번호, 제휴 키, 결제 정보 | 어떤 AI 입력에도 넣지 않는다 | 그래프 입력 스키마와 프롬프트 빌더에 비밀 필드가 없다(`credential_id`도 금지). 채팅에 비밀번호를 쓰면 안내 문구로 되돌리고 저장 전에 마스킹한다 |
| 오픈소스 강제 여부 | 기능에는 강제하지 않는다(`force_open_source=false`). 국외 이전 동의로 통제한다 | 글 품질이 제품 핵심이라 상용 우선. 동의가 없는 조직은 `resolve_ai_route`가 상용을 자동으로 걸러 낸다(`docs/products/_supabase-modular/migrations/0008_core_ai.sql:452-456`) |
| Dify 보조 노드 | 조직을 알 수 없어 동의를 확인할 수 없다 | `dify.aux`는 오픈소스 강제(`force_open_source=true`, 02장 5.1절) |
| 위키 | 개인 식별 정보를 정리해 넣지 않는다 | `contains_pii` 자료는 위키 ingest에서 제외. 개인정보 삭제 요청은 `core.purge_wiki_page`(`docs/products/_platform-core/LLM_WIKI.md:35`) |

| 고지·동의 | 시점 | 기록 |
|---|---|---|
| 상용 AI 국외 이전 | 이메일 인증 직후 온보딩, 설정에서 변경(기존 사용자는 AI 기능 첫 사용 직전) | `core.ai_org_settings`(`set_ai_cross_border_ack`, 고지문 버전) + 감사 `blog.ai.cross_border_ack` |
| 음성 처리 고지(녹음) | 첫 마이크 사용 직전(받아쓰기·음성 대화 공통). 녹음 목적, 원본 미저장, 상용 제공자 사용 시 국외 이전, "인터뷰·통화처럼 다른 사람의 목소리가 들어가는 내용은 상대에게 알리고 동의를 받으세요" 문구 | 감사 `blog.voice.notice_ack {notice_version}`. blog에는 동의 표가 없다. 녹음 원본을 저장하지 않으므로 `voice_jobs.store_audio=false`이고 녹음 보관 동의는 받지 않는다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:85-95`) |
| AI 생성 표시 | 원고 하단 "AI 도구를 활용해 작성한 글입니다"(6.2절, D-5), 채팅 답변마다 "AI가 생성한 답변", 읽어 주기 플레이어 "AI가 생성한 음성입니다", 위키 페이지 "AI가 정리한 문서(검수 전/검수됨)". 다른 모델로 대체된 답변은 "다른 AI 모델로 답했습니다" 표시 | 제안 |
| 제공자 목록 | 처리방침에 LLM(Anthropic, OpenAI, Google, OpenRouter), 음성(ElevenLabs)을 적고 오픈소스 LLM·임베딩·음성 서버와 Dify는 운영사가 자체 운영함을 적는다(서버 위치·위탁 여부는 구현 시 확인) | 6.1절 |

AI 대화·생성 추가 규칙(6.5절에 더해 채팅, 위키, 그래프에 적용):

| 분류 | 금지 | 대신 |
|---|---|---|
| 가상 후기·경험 | 사용자 메모 없는 1인칭 사용 경험, "후기 써 줘"식 가상 후기·별점 | 정보형·비교형 서술, 체험형은 사용자 메모 범위 안에서만 |
| 대가성 표기 회피 | "광고 표시 빼 주세요", 문구를 본문 아래로 옮기거나 이미지·흰 글씨·접기로 숨기기, 제휴 링크를 일반 링크처럼 위장 | 거절하고 대가성 문구는 자동으로 들어가며 끌 수 없다고 안내(설정 > 대가성 문구). 문구는 AI가 쓰거나 지우지 않는다 |
| 순위·수익 보장 | "상위 노출 보장", "월 OO만원 수익", "저품질 걱정 없음" | 일반적인 SEO 원칙 설명, 보장 표현 거절 |
| 타사 비방·사칭 | 경쟁사 비방, "네이버 공식", "쿠팡 공식 파트너" | 사실 기반 비교 |
| 의료·금융 단정 | 건강기능식품 효능 단정, 투자 수익 보장 | 단정 거절, 6.6절 규제 특례 안내 |
| 플랫폼 보안 우회 | CAPTCHA 풀이, 봇 감지 우회, 프록시 순환 요청 | 제공하지 않음. 채널 재인증 화면 안내(6.4절 운영 원칙) |
| 비밀 요구 | 비밀번호·쿠키·키를 채팅에서 묻거나 받기 | 묻지 않는다. 채널 연결 화면으로 안내 |

## 7. KPI

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| 활성화(가입 후 7일 안에 첫 발행) | 40%(제안) | `post_publications` 첫 published 시각 - 가입 시각 | 출시 후 3개월 |
| 키워드→발행 중앙값 | 15분 이하(제안) | 원고 생성 잡 생성 시각 → 첫 published 시각 | 월 |
| 발행 성공률 | 워드프레스 98%, 네이버·티스토리 90%(제안) | published / (published + failed), unconfirmed 별도 | 주 |
| unconfirmed 비율 | 3% 이하(제안) | unconfirmed / 발행 시도 | 주 |
| 대가성 문구 포함률 | 100% | `requires_disclosure and disclosure_included` / `requires_disclosure`(published 기준) | 상시(100% 미만이면 장애) |
| 브랜드커넥트 제출 성공률 | 85%(제안) | submitted / (submitted + failed) | 주 |
| 컴플라이언스 FAIL 후 수정 발행 비율 | 60%(제안) | FAIL 원고 중 이후 pass로 발행된 비율 | 월 |
| 유료 전환 | 가입 30일 내 5%(제안) | 엔타이틀먼트 plan pro/business | 월 |
| 계정 제한 신고 | 0건 목표, 1건이라도 생기면 자동화 상한 재검토 | 고객 지원 태그 | 월 |
| AI 도우미 사용률 | 첫 발행 사용자의 30%(제안) | `core.ai_conversations` 1개 이상 사용자 / 첫 발행 사용자 | 출시 후 3개월 |
| 그래프 승인율 | `approve` 도달 원고의 80%가 승인 후 발행(제안) | 승인 감사 행 / `approve` 도달 run | 월 |
| 컴플라이언스 첫 통과율 | 그래프 첫 결과의 PASS·WARN 비율 85% 이상(제안) | `ai_run_steps` compliance 결과 | 월 |
| 자료 근거 사용률 | 자료를 올린 조직의 그래프 결과 중 출처 1개 이상 비율 70%(제안) | `ai_run_steps` retrieve 결과 | 월 |
| 음성 받아쓰기 사용률 | 발행 사용자의 15%(제안) | `voice_jobs` feature `dictation` | 월 |
| AI 환불률 | AI 선차감 대비 환불 5% 이하(제안) | 원장 refund / AI consume | 주 |

## 8. 열린 결정

| # | 항목 | 선택지 | 권고 |
|---|---|---|---|
| 1 | 네이버 블로그에 쿠팡 링크 | (a) 경고 후 사용자 확인 시 허용 (b) 네이버 채널에서는 쿠팡 카드 차단 | (a). 확정 결정 12는 본문 자동 삽입을 정했고, 원본 주석(`naver-blog-poster.ts:2`)은 페널티 위험만 말한다. 자동 삽입은 네이버 채널에서 쿠팡 대신 네이버쇼핑 커넥트·브랜드커넥트를 우선한다 |
| 2 | 네이버 채널 링크 형식 | (a) 단축 링크 `/r/` (b) 제공자 직접 링크 | (b) 네이버, (a) 티스토리·워드프레스. 외부 단축 도메인이 노출에 미치는 영향은 미확인이라 보수적으로 |
| 3 | 텐핑·네이버쇼핑 커넥트 | (a) 공개 API 확인 후 어댑터 (b) Playwright (c) 수동 등록 유지 | (a) 확인 전까지 (c). (b)는 약관 확인 후에만 |
| 4 | 브랜드커넥트 무인 자동 지원(Phase 2) | (a) 키워드·카테고리 규칙 + 일일 상한 (b) 제공하지 않음 | (a). 규칙 저장용 `blog` 테이블은 Phase 2에서 추가(확정 결정 12의 "blog 스키마는 원고와 매핑만" 원칙과 충돌 여부 확인 필요) |
| 5 | AI 활용 표기 | (a) 기본 ON, 사용자 해제 가능 (b) 해제 불가 (c) 표기 안 함 | 법률 검토 후 결정. 확인 전 (a) |
| 6 | 네이버·티스토리 자격증명 | (a) 아이디·비밀번호 암호화 저장 후 워커 로그인 (b) 쿠키 가져오기(브라우저 확장) | MVP (a), Phase 2 (b) 추가. 2단계 인증 계정은 (b)만 가능 |
| 7 | 티스토리 공식 API | 공개 API 제공 여부 미확인 | 확인 전 Playwright. API가 있으면 어댑터 교체 |
| 8 | 모놀리스 스키마 | `public` | `MONOLITH_CORE_LITE.sql` 결정을 따른다. 사용자 최종 확인 |
| 9 | seed의 blog 플랜 | seed 샘플(월 10cr, `channels:1`) vs 이 문서 4.1절 | 4.1절로 seed 갱신(2026-10-13 반영 완료) |
| 10 | 인스타그램 | Phase 2 포함 vs 제외 | sns-uploader(video 소유) 일정에 맞춰 Phase 2 |
| 11 | 환불 정책 | 4.5절 | 법률 검토 후 확정 |
| 12 | 네이버 소셜 로그인 | 도입 여부. 도입 시 같은 이메일 자동 병합 금지, `naver_id` 매핑 + 로그인 상태에서 명시적 연결만 | MVP 미도입(이메일·Google·Kakao는 코어 auth 기본값을 따름) |
| D-13 | 비공개 브랜드 자료와 상용 AI | (a) 국외 이전 동의로 통제 + 업로드 안내(MVP 가정) (b) 자료별 "비공개" 표시 시 그 실행을 오픈소스로 강제(라우터에 호출 단위 강제 필요, 코어 요청) (c) 비공개 자료는 업로드 금지 | (a). 비공개 자료가 많은 사용자는 온보딩에서 "국내 오픈소스만"을 고르게 안내. (b)는 코어가 호출 단위 강제를 지원하면 재검토 |
| D-14 | 캠페인 요강·브랜드 소재의 AI 색인 허용 범위 | (a) 사용자가 정당하게 받은 자료만 올리게 하고 책임은 사용자에게(약관) (b) 브랜드커넥트 요강 자동 수집·색인 금지 (c) 허용 | (a)+(b). 네이버·브랜드의 이용 조건은 미확인. BL-F-032 스캔 결과를 자료 컬렉션에 자동 저장하지 않는다 |
| D-15 | 워커의 그래프 호출 인증 | (a) Next.js 잡 토큰 발급 엔드포인트 `/api/internal/ai-token`(워커 키 + running 잡 확인, org·사용자는 잡 행에서) (b) FastAPI가 잡을 직접 소비 (c) 워커에 개인키 배포 | (a). 개인키는 Next.js에만 둔다는 공용 규칙을 지키고 TS 워커를 유지한다(astro D-18과 같은 문제, 06장 AI-R3) |
| D-16 | 받아쓰기·읽어 주기 제공자와 ElevenLabs 데이터 보관 | (a) 받아쓰기 오픈소스 우선, 읽어 주기 ElevenLabs 우선, 보이스 1종 고정 (b) 사용자 선택. ElevenLabs 입력 보관·학습 사용·제로 리텐션은 계약 확인 후 처리방침 반영 | (a). 데이터 보관 조건은 미확인(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:83`) |
| D-17 | 채팅 화면 레퍼런스 Astryx | 존재·라이선스 확인 후 패턴만 사용 / 확인 실패 시 Primer + shadcn/ui 패턴 | 확인 전까지 미확인(`docs/products/_design-guide/DESIGN_SYSTEM.md:11`). blog의 주 레퍼런스는 Primer라 영향이 작다 |
| D-18 | 운영자 규정 해설집(표시광고법, 채널 가이드, SEO 원칙) 컬렉션 | (a) MVP는 규칙 사전만, Phase 2에 운영자 컬렉션 + 공개 위키 (b) MVP부터 운영자 컬렉션 | (a). 규정 해설은 법률 검토가 필요하고, MVP에서 AI가 법 해석을 답하지 않도록 한다(6.7절) |
| D-19 | 공정 사용 한도와 월 크레딧 재산정 | (a) 하루 채팅 턴 50/200/500, 문서 10/100/1,000, 4.1절 월 크레딧 유지 (b) 그래프 단가 5를 반영해 월 크레딧 상향(Free 25, Pro 375 등) | (a)로 출시, 실사용 원가(`core.ai_usage`)로 재산정 |
| D-20 | 반복 시리즈(BL-F-050) 무인 AI 초안의 사람 승인 | (a) 승인 면제 없음: 초안은 만들되 승인 전에는 발행 안 함 (b) 규칙 통과 시 면제(브랜드커넥트 무인 규칙과 함께) | (a). BL-F-052 원칙(되돌리기 어려운 발행 앞에는 사람 승인)을 유지, 면제는 Phase 2에서 법률 검토 후 |
