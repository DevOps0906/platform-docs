# NOMAD Commerce (nomad-commerce)

작성일 2026-10-12. 단계 2 제품 기획 산출물. 장 구조는 `docs/file/03-설계/공용코어/DOC_TEMPLATE.md` 2.1절을 따른다.

## 1. 한 줄 정의

쿠팡·스마트스토어에 상품을 올리는 국내 셀러가 아마존·국내 도매 상품을 가져와 상품DB에 쌓고, AI로 슬롯형 상세페이지(이미지 10장/15장, 카피, 금지어 검사)를 만든 뒤, 마켓 규격으로 변환해 API 업로드하거나 엑셀(플레이오토 호환)/ZIP으로 내려받는 SaaS다.

2026-10-13부터 상품 스펙·마켓 규칙 RAG, 마켓 규칙 위키(쿠팡·스마트스토어), 상세페이지 생성 그래프(`commerce.detail_page`), 셀러 어시스턴트 채팅, 음성(상품 설명 입력, 쇼츠 내레이션, 음성 대화), 3D 히어로가 MVP에 들어간다(확정 결정 13~17). 쇼츠 영상 렌더 엔진은 nomad-video 소유이고 commerce는 워커 API만 호출한다.

| 항목 | 내용 |
|---|---|
| 대상 사용자 | 부업 셀러, 여러 마켓을 운영하는 중급 셀러, 건강식품 구매대행 소싱러(`Nomad-AI-Factory_V.2/PRD.md:17-23`) |
| 브랜드 | NOMAD Commerce(확정 결정 10, `docs/reference/00_MERGE_ANALYSIS.md:18`). "NOMAD AI Factory"는 nomad-video가 쓴다 |
| 모듈러 스키마 | `commerce`, 마이그레이션 번호 1400~1499(`D:/WorkSpace/platform/docs/products/README.md:16`) |

## 2. 통합 근거

| 근거 | 내용 |
|---|---|
| 같은 도메인 4벌 | 네 원본이 모두 "소싱 → AI 상품 콘텐츠 → 마켓 등록"을 다룬다(`docs/reference/00_MERGE_ANALYSIS.md:743`) |
| 기획 정본 = V.2 | 슬롯, 마켓 규격, 등록 폼 등 도메인 스펙이 가장 깊다(`docs/reference/reviews/Nomad-AI-Factory_V.2.md:20-21`, `00_MERGE_ANALYSIS.md:745-746`) |
| 코드 베이스 = sellingstudio | 네 원본 중 로그인 → 생성 → 저장 → fal webhook → Realtime이 실제 연결된 유일한 코드, 완성도 약 55%(`docs/reference/reviews/sellingstudio.md:19-20`, `00_MERGE_ANALYSIS.md:747-750`) |
| v1, nomad-ai-commerce | v1은 Vite SPA라 V.2를 얹을 수 없고(`docs/reference/reviews/nomad-ai-factory.md:86`), CM은 코드 재사용 가치가 낮다(`docs/reference/reviews/Nomad-AI-Factory_V.2.md:117`). 프롬프트, 캔버스 설계, 화면 흐름, 플랜 상수만 참고 |
| 확정 결정 | 4(Toss 단일 PG), 5(org 스키마 + 1인 1워크스페이스), 7(MVP: 쿠팡 + 스마트스토어 + 엑셀/ZIP, SNS 없음), 8(V.2 가격표 + sellingstudio 크레딧 환산), 9(Capacitor는 MVP 이후), 10(브랜드), 1·12(블로그 원고는 nomad-blog로, 제휴 링크는 core affiliate + video/blog로. commerce 범위 밖) |

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| `Nomad-AI-Factory_V.2` (기획만) | `docs/reference/reviews/Nomad-AI-Factory_V.2.md` | 기획 약 60% | 18슬롯과 유형별 기본 슬롯, 마켓 이미지 규격, 등록 폼 필드, 8단계 파이프라인, 가격표, 금지어 목록, 엑셀 파서 필드맵 | Zustand 큐 + SSE 예제, 리뷰형 AI 후기, 반품 불가·건기식 부정 문구 자동 삽입, 랜딩 허위 수치, 중복 디자인 문서, DALL-E 3 |
| `nomad-ai-factory` (v1) | `docs/reference/reviews/nomad-ai-factory.md` | 약 30% | 리스팅 프롬프트(톤·채널 가이드), OpenRouter 모델 화이트리스트·json 모드, 캔버스 위상 정렬 설계 | Vite SPA, 공개 AI 프록시, localStorage 키 저장, 클라이언트 한도 판단, 죽은 코드 4,500줄 |
| `nomad-ai-commerce` | `docs/reference/reviews/nomad-ai-commerce.md` | 약 25% | 화면 흐름(수집 탭, 다계정 선택 업로드), 노드 실행기 분리 구조, 플랜 정책 상수 형태 | 쿠키 권한, 모의 로그인, 평문 키 반환 API, SSRF·raw_html, tableName insert, globalThis 잡, `\b` 한글 금지어 정규식 |
| `sellingstudio` | `docs/reference/reviews/sellingstudio.md` | 약 55% | `proxy.ts`, Supabase 클라이언트 3종, zod 검증, `lib/llm/openrouter.ts`, `lib/image/fal.ts`, 입력 5종(텍스트/Vision/URL/음성/네이밍), Realtime 뷰어 구조, 크레딧 단가와 플랜 크레딧 | 분리 차감 `/api/credits/use`, 클라이언트 `selling_pages` insert, `USING(true)` 정책, 무서명 webhook, Stripe, 거대 컴포넌트 2개의 목업 탭, 미사용 의존성 14개 |

세부 이식/폐기 목록은 `07_SOURCE_MIGRATION.md`.

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, MVP/Phase 범위, 기능 요구사항(CM-F-###, AI·음성 CM-F-040~052 포함), 요금/크레딧(AI·음성 단가 4.6절), 비기능 수치, 법/개인정보/금지 문구(AI 6.1절), KPI, 열린 결정(D-1~D-17, 인증 단계 D-18~D-20은 8.1절) |
| `02_ARCHITECTURE.md` | 스택(FastAPI·LangGraph·Dify·음성·3D 포함), 모듈 경계, 공용 모듈 사용, 잡/워커와 그래프 호출, AI 라우팅 기본값 14행과 그래프 2개(`commerce.detail_page`, `commerce.assist`), 리뷰 "높음" 차단 설계(비보안 5건), 배포, 환경변수, 인증 단계(9절: 단계표, 분기 위치, 인증 env, 외부 콘솔) |
| `03_SCREENS_UX.md` | 화면 목록, 플로우(AI 채팅·음성·내레이션·위키 포함), 화면별 명세, 디자인 시스템(Primer 주, Atlassian 보조), 랜딩 디자인 방향과 3D 히어로, 상태/오류, 접근성, 로그인 화면 단계별 구성(7절) |
| `04_API.md` | Route Handler(`/api/ai/*`, `/api/voice/*` 포함), RPC, 잡 페이로드, 그래프 계약, 웹훅, 외부 어댑터, FastAPI 엔드포인트, Dify 계약, 오류 코드, 인증 단계 경로(8절) |
| `05_DATA_MODEL.md` | 테이블 13개(AI 전용 제품 테이블 없음, 코어 AI·음성 표 참조), 상태 전이, RLS, 인덱스, 코어 참조, 리뷰 "높음" 차단 설계(보안·데이터 17건), 모놀리스/모듈러 차이, AI 라우팅 검증 결과, 개발용 시드 페르소나(10절, 스키마 변경 없음) |
| `06_AGENT_PLAN.md` | 작업 60개(AI·음성·3D·디자인 시스템 17개, 인증 단계 B·C 3개(CM-06-058~060, 8절) 포함), 웨이브, 모델 비율, 리뷰 작업 흡수표 57행, 코어 요청(AI 계층 R-1~R-8, 인증 R-9) |
| `07_SOURCE_MIGRATION.md` | 원본별 이식/폐기, 폐기 23항목, 복사 금지 결함, 아카이브 절차, 인증 단계 복사 금지(6절: `mock-login`·쿠키 역할, MVP 카카오 버튼) |
| `CLAUDE.md` | 개발 에이전트 지침, 인증 단계 규칙(맨 끝 절) |
| `supabase/monolith/` | `0001_core_lite.sql`(코어 lite 복사, affiliate 절 제거, AI·음성 SECTION 11·12 포함), `0002_commerce_domain.sql`(모듈러 조각 변환본), `seed.sql`(플랜 AI 키와 AI 라우팅 기본값 14행 포함) |
| 모듈러 조각 | `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1400_commerce.sql`(20절 AI·음성 기본값 포함) |

## 4.1 AI 요약 (2026-10-13)

| 영역 | 내용 |
|---|---|
| 그래프 | `commerce.detail_page`(정보 추출 → 규칙 검색 → 카피 → 금지어 → 마켓 형식 변환 → compliance), `commerce.assist`(상품명·자동완성·벤치마킹 요약·Vision·음성 구조화·쇼츠 스크립트). 텍스트 생성만 FastAPI이고 이미지·합성·마켓 변환·업로드는 TS 워커 |
| 지식 | 마켓 규칙 RAG와 위키(운영자 조직, 쿠팡·스마트스토어), 상품 스펙 RAG(셀러 조직). 임베딩은 오픈소스 고정 |
| 채팅 | 공용 Dify 앱 `commerce-chat` + FastAPI `/tools/answer`(모드 rules, product). 조언만 하고 실행하지 않는다 |
| 음성 | 상품 설명 음성 입력(STT), 쇼츠 내레이션(TTS, 도중 제공자 대체 금지), 음성 대화. 녹음 원본 미저장. 제공자는 오픈소스와 ElevenLabs 이원화 |
| 라우팅·동의 | `ai_routing_settings` 14행(org null, app commerce). 국외 이전 동의가 없으면 오픈소스만. 이미지 생성(fal)은 체인 밖(01장 D-15) |
| 3D 히어로·디자인 시스템 | 상품 상자 → 상세페이지 패널 → 마켓 진열대(모바일은 상자 열림만). Tailwind CSS v4 토큰이 정답, 주 레퍼런스 Primer, 보조 Atlassian |
| 경계 | 쇼츠 영상 렌더는 nomad-video 소유(Phase 2에 워커 API 호출) |

## 5. DB 구조 선택

| 구조 | 선택 | 이유 |
|---|---|---|
| 모듈러(통합) | 1차 출시 기본값 | SNS 업로더(video 소유)를 2단계에 소비하므로 같은 계정 체계가 유리하다(`D:/WorkSpace/platform/docs/products/_supabase-modular/ARCHITECTURE.md:35`). 크레딧 지갑과 SSO로 video·blog와 크로스 셀 |
| 모놀리스 | 대안으로 같은 도메인 모델 제공 | 셀러 마켓 키를 다른 제품과 물리 분리하고 싶을 때. 스키마 `public`(사용자 최종 확인 대기, `05_DATA_MODEL.md` 8장) |
