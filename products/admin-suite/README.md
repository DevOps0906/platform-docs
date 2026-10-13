# Admin Suite (admin-suite)

## 1. 한 줄 정의

중소기업, 병원, 학교의 내부 직원이 역할별로 재고·판매·인사(ERP), 예약·대기열·환자·검사(HMS), 학급·출석(SMS)을 관리하는 관리 시스템 묶음이다. 보안 보일러플레이트를 한 번만 올바르게 만든 공유 코어 패키지 `packages/admin-kit` 위에 앱 3개(`apps/erp`, `apps/hms`, `apps/sms`)를 올린다.

2026-10-13부터 사내 규정·매뉴얼(hms는 환자 정보가 없는 임상 가이드라인·운영 매뉴얼)을 근거로 답하는 AI 업무 어시스턴트(채팅·음성), 기관 운영 위키가 MVP에 들어간다(확정 결정 13~17). erp, sms는 상용/오픈소스 이원화와 국외 이전 동의, **hms는 사용자 결정에 따라 전용 서버만 쓰고 상용 API·공용 서버·공용 Dify를 쓰지 않는다**. 공개 랜딩이 없어 3D 히어로는 적용하지 않는다.

| 구분 | 대상 사용자 |
|---|---|
| `apps/erp` | 중소·중견 기업 내부 직원. 마스터 관리자, 재고 관리자, 판매 관리자, 일반 직원(`ERP-Wesite/PRD.md:43-49`) |
| `apps/hms` | 의원급 병원 내부 직원. 병원장(관리자), 의사, 원무, 임상병리사(`Hospital/PRD.md:15-21`) |
| `apps/sms` | 학교 관리자(교사 포함)와 학생(`School_Management_System/PRD.md:56-70`). 교사 단독 역할은 제안 |

## 2. 통합 근거

| 근거 | 내용 | 출처 |
|---|---|---|
| 확정 결정 2 | 공유 코어 패키지(`packages/admin-kit`)와 앱 3개로 구성한다. hms는 의료정보 격리를 위해 별도 DB로만 제공하고 모듈러 통합 DB에서 제외한다 | `docs/products/00_MERGE_ANALYSIS.md:11` |
| 단일 앱으로 합치지 않는 이유 | 사용자·데이터·규제 수준이 겹치지 않고, 병원 의료정보를 다른 도메인과 같은 DB·배포에 두면 사고 범위가 커진다 | `docs/products/00_MERGE_ANALYSIS.md:1104-1110` |
| 공유하는 이유 | 세 앱이 같은 보일러플레이트(SSR 클라이언트, 가드, profiles(role, status), 사이드바, 테이블+모달 CRUD)와 같은 버그(RLS 자기참조 재귀, KST 날짜, 가드 누락)를 공유한다 | `docs/products/00_MERGE_ANALYSIS.md:1111-1113`, `docs/reviews/ERP-Wesite.md:100` |
| 코어 패턴 참조 원본 | Hospital `src/proxy.ts`(세션 갱신, 보호 경로)와 `src/lib/permissions.ts`(역할→페이지 매트릭스). 단 역할 판정은 서버에서 강제하고 "프로필 없으면 admin" 기본값은 버린다 | `Hospital/src/proxy.ts:13-48`, `Hospital/src/lib/permissions.ts:5-10`, `Hospital/src/proxy.ts:57` |
| 첫 적용 앱 | ERP(가장 작고 역할 구조가 단순) | `docs/products/00_MERGE_ANALYSIS.md:1118` |
| 사용자 결정 반영 | 통합 형태 B(모노레포 공유 코어), 권한 모델 A(앱별 고정 role + 정적 매트릭스), 가입 정책 C(코어가 승인제/초대제 둘 다 제공), School은 HEAD 복원(A), 디자인은 앱별 테마(A) | `docs/products/00_MERGE_ANALYSIS.md:1239-1244` |

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| `ERP-Wesite/` | `docs/reviews/ERP-Wesite.md` | 약 50%(`:22`) | 도메인 모델(상품, 입출고, 판매, 부서), 화면 구성 5개, Blue/Orange 토큰, 권한 모달 UX | RLS 정책 전부(재귀·권한 상승), 비원자 서버 액션, 중복 라우트 4개, 설정 목업, 헤더 장식, gitlink |
| `Hospital/` | `docs/reviews/Hospital.md` | 약 45%(`:16`) | proxy 골격, 역할→페이지 매트릭스 형태, lab-ranges 상수, 대기열 Realtime 구조, Dark/Medical Red 토큰 | 클라이언트 PageGuard, OVERRIDE 1234와 verify-admin API, 브라우저 직접 update, 하드코딩 KPI, 미사용 shadcn/zustand, `as any` 20건 |
| `School_Management_System/` | `docs/reviews/School_Management_System.md` | 작업 트리 약 25%, HEAD 약 55%(`:16`) | HEAD `3c19d1e`의 학급/과목 CRUD, 출석 upsert + Realtime 보드, 학생 대시보드, Indigo/Cyan 토큰 | 루트 `middleware.ts`, CLAUDE.md의 재귀 RLS 예시, 이모지 아이콘, nested git |
| `basic-master-module`(간접) | `docs/reviews/basic-master-module.md` | - | `_platform-core`로 승격된 템플릿을 그대로 사용 | - |

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, MVP/Phase, admin-kit와 앱별 기능 요구사항(KIT/ERP/HMS/SMS), 요금, 비기능 수치, 의료·미성년자 개인정보, KPI |
| `02_ARCHITECTURE.md` | 스택(AI 서비스·Tailwind CSS v4 포함), admin-kit와 앱 경계, 공용 모듈 사용, AI 라우팅 기본값·그래프 `admin.assistant`·권한 확인·hms 전용 구성, 리뷰 "높음" 중 비보안 결함의 차단 설계, 배포 토폴로지 |
| `03_SCREENS_UX.md` | 앱별 화면 목록, 가입(승인/초대) 플로우, 로그인 화면과 앱 홈 디자인 방향 |
| `04_API.md` | Route Handler, 앱별 RPC 시그니처, SQLSTATE |
| `05_DATA_MODEL.md` | erp/sms/hms 테이블, 상태 전이, RLS, 의료정보 보호, 리뷰 "높음" 중 보안·데이터 결함의 차단 설계 |
| `06_AGENT_PLAN.md` | 작업 57개(AI·음성·디자인 시스템 17개 포함), 웨이브, 모델 비율, 리뷰 작업 흡수표 40행, 코어 요청 |
| `07_SOURCE_MIGRATION.md` | 원본별 이식/폐기 자산, 복사 금지 결함 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/erp/`, `hms/`, `sms/` | 앱별 단독 Supabase 프로젝트용 마이그레이션(`0001_core_lite.sql`, `0002_<app>_domain.sql`)과 `seed.sql`(AI 라우팅 기본값, 플랜 AI 키, `ai-docs` 버킷 포함. hms는 전용 제공자 `hms-*`만) |
| `../_supabase-modular/migrations/1600_erp.sql`, `1700_sms.sql` | 통합 DB의 erp, sms 스키마 조각(hms 조각은 없다) |

## 5. DB 구조 선택

| 앱 | 1차(출시) | 2차 | 이유 |
|---|---|---|---|
| erp | 모듈러(`erp` 스키마) | 고객사가 늘면 고객사별 모놀리스 | 1개 고객사까지는 통합, 이후 고객사별 프로젝트(`docs/products/_supabase-modular/ARCHITECTURE.md:44`) |
| sms | 모듈러(`sms` 스키마) | 고객사별 모놀리스 | 같은 이유(`ARCHITECTURE.md:45`) |
| hms | 모놀리스(강제) | 유지 | 의료정보 격리(확정 결정 2, `ARCHITECTURE.md:46`, `docs/products/_supabase-modular/README.md:80-89`) |

erp와 sms는 같은 도메인 모델을 두 형태로 모두 제공한다. 모듈러 조각을 정본으로 두고, 모놀리스 `0002_<app>_domain.sql`은 `DB_CONVENTIONS.md` 12장 규칙(`core.`→`public.`, `<schema>.`→`public.`, 스키마 블록 제거)으로 생성한다. 분석의 "DB 분리 B(앱별 분리)" 권고(`docs/products/00_MERGE_ANALYSIS.md:1240`)는 hms에만 강제하고 erp/sms는 모듈러를 기본으로 한다(확정 결정 2가 hms만 제외했기 때문). 모놀리스 스키마는 `public`이다(`MONOLITH_CORE_LITE.sql` 머리 주석). 이 선택은 사용자 최종 확인 대기다(05장 8절).
