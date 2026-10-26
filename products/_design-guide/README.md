# _design-guide — 전 제품 공통 디자인 가이드

| 파일 | 내용 |
|---|---|
| [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | 디자인 시스템 구축 규칙(레퍼런스 선택, 4단계 워크플로, Tailwind CSS v4 토큰이 정답 소스, 컴포넌트 작업 지시 템플릿) |
| [`DESIGN_PRINCIPLES.md`](DESIGN_PRINCIPLES.md) | UI 디자인 원칙(브리프, 토큰 플랜, 생성형 기본값 회피) |
| [`HERO_3D.md`](HERO_3D.md) | 메인 화면 3D 히어로 표준(기기별 구성, 저사양 판정, 성능 예산, 킬 스위치, 제품별 소재) |
| [`REFERENCES.md`](REFERENCES.md) | 제품별 시각 레퍼런스(Awwwards·Dribbble) |
| [`SKILLS.md`](SKILLS.md) | 개발 에이전트용 스킬 목록과 작업별 매핑 |
| [`DASHBOARD_VISUAL.md`](DASHBOARD_VISUAL.md) | **대시보드를 디자인할 때 반드시 거치는 분석 절차**와 시각 아키타입(V-A~V-N 14개), 트레이딩 문법 적합도, 색·숫자 규칙, 제품별 시각 지정. 근거는 이 폴더의 PDF 2개(Dribbble 트레이딩 대시보드 분석, 플랫폼별 대시보드 추천서) |
| [`LANDING_PERSUASION.md`](LANDING_PERSUASION.md) | 설득형 랜딩 내용 구조와 "왜 이 플랫폼이어야 하는가" 검증 규칙(2026-10-17): 외부 자료 사용 원칙(저작권·디자인 원칙), 설득 흐름, 대안 판정표, 증거 등급, 주장 장부, 필요성 검증 단계(V0~V3), 마케팅 컴포넌트, 비교 계산기, 제품별 적용 현황 |
| [`templates/persuasion-landing/`](templates/persuasion-landing/README.md) | 설득형 랜딩 템플릿: 공통 엔진(`engine.html`), 공통 템플릿(`data/_common.json`)과 제품별 데이터 16개, 결과 페이지(`dist/`), 빌드·검사 스크립트. 제품마다 "(제품) ○○ 여정"과 Whisper 음성 지시 페이지 포함 |
| [`DASHBOARD_PATTERNS.md`](DASHBOARD_PATTERNS.md) | 앱 화면 구조 패턴 카탈로그(A~O 15개, 홈 화면 고르는 기준, 공용화 기준, 제품별 제안). 제품 `03_SCREENS_UX.md` 화면 표의 `패턴` 열이 이 코드를 쓴다 |
| [`RESPONSIVE.md`](RESPONSIVE.md) | **전 제품 공통 반응형 기준**: 모바일(~767)·태블릿(768~1199)·데스크탑(1200~) 구간, 구간별 글자 크기 토큰, 간격·배치 규칙, 검수 체크리스트, 제품별 적용 현황 |

제품별 선택(레퍼런스, 토큰 값, 화면)은 각 제품 `03_SCREENS_UX.md`에 있습니다.
