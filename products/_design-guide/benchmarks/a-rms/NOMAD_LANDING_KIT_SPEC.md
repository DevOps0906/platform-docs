# NOMAD 랜딩 키트 — 템플릿 명세서

> 버전 1.0 · 2026-10-17 · 원본: `nomad-landing-kit.html`(단일 HTML) · 벤치마킹 대상: A-RMS 랜딩
>
> 이 문서는 A-RMS 랜딩 구조를 NOMAD AI Factory 브랜드로 옮긴 재현 템플릿을 **다시 만들 수 있도록** 정리한 명세다. 디자인 토큰, GNB 하위메뉴, 페이지별 섹션·카피, 컴포넌트, 애니메이션 코드를 담았다. Claude Code·Cursor에 그대로 넣어 Next.js로 이관할 때 기준 문서로 쓴다.

---

## 0. 한눈에 보기

| 항목 | 내용 |
| --- | --- |
| 형태 | 단일 HTML 파일, 해시 라우팅(`#landing_index` 등)으로 9개 페이지 전환 |
| 의존성 | Google Fonts(Bebas Neue · Noto Sans KR · JetBrains Mono)만 사용. 외부 JS 라이브러리 없음 |
| 테마 | 다크 단일 테마(`color-scheme: dark`). 원본 A-RMS와 같은 세계관 |
| 브랜드 | Jade Mint `#00C9A7` · Electric Denim `#2563EB` · Amber Gold `#F59E0B` · Coral Red `#F43F5E` |
| 반응형 | 1080px / 860px(햄버거 메뉴 전환) / 560px 브레이크포인트 |
| 접근성 | 탭 키보드 이동, `aria-current`, 포커스 링, `prefers-reduced-motion` 대응 |
| 수치 | 모든 ROI·통계는 **예시 데이터**. 화면에 "예시" 배지로 표시됨. 실데이터로 교체 필수 |

---

## 1. 정보구조 (GNB · 하위메뉴)

A-RMS 원본 URL의 `page=` 값을 그대로 slug로 썼다. 대메뉴 4개 아래 9개 페이지.

| 대메뉴 | 하위 페이지 | slug | 페이지 유형 | A-RMS 대응 |
| --- | --- | --- | --- | --- |
| Product | AI 자동화 공장 (메인) | `landing_index` | 스토리텔링 랜딩 | Ai-PM 메인 |
| Product | NOMAD 소개 | `landing_introduce` | 제품 개요 | A-RMS 소개 |
| Product | 기능 구성 | `landing_function` | 모듈 카탈로그 | (function) |
| Insight | 1편 · 프롬프트 ≠ 업무 | `landing_issue_not_req` | 논증형 아티클 | 이슈 ≠ 요구사항 |
| Insight | 2편 · 측정 단위 = 업무 명세 | `landing_measure_is_req` | 논증형 아티클 | 측정 단위 = 요구사항 |
| Insight | 3편 · AI 작업 단위 = 업무 명세 | `landing_ai_work_to_req` | 논증형 아티클 | AI 작업 단위 = 요구사항 |
| Adoption | 도입 액션 흐름 | `landing_poc` | 사용 가이드(라이선스 탭) | 액션 흐름 |
| Adoption | 도입 효과 | `landing_effect` | ROI 대시보드 | 도입 효과 |
| Support | Development Tools | `landing_devtools` | 아이콘 그리드 | Development Tools |

### 1-1. 내비게이션 데이터 (Next.js 이관용 `lib/nav.ts`)

```ts
export type NavItem = { slug: string; title: string; desc: string };
export type NavGroup = { key: 'product' | 'insight' | 'adopt' | 'support'; label: string; icon: string; items: NavItem[] };

export const NAV: NavGroup[] = [
  { key: 'product', label: 'Product', icon: 'box', items: [
    { slug: 'landing_index', title: 'AI 자동화 공장', desc: '메인 · 스토리텔링 랜딩' },
    { slug: 'landing_introduce', title: 'NOMAD 소개', desc: '왜 만들었고 누가 쓰는가' },
    { slug: 'landing_function', title: '기능 구성', desc: '6개 모듈과 파이프라인' },
  ]},
  { key: 'insight', label: 'Insight', icon: 'bulb', items: [
    { slug: 'landing_issue_not_req', title: '1편 · 프롬프트 ≠ 업무', desc: '무엇이 단위가 아닌가' },
    { slug: 'landing_measure_is_req', title: '2편 · 측정 단위 = 업무 명세', desc: '사람이 측정하는 단위' },
    { slug: 'landing_ai_work_to_req', title: '3편 · AI 작업 단위 = 업무 명세', desc: '에이전트가 실행하는 단위' },
  ]},
  { key: 'adopt', label: 'Adoption', icon: 'rocket', items: [
    { slug: 'landing_poc', title: '도입 액션 흐름', desc: 'POC · PRO · ENT 단계별' },
    { slug: 'landing_effect', title: '도입 효과', desc: 'ROI 한눈에 보기' },
  ]},
  { key: 'support', label: 'Support', icon: 'life', items: [
    { slug: 'landing_devtools', title: 'Development Tools', desc: '사용 기술 스택' },
  ]},
];
```

### 1-2. 페이지 메타 (타이틀바 · 브레드크럼 · 상담 말풍선)

| slug | 타이틀바 (굵게 / 연하게) | 브레드크럼 | 우하단 말풍선 문구 |
| --- | --- | --- | --- |
| landing_index | Product / AI Automation | Home › Product › AI 자동화 공장 | 반복 업무 1시간이 1년이면 몇 시간인지 계산해 보셨나요? |
| landing_introduce | Product / Introduce | Home › Product › NOMAD 소개 | 자동화의 3요소는 명세 · 실행 · 회수라는 것, 알고 계셨나요? |
| landing_function | Product / Function | Home › Product › 기능 구성 | 모듈 6개 중 하나만 먼저 써 봐도 됩니다. |
| landing_issue_not_req | Insight / 프롬프트 ≠ 업무 | Home › Insight › 프롬프트 ≠ 업무 | 지난주 프롬프트로 시킨 일, 지금 다시 찾을 수 있나요? |
| landing_measure_is_req | Insight / 측정의 단위 = 업무 명세 | Home › Insight › Unit of Measurement | 지금 세고 있는 숫자는 무엇의 개수인가요? |
| landing_ai_work_to_req | Insight / AI 작업 단위 = 업무 명세 | Home › Insight › AI 작업 단위 | 에이전트에게 맡긴 일, 어디까지 갔는지 지금 볼 수 있나요? |
| landing_poc | Adoption / Action Flow | Home › Adoption › 도입 액션 흐름 | 일정이 흔들린다면 Scope와 Resource도 함께 살펴봐야 해요. |
| landing_effect | Adoption / ROI Analysis | Home › Adoption › 도입 효과 | 손익분기점까지 몇 개월인지 직접 계산해 드릴까요? |
| landing_devtools | Support / Development Tools | Home › Support › Development Tool | 필요한 연동이 목록에 없다면 말씀해 주세요. |

---

## 2. 디자인 토큰

```css
:root{
  color-scheme:dark;
  /* 배경 */
  --bg:#40444e; --bg-deep:#363940; --glow:#69728c; --glow-2:#4f6a78;
  /* 글래스 */
  --glass:rgba(255,255,255,.065); --glass-2:rgba(255,255,255,.1);
  --line:rgba(255,255,255,.13); --line-2:rgba(255,255,255,.07);
  --panel:rgba(14,16,22,.32); --panel-2:rgba(14,16,22,.5);
  /* 텍스트 */
  --fg:#f1f3f7; --fg-2:#bcc2ce; --fg-3:#8d94a3;
  /* 브랜드 + 다크 배경용 밝은 잉크 */
  --mint:#00C9A7; --mint-ink:#5eead4;
  --denim:#2563EB; --denim-ink:#8fb0ff;
  --amber:#F59E0B; --amber-ink:#fbbf24;
  --coral:#F43F5E; --coral-ink:#fb7185;
  --violet-ink:#b4a3ff;
  --gnb:rgba(52,55,63,.88);
  /* 서체 */
  --f-display:"Bebas Neue","Arial Narrow",Impact,sans-serif;
  --f-body:"Noto Sans KR","Apple SD Gothic Neo","Malgun Gothic",system-ui,sans-serif;
  --f-mono:"JetBrains Mono",ui-monospace,"SFMono-Regular",Consolas,monospace;
  /* 형태 */
  --r-lg:24px; --r-md:16px; --r-sm:10px;
  --max:1240px;
}
```

### 2-1. 색의 의미 (원본 A-RMS 4색 규칙을 브랜드색으로 치환)

| 의미 | 토큰 | 쓰임 |
| --- | --- | --- |
| 해결 · 긍정 · 절감 | `--mint` / `--mint-ink` | "NOMAD가 해 주는 일", 절감액, HIRED 스탬프, 주 CTA(`#007A64` 버튼, WCAG AA) |
| 정보 · 기준 · 명세 | `--denim-ink` | 업무 명세(Spec) 쪽, 활성 탭, 강조 데이터 |
| 강조 · 아이브로 · 결과물 | `--amber-ink` | `THESIS · 01` 라벨, 헤드라인 핵심어, 스텝 레일 마지막 단계, 브로셔 버튼 |
| 문제 · 손실 | `--coral-ink` | 프롬프트(Prompt) 쪽, 비용 손실, UNFILLED 스탬프 |
| 보조 | `--violet-ink` | 체크 아이콘, 3Y NET 타일 |

### 2-2. 타이포 스케일

| 역할 | 크기 | 서체 · 굵기 |
| --- | --- | --- |
| 히어로 대형 | `clamp(84px, 12vw, 168px)` | Bebas Neue, line-height .82 |
| 섹션 헤드라인 `h2.hl` | `clamp(24px, 3vw, 34px)` | Noto Sans KR 700, `text-wrap: balance` |
| 카드 제목 | 17~22px | 700 |
| 본문 | 15px (카드 안 14px) | 400, line-height 1.7 |
| 아이브로 | 12px, letter-spacing .16em, 대문자 | 700, amber |
| 출처·주석 | 12~12.5px | `--fg-3` |
| 숫자 KPI | `clamp(28px, 3vw, 40px)` | JetBrains Mono 700, `tabular-nums` |

---

## 3. 레이아웃 원칙

1. **고정 배경 레이어(`.atmo`)** — `position: fixed`에 방사형 그라디언트 3개 + 세로 그라디언트 + SVG 노이즈(투명도 .18, `mix-blend-mode: overlay`). 스크롤해도 빛이 제자리에 있어 카드만 떠오르는 느낌.
2. **섹션 틀 1개 반복** — 아이브로 → 헤드라인(핵심어만 색) → 리드 → 글래스 카드.
3. **2단 중첩** — 바깥 `.glass`(반투명 흰색 + blur) 안에 `.panel`(반투명 검정)로 도해·차트·표를 담는다.
4. **정렬 리듬** — 설득형(메인·POC)은 중앙 정렬, 논증형(Insight 3부작)은 왼쪽 정렬.
5. **측면 여백** — `.wrap`에 `padding-inline: max(16px, env(safe-area-inset-*))`, 최대 폭 1240px.

```css
.atmo{position:fixed;inset:0;z-index:-1;pointer-events:none;
  background:
    radial-gradient(60% 45% at 50% -5%, var(--glow) 0%, transparent 70%),
    radial-gradient(40% 50% at 8% 40%, rgba(105,114,140,.55) 0%, transparent 70%),
    radial-gradient(45% 55% at 100% 85%, rgba(79,106,120,.45) 0%, transparent 70%),
    linear-gradient(180deg,var(--bg) 0%,var(--bg-deep) 100%)}
.atmo::after{content:"";position:absolute;inset:0;opacity:.18;mix-blend-mode:overlay;
  background-image:url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='2' stitchTiles='stitch'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>")}

.glass{background:var(--glass);border:1px solid var(--line);border-radius:var(--r-lg);
  box-shadow:0 30px 60px -30px rgba(0,0,0,.45),inset 0 1px 0 rgba(255,255,255,.06);
  backdrop-filter:blur(10px)}
.panel{background:var(--panel);border:1px solid var(--line-2);border-radius:var(--r-md)}
```

---

## 4. 공통 컴포넌트

| # | 컴포넌트 | 클래스 | 구조 | 쓰인 페이지 |
| --- | --- | --- | --- | --- |
| 1 | GNB + 드롭다운 | `.gnb` `.menu` `.drop` | 로고(N 마크 + Bebas "NOMAD") · 대메뉴 4개(아이콘+라벨) · 검색 · 언어 · 계정 · 햄버거. 드롭다운 항목 = 제목 + 설명 + slug(모노) | 전부 |
| 2 | PageTitleBar | `.titlebar` | 좌: 아이콘 + 굵은 그룹명 + 연한 페이지명 / 우: 브레드크럼 | 전부 |
| 3 | SectionHeader | `.sec-head` `.eyebrow` `h2.hl` `.lead` | 아이브로 → 헤드라인 → 리드. `.left` 변형은 왼쪽 정렬 | 전부 |
| 4 | GlassCard | `.glass.pad` + `.widget-h` | 위젯 헤더(굵은 라벨 + 연한 설명 + ‹ ⌄ › ⤢ 컨트롤) | 전부 |
| 5 | Footer | `.foot` `.channels` `.foot-cols` | NETWORKING 원형 채널 10개 + ABOUT US / GET IN TOUCH / RIGHTS 3열 | 전부 |
| 6 | FloatingButtons | `.float` `.bubble` | 상담 버튼(앰버) + 맨 위로 버튼 + 페이지별 말풍선(1.8초 지연, 닫기 가능) | 전부 |
| 7 | HeroCTA | `.cta-card` | 필 배지 + 타이핑 문구 + 공식 한 줄 + 버튼 3개(브로셔·소개서·시연 영상) + 회전 동심원 | index |
| 8 | RoleTabs | `.tabs` `.tabpanel` `.art` `.qa` | 탭 3개 → 좌 일러스트 패널 + 우 Time/Scope/Resource 질문 3개 | index |
| 9 | PainCard | `.pain` | 아이콘 칩 + 제목 + 설명 + 일러스트(호버 시 블러 + 오버레이 문구) | index |
| 10 | KpiTile | `.kpi.k-d/m/a/c/v` | 아이콘 + 태그(TIME·SAVED·ROI·BEP·3Y NET) + 큰 숫자 + 단위 + 라벨 + 근거 | index, effect |
| 11 | DonutStat / Bars | `.donut` `.bars` | SVG 원 2개(트랙·값) + 중앙 라벨 / 단계별 막대 | index |
| 12 | StepRail | `.rail .st` `.ar` `.loop` | 아이콘 박스 + 화살표, 마지막 `.out`(앰버), 하단 점선 "되돌아옴" | index, function, issue, ai_work, poc |
| 13 | CompareCard | `.cmp.bad` / `.cmp.good` | 제목 + 부제 + `dl`(시점·단위·수명·완결성·합의) | issue |
| 14 | MiniCard | `.mini` / `.mini.hot` | 아이브로 + 제목 + 본문 (+ 출처 `.src`) | function, issue, ai_work |
| 15 | Callout | `.callout` / `.callout.m` | 왼쪽 색 띠 + 아이콘 + 굵은 결론 + 설명 | issue, ai_work, effect |
| 16 | Checks | `.checks` | 체크 아이콘 + 제목 + 설명, 4열 | introduce, measure |
| 17 | VerdictTable | `.tbl` | 판정 요건 × 후보 3개(○△✕), 정답 열 하이라이트 | ai_work |
| 18 | CodeCard | `.code` | 모노 서체 블록, 강조 라인 앰버 | ai_work |
| 19 | LicenseTabs + Timeline | `.ltabs` `.tl` | 아이콘 탭(POC·PRO·ENT) → 스텝 레일 + 세로 타임라인(사용자 행동 ☞ / 시스템 반응 ›) | poc |
| 20 | ProgressRows / Split / YearBars / StackBox | `.prog` `.split` `.yr` `.stack-box` | Before→After 진행 바, 직접/간접 비율 바, 3년 누적 막대, 투자·절감·순이익 박스 | effect |
| 21 | JobPosting | `.job` `.stamp.u/.h` | 가상 채용공고 vs 자동화 시스템, 회전 스탬프 | effect |
| 22 | ToolTile | `.tools-cat .tile` | 라이트 타일 + 컬러 모노그램 + 이름 | devtools |
| 23 | VideoThumb / ArchDiagram | `.video` `.arch` `.hex` | 영상 썸네일 링크(임베드 대신) / 좌 NOMAD 계층 · 중앙 육각 배지 · 우 실행 도구 | introduce |

### 4-1. 핵심 컴포넌트 CSS

```css
/* 아이브로 · 헤드라인 */
.eyebrow{font-size:12px;font-weight:700;letter-spacing:.16em;text-transform:uppercase;color:var(--amber-ink);margin:0 0 10px}
h2.hl{font-size:clamp(24px,3vw,34px);line-height:1.3;margin:0 0 12px;font-weight:700;text-wrap:balance}
.hi-a{color:var(--amber-ink)} .hi-m{color:var(--mint-ink)} .hi-d{color:var(--denim-ink)} .hi-c{color:var(--coral-ink)}
.shimmer{background:linear-gradient(90deg,var(--denim-ink),var(--mint-ink),var(--denim-ink));background-size:200% 100%;
  -webkit-background-clip:text;background-clip:text;color:transparent;animation:shim 6s linear infinite}
@keyframes shim{to{background-position:-200% 0}}

/* KPI 타일 */
.kpi{padding:20px;border-radius:var(--r-md);border:1px solid var(--line)}
.kpi .num{font-family:var(--f-mono);font-size:clamp(28px,3vw,40px);font-weight:700}
.k-d{background:rgba(37,99,235,.14);color:var(--denim-ink)}
.k-m{background:rgba(0,201,167,.12);color:var(--mint-ink)}
.k-a{background:rgba(245,158,11,.13);color:var(--amber-ink)}
.k-c{background:rgba(244,63,94,.12);color:var(--coral-ink)}
.k-v{background:rgba(139,120,255,.14);color:var(--violet-ink)}

/* 스텝 레일 */
.rail{display:flex;align-items:stretch}
.rail .st{flex:1;min-width:0;padding:16px 12px;border-radius:12px;border:1px solid var(--line);background:rgba(0,0,0,.18);text-align:center}
.rail .st.out{border-color:rgba(251,191,36,.55);background:rgba(245,158,11,.1)}
.rail .ar{flex:0 0 28px;display:grid;place-items:center;color:var(--denim-ink)}
.loop{font-size:12.5px;color:var(--fg-3);text-align:center;border:1px dashed rgba(251,191,36,.45);border-top:0;border-radius:0 0 14px 14px;padding:10px;margin:6px 8% 0}

/* 비교 카드 */
.cmp{border-radius:var(--r-md);padding:24px;border:1px solid}
.cmp.bad{border-color:rgba(251,113,133,.3);background:rgba(244,63,94,.07)}
.cmp.good{border-color:rgba(143,176,255,.3);background:rgba(37,99,235,.08)}

/* 콜아웃 */
.callout{display:flex;gap:16px;padding:20px 24px;border-radius:var(--r-md);border:1px solid var(--line);
  border-left:4px solid var(--amber);background:linear-gradient(90deg,rgba(245,158,11,.1),rgba(255,255,255,.03))}
.callout.m{border-left-color:var(--mint);background:linear-gradient(90deg,rgba(0,201,167,.1),rgba(255,255,255,.03))}

/* 호버 블러 카드 */
.pain .over{position:absolute;inset:0;display:grid;place-content:center;text-align:center;padding:24px;opacity:0;transition:.35s;background:rgba(20,22,30,.35)}
.pain:hover .art svg.big,.pain:focus-within .art svg.big{filter:blur(6px)}
.pain:hover .over,.pain:focus-within .over{opacity:1}

/* 흐르는 점선 */
.flow{stroke-dasharray:6 6;animation:dash 1.1s linear infinite}
@keyframes dash{to{stroke-dashoffset:-12}}
```

---

## 5. 페이지별 명세

### 5-1. `landing_index` — AI 자동화 공장 (메인 · 스토리텔링)

| 순서 | 섹션 | 레이아웃 | 콘텐츠 |
| --- | --- | --- | --- |
| 1 | 히어로 | 2열(1.5 : 1) | 좌: 도구 칩 `n8n · Make · Claude · Supabase` + "를 연결한" + 대형 **AI FACTORY**(FACTORY는 민트) + 서브카피 "흩어진 문서·도구·프롬프트를 하나의 업무 명세로 묶고, 에이전트가 실행한 결과를 다시 그 명세로 회수합니다. 1인 기업과 소규모 팀을 위한 자동화 공장입니다." / 우: HeroCTA — 배지 "AI-Powered Automation", 타이핑 "자동화 공장 바로가기 ↗", 공식 "Ai + Workflow(n8n, Make…) + Spec + Ops = NOMAD", 버튼 브로셔·소개서·시연 영상 |
| 2 | 반복 문제 | 중앙 헤더 + 글래스 + RoleTabs | 헤드라인 "우리는 같은 일을 매주 반복하고 있습니다." / 탭: 대표(오너) · 운영 매니저 · 실무자(크리에이터). 각 탭에 Time·Scope·Resource 질문 3개 + 손실 설명 |
| 3 | 역할별 고충 | 3열 PainCard | "같은 반복. 다른 무게. 역할마다 짊어진 고충이 다릅니다." — 대표는 지금 궁금합니다 / 매니저는 너무 바쁩니다 / 실무자는 정확하게 모릅니다 (호버 시 "현황판이 없습니다" 등 오버레이) |
| 4 | 원인 | 2열 글래스 + SVG 도해 | "문제의 원인은 '흩어진 작업' 입니다." 좌: 업무 명세 중심 8단계 순환도(업무 계획 → 명세 추출 → 에이전트 배정 → 실행 → 검수 → 결과 회수 → AI 통계, 점선 흐름 애니메이션) / 우: NOMAD ↔ 실행 도구(n8n·Make·Claude·GPT), 명세 배포 · 결과 수집 화살표 |
| 5 | 피해 수치 `예시` | 패널 4열 | 도넛 3개(발행 지연 42% · 요청 누락 35% · 수작업 비율 48%) + 막대 "늦게 발견할수록 커지는 재작업 비용"(기획 1배 → 명세 3 → 제작 6 → 검수 12 → 발행 30 → 고객 60배) |
| 6 | 해결 파이프라인 | 글래스 + StepRail | "'연결된 작업'은 현장의 문제를 해결하고, 업무를 자동화합니다." — 문서 → 명세 추출 → 에이전트 배정 → 실행 → 결과 회수 → **AI 통계**, 하단 "분석 결과가 다음 업무 명세에 다시 반영됩니다" |
| 7 | 도입 효과 `예시` | KPI 5열 + CTA | TIME 82% · SAVED 1,840만 · ROI 254% · BEP 2.3개월 · 3Y NET 4.6천만 → 버튼 "도입 효과 자세히 보기"(민트) |

**역할 탭 카피**

| 탭 | Time | Scope | Resource |
| --- | --- | --- | --- |
| 대표 | 이번 달 콘텐츠는 언제 **발행**할 수 있습니까? | 자동화한 범위가 실제 **업무**와 맞습니까? | 쓴 **비용**만큼 **결과**가 나옵니까? |
| 운영 매니저 | 지금 어떤 작업이 **멈춰** 있습니까? | 요청과 결과물이 **연결**돼 있습니까? | 누가 어떤 일에 **시간**을 썼습니까? |
| 실무자 | 이 일의 **마감**은 언제입니까? | 어디까지 하면 **완료**입니까? | 어떤 **자료**를 써야 합니까? |

### 5-2. `landing_introduce` — NOMAD 소개

| 순서 | 섹션 | 콘텐츠 |
| --- | --- | --- |
| 1 | 2열 히어로 | 아이브로 "SaaS / Single Tenant · Installable" · 제목 "NOMAD 소개" · 설명 "NOMAD AI Factory는 AI 기반 업무 명세 · 에이전트 실행 · 결과 회수를 통합한 자동화 플랫폼입니다." · 골드 버튼 2개(Brochure · Profile) / 우: 영상 썸네일 카드(재생 버튼, "NOMAD 1.0 소개 영상") — iframe 대신 외부 링크 |
| 2 | 3단 정의 | Problem Definition "NOMAD 개발 배경"(3가지 관행 문제) · Application Field "적용 분야"(1인 미디어·출판사, 소규모 에이전시, 온라인 셀러, AI 도입 스타트업, 정부지원사업 기업) · Expected Effect "기대 효과"(5가지) |
| 3 | 아키텍처 도해 | 좌: Product & Service · Version · Spec · Analytics / 중앙 육각 배지 ①연결 ②배포 ③수집 ④통계 / 우: n8n·Make, Claude·GPT, Supabase, Slack·Notion |
| 4 | 4대 분석 | Time · Scope · Resource · Cost 분석 질문 4열 |

### 5-3. `landing_function` — 기능 구성

| 순서 | 섹션 | 콘텐츠 |
| --- | --- | --- |
| 1 | 헤더 | "Core Function · 6 Modules" / "NOMAD는 6개 모듈이 하나의 명세로 이어집니다" |
| 2 | 모듈 6카드(3열) | 01 Docs 문서 관리 · **02 Extract AI 추출(hot)** · 03 Spec 명세 관리 · 04 Deploy 자동 배포 · 05 Collect 결과 수집 · 06 Report 통계 생성 |
| 3 | 업무 흐름 레일 | Wiki → 명세(SPEC-001, SPEC-002) → 명세 관리(주차 일정) → 작업 전환((자동) TASK-001 ← SPEC-001) → 워크플로((자동) 하위·연결 작업) → **AI 통계**(완료·진행·대기 비율) |

### 5-4. `landing_issue_not_req` — 1편 · 프롬프트 ≠ 업무 (논증형)

| 단계 | 헤드라인 | 콘텐츠 |
| --- | --- | --- |
| THESIS · 01 | **프롬프트 ≠ 업무** (코랄 / 앰버 / 데님) | "프롬프트는 대화 안에 남는 기록이고, 업무는 일을 시작하기 전에 맺는 약속입니다." + 인용 박스 |
| CONTRAST · 02 | 같은 화면에 놓여 있을 뿐, 서로 다른 것을 가리킵니다 | CompareCard: 프롬프트(사후 · 대화 단위 · 대화창 닫히면 끝 · 부분적 · 입력자 판단) vs 업무 명세(사전 · 합의 단위 · 완료까지 지속 · 전체 범위 · 승인 전제) + SVG 시간축(명세 = 이어진 선, 프롬프트 = 끊어진 점) |
| SYMPTOM · 03 | 프롬프트만 쌓이면, 성과 지표부터 조용히 망가집니다 | 증상 3카드(성과 착시 · 연결 정보 없음 · 관리를 위한 관리) + 비용 환산 콜아웃 "주 10시간 × 5인 × 시급 3만 원 = 연 7,800만 원" `예시` |
| ARGUMENT · 04 | 대화 단위로는 합의 단위를 대신할 수 없습니다 | 사후·실행층(프롬프트 = 실행 단위) vs 사전·합의층(업무 명세 = 합의 단위) |
| RESOLUTION · 05 | 프롬프트를 없애지 않습니다. 위층을 다시 세웁니다 | 레일 01 연결 → 02 배포 → 03 수집 → **04 통계** + 되돌아오는 점선 + 콜아웃 "핵심은 분모를 바꾸는 것입니다" |
| NEXT · 06 | 그래서, 무엇을 기준으로 측정해야 하는가 | 버튼 2편 · 3편 |

### 5-5. `landing_measure_is_req` — 2편 · 측정 단위 = 업무 명세 (논증형)

| 단계 | 콘텐츠 |
| --- | --- |
| Thesis 히어로 | "자동화 측정의 단위는 업무 명세입니다" + 시머 인용 "측정하지 못하면 관리할 수 없고, 관리할 수 없으면 개선할 수 없다" / 우 요약 카드 "Measurement Chain: 측정 → 관리 → 개선" |
| Problem | No Unit "단위 자체가 없는 현장" · Wrong Unit "실행 로그를 단위로 삼을 때" · Consequence "그래서 남는 결과" (3열) |
| Criteria | 4요건 체크: ① 합의가능성 ② 완결성 ③ 추적성 ④ 비교가능성 + 비용 체인 "기획 1배 → 명세 3배 → 제작 6배 → 검수 12배 → 발행 30배 → 고객 60배" `예시` |
| Argument | Time · Scope · Resource · Cost 분석(각각 발행시점 · 목표설정 · 배치 · 투자예측) + 시머 문구 "업무 명세 단위로 비용을 역산해, 자동화의 진짜 원가를 보여줍니다" |
| Next | "단위를 바꾸면, 보이는 것이 달라집니다" + 버튼 1편 · 3편 · NOMAD 효과(민트) |

### 5-6. `landing_ai_work_to_req` — 3편 · AI 작업 단위 = 업무 명세 (논증형)

| 단계 | 콘텐츠 |
| --- | --- |
| Thesis + Hook | "AI는 업무 명세를 기준으로 작업을 진행한다" / 핵심 문장 "작업자는 [업무 명세]로 일한다." / Hook 카드 "귀사의 업무 한 줄이 어디까지 갔는지, 지금 당장 볼 수 있습니까?" |
| PROBLEM · 02 | "AI에게 일을 시켰는데, 무엇을 시켰는지 남지 않는다" — Case 1 Prompt(1회성) · Case 2 Log(오염된 통계) · Case 3 Acceptance(완료 기준 부재) + 경고 콜아웃 |
| CRITERIA · 03 | 6요건 카드: 01 불변 식별자 · 02 완결된 명세 · 03 검증 가능한 완료 조건 · 04 상태 기계 · **05 실행 주체 배정 가능(hot)** · 06 결과 되추적 + 판정표 |
| ARGUMENT · 04 | "나간 곳으로 되돌아오는 구조 — 닫힌 고리" 7칸 레일(업무 명세 → AI 추출·분해 → 작업 배포 → 실행 → 결과 되수집 → 명세 단위 환원 → **OUTPUT: Time·Scope·Resource·Cost**) + 콜아웃 "성능이 아니라 회수 가능성" |
| Self-proof | 코드 카드 `[개요] [상세 기능] [입력 / 출력] [제약 조건] [검증 기준] [Worker Settings] MainAgent : content-planner / SubAgent : thumbnail-maker` |
| NEXT · 06 | "이 페이지는 3부작의 3편입니다" — 1편 · 2편 · 도입 효과(hot) 카드 |

**판정표**

| 판정 요건 | 프롬프트 | 실행 로그 | 업무 명세 |
| --- | --- | --- | --- |
| 01 불변 식별자 | ✕ | △ | ○ |
| 02 완결된 명세 | ✕ | ✕ | ○ |
| 03 검증 가능한 완료 조건 | ✕ | ✕ | ○ |
| 04 상태 기계 | ✕ | △ | ○ |
| 05 실행 주체 배정 가능 | ✕ | △ | ○ |
| 06 결과 되추적 | ✕ | ✕ | ○ |

### 5-7. `landing_poc` — 도입 액션 흐름 (라이선스 탭)

헤더: "License Action Flow · NOMAD 액션 흐름" + "각 단계는 **사용자가 하는 일**과 **NOMAD가 해 주는 일**로 나누어 읽으시면 됩니다." → 탭 POC(4단계) · PRO(5단계) · ENT(6단계) → 패널(제목 · 설명 · 스텝 레일 · 세로 타임라인) → "라이선스 비교 보기" 버튼.

| 탭 | 제목 | 단계 (사용자가 하는 일 / NOMAD가 해 주는 일) |
| --- | --- | --- |
| POC | 도입 검증 — 이미 쓰는 도구로 4단계 만에 결과를 확인합니다 | ① 도구 연결: n8n·Make 주소와 API 키 입력 / 워크플로 목록을 읽어 옴 ② 기준 설정: 기준 서비스 선택 / 이후 수집·분석의 기준 ③ 업무 선정: 업무에 해당하는 실행 표시 / 업무 명세 후보 등록 ④ 분석·보고: 분석 화면·주간 보고 열기 / TSRC 4관점 정리 |
| PRO | 정식 운영 — 명세를 먼저 쓰고 에이전트에 배포합니다 | ① 문서 업로드 / AI가 명세 초안 추출 ② 명세 확정 / 불변 ID 부여 ③ 에이전트 배정 / 워크플로 배포 ④ 자동 수집 / 결과·로그가 명세로 회수 ⑤ 성과 보고 / 명세 기준 리포트 |
| ENT | 전사 확장 — 여러 브랜드와 팀을 하나의 기준으로 묶습니다 | ① 조직 구성 / 권한 자동 분리 ② 도구 연결 / 연결 상태 통합 ③ 명세 표준화 / 공통 필드 ④ 자동 운영 / 결과 회수 ⑤ 전사 통계 / 팀별 같은 축 비교 ⑥ 정기 보고 / 익일 09시 리포트 |

### 5-8. `landing_effect` — 도입 효과 (ROI 대시보드) `전부 예시`

가정 조건: 5인 콘텐츠 팀 · 월 120개 업무 명세 · 시급 3만 원 · 셋업 320만 원 + 구독 연 200만 원.

검산: 1년차 순이익 = 1,840 − (320 + 200) = 1,320 / 2년차 누적 = 1,320 + (1,840 − 200) = 2,960 / 3년차 누적 = 2,960 + 1,640 = 4,600 / 월 순절감 = 1,840 ÷ 12 − 200 ÷ 12 ≈ 137만.

| 블록 | 내용 |
| --- | --- |
| KPI 5개 | TIME 82%(월 92h → 16h) · SAVED 1,840만(직접 1,040 + 간접 800) · ROI 254%(1년차 순이익 1,320만 ÷ 1년차 투자 520만) · BEP 2.3개월(설정비 320만 ÷ 월 순절감 137만) · 3Y NET 4.6천만(투자 대비 5.0배) |
| 단계별 시간 절감 | ① 명세 작성 30h → 6h (-80%) ② 작업 배포·지시 22h → 2h (-91%) ③ 결과 수집·보고 40h → 8h (-80%) · 월 총 92h → 16h, 76h 절감 |
| 연간 비용 구조 | 분할 바 직접 1,040만(57%) / 간접 800만(43%) + 내역: 시간 절감 인건비 1,040(절감 912h 중 인건비 전환분 38% × 시급 3만 원) · 재작업 감소(25%→8%) 450 · 커뮤니케이션(회의 40%↓) 230 · 검수 대응(준비 70%↓) 120 |
| 3년 누적 | 막대 1년차 1,320 · 2년차 2,960 · 3년차 4,600(만원) + 박스 TOTAL INVESTMENT 920(셋업 320 + 구독 연 200 × 3년) · TOTAL SAVINGS 5,520 · NET PROFIT 4,600 |
| 결론 콜아웃 | "2.3개월이면 투자금 회수, 이후는 순이익." + 예시 데이터 고지 |
| 채용공고 비교 | UNFILLED "콘텐츠 운영 매니저"(월 30만원 · 365일 24시간 · 계약직 → 채용 불가능) vs HIRED "NOMAD · 무중단 운영 시스템"(무제한 처리 · 월 구독 · 무중단 → 4대 업무 자동 수행) |

### 5-9. `landing_devtools` — Development Tools

3열 글래스 위젯 × 6개 카테고리, 각 위젯 안에 라이트 타일(컬러 모노그램 + 이름).

| 카테고리 | 설명 | 타일 |
| --- | --- | --- |
| Frontend | web application | Next.js · React · TypeScript · Tailwind · shadcn/ui |
| Backend & DB | data, auth, storage | Supabase · PostgreSQL · Edge Fn · Redis |
| Automation | workflow orchestration | n8n · Make · Webhook · Cron |
| AI | llm & agents | Claude · OpenAI · LangChain · OpenRouter |
| Media | image, voice, video | Fal.ai · ElevenLabs · FFmpeg |
| Infra | deploy & monitor | Vercel · Railway · GitHub · Sentry |

---

## 6. 인터랙션 · 애니메이션

| 효과 | 대상 | 방식 |
| --- | --- | --- |
| 해시 라우팅 | 전체 | `hashchange` → 해당 `.page`만 표시, 타이틀바·브레드크럼·GNB 활성·문서 제목·말풍선 갱신, 맨 위로 스크롤 |
| 스크롤 등장 | 섹션·카드 | 첫 화면 밖 요소만 `.rv-pre`(투명·아래 26px)로 숨겼다가 IntersectionObserver로 등장 |
| 카운트업 | `.count[data-to]` | 0 → 목표값 1.3초, easeOutCubic. `data-dec`(소수 자리), `data-sep`(천 단위 콤마), `data-suffix` |
| 도넛 채우기 | `.donut[data-pct]` | `stroke-dashoffset` 1.4초 transition |
| 막대 성장 | `.bars i` `.yr i` `.prog .bar i` | `scaleY` / `scaleX` 0 → 1 |
| 타이핑 | 히어로 CTA | 2.4초 후 시작, 지우기 55ms · 쓰기 110ms, 완성 상태 약 3초 유지 |
| 회전 아크 | CTA 카드 모서리 | 동심원 5개, 40초 1회전 |
| 흐르는 점선 | SVG `.flow` | dashoffset 1.1초 루프 |
| 호버 블러 | PainCard | 일러스트 blur 6px + 오버레이 문구 |
| 시머 텍스트 | `.shimmer` | 데님↔민트 그라디언트 6초 이동 |
| 탭 | 역할 탭 · 라이선스 탭 | 클릭 + 좌우 화살표 키 이동, `aria-selected` |
| 모바일 메뉴 | ≤860px | 햄버거 → 전체 화면 메뉴, 대메뉴 클릭 시 하위 아코디언 |
| 모션 감소 | `prefers-reduced-motion` | 모든 animation·transition 끔, 숨김 해제 |

### 6-1. 핵심 스크립트 (스크롤 등장 + 카운트업)

```js
// 첫 화면에 보이는 요소는 그대로 두고, 화면 밖 요소만 숨겼다가 등장시킨다
function fmt(el, v){
  const dec = +(el.dataset.dec || 0);
  const s = el.dataset.sep ? Math.round(v).toLocaleString('ko-KR') : v.toFixed(dec);
  return s + (el.dataset.suffix || '');
}
function countUp(el){
  const to = +el.dataset.to, dur = 1300; let t0 = null;
  const f = ts => { t0 ??= ts; const p = Math.min((ts - t0) / dur, 1);
    el.textContent = fmt(el, to * (1 - Math.pow(1 - p, 3))); if (p < 1) requestAnimationFrame(f); };
  requestAnimationFrame(f);
}
const io = new IntersectionObserver(entries => entries.forEach(en => {
  if (!en.isIntersecting) return;
  const el = en.target; io.unobserve(el); el.classList.remove('rv-pre');
  el.querySelectorAll('.count').forEach(countUp);
}), { rootMargin: '0px 0px -8% 0px' });

function arm(page){
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  const vh = innerHeight;
  page.querySelectorAll('section.sec, .glass, .hero, .grid > *').forEach(el => {
    if (el.closest('.rv-pre') || el.getBoundingClientRect().top < vh * 0.92) return;
    el.classList.add('rv', 'rv-pre');
    el.querySelectorAll('.count').forEach(c => c.textContent = fmt(c, 0));
    io.observe(el);
  });
}
```

```css
.rv-pre{opacity:0;transform:translateY(26px)}
.rv{transition:opacity .7s cubic-bezier(.2,.7,.2,1),transform .7s cubic-bezier(.2,.7,.2,1)}
```

### 6-2. 도넛 게이지

```html
<div class="donut" data-pct="42">
  <svg viewBox="0 0 120 120">
    <circle class="trk" cx="60" cy="60" r="50" stroke="#8fb0ff"/>
    <circle class="val" cx="60" cy="60" r="50" stroke="#8fb0ff"/>
  </svg>
  <div class="lbl"><b>발행 지연</b><span class="count" data-to="42" data-suffix="%">42%</span></div>
</div>
```

```js
const C = 2 * Math.PI * 50;
function setDonut(d, pct){ const v = d.querySelector('.val');
  v.style.strokeDasharray = C; v.style.strokeDashoffset = C * (1 - pct / 100); }
```

---

## 7. 반응형

| 폭 | 변화 |
| --- | --- |
| ≤1080px | 검색창 숨김, 도넛 3열 + 막대 전체 폭, KPI 5열 → 3열, 4열 → 2열 |
| ≤860px | 햄버거 메뉴(전체 화면 + 아코디언), 히어로·탭 패널·3년 막대 1열, 2·3열 그리드 1열, 아키텍처 세로, 스텝 레일 세로(화살표 90° 회전), 타임라인 일러스트 숨김 |
| ≤560px | 도넛·KPI 2열, CTA 버튼 1열, 탭 패딩 축소 |

가로 스크롤은 표·레일·SVG 도해에만 허용(`.scroll-x`), 페이지 본문은 가로로 넘치지 않는다.

---

## 8. Next.js 이관 가이드

| 단일 HTML | Next.js 16 App Router |
| --- | --- |
| 해시 라우팅 `#landing_*` | `app/(marketing)/[slug]/page.tsx` + `generateStaticParams`로 9개 정적 생성 |
| `.page` 블록 | 페이지별 컴포넌트 또는 MDX(`content/insight/*.mdx`) — 논증 3부작은 MDX 권장 |
| `NAV` 데이터 | `lib/nav.ts` (1-1 참조) |
| CSS 토큰 | Tailwind v4 `@theme`에 2장 토큰 등록 |
| `.glass` 등 클래스 | `components/landing/*` (GlassCard, SectionHeader, KpiTile, StepRail, CompareCard, Callout, Timeline …) |
| IntersectionObserver 등장 | Motion `whileInView` + `viewport={{ once: true, margin: '-8%' }}` |
| 카운트업 | `useInView` + `animate()` 또는 소형 훅 |
| SVG 아이콘 스프라이트 | lucide-react (box, lightbulb, rocket, life-buoy, clock, target, coins, users …) |
| 다국어 | next-intl (ko · en) |

### 8-1. Claude Code 이관 프롬프트 예시

```text
@NOMAD_랜딩_키트_템플릿_명세.md 를 기준으로 Next.js 16 App Router + Tailwind v4 + shadcn/ui 랜딩을 만들어 줘.
1) 2장 디자인 토큰을 Tailwind @theme에 등록
2) 4장 컴포넌트를 components/landing/ 에 TypeScript로 작성 (GlassCard, SectionHeader, KpiTile, StepRail, CompareCard, Callout, Timeline, LicenseTabs)
3) 1-1의 NAV로 GNB(데스크톱 드롭다운 + 모바일 아코디언) 구현
4) 5장 페이지 명세대로 9개 페이지를 (marketing) 라우트 그룹에 정적 생성, Insight 3부작은 MDX
5) 6장 애니메이션은 Motion whileInView, prefers-reduced-motion 대응
6) 모든 ROI 수치에 "예시" 배지를 유지
```

---

## 9. 교체 체크리스트

- [ ] 모든 예시 수치(5-1 피해 수치, KPI, 5-8 ROI 전체)를 실측·고객 데이터로 교체
- [ ] 인용 박스·증상 카드의 "예시 근거 자리"를 실제 출처로 교체
- [ ] 브로셔 · 소개서 · 시연 영상 버튼 링크를 실제 파일·영상 URL로 연결
- [ ] 푸터 채널 10개 링크를 실제 계정 주소로 연결
- [ ] 연락처 이메일·저작권 문구 확인
- [ ] OG 이미지 · 메타 설명 · 사이트맵 추가(SEO)
- [ ] 상담 버튼을 채널톡·카카오 오픈채팅 등 실제 상담 도구에 연결
