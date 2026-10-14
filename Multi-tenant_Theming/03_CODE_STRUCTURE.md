# 03_CODE_STRUCTURE — 코드 구조와 요청 흐름

작성일 2026-10-14. 스택은 Next.js 16.2.x(App Router, `src/proxy.ts`), React 19.2, TypeScript strict, Tailwind CSS v4, shadcn/ui, Supabase. 경로는 제품 저장소 기준이며 `apps/<제품>/`은 제품마다 `web/`으로 줄여 쓰기도 한다(각 제품 `06_AGENT_PLAN.md` 머리 표). TypeScript 블록은 계약 예시이고 구현 파일이 아니다.

## 1. 폴더 트리

```
packages/core-tenancy/                      공용 패키지(제안, SHARED_MODULES.md 0장 배치 규칙을 따름)
├── src/index.ts                 공개 API: getTenant, themeCss, t, getNavigation, Slot, assetUrl
├── src/types.ts                 ResolvedTenant, TenantTheme, TenantSettings (아래 2장)
├── src/resolve.ts               host·slug → core.resolve_tenant RPC, 캐시 태그
├── src/host.ts                  Host 정규화, 플랫폼 루트 도메인 판별, slug 추출
├── src/theme-css.ts             ResolvedTenant → CSS 문자열(허용 목록·값 재검증, 다크 파생)
├── src/tokens/allowlist.ts      의미 토큰 허용 목록(SQL is_valid_theme_tokens 와 같은 목록)
├── src/tokens/defaults.ts       플랫폼 기본 의미 토큰(tokens.css 와 같은 값, 생성 스크립트로 동기화)
├── src/palette/extract.ts       로고 → 후보 색(서버 전용: sharp)
├── src/palette/derive.ts        brand → 파생 토큰, 라이트 → 다크
├── src/contrast.ts              WCAG 대비 계산, 자동 보정, contrast_report 생성
├── src/fonts.ts                 서체 레지스트리(키 → next/font/local)
├── src/labels.ts                t(key, vars) = 테넌트 라벨 ▶ 제품 기본 사전 ▶ 키
├── src/navigation.ts            메뉴 레지스트리 + tenant navigation 병합
├── src/slots.tsx                <Slot>: 확장 레지스트리 조회 → 없으면 fallback
├── src/assets.ts                Storage 경로 → 공개 URL, 슬롯 폴백(02장 3절)
├── src/schema.ts                zod: tokens, fonts, settings, navigation, labels (DB CHECK 와 같은 규칙)
├── src/server/                  서버 전용: 업로드 서명 URL, SVG 정화, 대비 기록(service_role)
└── tests/                       theme-css 이스케이프, 파생 결정성, 대비, 허용 목록 3중 일치

apps/<제품>/
├── src/proxy.ts                 라우트 보호(기존) + 테넌트 판별(이 문서 3장)
├── src/app/layout.tsx           테마 CSS·서체·파비콘·메타데이터 서버 렌더
├── src/app/(marketing)/         공개 랜딩: 테넌트가 있으면 테넌트 브랜드, 없으면 제품 브랜드
├── src/app/(auth)/              로그인: 테넌트 로고·이름, 커스텀 도메인에서는 그 조직 전용 로그인
├── src/app/(app)/settings/branding/   브랜딩(패턴 H + J): 로고 업로드 → 색 추출 → 편집 → 대비 → 미리보기 → 게시·되돌리기
├── src/app/(app)/settings/domains/    커스텀 도메인(패턴 H, 상태는 N 형식 배지)
├── src/app/(app)/settings/labels/     용어 바꾸기(패턴 O 그리드: 키, 기본 문구, 내 문구)
├── src/app/(app)/settings/menu/       메뉴 숨김·순서(L2)
├── src/app/api/tenant/          Route Handler(5장 표)
├── src/app/api/internal/domains/verify/   도메인 검증 크론(service_role)
├── src/lib/tenancy/             제품 어댑터: core-tenancy 설정(앱 id, 루트 도메인, 서체·확장 레지스트리 연결)
├── src/lib/i18n/messages.ko.ts  제품 기본 사전 = 라벨 키 정본
├── src/lib/nav/registry.ts      메뉴 키 정본
├── src/extensions/registry.ts   확장 키 → 지연 import 정적 맵(L3/L4)
├── src/extensions/<tenant-slug>/      고객사 전용 코드(최소). 반복되면 공통 기능으로 승격
└── src/styles/tokens.css        원시·의미 토큰 기본값(02장 6절)
```

## 2. 해석 결과 타입 (DB `core.resolve_tenant` 반환과 1:1)

```ts
export type ThemingLevel = 0 | 1 | 2 | 3 | 4;

export interface ResolvedTenant {
  org_id: string;
  slug: string;
  app_id: string;
  level: ThemingLevel;               // 1 이상만 반환된다(0이면 null)
  primary_domain: string | null;     // L2 이상 + 활성 대표 커스텀 도메인. 서브도메인 접속을 여기로 301
  theme: {
    id: string;
    version: number;
    brand_name: string;
    assets: Partial<Record<'logo_horizontal' | 'logo_mark' | 'logo_dark' | 'favicon' | 'og_image' | 'email_header', string>>; // Storage 경로
    tokens: { light?: Record<string, string>; dark?: Record<string, string> };
    fonts: Partial<Record<'heading' | 'body' | 'mono', string>>;
  } | null;                          // 게시본이 없으면 null → 기본 테마 + 브랜드 이름만 조직 이름
  settings: {
    support_email: string | null; support_url: string | null; email_from_name: string | null;
    default_locale: string; timezone: string;
    legal: Record<string, string>; footer_links: { label: string; href: string }[];
    navigation: { key: string; hidden?: boolean; order?: number; label_key?: string }[]; // L1이면 []
  } | null;
  extensions: Record<string, string>; // slot_key → extension_key (L3 슬롯, L4 훅). config 는 없다
}

export async function getTenant(): Promise<ResolvedTenant | null>; // 요청당 1회(React cache) + 교차 요청 캐시
```

모델 A(설치형, 예: arch-studio)는 같은 형식의 `tenant.json`을 빌드에 넣고 `getTenant()`가 파일을 읽는다(01장 3절).

## 3. 요청 흐름

```
브라우저 ─▶ proxy.ts
             1) 들어온 x-tenant-* 헤더를 지운다(위조 방지)
             2) host = 정규화(소문자, 포트 제거)
             3) host ∈ PLATFORM_ROOT_DOMAINS        → 테넌트 없음(제품 브랜드)
                host = <slug>.<루트 도메인>          → x-tenant-slug=<slug>
                그 외                                → x-tenant-host=<host> (커스텀 도메인 후보)
             4) 기존 라우트 보호(session_context) 그대로
        ─▶ app/layout.tsx (서버 컴포넌트)
             5) tenant = await getTenant()          → resolve_tenant RPC(anon 키로 충분), 캐시
             6) <html data-tenant={tenant?.slug}> <head><style nonce>{themeCss(tenant)}</style> + 파비콘 + 서체 클래스
             7) generateMetadata: title·OG·manifest 를 테넌트 값으로
        ─▶ 페이지
             8) 텍스트는 t('key'), 메뉴는 getNavigation(), 교체 지점은 <Slot name>
             9) 기능 판단은 서버에서 effective_features(org, app) (클라이언트 값 금지)
```

| 규칙 | 내용 |
|---|---|
| 판별은 proxy, 해석은 layout | proxy는 문자열 판별과 헤더만(빠르게). DB 호출·캐시는 서버 컴포넌트의 `getTenant()` 한 곳 |
| 캐시 | 요청 안 중복 제거는 React `cache()`. 요청 간 캐시는 Next 16 `"use cache"` + `cacheTag('tenant:<org_id>', 'host:<host>')`(cacheComponents 사용 시) 또는 `unstable_cache`. 게시·도메인·설정 변경 시 태그 무효화(05장 2절). 정확한 API 이름·시그니처는 구현 시 Next.js 16.2 문서로 확인 |
| 로컬 개발 | `acme.localhost:3000`이 서브도메인 판별을 그대로 시험한다. `PLATFORM_ROOT_DOMAINS=localhost:3000,<운영 도메인>` |
| 쿠키 범위 | Supabase 인증 쿠키는 **호스트 전용**(Domain 속성 없이). 서브도메인 간 세션이 공유되지 않게 한다. 커스텀 도메인은 원래 쿠키가 분리된다 |
| 조직 불일치 | 테넌트 호스트에서 로그인한 사용자의 현재 조직(`session_context.org`)이 그 테넌트가 아니면: 멤버면 그 조직으로 전환, 아니면 "이 워크스페이스의 멤버가 아닙니다" 화면. 다른 조직 데이터를 그 브랜드 아래에 보여 주지 않는다 |
| 플랫폼 도메인 | 플랫폼 도메인(테넌트 없음)의 앱 화면은 로그인 사용자의 현재 조직 테마를 쓴다: `resolve_tenant(null, org.slug, app)` |

## 4. 라벨·메뉴·슬롯·기능

| 장치 | 단계 | 구현 규칙 |
|---|---|---|
| 라벨 `t(key)` | L2 | 제품 기본 사전(`messages.ko.ts`)이 키의 정본. 테넌트 라벨은 사전에 있는 키만 덮어쓴다(설정 화면은 사전 키 목록에서 고르게). 변수(`{count}`)는 기본 문구와 같은 변수만 허용. 라벨 값은 텍스트로만 렌더(HTML 금지) |
| 메뉴 | L2 | 메뉴 레지스트리(`nav/registry.ts`)가 키·경로·권한·기본 순서의 정본. 테넌트는 `hidden`, `order`, `label_key`만. 경로·권한은 바꿀 수 없다. 숨긴 메뉴의 라우트는 그대로 권한 검사를 받는다(숨김 ≠ 차단). 차단은 기능 플래그로 |
| 기능 플래그 | L2 | 서버에서 `effective_features(org, app)`. 키 의미는 제품 `01_PRD.md` 4장 표가 정본. 조직 예외는 운영자가 `tenant_feature_overrides`에 기간(`expires_at`)과 사유를 남겨 넣는다 |
| 슬롯 `<Slot name>` | L3 | 코드에 미리 둔 교체 지점(예: `dashboard.home`, `auth.side-panel`, `footer.extra`). 슬롯 목록은 제품 문서에 표로 둔다. `extension_key` → 컴포넌트는 `extensions/registry.ts`의 **정적 맵**에서만 찾는다(임의 코드 로드 금지). 확장 컴포넌트도 토큰·라벨·권한 규칙을 그대로 따른다 |
| 훅 | L4 | 서버 이벤트 지점(예: `order.after_create`)에서 `tenant.extensions`에 키가 있으면 확장 함수 실행 또는 잡 enqueue. 외부 전송은 웹훅·n8n(서명, 재시도, 멱등 키) |

```tsx
// 슬롯 사용 예(형식)
<Slot name="dashboard.home" fallback={<DefaultHome />} />
// extensions/registry.ts: { 'acme-home': () => import('./acme/AcmeHome') } — 정적 맵, 키가 없으면 fallback
```

## 5. Route Handler

진입 규칙은 제품 공통과 같다: `requireSession('<app>')` → owner/admin 확인 → zod → 레이트 리밋 → 처리. 단계 검사는 DB(RLS·RPC)가 다시 한다.

| 메서드·경로 | 하는 일 | DB |
|---|---|---|
| `POST /api/tenant/assets/upload-url` | 슬롯 이름·형식 검사 → `public-assets/<org_id>/theming/<theme_id>/<slot>.<ext>` 서명 업로드 URL | Storage 정책(멤버만 자기 조직 폴더) |
| `POST /api/tenant/assets/finalize` | 업로드 파일 검사(형식·크기·비율), SVG 정화 후 덮어쓰기, PNG 파생본(파비콘 크기별·메일 머리) 생성 | 서버 |
| `POST /api/tenant/themes` | 초안 생성 | `tenant_themes` INSERT(사용자 세션, RLS) |
| `POST /api/tenant/themes/extract` | 로고 → 팔레트 → 초안 토큰 제안(저장 전 미리보기) | 없음 |
| `PATCH /api/tenant/themes/[id]` | 초안 수정(토큰·로고·서체·이름) | UPDATE(초안만, 트리거가 대비 결과 초기화) |
| `POST /api/tenant/themes/[id]/check` | 대비 검사 → `contrast_report` 기록 | service_role UPDATE |
| `POST /api/tenant/themes/[id]/publish` | 게시 → 캐시 태그 무효화 | `publish_tenant_theme`(사용자 세션) |
| `POST /api/tenant/themes/[id]/clone` | 게시본·보관본 → 새 초안(되돌리기) | `clone_tenant_theme` |
| `PUT /api/tenant/settings` | 고객센터·사업자 정보·푸터·메뉴 | `tenant_settings` upsert |
| `PUT /api/tenant/labels` | 라벨 일괄 저장(사전 키만) | `tenant_labels` upsert/delete |
| `POST /api/tenant/domains` | 도메인 요청 → 호스팅에 도메인 추가 → DNS 안내 저장 | `request_tenant_domain` → service `set_tenant_domain_status('verifying', 안내)` |
| `DELETE /api/tenant/domains/[id]` | 호스팅에서 제거 → `removed` | service |
| `POST /api/internal/domains/verify` | 크론(10분): verifying·active 도메인 점검 | service |

## 6. 관리 화면 (`_design-guide/DASHBOARD_PATTERNS.md` 코드)

| 화면 | 패턴 | 필수 요소 |
|---|---|---|
| 브랜딩 | H + J | 왼쪽: 로고 슬롯 6개(드롭존, 규격 안내), "로고에서 색 뽑기", 색 편집(라이트·다크 탭), 서체 선택, 라운드. 오른쪽: 실제 컴포넌트 미리보기(헤더, 사이드바, 버튼, 배지, 표, 오류 알림, 차트) 라이트·다크 전환. 하단 바: 대비 결과(통과·자동 보정·실패 쌍), "게시", 버전 기록(게시일·게시자·되돌리기) |
| 도메인 | H | 도메인 입력 → DNS 레코드 표(복사 버튼) → 상태 배지(대기·확인 중·연결됨·실패, 색 + 텍스트) → 대표 도메인 표시. L2 미만이면 잠금 안내와 업그레이드 경로 |
| 용어 | O | 키·기본 문구·내 문구 3열 그리드, 검색, 변경된 것만 보기, 되돌리기 |
| 메뉴 | H | 메뉴 목록 끌어 놓기 순서, 숨김 스위치, 미리보기 사이드바 |

권한: owner·admin만 편집, member·viewer는 읽기만(DB 정책과 같음). 모든 화면은 기본·로딩·빈 상태·오류·권한 없음 상태를 가진다(`DASHBOARD_PATTERNS.md` 6장).

## 7. 린트·정적 규칙

| 규칙 | 막는 것 |
|---|---|
| `no-arbitrary-color`(제안: `bg-[#…]`, `text-[#…]`, `style={{ color: '#…' }}` 금지) | 테넌트 색이 안 바뀌는 구멍 |
| 테넌트 분기 금지: `tenant.slug ===`, `org_id ===` 리터럴 비교, `extensions/<slug>` 밖에서 고객사 이름 문자열 | 포크와 같은 효과의 코드 분기 |
| `x-tenant-*` 헤더는 `core-tenancy` 밖에서 읽기 금지 | 헤더 신뢰 경계 분산 |
| `dangerouslySetInnerHTML` 금지(로고·라벨) | XSS |
| `extensions/` 밖에서 `extensions/<slug>/` import 금지(레지스트리만 예외) | 고객사 코드가 공통 코드에 섞임 |

## 8. 테스트

| 종류 | 항목 | 위치(제안) |
|---|---|---|
| 단위 | `themeCss`: 허용 목록 밖 키 무시, 위험 값 거부, 라이트만 준 키의 다크 파생, 선택자 형식 | `packages/core-tenancy/tests/` |
| 단위 | 팔레트 파생 결정성(같은 로고 → 같은 결과), 대비 계산이 기준 도구와 ±0.01 이내, 자동 보정 후 전 쌍 통과 | 같음 |
| 동기화 | 허용 목록 3곳(SQL 함수, `allowlist.ts`, 02장 표)이 같은지 CI에서 비교 | 같음 |
| DB | `supabase/tests/tenant_theming_smoke.sql` 91항목(모듈러·모놀리스) | 이 폴더 |
| E2E | 시험 테넌트 2개(`acme`, `beta`)를 `*.localhost`로 열어 로고·색·라벨이 서로 섞이지 않는지, 비멤버 접근 차단, 게시 직후 반영 | `e2e/tenancy/` |
| 시각 회귀 | 시험 테넌트 3종(파랑·빨강·노랑) × 라이트·다크 × 핵심 화면 5개 스크린샷 | `e2e/visual/` |
