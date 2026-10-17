# 06_ADOPTION_PLAN — 제품에 적용하는 작업 계획

작성일 2026-10-14. 제품 `06_AGENT_PLAN.md`와 같은 형식이다. 작업 ID는 `MT-<번호>`이고, 제품에 넣을 때는 제품 접두사를 붙여 제품 작업 계획에 복사한다(예: `PB-06-0xx (MT-03)`). 권장 모델은 멀티에이전트 구조(고문 Fable, 주 Opus, 부 Sonnet)를 따른다.

## 1. 선행: 코어 반영 (한 번만)

| 단계 | 할 일 | 담당 | 완료 조건 |
|---|---|---|---|
| C-1 | 이 폴더 문서 승인(대표님) | 사람 | `[DECISION]` 기록 |
| C-2 | `supabase/0011_core_tenant_theming.sql`을 `products/_supabase-modular/migrations/0011_core_tenant_theming.sql`로 옮기고 `_platform-core/README.md` 표에 추가. `staged/0010`과 번호를 다시 확인 | Fable 5.1(코어 변경 규칙, `_supabase-modular/ARCHITECTURE.md` 5장) | 모듈러 PGlite OK |
| C-3 | `MONOLITH_CORE_LITE.sql`에 SECTION 13(선택 절)으로 치환본 추가 또는 제품별 `0003_tenant_theming.sql`로 배포 중 택일 | Fable 5.1 | 모놀리스 PGlite OK |
| C-4 | 전 제품 RLS 스모크 + 이 폴더 스모크 91항목(mod·mono) 통과 | Sonnet(테스트) | 회귀 0 |
| C-5 | `packages/core-tenancy` 골격과 `SHARED_MODULES.md`에 모듈 행 추가(소유자: _platform-core, 소비자: 전 제품) | Opus | 타입·RPC 래퍼 빌드 |

## 2. 제품 작업 목록

| ID | 작업 | 소유 경로(제품 저장소) | 의존 | 권장 모델 | 수용 기준 |
|---|---|---|---|---|---|
| MT-01 | 테넌트 마이그레이션 적용·타입 생성 | `supabase/`, `src/types/supabase.ts` | C-2/C-3 | Sonnet | `supabase db reset` 오류 0, 스모크 91/91, 타입에 `tenant_*` 포함 |
| MT-02 | 토큰 3계층 정리, 하드코딩 색 제거, 린트 `no-arbitrary-color` | `src/styles/tokens.css`, `src/components/ui/`, ESLint 설정 | 제품 디자인 시스템 W1(`DESIGN_SYSTEM.md` 4장) | Sonnet + 사람 검토 | 린트 0건, 개방 토큰 이름이 허용 목록과 일치, shadcn 변수는 의미 토큰만 참조 |
| MT-03 | `core-tenancy` 연결: `getTenant`, `themeCss`, 폰트 레지스트리 | `src/lib/tenancy/`(제품 어댑터) | C-5, MT-01 | Opus | 시험 테넌트 2개가 `*.localhost`에서 서로 다른 색·로고로 첫 화면부터 렌더(깜빡임 0) |
| MT-04 | `proxy.ts` 테넌트 판별(헤더 위조 제거, 루트·서브·커스텀 판별), 쿠키 호스트 전용 | `src/proxy.ts` | MT-03 | Opus | 위조 `x-tenant-*` 헤더 무시 테스트, 서브도메인 간 세션 비공유 E2E |
| MT-05 | 루트 레이아웃·메타데이터(타이틀, OG, 파비콘, manifest), 조직 불일치 화면 | `src/app/layout.tsx`, `src/app/(auth)/` | MT-03, MT-04 | Sonnet | 03장 3절 "조직 불일치" 규칙 E2E, OG 이미지 테넌트별 생성 |
| MT-06 | 자산 업로드(서명 URL, 검사, SVG 정화, 파생본) | `src/app/api/tenant/assets/`, `core-tenancy/src/server/` | MT-01 | Sonnet | 악성 SVG(script, onload, foreignObject) 정화 테스트, 다른 조직 경로 업로드 거부 |
| MT-07 | 로고 → 팔레트 → 대비 검사·자동 보정 | `core-tenancy/src/palette/`, `contrast.ts`, `src/app/api/tenant/themes/{extract,[id]/check}/` | MT-06 | Opus | 같은 로고 → 같은 결과(결정성), 시험 로고 10종 전부 자동 보정 후 통과, `contrast_report` 형식 02장 5절 |
| MT-08 | 브랜딩 설정 화면(H + J): 편집·미리보기·게시·버전·되돌리기 | `src/app/(app)/settings/branding/` | MT-07, 제품 디자인 시스템 완료 | Sonnet + 사람 검토 | 게시 후 5초 안에 전 화면 반영(캐시 무효화), TM002·TM003 문구 표시, 라이트·다크 미리보기 |
| MT-09 | 고객센터·사업자 정보·푸터 설정 | `src/app/(app)/settings/branding/`(설정 탭), 푸터 컴포넌트 | MT-08 | Sonnet | `legal` 값이 푸터·메일에 표시, `javascript:` URL 거부 |
| MT-10 | 라벨 사전과 `t()`, 용어 설정 화면(O) | `src/lib/i18n/`, `src/app/(app)/settings/labels/` | MT-03 | Sonnet | 하드코딩 한글 문구 0(린트 또는 검사 스크립트), 라벨 HTML 렌더 금지 테스트 |
| MT-11 | 메뉴 레지스트리와 숨김·순서 | `src/lib/nav/`, `src/app/(app)/settings/menu/` | MT-10 | Sonnet | 숨긴 메뉴 경로도 권한 검사 유지, L1에서는 무시 |
| MT-12 | 커스텀 도메인(요청·Vercel 연동·검증 크론·301 이동) | `src/app/api/tenant/domains/`, `src/app/api/internal/domains/verify/`, `src/app/(app)/settings/domains/` | MT-04 | Opus | 스테이징 실제 도메인 1개 연결 → `active` → 해석·301 이동 확인, 해지 시 기본 브랜드 |
| MT-13 | 기능 오버라이드 운영자 화면(서버 쓰기, 사유·만료) | `src/app/admin/tenants/` | MT-01 | Sonnet | platform_admin만 접근, 감사 기록 |
| MT-14 | 슬롯 레지스트리와 `<Slot>`, 슬롯 목록 문서화 | `core-tenancy/src/slots.tsx`, `src/extensions/registry.ts` | MT-03 | Opus | 정적 맵 외 로드 불가, 확장 없음·키 불일치 시 fallback |
| MT-15 | 훅·웹훅 지점(L4) | 제품 서버 이벤트 지점, `automation-core` 연동 | MT-14 | Opus | 서명·재시도·멱등 키, 단계 3 이하에서는 실행 안 됨 |
| MT-16 | E2E·시각 회귀(시험 테넌트 3종 × 라이트·다크) | `e2e/tenancy/`, `e2e/visual/` | MT-05, MT-08 | Sonnet | 03장 8절 표 전부 통과 |

## 3. 웨이브

| 웨이브 | 작업 | 끝나면 생기는 것 | 판매 가능 상품 |
|---|---|---|---|
| T0 | C-1~C-5, MT-01, MT-02 | 코어 테이블, 토큰화된 UI | - |
| T1 (MVP) | MT-03~MT-09, MT-16(L1 범위) | 셀프서비스 L1 화이트라벨(로고·색·서체·사업자 정보, 서브도메인) | 화이트라벨 Basic |
| T2 | MT-10~MT-13 | 용어·메뉴·기능 예외·커스텀 도메인 | 화이트라벨 Pro |
| T3 | MT-14~MT-15 | 슬롯·훅 | 엔터프라이즈(건별 견적) |

T2·T3는 **같은 요청이 실제 고객 2곳 이상에서 나올 때** 시작한다(린 원칙). 그 전에는 운영자가 수동으로 처리하고 요청을 기록한다(07장 4절).

## 4. 제품별 적용 순서 (제안)

| 순서 | 제품 | 이유 | 범위 |
|---|---|---|---|
| 1 | flora-publishing | 가장 먼저 완성해 직접 검토하기로 한 제품. 기반 작업(T0~T1)을 여기서 검증한 뒤 다른 제품에 복제 | T0~T1 |
| 2 | admin-suite ERP·School | 고객사(회사·학교) 로고·명칭 요구가 가장 확실. 고객사별 분리 배치(모델 B) 계획이 이미 있음(`_supabase-modular/ARCHITECTURE.md` 3장) | T0~T2 |
| 3 | nomad-docs | 에이전시가 자기 브랜드로 견적서·계약서를 내는 수요. 문서 출력에 테마 적용(02장 8절) | T0~T2 |
| 4 | Web-App-Agency 납품물·리드 대시보드 | `Price_Plans/Web-App-Agency/PRICE_PLAN.md`의 AG-WL(화이트라벨 공급) | T1 |
| 5 | sceneflow 대행 화이트라벨(Phase 2, video D-24) | 다른 대행사에 판매 | 결정 후 |

## 5. 공용 모듈 요청 방식

제품 작업 중 테마 확장에 바꿀 것이 생기면 이 폴더를 직접 고치지 않고 제품 `06_AGENT_PLAN.md` 6절 "공용 모듈 요청"에 적는다. 허용 목록 키 추가, 슬롯 추가처럼 여러 제품에 영향을 주는 변경은 이 폴더 문서 → SQL → `core-tenancy` 순서로 한 PR에서 바꾼다.

## 6. 열린 결정

| ID | 결정할 것 | 선택지 | 추천 |
|---|---|---|---|
| MT-D1 | 코어 반영 시점 | (a) 지금 코어에 넣기 (b) 첫 화이트라벨 고객 확정 후 | (b) 테이블은 비어 있어도 해가 없지만 코어 변경은 전 제품 회귀가 필요하므로 T0를 시작할 때 함께 |
| MT-D2 | 단계별 가격 | `07_SALES_AND_OPERATIONS.md` 2장 제안 | 시장 검증 후 확정(Price_Plans 규칙) |
| MT-D3 | "Powered by" 숨김 단계 | L1부터 / L2부터 / 별도 옵션 | L2부터(상품 차등) |
| MT-D4 | 첫 적용 제품 | 4장 표 | flora-publishing에서 기반 검증, 판매 파일럿은 admin-suite 또는 에이전시 고객 1곳 |
| MT-D5 | 서체 레지스트리 초기 목록 | 02장 7절 | 라이선스(OFL 등) 확인 후 확정 |
| MT-D6 | 모델 A(설치형) 테마 | `tenant.json` 빌드 주입 / 설치 후 설정 화면 | `tenant.json`(로컬 저장 구조와 맞음) |
| MT-D7 | 조직당 커스텀 도메인 수 | 5(현재 SQL) / 플랜별 | 5로 시작, 플랜 features `max_domains`로 옮기는 것은 요청이 생기면 |
