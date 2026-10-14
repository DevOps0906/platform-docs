# docs/products — 통합 제품 기획 인덱스

`docs/reviews/`의 25개 코드 리뷰와 통합 전 기능 분석(`00_MERGE_ANALYSIS.md`)을 바탕으로 비슷한 계열 프로젝트를 합치고, 빠진 기획을 채운 결과물이다. 이 폴더 아래에는 문서와 SQL만 있다. 원본 프로젝트 폴더는 수정하지 않았다.

## 폴더 구성

| 폴더 | 종류 | 원본 프로젝트 | 모듈러 스키마 | 마이그레이션 번호 |
|---|---|---|---|---|
| `_platform-core/` | 공통 | basic-master-module + 그룹 간 공통 결함 | `core` | 0000~0099 |
| `_design-guide/` | 공통 | 신규 | - | - |
| `_supabase-modular/` | 공통 | 신규 (통합 DB) | 전체 | - |
| `flora-publishing/` | 통합 | Flora-v2, flora, flora-publisher, SellingDocs | `publishing` | 1000 |
| `astro-ai/` (신비로운AI) | 통합 | Astro AI, FortuneDocs | `astro` | 1100 |
| `nomad-video/` (NOMAD AI Factory) | 통합 | NOMAD Shorts Maker, Nomad-BlogStudio, Youtube_shots_Maker | `video` | 1200 |
| `nomad-blog/` | 분리 신설 | Shorts Maker 내 Content Automator, Youtube_shots_Maker Track D | `blog` | 1300 |
| `nomad-commerce/` (NOMAD Commerce) | 통합 | Nomad-AI-Factory_V.2, nomad-ai-factory, nomad-ai-commerce, sellingstudio | `commerce` | 1400 |
| `microweb-studio/` | 통합 | premium-wedding-invitation, nexus-micro-web-builder, webcraft-agency-simulator | `microweb` | 1500 |
| `admin-suite/` | 통합(공유 코어 + 앱 3개) | ERP-Wesite, Hospital, School_Management_System | `erp`, `sms` (hms는 제외) | 1600, 1700 |
| `live-poll/` | 단독 | 구현해야 할 프로젝트/Slido_Project | `poll` | 1800 |
| `stock-dashboard/` | 단독 | 구현해야 할 프로젝트/Stock_Trader_nomad | `stock` | 1900 |
| `toon-factory/` | 단독 | Toon-Factory | `toon` | 2000 |
| `study-note/` | 단독 | study-note-organizer-codex-01 | `notes` | 2100 |
| `website-floria/` | 단독 | WebSite | `site` | 2200 |
| `nomad-docs/` (NOMAD Docs) | 신설 | 없음(설계 이식: flora-publishing, flora, SellingDocs, FortuneDocs) | `docs` | 2300 |
| `arch-studio/` (Arch Studio, 가칭) | 신설(설치형 데스크톱 + 시리얼 라이선스) | 없음(설계 이식: nomad-docs, flora-publishing, `_platform-core` AI 계층) | `arch`(제안) | 2400(제안) |

## 제품 폴더 표준 구성
| 파일 | 내용 |
|---|---|
| `README.md` | 한 줄 정의, 통합 근거, 원본 매핑 |
| `01_PRD.md` | 페르소나, MVP와 Phase 범위, 기능 요구사항과 수용 기준, 요금/크레딧, 비기능 수치, 법/개인정보, KPI |
| `02_ARCHITECTURE.md` | 스택, 모듈 경계, 잡/워커, AI 라우팅, 리뷰 "높음" 결함의 차단 설계 |
| `03_SCREENS_UX.md` | 화면 목록, 사용자 플로우, 메인페이지 디자인 방향 |
| `04_API.md` | Route Handler / RPC / Edge Function 명세 |
| `05_DATA_MODEL.md` | 테이블, RLS 정책, 모놀리스와 모듈러의 차이 |
| `06_AGENT_PLAN.md` | 멀티에이전트 개발 작업 분해(작업 ID, 소유 파일 경계, 의존성, 권장 모델, 수용 기준) |
| `07_SOURCE_MIGRATION.md` | 원본별 이식/폐기 자산, 복사 금지 결함 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/` | 단독 Supabase 프로젝트용 마이그레이션과 seed |

## DB 두 가지 구조

| 구조 | 위치 | 설명 |
|---|---|---|
| 모놀리스 | `<제품>/supabase/monolith/` | 제품마다 Supabase 프로젝트 1개. 인증, 조직, 크레딧 같은 공통 테이블을 제품 안에 축소해 포함한다. |
| 모듈러(통합) | `_supabase-modular/` | Supabase 프로젝트 1개에 `core` 스키마와 제품별 스키마를 둔다. 공통 테이블과 RLS 헬퍼를 core에 한 번만 정의한다. hms(병원)는 의료정보 격리를 위해 제외한다. |

## 모델 배치 원칙

| 모델 | 담당 |
|---|---|
| Fable 5.1 | 결제, 권한, RLS, 데이터 모델 같은 실수 비용이 큰 설계 (이번 작업에서는 `_platform-core`와 통합 DB core만) |
| Opus 5.5 | 기획 통합 분석, 기능 설계, API 연동, 테스트 설계, 검증 |
| Sonnet 5.5 | UI/메인페이지 구현, 컴포넌트, 문서 정리 |
| Haiku 5.5 | 보일러플레이트, 린트/타입 정리, 문구, 체크리스트 점검 |

## 확정 결정
`00_MERGE_ANALYSIS.md` 상단의 "확정 결정" 표를 따른다. 2026-10-12에 결정 12(제휴마케팅 공용 모듈)가 추가되었다.

## 진행 상태 (2026-10-13)

| 단계 | 내용 | 상태 | 산출물 |
|---|---|---|---|
| 0 | 폴더 골격, 통합 분석, 인덱스 | 완료 | `00_MERGE_ANALYSIS.md`, 이 문서 |
| 1 | 공용 코어, core DB, 디자인 가이드 | 완료 | `_platform-core/` 6개, `_supabase-modular/migrations/0000~0007`, `_design-guide/` 3개 |
| 2 | 제품 12개 기획과 DB | 완료 | 제품 폴더마다 문서 9개와 `supabase/`, 모듈러 조각 13개 |
| 3 | SQL 통합 검증, 구조 점검 | 완료 | `_supabase-modular/VERIFICATION.md`, `_STRUCTURE_CHECK.md` |
| 4 | 인덱스 마무리, 최종 보고 | 완료 | 이 절 |
| 5 | AI 계층·음성·3D 히어로·디자인 시스템 반영, 개발 방법 문서 12개 | 완료 | 아래 "2026-10-13 AI 계층 추가", `../develop/<제품>/` |
| 6 | 네이버 클립·브랜드커넥트 범용화·toon 벤치마킹·쇼츠 대행 (확정 결정 18~21) | 완료 | 아래 "2026-10-13 결정 18~21", PR #2 |
| 7 | 인증 단계: Mock → Google → 카카오·네이버 (확정 결정 22), 13개 제품 반영 | 완료 | 아래 "2026-10-14 인증 단계", `_platform-core/AUTH_ROADMAP.md` |

## 제품별 결과

| 제품 | 리뷰 "높음" = 차단 설계 | 06장 작업 | RLS 스모크(모듈러 / 모놀리스) | 사용자 결정 위치 |
|---|---|---|---|---|
| flora-publishing | 25 | 38 | 57/57 / 57/57 | `flora-publishing/01_PRD.md` 8절 |
| astro-ai | 14 | 38 | 65/65 / 64/64 | `astro-ai/01_PRD.md` 8절 |
| nomad-video | 26 | 40 | 65/65 / 65/65 | `nomad-video/01_PRD.md` 8절 |
| nomad-blog | 16 | 40 | 69/69 / 67/67 | `nomad-blog/01_PRD.md` 8절 |
| nomad-commerce | 22 | 40 | 60/60 / 59/59 | `nomad-commerce/01_PRD.md` 8절 |
| microweb-studio | 10 | 35 | 87/87 / 87/87 | `microweb-studio/01_PRD.md` 8절 |
| admin-suite | 14 | 40 | 92/92 / erp 21, sms 19, hms 52 전부 통과 | `admin-suite/01_PRD.md` 8절 |
| live-poll | 4 | 32 | 79/79 / 77/77 | `live-poll/01_PRD.md` 8절 |
| stock-dashboard | 6 | 34 | 75/75 / 75/75 | `stock-dashboard/01_PRD.md` 8절 |
| toon-factory | 6 | 40 | 68/68 / 68/68 | `toon-factory/01_PRD.md` 8절 |
| study-note | 3 | 30 | 84/84 / 85/85 | `study-note/01_PRD.md` 8절 |
| website-floria | 8 | 32 | 72/73 (실패 1건은 core 결함, 0007로 해소, 단계 3 통합 검증 통과) / 71/71 | `website-floria/01_PRD.md` 8절 |
| 합계 | 154 | 439 | | |

통합 DB(core + 조각 13개 + seed) 결과는 `_supabase-modular/VERIFICATION.md`를 따른다.
- 두 가지 적용 순서 모두 OK다.
- PUBLIC EXECUTE 남은 함수 0개, search_path 없는 DEFINER 0개, RLS 꺼진 테이블 0개다.
- 교차 조직 누출은 129개 테이블에서 0건이다.

06장 작업의 모델 배분(439개)은 Fable 76(17.3%), Opus 211(48.1%), Sonnet 112(25.5%), Haiku 40(9.1%)이다.

## 개발 순서 (제안)

| 웨이브 | 대상 | 이유 |
|---|---|---|
| 0 | `_platform-core` 패키지, core DB 0000~0007, 통합 seed | 모든 제품이 의존한다 |
| 1 | study-note, website-floria | 범위가 작아 core 계약을 먼저 실전 검증한다 |
| 2 | flora-publishing, astro-ai | 공용 WeasyPrint 렌더 서비스를 함께 만든다 |
| 3 | nomad-video, nomad-blog, nomad-commerce | affiliate·SNS 업로더·잡 워커를 공유한다 |
| 4 | microweb-studio, live-poll, toon-factory | 독립 도메인이다 |
| 5 | admin-suite, stock-dashboard | 의료정보·금융 규제 확인이 먼저 필요하다 |

## 남은 코어 과제

| 과제 | 출처 |
|---|---|
| `adjust_credits` RPC 추가 | 여러 제품 06장 6절 |
| 익명 사용자 가입 시 개인 조직 생성 건너뛰기 | `live-poll/06_AGENT_PLAN.md` 6절 |
| 팀 조직 생성 함수, `purge_organization`과 결제 기록 보존 충돌 | `admin-suite`, `astro-ai` 06장 6절 |
| `write_audit` action 제한(멤버가 임의 action 기록 가능) | `_platform-core` 작성 보고 |
| 로컬 Supabase(`supabase db reset`)에서 재검증 | 검증은 PGlite 기준 |

2026-10-13에 처리한 결함

| 결함 | 처리 |
|---|---|
| 금액 불일치 주문이 failed로 남지 않음 | `confirm_payment_order`는 PM001 유지, 서비스 전용 `fail_payment_order` 추가 |
| `signup_policy='invite'` 미강제 | 가입 트리거가 invite 앱 엔타이틀먼트를 만들지 않음, 사용자 `bootstrap_app_for_org` 거부 |
| `has_entitlement`/`entitled_plan_code` anon 호출 | anon EXECUTE 회수 |
| storage 정책의 deprecated `owner` 컬럼 | `owner_id = auth.uid()::text` |
| 감사 로그 INSERT의 무의미한 `on conflict` | 제거 |

같은 수정을 모듈러 core(0001~0005), `MONOLITH_CORE_LITE.sql`, 제품별 `0001_core_lite.sql` 14개에 적용했다. 통합 적용, 모놀리스 14세트, 권한 감사, 교차 조직 스모크, 새 동작 13항목(모듈러·라이트 각각)을 다시 통과했다.

## 2026-10-13 AI 계층 추가

확정 결정 13~17(`00_MERGE_ANALYSIS.md` 상단 표)을 추가했다. 12개 제품 모두 MVP에 AI 기능과 음성 대화를 넣는다. 제품 문서(01~06)는 이 문서들을 인용만 하고 재정의하지 않는다.

| 결정 | 내용 |
|---|---|
| 13 | AI 계층: FastAPI LangChain/LangGraph, pgvector, Voyage 임베딩. LLM Wiki(제품 위키 + 개발 위키) 포함 |
| 14 | Dify: 채팅·운영용 공용 자체 호스팅 1개. 지식·도구는 FastAPI |
| 15 | 3D 히어로 표준: PC·태블릿 풀 3D, 모바일 절충안(가벼운 3D 자동 로드 유지, 로딩 전 저사양 판정, 공용 3D 키트) |
| 16 | 음성: 음성 대화 + 제품 음성 기능. ElevenLabs(TS)와 오픈소스 GPU 음성 서버 이원화 |
| 17 | LLM 이원화: 상용(ChatGPT, Claude, Gemini 등) + 오픈소스 vLLM 병행, 라우팅·대체 |

| 문서 | 내용 |
|---|---|
| `_platform-core/AI_ARCHITECTURE.md` | AI 계층 구조, 서명 토큰, Dify 연동, 모델 라우팅, RAG, 그래프 |
| `_platform-core/LLM_WIKI.md` | 제품 지식 위키와 개발용 프로젝트 위키 |
| `_platform-core/VOICE_ARCHITECTURE.md` | 음성 이원화, 대화 흐름, 개인정보 |
| `_design-guide/HERO_3D.md` | 3D 히어로 표준, 저사양 판정, 공용 3D 키트, 제품별 소재 |
| `_design-guide/DESIGN_SYSTEM.md` | 디자인 시스템 규칙(Primer·Atlassian·Astryx 참고), 정답 소스는 Tailwind CSS v4 CSS + 코드 컴포넌트, 4단계 구축 워크플로, 작업 지시 템플릿 |
| `_supabase-modular/migrations/0008_core_ai.sql`, `0009_core_voice.sql` | AI·음성 코어 SQL (검사는 `check.mjs --vector`) |
| `../develop/_shared/{dify,voice,llm,llm-wiki}/` | 공용 설치·운영 가이드, 개발 위키 스킬 원본 |

고문 검토 반영 결정(2026-10-13)

| 번호 | 결정 |
|---|---|
| 1 | Dify에 토큰을 넘기지 않고 대화 매핑(대화 id + 서버 생성 `dify_user`)을 쓴다 |
| 2 | 서명 토큰은 EdDSA(Ed25519) 공개키 방식, 제품별 `iss`/`aud`, JWKS 검증 |
| 3 | hms는 전용 서버(LLM, 음성, 임베딩)만 쓴다. 공용 GPU 서버, 상용 API, 공용 Dify 미사용 |
| 4 | 상용(국외) 대체 경로는 조직이 국외 이전에 동의한 경우에만(`set_ai_cross_border_ack`, `AI002`) |
| 5 | 크레딧은 선차감 + 정산 |
| 6 | 위키 삭제는 보관(archive), 개인정보 삭제 요청은 `purge_wiki_page`로 개정 이력까지 실제 삭제 |
| 7 | 모바일 히어로는 가벼운 3D 자동 로드를 유지하되 로딩 전 저사양 판정, 공용 3D 장면 키트 |

기술 스택 고정: **Tailwind CSS v4** (v3 문법과 `tailwind.config.js` 금지).

갱신한 기존 문서: `SHARED_MODULES.md`(19장), `CORE_SPEC.md`(17장), `SECURITY_BASELINE.md`(16장), `DB_CONVENTIONS.md`(14장), `DOC_TEMPLATE.md`, `DESIGN_PRINCIPLES.md`, `_supabase-modular/`(README, ARCHITECTURE, VERIFICATION 10장), `_PRODUCT_AGENT_BRIEF.md`. 위 "제품별 결과" 표는 AI 계층 반영 전 상태이고, 반영 후 수치는 아래 표를 따른다.

### AI 계층 반영 결과 (2026-10-13)

| 제품 | 06장 작업 | 개발 문서 | 문서 경로 검사(참조 / 누락) |
|---|---|---|---|
| flora-publishing | 55 | `../develop/flora-publishing/` | 443 / 0 |
| astro-ai (기준 예시) | 54 | `../develop/astro-ai/` | 531 / 0 |
| nomad-video | 56 | `../develop/nomad-video/` | 341 / 0 |
| nomad-blog | 56 | `../develop/nomad-blog/` | 383 / 0 |
| nomad-commerce | 57 | `../develop/nomad-commerce/` | 434 / 0 |
| microweb-studio | 53 | `../develop/microweb-studio/` | 340 / 0 |
| admin-suite | 57 | `../develop/admin-suite/` | 387 / 0 |
| live-poll | 48 | `../develop/live-poll/` | 338 / 0 |
| stock-dashboard | 51 | `../develop/stock-dashboard/` | 455 / 0 |
| toon-factory | 59 | `../develop/toon-factory/` | 384 / 0 |
| study-note | 52 | `../develop/study-note/` | 290 / 0 |
| website-floria | 48 | `../develop/website-floria/` | 360 / 0 |
| 합계 | 646 | | |

06장 작업의 모델 배분(646개)은 Fable 116(18.0%), Opus 304(47.1%), Sonnet 174(26.9%), Haiku 40(6.2%), 사람 12(1.9%, 디자인 시스템 3단계 비주얼 검토)이다.

검증(PGlite 기준, 실제 Supabase 재검증은 남은 코어 과제)
- 통합 DB(0000~0009 + seed + 조각 13개)를 정순·역순으로 적용했고 모두 OK다(`check.mjs --vector`).
- 모놀리스 14세트(admin-suite erp·hms·sms 포함)가 모두 OK다.
- AI 보안 테스트 25/25(모듈러, 라이트 각각): 교차 조직 차단, `match_ai_chunks` 조직 필터, 국외 이전 미동의 시 상용 제외, AI001·AI002, 음성 녹음 만료, `purge_wiki_page`.
- setup 스크립트 24개: `bash -n`과 PowerShell 구문 분석 오류 0, 드라이런 24회 모두 정상, 대상 폴더를 만들지 않음.
- 고문(Fable) 교차 검토: 조건부 통과. 지적 12건 중 9건 반영, 1건 유지(microweb 기능 키 밑줄 표기는 모놀리스 변환 때문에 의도된 것, `microweb-studio/02_ARCHITECTURE.md:11`), 2건은 사용자 결정 대기(아래).

교차 검토 반영 내역
- nomad-video `video.script` 그래프 순서를 `… → metadata → compliance`로 바꿨다(02·01·03·06장, 개발 문서).
- `AI_ARCHITECTURE.md` 2.1절에 잡 토큰 규격을, 6절에 "compliance 뒤에는 비생성 노드만" 규칙을 추가했다.
- `VOICE_ARCHITECTURE.md`에 업무용 앱 TTS 오픈소스 우선 예외를, `HERO_3D.md`에 킬 스위치 `NEXT_PUBLIC_HERO3D_ENABLED`를 추가했다. 줄 번호 인용이 깨지지 않도록 기존 줄 안에서 고쳤다.
- nomad-video 01장 8절 번호를 D-1~D-12로 통일, stock-dashboard 모바일 3D 문구 정리, 낡은 `AI_TOKEN_SECRET` 참조 문구 정리, nomad-commerce 개발 문서의 작업 ID 오기(CM-06-001) 수정.

사용자 결정(2026-10-13 확정, 모두 권장안)
| 번호 | 결정 | 반영 위치 |
|---|---|---|
| A | 임베딩: 플랫폼 기본 Voyage, 제품 지식 컬렉션 기본 오픈소스(oss-embed). 임베딩 체인은 새 컬렉션의 제공자를 고를 때만 쓰고, 기존 컬렉션은 기록된 제공자·모델로만 색인·검색하며 대체하지 않는다 | `_platform-core/AI_ARCHITECTURE.md` 5절 임베딩 행, `00_MERGE_ANALYSIS.md` 결정 13 (SQL 변경 없음: 제품 seed가 이미 oss-embed, 컬렉션 모델 열은 `ai_collections`에 있음) |
| B | admin-suite AI 과금 예외 승인: 선차감·정산 없이 플랜 포함 한도 + `ai_usage` 원가 기록(D-10 A 확정) | `AI_ARCHITECTURE.md` 7절, `00_MERGE_ANALYSIS.md` 결정 13, `admin-suite/01_PRD.md` 4.1절·8절, admin-suite 개발 문서 |
| C | 낭독류 TTS 기본 모드를 `auto` + ElevenLabs 우선으로 통일(같은 목소리 기능의 작업 도중 대체 금지는 유지) | 조각 1000·1100·1400·1900·2000과 해당 모놀리스 seed 5개, 5개 제품 02·05장, `VOICE_ARCHITECTURE.md` 3절 |

반영 후 재검증: 통합 DB 정순·역순 OK, 모놀리스 14세트 OK, AI 보안 테스트 25/25(모듈러·라이트), root 12개 재생성 후 경로 누락 0.

## 2026-10-13 결정 18~21 (네이버 클립, 브랜드커넥트, toon 벤치마킹, 쇼츠 대행)

PR: https://github.com/DevOps0906/platform-docs/pull/2 (병합 커밋 `f868eb7`). 결정 원문은 `00_MERGE_ANALYSIS.md` 확정 결정 18~21.

| 주제 | 먼저 볼 문서 | 관련 문서 |
|---|---|---|
| 네이버 클립 채널(결정 18) | `nomad-video/01_PRD.md` VD-F-075, 6.5절 위험 고지, D-23 | `nomad-video/02~06`, `_platform-core/SHARED_MODULES.md` 11장, `_supabase-modular/migrations/1200_video.sql` |
| 브랜드커넥트 범용화(결정 19) | `_platform-core/CORE_SPEC.md` 13장, 16.1절 | `nomad-blog/01_PRD.md` 3.4절(BL-F-036/037), `nomad-blog/04_API.md`, `_supabase-modular/migrations/0006_core_affiliate.sql` |
| toon-factory 벤치마킹(결정 20) | `toon-factory/08_BENCHMARK.md` (비교표, 격차→제안, 분기 재점검 방법) | `toon-factory/01_PRD.md` TN-F-024/038/070~073/080/081, `_supabase-modular/migrations/2000_toon.sql` 11절 |
| 쇼츠 대행사업(결정 21) | `nomad-video/08_AGENCY_OPERATIONS.md` (패키지, 가격 근거, 프로세스, 필요 문서 14종, 법적 위험) | `nomad-video/01_PRD.md` VD-F-120~126, `nomad-docs/01_PRD.md` DC-F-046 `shorts_agency`, `_supabase-modular/migrations/2300_docs.sql` |

확인 필요: 네이버 약관의 자동화 조항(미확인), 공정위 AI 가상인물 표시 개정안 확정 여부(미확인), 이미 배포된 DB에는 별도 `alter table` 필요.

## 2026-10-14 인증 단계 (확정 결정 22)

정본은 `_platform-core/AUTH_ROADMAP.md`다. 개발 1단계(MVP)는 로컬 Supabase 시드 계정으로 실제 JWT를 받는 Mock 로그인(Stage A), 모든 MVP 기능이 동작하면 사람이 G1을 판정하고 Google OAuth(+ 제품에 따라 이메일·초대 메일, Stage B), 그것이 안정되면 G2 후 카카오(C1)·네이버(C2)를 붙인다. 쿠키에 역할을 적는 Mock은 금지이고, 단계 분기 코드는 인증 모듈(`src/lib/auth/` 또는 admin-kit `src/auth/`)과 로그인·콜백·`/api/dev/login`에만 둔다. 개발 묶음의 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md`(DOC-CORE-009)로 들어간다.

| 제품 | 06장 작업 | A(Mock) | B(Google) | C1 카카오 | C2 네이버 | 문서 경로 검사(참조 / 누락) |
|---|---|---|---|---|---|---|
| flora-publishing | 65 | PB-06-006 | PB-06-056 | PB-06-057(P1) | PB-06-058(P1) | 490 / 0 |
| astro-ai | 57 | AS-06-003 | AS-06-055 | AS-06-056(P1) | AS-06-057(P1) | 574 / 0 |
| nomad-video | 65 | VID-06-004 | VID-06-063 | VID-06-064(P1) | VID-06-065(P1) | 377 / 0 |
| nomad-blog | 59 | BL-06-004 | BL-06-057 | BL-06-058(P1) | BL-06-059(P1) | 427 / 0 |
| nomad-commerce | 60 | CM-06-007 | CM-06-058 | CM-06-059(P1) | CM-06-060(P1) | 473 / 0 |
| microweb-studio | 56 | MW-06-003 | MW-06-054 | MW-06-055(P2 선택) | MW-06-056(P2 선택) | 378 / 0 |
| admin-suite | 60 | ADM-06-007 | ADM-06-058(hms는 이메일만) | ADM-06-059(erp·sms P2 선택, hms 제외) | ADM-06-060(같음) | 433 / 0 |
| live-poll | 51 | LP-06-003 | LP-06-049 | LP-06-050(P1) | LP-06-051(P1) | 382 / 0 |
| stock-dashboard | 54 | ST-06-006, 009 | ST-06-052 | ST-06-053(P2 선택) | ST-06-054(P2 선택) | 495 / 0 |
| toon-factory | 69 | TN-06-004, 027 | TN-06-067 | TN-06-068(P1) | TN-06-069(P1) | 428 / 0 |
| study-note | 55 | NT-06-006 | NT-06-053 | NT-06-054(P1) | NT-06-055(P1) | 326 / 0 |
| website-floria | 49 | SI-06-019 | SI-06-049 | 제외 | 제외 | 396 / 0 |
| nomad-docs | 65 | DC-06-014 | DC-06-063 | DC-06-064(P1) | DC-06-065(P1) | 607 / 0 |
| 합계 | 765 | | | | | |

각 제품 반영 위치는 `AUTH_ROADMAP.md` 10장 그대로다: 01장 2절·가입 FR·6절·8절(인증 결정), 02장 9절, 03장 7절, 04장 8절, 05장 10절(시드 페르소나), 06장 8절, 07장 6절(복사 금지), `CLAUDE.md` "인증 단계 규칙", 개발 안내서 19장. 네이버를 서버 브리지로 붙이게 되면 코어 `staged/0010_core_auth_identity_links.sql`을 한 번만 적용한다(각 제품 06장 코어 요청).

같은 날 flora-publishing은 "FLORA 개편"(에이전트 실행 계층 `agent_tasks`, 운영 콘솔, 디자인 레이어 3종, PB-06-059~065)을 따로 반영했다. 이 개편은 flora 전용이고 다른 제품에는 넣지 않았다.
