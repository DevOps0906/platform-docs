# 02_DESIGN_TOKENS — 테넌트 테마의 디자인 구조

작성일 2026-10-14. `_design-guide/DESIGN_SYSTEM.md`(정답 소스 = 제품 저장소의 Tailwind CSS v4 `tokens.css`)를 전제로, **테넌트가 무엇을 얼마나 바꿀 수 있는지**를 정한다. 코드 블록은 형식 예시이며 구현 정답은 제품 저장소 코드다.

## 1. 3계층 토큰과 테넌트 권한

| 계층 | 예 | 정의 위치 | 테넌트 변경 |
|---|---|---|---|
| 원시(Primitive) | `--blue-600`, `--gray-50`, `--space-4`, `--shadow-md` | `tokens.css` `@theme` | 불가 |
| 의미(Semantic) — 개방 | `--color-brand`, `--color-accent`, `--color-sidebar`, `--color-chart-1`, `--radius-control` | `tokens.css` 기본값 + 테넌트 `<style>` | **허용 목록만** |
| 의미(Semantic) — 고정 | `--color-background`, `--color-surface`, `--color-text`, `--color-text-muted`, `--color-border`, `--color-danger`, `--color-success`, `--color-warning` | `tokens.css` | 불가 |
| 컴포넌트 | `--button-bg: var(--color-brand)` | 컴포넌트 CSS | 불가(의미 토큰을 따라 자동 변경) |

고정하는 이유: 배경·본문 글자는 대비(가독성), 상태색은 의미(빨강=위험)를 지켜야 한다. 고객사 브랜드가 빨강이어도 `danger`는 따로 남아 오류 표시가 묻히지 않는다.

## 2. 테넌트 허용 목록 (DB `core.is_valid_theme_tokens`와 같은 목록)

| 키(DB) | CSS 변수 | 용도 | 값 형식 | 기본 파생(비어 있을 때) |
|---|---|---|---|---|
| `brand` | `--color-brand` | 주 버튼, 활성 탭, 링크 | `#rrggbb` 또는 `oklch(L C H)` | 플랫폼 기본 |
| `brand-foreground` | `--color-brand-foreground` | 주 버튼 위 글자 | 같음 | `brand`와 대비 4.5:1 이상인 흰색/검정 중 하나 |
| `brand-hover` | `--color-brand-hover` | 주 버튼 호버 | 같음 | `brand`의 OKLCH L −0.06 |
| `brand-subtle` | `--color-brand-subtle` | 선택 행, 배지 배경 | 같음 | L 0.96, C ×0.25 (다크: L 0.28) |
| `accent` | `--color-accent` | 보조 강조, 하이라이트 | 같음 | `brand`의 H +30° |
| `accent-foreground` | `--color-accent-foreground` | 보조 강조 위 글자 | 같음 | 대비로 선택 |
| `focus-ring` | `--color-focus-ring` | 키보드 포커스 링 | 같음 | `brand` (배경 대비 3:1 미만이면 L 보정) |
| `sidebar` | `--color-sidebar` | 앱 셸 사이드바 배경 | 같음 | 플랫폼 기본(중립) |
| `sidebar-foreground` | `--color-sidebar-foreground` | 사이드바 글자 | 같음 | 대비로 선택 |
| `chart-1`~`chart-5` | `--color-chart-1`~`5` | 차트 계열색 | 같음 | `brand`부터 H를 72°씩 회전 |
| `radius-control` | `--radius-control` | 버튼·입력 라운드 | `0`, `Npx`, `Nrem` | 플랫폼 기본 |
| `radius-card` | `--radius-card` | 카드·모달 라운드 | 같음 | 플랫폼 기본 |

- DB는 문자 수준만 막는다(`#`·숫자·`oklch(…)`, 세미콜론·중괄호·`url()` 불가, CHECK 23514). 색 공간 범위·대비 같은 정밀 검증은 서버(`packages/core-tenancy/src/schema.ts`, `contrast.ts`)가 한다.
- 키를 추가하려면 세 곳을 같이 바꾼다: SQL `is_valid_theme_tokens`, `core-tenancy/src/tokens/allowlist.ts`, 이 표. 셋이 다르면 CI가 실패하게 한다(03장 8절).

## 3. 로고·자산 슬롯 규격

| 슬롯(DB 컬럼) | 쓰는 곳 | 권장 형식·크기 | 업로드 검사 | 없을 때 |
|---|---|---|---|---|
| `logo_horizontal_path` | 헤더, 로그인, 메일 서명 | SVG(권장) 또는 PNG 투명, 높이 기준 표시(헤더 28px, 로그인 40px) | 가로세로비 1.5~8:1, PNG 최소 높이 120px | 브랜드 이름 텍스트(서체 heading) |
| `logo_mark_path` | 접힌 사이드바, 모바일 헤더, PWA 아이콘 | SVG 또는 PNG 512×512 정사각 | 가로세로비 0.8~1.25 | 브랜드 이름 첫 글자 + `brand` 배경 원 |
| `logo_dark_path` | 다크 모드·어두운 사이드바 | 가로형과 같음 | 같음 | 가로형을 밝은 배경 판(`--color-surface`) 위에 표시. 자동 색 반전 금지 |
| `favicon_path` | 브라우저 탭 | 정사각 PNG 512 → 서버가 16/32/180/192/512 생성 | 정사각 | `logo_mark` 에서 생성 |
| `og_image_path` | 링크 공유 미리보기 | 1200×630 PNG·JPG | 크기 일치 | `next/og`로 브랜드 이름 + 로고 + `brand` 배경 자동 생성 |
| `email_header_path` | 트랜잭션 메일 머리 | PNG 600×120 이하(메일 클라이언트는 SVG 미지원) | PNG·JPG만 | 가로형 로고를 PNG로 변환 |

저장 경로: `public-assets/<org_id>/theming/<theme_id>/<slot>.<ext>`(기존 공개 버킷, `0005_core_jobs_storage.sql:322`). DB CHECK가 다른 조직 경로와 `..`을 거부한다.

SVG 안전 규칙:

| 규칙 | 이유 |
|---|---|
| 업로드 시 서버에서 정화(스크립트·이벤트 속성·외부 참조·`<foreignObject>` 제거, 예: SVGO + DOMPurify 서버 모드) 후 저장 | SVG는 스크립트를 담을 수 있다 |
| 화면에는 `<img src>` 또는 `next/image`로만 표시. `dangerouslySetInnerHTML` 금지 | `<img>`로 넣은 SVG는 스크립트가 실행되지 않는다 |
| 파일명은 서버가 정한다(`<slot>.svg`). 사용자 파일명은 쓰지 않는다 | 경로 조작 방지(`SECURITY_BASELINE.md`) |
| 업로드 크기 1MB 이하(버킷 한도 10MB와 별도) | 렌더 성능 |

## 4. 로고에서 테마 자동 생성 (L1 셀프서비스의 핵심)

| 단계 | 처리 | 구현(제안) |
|---|---|---|
| 1 | 로고를 PNG로 래스터화(SVG면 512px) | `sharp` |
| 2 | 투명·흰색·검정에 가까운 픽셀을 빼고 색 양자화(k-means, k=6) | `sharp` raw 픽셀 + 자체 k-means 또는 `node-vibrant` |
| 3 | 후보를 OKLCH로 변환, `면적 비율 × 채도(C)` 점수로 정렬 → 1위 = `brand`, H가 30° 이상 다른 2위 = `accent` | `culori` |
| 4 | 라이트 값: 그대로 쓰되 `brand`의 L을 0.45~0.62 범위로 클램프(흰 배경 위 버튼 가독성) | 같음 |
| 5 | 다크 값: L을 0.68~0.78로 올리고 C를 ×0.9 | 같음 |
| 6 | 파생 토큰 계산(2장 표 "기본 파생" 열) | 같음 |
| 7 | 대비 검사(5장) → 미통과 쌍은 H를 유지하고 L만 0.01씩 조정해 통과시킨 뒤, 원래 값과 함께 "자동 보정됨"으로 보여 준다 | `contrast.ts` |
| 8 | 초안 저장(`source='logo_extract'`), 미리보기 화면으로 | Route Handler |

사용자는 결과를 보고 색을 직접 고칠 수 있다. 고치면 DB 트리거가 대비 결과를 지우고, 서버가 다시 검사해야 게시할 수 있다.

## 5. 대비 검사 (게시 조건, DB가 강제)

| 쌍(앞/뒤) | 기준(WCAG 2.1 AA) | 모드 |
|---|---|---|
| `brand-foreground` / `brand` | 4.5:1 | 라이트·다크 |
| `brand-foreground` / `brand-hover` | 4.5:1 | 라이트·다크 |
| `accent-foreground` / `accent` | 4.5:1 | 라이트·다크 |
| `sidebar-foreground` / `sidebar` | 4.5:1 | 라이트·다크 |
| `brand` / `background` (링크·아이콘) | 3:1 | 라이트·다크 |
| `focus-ring` / `background` | 3:1 | 라이트·다크 |
| `brand-subtle` / `text` | 4.5:1 | 라이트·다크 |
| `chart-n` / `surface` | 3:1 | 라이트·다크 |

`contrast_report` 형식(서버만 기록, 사용자 세션은 컬럼 권한이 없어 42501):

```json
{
  "passed": true,
  "checked_by": "server",
  "algorithm": "wcag21",
  "pairs": [{ "mode": "light", "fg": "brand-foreground", "bg": "brand", "ratio": 5.12, "min": 4.5, "ok": true }],
  "adjusted": [{ "mode": "dark", "key": "brand", "from": "oklch(0.62 0.19 255)", "to": "oklch(0.70 0.17 255)" }]
}
```

`publish_tenant_theme`은 `contrast_report.passed = true`가 아니면 TM002로 거부한다. 토큰·로고를 바꾸면 트리거가 결과를 지운다.

## 6. CSS로 내보내는 형식

기본값(`tokens.css`, Tailwind CSS v4):

```css
@import "tailwindcss";
@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *));

@theme {
  /* 의미 토큰 기본값 (테넌트 덮어쓰기 대상) */
  --color-brand: oklch(0.55 0.2 255);
  --color-brand-foreground: oklch(0.99 0 0);
  --radius-control: 8px;
  /* … 고정 의미 토큰, 원시 토큰 … */
}

/* shadcn/ui 변수는 의미 토큰을 가리키기만 한다 */
:root {
  --primary: var(--color-brand);
  --primary-foreground: var(--color-brand-foreground);
  --ring: var(--color-focus-ring);
  --sidebar: var(--color-sidebar);
  --chart-1: var(--color-chart-1);
  --radius: var(--radius-control);
}
```

테넌트 덮어쓰기(`core-tenancy/src/theme-css.ts`가 만들고 루트 레이아웃이 `<head>`에 서버 렌더):

```css
:root:not([data-theme="dark"]) { --color-brand: #1d4ed8; --color-brand-foreground: #ffffff; --radius-control: 6px; }
:root[data-theme="dark"]       { --color-brand: oklch(0.7 0.15 250); --color-brand-foreground: #0b1020; }
```

| 규칙 | 이유 |
|---|---|
| 라이트는 `:root:not([data-theme="dark"])`, 다크는 `:root[data-theme="dark"]` 선택자 | 라이트 덮어쓰기가 다크 모드로 새지 않게 |
| 라이트에 있는 키는 다크에도 반드시 출력(없으면 4장 5단계로 파생) | 다크에서 플랫폼 기본색과 섞이는 사고 방지 |
| 키는 허용 목록을 다시 확인하고, 값은 DB와 같은 정규식으로 재검증 후 출력 | DB 우회(직접 SQL 수정) 대비 이중 잠금 |
| `<style nonce>`로 CSP 허용 | 인라인 스타일 CSP |
| 컴포넌트는 `bg-brand`, `text-brand-foreground`처럼 토큰 유틸만. `bg-[#…]` 금지 | 테넌트 색이 적용되지 않는 구멍 방지(`DESIGN_SYSTEM.md` 6장) |

## 7. 서체

| 규칙 | 내용 |
|---|---|
| 저장 | `fonts = {"heading": "pretendard", "body": "noto-sans-kr", "mono": "jetbrains-mono"}`. URL·파일 경로 금지(DB가 키 형식만 허용) |
| 레지스트리 | `core-tenancy/src/fonts.ts`에 키 → `next/font/local` 정의. 라이선스가 확인된 서체만(OFL 등). 초기 목록(제안): `pretendard`, `noto-sans-kr`, `suit`, `spoqa-han-sans-neo`, `nanum-square-neo`, `ibm-plex-sans-kr`, `jetbrains-mono` |
| 로딩 | 레지스트리 서체는 모두 `display: swap`, 테넌트가 고른 것만 `<html>` 클래스로 활성. 한글 서체는 서브셋(KS X 1001 2,350자) 우선 |
| 고객 전용 서체 | L3 견적. 고객이 웹 사용 라이선스를 증빙해야 하며 레지스트리에 키로 추가한다 |

## 8. 메일·OG·PWA

| 대상 | 규칙 |
|---|---|
| 메일 | 메일 클라이언트는 CSS 변수·OKLCH를 모른다. 렌더 시 의미 토큰을 hex로 변환해 인라인 스타일로. 머리 이미지는 `email_header` PNG. 발신 이름은 `tenant_settings.email_from_name`, 발신 주소·도메인은 플랫폼(05장 5절) |
| OG 이미지 | `og_image`가 없으면 `next/og`로 생성(브랜드 이름, 로고 마크, `brand` 배경). 해석 결과 `theme.version`을 캐시 키에 넣는다 |
| 파비콘·PWA | `favicon` → 없으면 `logo_mark`에서 크기별 생성. `manifest`의 `name`·`theme_color`는 테넌트 값 |
| 문서 출력(PDF) | 렌더 서비스(WeasyPrint)에 의미 토큰 hex와 로고 URL만 넘긴다. 템플릿은 토큰 변수만 사용 |

## 9. 디자인 작업 순서 (`DESIGN_SYSTEM.md` 4단계 위에 더할 것)

| 단계 | 할 일 | 확인 |
|---|---|---|
| 1 | 제품 `tokens.css`를 3계층으로 나누고 개방·고정 의미 토큰을 2장 표대로 이름 짓기 | 이름이 허용 목록과 일치 |
| 2 | 컴포넌트에서 hex·원시 토큰 직접 사용 제거(린트 `no-arbitrary-color`) | 린트 0건 |
| 3 | 미리보기 페이지(`/dev/components`)에 "테마 전환" 컨트롤 추가: 기본 / 시험 테넌트 3종(파랑·빨강·노랑 브랜드) × 라이트·다크 | 스크린샷 12장 |
| 4 | 노랑(대비 최악)·빨강(위험색 충돌) 시험 테넌트로 버튼·배지·오류 표시가 구분되는지 사람이 확인 | 사람 검토 기록 |
