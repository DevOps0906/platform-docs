# 제품 기획 에이전트 공통 지시 (단계 2)

작업 루트: `D:\WorkSpace\platform`. 산출물은 한국어로 쓴다. 코드, SQL, 식별자는 원문 그대로 둔다.

## 절대 규칙
- 이번 작업은 기획서 작성만 한다. 앱 코드는 구현하지 않는다(TS/TSX/Python 파일 생성 금지, 프로젝트 스캐폴딩 금지, 패키지 설치 금지). 문서 안의 코드 블록은 인터페이스나 계약을 보여 주는 예시로만 쓴다. SQL은 DB 설계 산출물로만 작성한다.
- 쓰기는 두 곳만 허용한다.
  - 배정된 제품 폴더 `docs/products/<product>/`
  - 배정된 모듈러 조각 파일 `docs/products/_supabase-modular/migrations/<번호>_<schema>.sql` (admin-suite만 2개)
- 위 두 곳 외의 파일은 만들거나 수정하지 않는다. 특히 금지하는 것:
  - 원본 프로젝트 폴더
  - `docs/reviews/`
  - `_platform-core/`, `_design-guide/`
  - `_supabase-modular/`의 다른 파일
- 원본을 바꾸는 git 명령은 쓰지 않는다. checkout, reset, stash, add, commit이 모두 해당한다. 읽을 때는 `git show <커밋>:<경로>`만 쓴다.
- 클라우드 리소스는 만들지 않는다. Supabase MCP와 배포 도구도 쓰지 않는다.
- 형식 규칙
  - 표는 Markdown 표(`|`)만 쓴다.
  - 이모지와 HTML 태그는 쓰지 않는다.
  - 근거는 `상대경로:줄번호`로 단다.
- 추측으로 쓰지 않는다. 원본 문서와 리뷰에 근거가 없는 수치나 정책은 "제안"으로 표시하고 이유를 적는다.

## 먼저 읽을 것 (순서대로)
1. `docs/products/README.md`: 폴더, 스키마 이름, 마이그레이션 번호
2. `docs/products/00_MERGE_ANALYSIS.md`
   - 상단 "확정 결정"은 분석 본문보다 우선한다.
   - 자기 그룹 절을 읽는다.
   - 그룹 간 겹침 표(C-6)를 읽는다.
3. `docs/products/_platform-core/`의 전 파일
   - `CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`
   - AI 계층 문서: `AI_ARCHITECTURE.md`, `VOICE_ARCHITECTURE.md`, `LLM_WIKI.md`. 3D 히어로는 `_design-guide/HERO_3D.md`. 인증 단계(확정 결정 22)는 `AUTH_ROADMAP.md`(필독: 8장 매트릭스에서 자기 제품 행, 10장 문서별 반영 위치)
4. `docs/products/_supabase-modular/README.md`, `migrations/0000_*` ~ `0009_*`(0008 AI, 0009 음성. SQL 검사에 0008 이후가 포함되면 `node check.mjs --vector ...`)
5. `docs/nomad-design-modules/_design-guide/`의 전 파일. 이 중 `REFERENCES.md`는 자기 제품 절을 읽는다.
6. 배정된 리뷰 md 전체와 원본 기획 문서(PRD, CLAUDE, DESIGN 등)
   - 코드는 기능 확인이 필요한 부분만 읽는다.
   - node_modules, .next, dist, venv, __pycache__, ckpts는 읽지 않는다.

## 산출물 (`DOC_TEMPLATE.md`의 장 구조를 정확히 따른다)
- `README.md`, `01_PRD.md`, `02_ARCHITECTURE.md`, `03_SCREENS_UX.md`, `04_API.md`, `05_DATA_MODEL.md`, `06_AGENT_PLAN.md`, `07_SOURCE_MIGRATION.md`, `CLAUDE.md`
- `supabase/monolith/migrations/0001_core_lite.sql`
  - `_platform-core/MONOLITH_CORE_LITE.sql`을 그대로 복사한다.
  - 제품에 필요 없는 부분만 주석과 함께 제거한다.
- `supabase/monolith/migrations/0002_<product>_domain.sql` 등 도메인 마이그레이션, `supabase/monolith/seed.sql`
- `docs/products/_supabase-modular/migrations/<번호>_<schema>.sql`
  - 같은 도메인 모델을 제품 스키마에 둔다.
  - core 헬퍼와 `core.organizations`를 참조한다.
  - `core.apps`에 등록한다.

## 반드시 지킬 내용 기준
- 분석에서 "폐기"로 분류한 항목은 `07_SOURCE_MIGRATION.md`에 사유와 함께 빠짐없이 남긴다.
- "신규" 항목과 "새로 채워야 할 기획 공백"은 01~05장에 실제 명세로 채운다. 대상은 수치, 상태 전이, 테이블, 정책, API다.
- 리뷰 3장 문제점 표에서 심각도 "높음"인 항목은 하나도 빠짐없이 차단 설계를 쓴다. 위치는 02장 또는 05장이다. 쓸 때는 리뷰 항목 번호를 인용한다. 표 형식은 "리뷰 #n → 차단 설계"다.
- 리뷰 5장 작업 목록은 `06_AGENT_PLAN.md` 작업 분해에 흡수한다. 각 작업에 출처를 표시한다.
- 공용 모듈(인증, org, 크레딧, Toss, 웹훅, OAuth, LLM, fal, WeasyPrint, SNS 업로더, automation-core, compliance, storage, audit, jobs, affiliate, ai-gateway, ai-service, dify, core-voice, llm-wiki)은 `_platform-core`를 참조만 한다(`SHARED_MODULES.md` 19장). 재정의하지 않는다.
- `06_AGENT_PLAN.md`
  - 작업마다 다음을 적는다: ID, 작업, 소유 파일/디렉토리, 선행 작업, 우선순위, 규모, 권장 모델, 수용 기준.
  - 소유 파일/디렉토리는 겹치지 않게 나눠, 병렬 에이전트가 충돌하지 않게 한다.
  - 권장 모델은 Fable/Opus/Sonnet/Haiku 중 하나다.
  - 웨이브(병렬 실행 순서) 표와 모델별 비율을 포함한다.
  - 모델 기준
    - Fable: 결제, 권한, RLS, 데이터 모델 변경
    - Opus: 기능 구현, API 연동, 테스트 설계
    - Sonnet: UI, 메인페이지 구현, 컴포넌트, 문서
    - Haiku: 보일러플레이트, 린트/타입 정리, 문구, 반복 체크
- `03_SCREENS_UX.md` 메인페이지/랜딩 절은 `_design-guide/DESIGN_PRINCIPLES.md` 절차를 따른다.
  - 레퍼런스(Awwwards/Dribbble), 브리프, 토큰 플랜(색 4~6개, 타입 역할, ASCII 와이어프레임), 제네릭 기본값 회피 검토를 포함한다.
  - 레퍼런스 URL은 `REFERENCES.md`에 있는 것만 인용한다.
- SQL 요건
  - PostgreSQL 15 기준이다. Supabase 표준 객체만 쓴다(`auth.users`, `auth.uid()`, anon/authenticated/service_role, `storage.*`).
  - 모든 테이블에 RLS를 켠다.
  - 사용자가 자기 역할, 플랜, 크레딧, 권한을 바꿀 수 없어야 한다.
  - SECURITY DEFINER 함수에는 `set search_path`를 지정하고 EXECUTE 권한을 정리한다.
- 법/개인정보 요건과 금지 문구(가상 후기, 허위 수치 등)를 01장에 명시한다.

## 완료 보고 (40줄 이내)
- 만든 파일 목록과 각 줄 수
- 리뷰 "높음" 항목 수와 차단 설계 수(같아야 함)
- 06장 작업 수와 모델별 비율
- 사용자 결정이 더 필요한 사항
