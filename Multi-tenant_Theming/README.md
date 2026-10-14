# Multi-tenant Theming — 고객사 브랜드에 맞춰 플랫폼을 바꾸는 구조 (화이트라벨)

작성일 2026-10-14. 내가 만든 플랫폼(`products/`의 모든 제품)을 고객사마다 그 회사의 로고·색·서체·용어·도메인으로 바꿔 판매·운영할 때 따르는 **공용 설계 문서**입니다. 제품을 만들 때 이 폴더의 구조대로 처음부터 깔아 두면, 나중에 화이트라벨 판매(공용 판매 모델 B)를 할 때 코드를 고치지 않고 설정만으로 고객사 버전을 만들 수 있습니다.

> **핵심 원칙 한 줄**: 고객사별로 코드를 복사(포크)하지 않는다. **코드는 하나, 고객사 차이는 DB 설정(토큰·로고·라벨·플래그)으로** 만든다.

## 0. 이 개념을 부르는 이름

| 용어 | 뜻 | 어디서 쓰나 |
|---|---|---|
| **화이트라벨(White-label)** | 내 플랫폼을 고객사 브랜드로 바꿔 판매 | 영업·계약(공용 판매 모델 B) |
| **멀티테넌시(Multi-tenancy)** | 하나의 시스템이 여러 고객사(테넌트)를 분리해 서비스. 이 저장소의 테넌트는 `core.organizations` | 아키텍처 |
| **멀티테넌트 테마(Multi-tenant Theming)** | 테넌트마다 로고·색·서체를 바꾸는 것. 리브랜딩, 스키닝(Skinning)이라고도 함 | 디자인 구현 |
| **디자인 토큰(Design Tokens)** | 색·간격·라운드를 변수로 관리. 테넌트는 토큰 값만 바꾼다 | 디자인 시스템 |
| **설정 기반 커스터마이징(Config-driven Customization)** | 코드 수정 없이 DB 설정으로 바꾸기. 반대말은 포크(Fork) | 권장 방식 |
| **피처 플래그 / 엔타이틀먼트(Feature Flag / Entitlement)** | 고객사별 기능 켜고 끄기, 한도 | 요금제 |
| **커스텀 도메인(Custom / Vanity Domain)** | `app.고객사.com`으로 접속 | 테넌트 식별 |
| **확장 포인트·슬롯(Extension Point / Slot)** | 특정 화면·로직만 고객사 전용으로 교체 | 고급 커스텀 |
| 국내 SI 용어 | 구축형(설치형, 모델 A) / 임대형(SaaS, 모델 C) / 솔루션 커스터마이징 | 견적·제안서 |

자세한 용어와 비교는 [`01_CONCEPTS.md`](01_CONCEPTS.md).

## 1. 커스터마이징 5단계 (화이트라벨 단계 = `theming_level`)

고객 요청을 이 5단계로 나눠 받는 것이 이 구조의 전부입니다. **요청의 80%를 L1~L2에서 끝내야** 고객사가 늘어도 1인 운영이 됩니다.

| 단계 | 이름 | 고객이 바꾸는 것 | 구현 방식 | DB | 과금(제안) |
|---|---|---|---|---|---|
| L0 | 없음 | - | 플랫폼 기본 테마 | 해석 결과 `null` | 표준 SaaS(C) |
| **L1** | 브랜딩 | 로고 3종+, 브랜드 색, 서체, 라운드, 파비콘, OG 이미지, 메일 머리, 고객센터·사업자 정보 | 의미 토큰 덮어쓰기 + 자산 슬롯 | `tenant_themes`, `tenant_settings` | 화이트라벨 Basic 기본 포함 |
| **L2** | 구성 | 용어("회원"→"수강생"), 메뉴 숨김·순서, 기능 켜고 끄기·한도, **커스텀 도메인** | 라벨 사전, 메뉴 레지스트리, 피처 오버라이드 | `tenant_labels`, `tenant_settings.navigation`, `tenant_feature_overrides`, `tenant_domains` | 화이트라벨 Pro |
| **L3** | 화면 | 특정 화면 영역을 고객사 전용 컴포넌트로 교체 | 슬롯 레지스트리(코드는 저장소, DB는 켜고 끄기) | `tenant_extensions(kind='slot')` | 건별 견적 |
| **L4** | 로직 | 고객사 전용 워크플로, 외부 시스템 연동 | 훅·웹훅, n8n, 확장 패키지 | `tenant_extensions(kind='hook'/'webhook')` | 개발비 + 연 유지비 |
| L5 | 포크 | 코드 복제 후 별도 개발 | **원칙적 금지** | 없음 | 받으려면 가격으로 거절 |

단계 값은 플랜에서 나옵니다: `core.plans.features.theming_level`(0~4) → 조직별 예외는 `core.tenant_feature_overrides`의 `theming_level`. 서버·RLS·해석 함수가 모두 이 값 하나로 판단합니다.

## 2. 전체 구조 한눈에

```
                         ┌───────────────────────────── 요청 ─────────────────────────────┐
  app.acme.co.kr ──┐     │ 1. proxy.ts: Host → resolve_tenant(hostname | slug, app)       │
  acme.myplatform.com ─┼─▶│ 2. 캐시(tenant:<org_id>) 에 해석 결과 저장                     │
  myplatform.com ──┘     │ 3. 루트 layout: 의미 토큰을 <style> CSS 변수로 서버 렌더(깜빡임 0) │
                         │ 4. 컴포넌트는 토큰만 사용(hex 금지) → 자동으로 고객사 디자인     │
                         │ 5. 라벨 t('nav.customers') → 고객사 용어, 슬롯 → 전용 컴포넌트   │
                         └────────────────────────────────────────────────────────────────┘
   코드(하나)                                  DB(테넌트마다 다름)
   ├─ 원시 토큰·중립색(플랫폼 고정)            ├─ tenant_themes      로고·의미 토큰·서체(L1)
   ├─ 의미 토큰 기본값                        ├─ tenant_settings    고객센터·사업자 정보·메뉴(L1/L2)
   ├─ 컴포넌트(토큰만 참조)                    ├─ tenant_labels      용어(L2)
   ├─ 메뉴·라벨·슬롯 레지스트리                ├─ tenant_feature_overrides 기능·한도(L2)
   └─ 확장 패키지(L3/L4, 최소)                 ├─ tenant_domains     커스텀 도메인(L2)
                                               ├─ tenant_extensions  슬롯·훅 스위치(L3/L4)
                                               └─ tenant_deployments 판매 모델 A/B/C 기록
```

## 3. 디자인 구조 (3계층 토큰 + 자산 슬롯)

```
디자인 시스템 (정답 = 제품 저장소 src/styles/tokens.css, _design-guide/DESIGN_SYSTEM.md 3장)
├── 1. 원시 토큰(Primitive)      blue-50~950, gray-*, spacing-*, shadow-*      ← 테넌트 변경 불가
├── 2. 의미 토큰(Semantic)       ★ 테넌트는 이 층의 "허용 목록"만 덮어쓴다
│   ├── 브랜드   brand, brand-foreground, brand-hover, brand-subtle
│   ├── 강조     accent, accent-foreground, focus-ring
│   ├── 사이드바 sidebar, sidebar-foreground
│   ├── 차트     chart-1 ~ chart-5
│   ├── 모양     radius-control, radius-card
│   └── (고정)   background, surface, text, text-muted, border, danger/success/warning  ← 대비·상태 의미 보호
├── 3. 컴포넌트 토큰             button-bg = var(--color-brand) … 의미 토큰만 참조
└── 4. 자산 슬롯(로고는 최소 3종)
    ├── logo_horizontal  가로형(헤더, 로그인)     SVG 권장, 높이 기준 표시
    ├── logo_mark        심볼(접힌 사이드바, 모바일, 앱 아이콘) 정사각
    ├── logo_dark        어두운 배경용 가로형(없으면 가로형을 밝은 배경 판 위에 표시. 자동 색 반전 금지)
    ├── favicon / og_image(1200×630) / email_header
    └── 서체: heading / body / mono — URL이 아니라 앱 서체 레지스트리 키(pretendard, noto-sans-kr …)
```

로고에서 색을 뽑아 토큰을 만들고 WCAG AA 대비를 자동 보정하는 규칙, 다크 모드 처리, shadcn/ui 변수 연결은 [`02_DESIGN_TOKENS.md`](02_DESIGN_TOKENS.md).

## 4. 코드 구조 (Next.js App Router, 제품 저장소 기준)

```
packages/core-tenancy/                      ← 신규 공용 패키지(제안). 제품은 import만
├── src/resolve.ts            resolveTenant(host) → core.resolve_tenant RPC + 캐시 태그 tenant:<org_id>
├── src/theme-css.ts          해석 결과 → CSS 변수 문자열(허용 목록 재검증, 값 이스케이프)
├── src/tokens/               의미 토큰 허용 목록·기본값(SQL is_valid_theme_tokens 와 같은 목록)
├── src/palette/              로고 색 추출 → 라이트/다크 의미 토큰 생성 → 대비 보정(culori 등)
├── src/contrast.ts           WCAG 대비 검사 → contrast_report 생성(서버만)
├── src/labels.ts             t(key) = 테넌트 라벨 ▶ 제품 기본 사전 ▶ 키
├── src/navigation.ts         메뉴 레지스트리 + tenant navigation(숨김·순서) 병합
├── src/slots.tsx             <Slot name="dashboard.home" fallback={…}/> + 확장 레지스트리
├── src/assets.ts             Storage 경로 → 공개 URL, 로고 슬롯 폴백 규칙
└── src/schema.ts             zod: tokens, fonts, settings, navigation (DB CHECK 와 같은 규칙)

apps/<제품>/src/
├── proxy.ts                  Host·slug 판별 → resolveTenant → 요청 헤더 x-tenant-org 설정 (기존 라우트 보호와 한 파일)
├── app/layout.tsx            <html> 에 테넌트 CSS 변수·파비콘·서체 주입, generateMetadata 로 타이틀·OG
├── app/(app)/settings/branding/   브랜딩 설정(패턴 H + J): 로고 업로드, 색 추출, 미리보기, 게시·되돌리기
├── app/(app)/settings/domains/    커스텀 도메인 연결(L2): DNS 안내, 상태
├── app/(app)/settings/labels/     용어 바꾸기(L2)
├── app/api/tenant/…               Route Handler: 업로드 서명 URL, 대비 검사, 게시, 도메인 요청
├── lib/i18n/messages.ko.ts        제품 기본 사전(라벨 키의 정본)
├── lib/nav/registry.ts            메뉴 키 정본
├── extensions/<tenant-slug>/      L3/L4 전용 코드(최소). 반복되면 공통 기능으로 올린다
└── styles/tokens.css              원시·의미 토큰 기본값(Tailwind CSS v4 @theme, 라이트/다크)
```

요청 흐름, 캐시, 슬롯·라벨·메뉴 구현 규칙, 린트 규칙은 [`03_CODE_STRUCTURE.md`](03_CODE_STRUCTURE.md).

## 5. DB 구조

### 5.1 먼저: 모든 테이블의 멀티테넌트 기본 규칙 (코어에 이미 있음)

테마보다 먼저 **데이터가 테넌트별로 나뉘어 있어야** 합니다. 이 저장소 코어가 이미 이 구조이고, 새 제품 테이블은 아래를 그대로 지킵니다(상세 [`04_DATA_MODEL.md`](04_DATA_MODEL.md) 1장, `products/_platform-core/DB_CONVENTIONS.md`).

| 구성요소 | 규칙 |
|---|---|
| 테넌트 | `core.organizations`(가입 시 개인 조직 자동 생성, 회사 조직은 `is_personal=false`) |
| 멤버·역할 | `core.org_members` owner/admin/member/viewer, 조직당 owner 1명, 쓰기는 DEFINER 함수만 |
| 업무 테이블 | 모든 행에 `org_id uuid not null references core.organizations(id) on delete cascade` |
| RLS | 전 테이블 ON. 읽기 `is_org_member(org_id) and has_entitlement(org_id,'<app>')`, 쓰기는 `with check` 필수, `FOR ALL` 금지, 삭제는 owner/admin |
| 이용권·플랜 | `core.app_entitlements` + `core.plans.features`(서버만 해석) |
| 돈·권한·상태 | 사용자 쓰기 금지 → SELECT 정책 + `guard_privileged_write` + RPC |
| 파일 | Storage 경로 첫 폴더 = `org_id` |
| 감사·격리 시험 | `write_audit`, 다른 조직 사용자로 0행·42501 확인하는 RLS 스모크 |

### 5.2 테마 확장 테이블

테넌트는 **기존 코어의 `core.organizations`** 그대로입니다(`products/_supabase-modular/migrations/0001_core_identity.sql:32`). 이 폴더는 새 테이블만 더하고 기존 `core.*`를 고치지 않습니다. SQL 정본: [`supabase/0011_core_tenant_theming.sql`](supabase/0011_core_tenant_theming.sql)(제안·staged).

```
core.organizations (기존, 테넌트)  slug = 서브도메인(acme.myplatform.com)
├── core.app_entitlements (기존) → core.plans.features.theming_level  ← 화이트라벨 단계의 출처
│
├── tenant_themes            L1  org_id, app_id(null=조직 공통), status draft/published/archived, version,
│                                brand_name, logo_horizontal/mark/dark/favicon/og_image/email_header_path,
│                                tokens jsonb(허용 목록), fonts jsonb(키), contrast_report(서버만), published_*
├── tenant_settings          L1  org_id, app_id(null=공통), support_email/url, email_from_name, default_locale,
│                                timezone, legal(사업자 정보), footer_links, navigation(L2부터 적용)
├── tenant_labels            L2  (org_id, app_id, locale, key) → value
├── tenant_feature_overrides L2  (org_id, app_id, feature_key) → value, expires_at   [서버만 쓰기]
├── tenant_domains           L2  hostname(전역 유일), app_id, status pending→verifying→active, is_primary [RPC·서버만]
├── tenant_extensions        L3/4 (org_id, app_id, slot_key) → extension_key, kind slot/hook/webhook, config(서버만 읽기) [서버만 쓰기]
└── tenant_deployments       운영 org_id, app_id, deploy_model A/B/C, supabase_project_ref, vercel_project_id, release_channel [서버만 쓰기]

Storage: public-assets/<org_id>/theming/<theme_id>/<slot>.<ext>   (기존 버킷·정책 재사용, CHECK 로 경로 강제)
```

| 함수 | 호출자 | 하는 일 |
|---|---|---|
| `resolve_tenant(hostname, slug, app)` | anon·로그인·서버 | 요청마다 테넌트 해석. 공개해도 되는 값(게시 테마, 공개 설정, 단계, 대표 도메인, 슬롯 키)만. 단계 0이면 `null` |
| `tenant_public_labels(org, app, locale)` | anon·로그인·서버 | L2 이상일 때 라벨 사전 |
| `theming_level(org, app)` | 로그인·서버 | 단계(비멤버에게는 0) |
| `effective_features(org, app)` | 멤버·서버 | 플랜 features + 조직 오버라이드 |
| `publish_tenant_theme(theme_id)` | owner·admin·서버 | 대비 검사 통과한 초안만 게시, 이전 게시본 보관, 버전 +1, 감사 |
| `clone_tenant_theme(theme_id)` | owner·admin·서버 | 게시본·보관본을 새 초안으로(수정·되돌리기의 유일한 경로) |
| `request_tenant_domain(org, app, hostname)` | owner·admin(L2) | 도메인 연결 요청(조직당 5개) |
| `set_tenant_domain_status(id, status, …)` | 서버(검증 워커) | DNS 검증 결과 반영, 첫 활성 도메인을 대표로 |

**판매 모델과 DB**: 모델 C(공유 SaaS)와 모델 B(고객사 전용 Supabase)는 **같은 마이그레이션**을 씁니다. B는 그 DB에 조직이 1개일 뿐입니다. 그래서 C 고객이 B로 올라갈 때 코드 변경 없이 데이터만 옮깁니다(`products/_supabase-modular/ARCHITECTURE.md` 4.2절). 모델 A(설치형)는 Supabase 대신 로컬 저장이므로 해석 함수 대신 같은 JSON 형식의 설정 파일을 읽습니다.

테이블별 컬럼·RLS·상태 전이·SQLSTATE·모놀리스 변환은 [`04_DATA_MODEL.md`](04_DATA_MODEL.md).

## 6. 런타임과 운영

| 항목 | 규칙 | 상세 |
|---|---|---|
| 테넌트 식별 순서 | ① 활성 커스텀 도메인 ② `<slug>.<플랫폼 도메인>` 서브도메인 ③ 로그인 사용자의 현재 조직(앱 내부 화면) ④ 없으면 플랫폼 기본 | [`05_RUNTIME_AND_DOMAINS.md`](05_RUNTIME_AND_DOMAINS.md) 1장 |
| 캐시 | 해석 결과를 `tenant:<org_id>`·`host:<hostname>` 태그로 캐시, 게시·도메인 변경 시 무효화 | 2장 |
| 깜빡임 방지 | 테마 CSS는 서버가 `<head>`에 직접 넣는다. 클라이언트에서 불러와 바꾸지 않는다 | 3장 |
| 커스텀 도메인 | Vercel 프로젝트 도메인 API로 추가 → 고객이 DNS 설정 → 검증 워커가 상태 갱신 | 4장 |
| 이메일 | 발신 이름만 테넌트, 발신 도메인은 플랫폼(고객 도메인 발신은 L4 옵션, SPF·DKIM 필요) | 5장 |
| 장애 시 | 해석 실패·타임아웃은 플랫폼 기본 테마로 렌더하고 로그만 남긴다(서비스 중단 금지) | 6장 |

## 7. 제품에 적용하는 순서

| 순서 | 할 일 | 산출물 | 상세 |
|---|---|---|---|
| 0 | 이 문서 승인 → `0011` SQL을 `_supabase-modular/migrations/`로 옮김(코어 변경 = Fable 담당, 전 제품 RLS 회귀 통과 후) | 코어 마이그레이션 | [`06_ADOPTION_PLAN.md`](06_ADOPTION_PLAN.md) 1장 |
| 1 | 제품 `tokens.css`를 3계층으로 정리하고 하드코딩 색 제거(`bg-[#…]` 린트) | 토큰화된 UI | MT-02 |
| 2 | `packages/core-tenancy` + `proxy.ts`·`layout.tsx` 연결 | L1 동작 | MT-03~05 |
| 3 | 브랜딩 설정 화면(로고 업로드·색 추출·대비 검사·미리보기·게시) | 셀프서비스 L1 | MT-06~08 |
| 4 | 라벨·메뉴·피처 오버라이드·커스텀 도메인 | L2 | MT-09~12 |
| 5 | 슬롯 레지스트리, 확장 훅 | L3/L4 | MT-13~14 |
| 6 | 운영 SOP·가격 연결 | 판매 | [`07_SALES_AND_OPERATIONS.md`](07_SALES_AND_OPERATIONS.md) |

**지금 당장 할 최소 단위(MVP)**: 0~3단계(L1)만. 이것만으로 "로고 주시면 귀사 전용 플랫폼" 판매가 가능합니다. L2 이후는 실제 고객 요청이 2번 이상 반복될 때 만듭니다.

## 8. 파일 목록

| 파일 | 내용 |
|---|---|
| [`01_CONCEPTS.md`](01_CONCEPTS.md) | 용어 사전, 5단계 판단 기준, 판매 모델 A/B/C 매핑, 포크·설정·전용 DB 비교, 원칙과 금지 |
| [`02_DESIGN_TOKENS.md`](02_DESIGN_TOKENS.md) | 3계층 토큰, 테넌트 허용 목록, 로고 슬롯 규격, 로고→팔레트 자동 생성, 대비 보정, 서체, 다크 모드, 메일·OG |
| [`03_CODE_STRUCTURE.md`](03_CODE_STRUCTURE.md) | 패키지·앱 폴더 트리, proxy·layout 흐름, 라벨·메뉴·슬롯, 관리 화면, 린트·테스트 |
| [`04_DATA_MODEL.md`](04_DATA_MODEL.md) | ERD, 테이블 상세, RLS·권한 표, 함수, 상태 전이, SQLSTATE, Storage, 모놀리스·모델 B |
| [`05_RUNTIME_AND_DOMAINS.md`](05_RUNTIME_AND_DOMAINS.md) | 요청 흐름, 캐시 무효화, 커스텀 도메인 연결, 이메일, SEO, 장애 폴백 |
| [`06_ADOPTION_PLAN.md`](06_ADOPTION_PLAN.md) | 작업 목록(MT-01~16, 소유 경로·의존성·수용 기준), 웨이브, 제품별 적용 순서, 열린 결정 |
| [`07_SALES_AND_OPERATIONS.md`](07_SALES_AND_OPERATIONS.md) | 단계별 상품·가격 연결, 고객 온보딩 체크리스트, 운영 SOP, 자동화, 린 검증 |
| [`supabase/0011_core_tenant_theming.sql`](supabase/0011_core_tenant_theming.sql) | 코어 확장 마이그레이션(제안). 모듈러 그대로, 모놀리스는 `core.`→`public.` 치환 |
| [`supabase/tests/tenant_theming_smoke.sql`](supabase/tests/tenant_theming_smoke.sql) | RLS·권한 회귀 91항목(제품 `rls_smoke.sql`과 같은 형식) |
| [`supabase/tests/run-smoke.mjs`](supabase/tests/run-smoke.mjs) | PGlite 러너(Supabase 없이 실행) |

## 9. 검증 (2026-10-14, PGlite)

```bash
cd products/_tools-sqlcheck && npm ci && cd ../..
# 적용 검사(두 번 적용해 반복 실행 안전성 확인)
node products/_tools-sqlcheck/check.mjs --vector mod products/_supabase-modular/migrations/000*.sql \
  products/_supabase-modular/seed.sql Multi-tenant_Theming/supabase/0011_core_tenant_theming.sql Multi-tenant_Theming/supabase/0011_core_tenant_theming.sql
# RLS·권한 회귀
node Multi-tenant_Theming/supabase/tests/run-smoke.mjs --target mod
node Multi-tenant_Theming/supabase/tests/run-smoke.mjs --target mono
```

| 검사 | 결과 |
|---|---|
| 모듈러 적용(core 0000~0009 + seed + 0011 두 번) | OK |
| 모놀리스 적용(`MONOLITH_CORE_LITE.sql` + 0011 치환본 두 번) | OK |
| RLS 스모크 모듈러 / 모놀리스 | 91/91, 91/91 통과 |

주요 검사 항목: 다른 조직 테마·라벨·도메인·배포 기록 0행, 비멤버·member의 생성·게시 42501, 단계 0 조직의 테마 생성 42501, CSS 주입 토큰·허용 목록 밖 토큰·URL 서체·다른 조직 로고 경로·`..` 경로 23514, 상태·대비 결과 직접 쓰기 42501, 대비 미통과 게시 TM002, 게시본 수정 TM003(서버 포함), 토큰 수정 시 대비 결과 무효화, 버전 증가·보관, 도메인 중복 TM005, 잘못된 도메인 전이 22023, 단계를 낮추면 내비게이션·라벨·슬롯이 즉시 비노출, 엔타이틀먼트 정지 시 기본 테마로 복귀, anon은 해석 함수 외 접근 불가.

## 10. 규칙

- 이 폴더는 공용 설계입니다. 제품 작업에서 고치지 않고 각 제품 `06_AGENT_PLAN.md` 6절 "공용 모듈 요청"에 적습니다(루트 README 6장과 같은 규칙).
- `0011` SQL은 승인 전까지 이 폴더에만 둡니다. 코어로 옮길 때는 번호 충돌(`_platform-core/staged/0010`)을 다시 확인합니다.
- 기술 스택은 Next.js 16.2.x, React 19.2, Tailwind CSS v4(4.x 고정, `tailwind.config.js` 금지), shadcn/ui, Supabase(PostgreSQL 15)입니다.
- 이 저장소 변경은 브랜치 → PR → main 병합으로 합니다.
