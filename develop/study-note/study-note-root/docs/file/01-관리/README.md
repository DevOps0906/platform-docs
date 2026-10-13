# Study Note (study-note)

작성일 2026-10-12. 단독 제품, 공개 베타, 가입 개방(`apps.signup_policy = 'open'`, `status = 'beta'`). 이 폴더는 기획 문서와 SQL만 있고 앱 코드는 없다(`D:/WorkSpace/platform/docs/products/_PRODUCT_AGENT_BRIEF.md:6`).

## 1. 한 줄 정의

수업이나 회의 원문을 붙여넣으면 서버가 AI 모델 2개로 병렬 정리한 뒤 통합 모델이 하나의 "학습 일지"(학습 목표 / 학습 내용 형식)로 합쳐 주고, 결과를 TXT 파일과 보관함에 남기는 학습 노트 정리 서비스다. 대상은 IT 교육 과정 수강생, 부트캠프 수강생, 강사, 회의 기록을 매일 정리하는 직장인이다(원본 대상 `docs/reference/reviews/study-note-organizer-codex-01.md:6`).

AI 요약(2026-10-13): 노트·교재를 과목별로 색인(RAG)하고, LangGraph `notes.organize`(업로드 → 요약 → 개념 연결 → 퀴즈 → 검사)로 과목별 개념 위키를 자동 정리하며, 내 노트 근거 Q&A 채팅(Dify)과 퀴즈를 제공한다. 음성은 강의 녹음 → 자동 노트 생성(STT, 제3자 음성 고지, 오픈소스 강제)이 핵심이고 음성 대화와 퀴즈 음성도 있다. 랜딩은 흩어진 메모 카드가 노트로 모이는 3D 히어로(모바일 카드 5장), UI는 Tailwind CSS v4 디자인 시스템이다. 기존 일지 정리, 요금 제안, 베타(Pro 비활성), 만 14세 미만 정책 결정(D-6)은 그대로다.

## 2. 통합 근거

| 항목 | 내용 | 근거 |
|---|---|---|
| 통합 대상 | 합칠 다른 원본은 없다. 단일 프로젝트를 정리하고 빠진 기획을 채우는 "정리형" 기획이다 | `docs/reference/00_MERGE_ANALYSIS.md:1326` |
| 베이스 | `study-note-organizer-codex-01`. 완성도 약 85%이고 남은 작업 대부분이 S 규모다. 리뷰 권고는 "계속 발전" | `docs/reference/reviews/study-note-organizer-codex-01.md:17`, `:125` |
| 가장 큰 변화 | 브라우저에서 OpenRouter를 직접 호출하던 구조를 서버 호출로 바꾼다. 가입 개방 제품이므로 사용자 API Key 입력(BYOK)과 번들 키 주입을 모두 없애고, 키는 서버 환경변수에만 둔다 | 리뷰 #1, `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:121` |
| 확정 결정 적용 | 4 Toss(유료 전환 시), 5 org 기준 스키마와 1인 1워크스페이스 | `docs/reference/00_MERGE_ANALYSIS.md:12-13` |
| 다른 제품과의 관계 | 없음. "2모델 병렬 후 통합" 패턴은 다른 제품에서 재사용될 때 추출한다 | `docs/reference/00_MERGE_ANALYSIS.md:1326` |
| 공유하는 것 | `_platform-core`의 공용 모듈만(auth, org, credits, toss, llm gateway, jobs, audit, rate limit) | `docs/file/03-설계/공용코어/SHARED_MODULES.md:27-44` |

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| `study-note-organizer-codex-01/` | `docs/reference/reviews/study-note-organizer-codex-01.md` | 약 85% (`:17`) | 프롬프트 2종(PRD 4장), 출력 규격과 TXT 파일명 규칙(PRD 9~10장), 키워드 추출/제거 함수, 카드 UI(ResultCard, Header, ErrorDisplay, LoadingSpinner), 한국어 에러 문구, 다크/라이트 테마, 13개 모델 목록(서버 화이트리스트로) | `VITE_OPENROUTER_API_KEY` 폴백, `README copy.md`, `useLocalStorage`, `RESET_RESULTS`, localStorage 기반 API Key/히스토리 저장, `latest` 의존성, `dist/`, 중첩 `.git` |

상세는 `07_SOURCE_MIGRATION.md`.

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, 범위, 기능 요구사항(NT-F-###), 요금/크레딧, 비기능 수치, 법/개인정보, KPI, 열린 결정 |
| `02_ARCHITECTURE.md` | 스택, 모듈 경계, 공용 모듈 사용, 잡 타입, AI 라우팅, 리뷰 "높음" 3건의 차단 설계, 배포, 환경변수 |
| `03_SCREENS_UX.md` | 화면 목록, 플로우, 화면별 명세, 랜딩 디자인 방향(레퍼런스, 브리프, 토큰, 와이어프레임), 상태/오류, 접근성 |
| `04_API.md` | Route Handler, RPC, 잡 페이로드, 웹훅, 외부 API, 오류 코드 |
| `05_DATA_MODEL.md` | 테이블 7개, 상태 전이, RLS, 코어 참조, 차단 설계(보안/데이터), 모놀리스와 모듈러 차이 |
| `06_AGENT_PLAN.md` | 작업 52개(AI·음성·3D·디자인 시스템 22개 포함), 웨이브 W0~W7, 모델별 비율, 리뷰 작업 흡수표, 코어 요청(C-1~C-10) |
| `07_SOURCE_MIGRATION.md` | 원본 자산 분류, 폐기 목록, 복사 금지 결함, 아카이브 절차 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/` | `migrations/0001_core_lite.sql`(코어 축소판 복사본), `0002_study_note_domain.sql`(도메인), `seed.sql` |
| `../_supabase-modular/migrations/2100_notes.sql` | 모듈러 조각(스키마 `notes`). 모놀리스 0002와 같은 도메인 모델 |

## 5. DB 구조 선택

| 항목 | 내용 |
|---|---|
| 1차 출시 | 모듈러(스키마 `notes`). `D:/WorkSpace/platform/docs/products/_supabase-modular/ARCHITECTURE.md:39`가 study-note를 "모듈러, 코어 인증만 필요"로 정했다 |
| 모놀리스 제공 이유 | 베타를 독립 Supabase 프로젝트로 먼저 띄우고 싶을 때 쓴다. 같은 함수 이름과 시그니처이므로 `SUPABASE_DB_SCHEMA=public`만 바꾼다. 모놀리스 스키마는 `public`이며 최종 확인은 사용자 결정 대기다(`05_DATA_MODEL.md` 8장에 기록) |
| 이동 | 모놀리스에서 모듈러로 흡수하는 절차는 `ARCHITECTURE.md:50-59` |
| 코어 사용 | 크레딧 선차감과 잡 큐를 쓰므로 모놀리스에서도 코어 축소판의 SECTION 3(Toss), 4(크레딧), 6-C(레이트 리밋), 7(잡)을 유지했다. SECTION 6-A/6-B/8/9는 사유와 함께 제거했다(`0001_core_lite.sql` 안 주석) |
| 주의 | 모듈러 코어(0000~0006)는 `core` 함수 다수의 PUBLIC EXECUTE가 회수되지 않는 결함이 있다. 제품 SQL은 영향을 받지 않게 함수마다 명시적으로 회수했지만, 코어 수정 전까지는 출시 전제 조건이다(`06_AGENT_PLAN.md` 6장 C-1) |
