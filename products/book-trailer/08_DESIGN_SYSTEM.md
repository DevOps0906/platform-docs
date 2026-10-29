# 08 디자인 시스템: NOMAD Book Trailer (book-trailer)

작성일 2026-10-15. 이 제품의 디자인 시스템은 두 층이다. (A) 앱 UI(편집기·대시보드·랜딩)와 (B) 영상 시스템(렌더되는 트레일러의 캔버스·서체·모션·장면 규격). 공통 규칙은 `docs/nomad-design-modules/_design-guide/DESIGN_SYSTEM.md`(정답 소스, 4단계 워크플로, 금지 사항), 절차는 `DESIGN_PRINCIPLES.md`, 앱 화면 구조는 `DASHBOARD_PATTERNS.md`를 따르고 이 문서는 book-trailer 값만 정한다. 수치는 모두 제안이며 4장 3단계(사람 비주얼 검토)에서 고친다. 화면 목록과 플로우는 `03_SCREENS_UX.md`.

## 0. 정답 소스

| 층 | 정답(코드) | 문서 | 확인 |
|---|---|---|---|
| A 앱 토큰 | `apps/web/src/styles/tokens.css`(Tailwind CSS v4 `@theme`, 라이트/다크) | `docs/file/03-설계/디자인/DESIGN.md`(이 문서 3.7절에서 초기화) | `/dev/components` 라이트/다크 x 컴팩트/기본 스크린샷 |
| A 앱 컴포넌트 | `apps/web/src/components/ui/`(shadcn/ui 복사본을 토큰으로 재스타일), 제품 컴포넌트 `src/components/{studio,brief,render,preview}/` | `COMPONENTS.md`(11.3절에서 초기화) | 같음 |
| B 영상 토큰 | `packages/trailer-compositions/src/tokens/{canvas,type,motion,palette,safe-zones}.ts` | 이 문서 5~10장 | 렌더러 프레임 스냅샷(TR-06-047), 포맷별 안전 영역 오버레이 |
| B 장면 컴포넌트 | `packages/trailer-compositions/src/scenes/*.tsx`, 컴포지션 `src/compositions/*.tsx` | 이 문서 9장 | Remotion Studio(로컬) + 렌더러 테스트 |

- 피그마는 초안에만 쓰고 정답으로 삼지 않는다(`DESIGN_SYSTEM.md` 3장). 문서에 피그마 노드 ID를 남기지 않는다.
- 앱과 영상은 토큰 파일이 다르다. 앱은 CSS 변수, 영상은 TS 상수(Remotion 컴포넌트가 import)다. 사용자 브랜드 키트(4장)는 영상에만 적용하고 앱 크롬에는 쓰지 않는다(편집 화면이 책마다 바뀌면 사용법이 흔들린다).
- 스택 버전을 항상 적는다: Next.js 16.2.x, React 19.2, Tailwind CSS v4.x, shadcn/ui(Tailwind CSS v4 지원 버전), Remotion 4.0.x(정확한 버전 고정).

## 1. 레퍼런스와 방향 (`DESIGN_SYSTEM.md` 4장 1단계)

| 화면 성격 | 주 레퍼런스 | 보조 | 가져올 패턴 | 가져오지 않을 것 |
|---|---|---|---|---|
| 작업실(스토리보드 편집 + 미리보기) | Atlassian(복잡한 폼과 단계 상태) | Primer(밀도, 상태 표시) | 왼쪽 장면 목록 + 가운데 실물 미리보기 + 오른쪽 속성(`DASHBOARD_PATTERNS.md` J), 단계 배지, 실행 취소 | 영상 편집기식 다중 트랙 타임라인(이 제품은 장면 단위 편집이다) |
| 홈·책·렌더 기록 | Primer | Atlassian(권한·상태 배지) | 리스트-상세(B), 레코드 상세(G), 작업 모니터(N), 미디어 갤러리(M) | 모든 정보를 같은 카드로 나누는 SaaS 카드 키트 |
| 코치 채팅·음성·위키 | Astryx(MIT 베타, 패턴만, 설치하지 않음) | Primer | 출처가 붙는 메시지 스레드, 마이크 상태 | 설치·의존 |
| 랜딩 | `DESIGN_PRINCIPLES.md` + `HERO_3D.md` + 03장 4절 레퍼런스 | - | 03장 4.1절 | B2B 대시보드 레퍼런스 |

## 2. 브리프와 디자인 원칙

| 항목 | 내용 |
|---|---|
| 주제 | 책(원고, 표지, 띠지, 밑줄 친 문장)과 상영(예고편, 세로 화면, 자막) |
| 대상 | 1인 출판사·작가·출판 마케터. 원고와 표지는 있지만 영상 도구는 익숙하지 않다 |
| 주된 일 | 원고에서 고른 문장과 장면으로 규격별 트레일러를 만들어 내려받는다 |
| 고유 어휘 | 띠지(책 허리에 두르는 홍보 문구 띠), 형광펜 밑줄, 교정지, 판권면, 예고편 자막, 세로 프레임 |
| 피할 인상 | 크림 배경 + 세리프 + 테라코타 문학 잡지(기본값 1), 거의 검정 + 단일 형광 강조(기본값 2), 보라 그라디언트 AI 툴, 영상 편집기의 복잡한 트랙 |

원칙

| # | 원칙 | 적용 |
|---|---|---|
| 1 | 책이 주인공, 도구는 조용히 | 앱 크롬은 무채색. 색은 미리보기 속 책과 상태 표시에만 |
| 2 | 밑줄 친 문장이 기준점 | 원고에서 가져온 인용은 어디서든 같은 형광 밑줄 표시로 구분(브리프, 장면 카드, 영상 인용 장면) |
| 3 | 띠지 하나만 대담하게 | 기억에 남는 요소는 "띠지" 하나: 랜딩 히어로의 띠지, 작업실의 장면 스트립(띠지 모양 타임라인). 나머지는 조용히 |
| 4 | 규격은 눈에 보이게 | 포맷 전환과 안전 영역 오버레이를 항상 한 번에 켤 수 있다 |
| 5 | 돈과 권리는 버튼 옆에 | 크레딧 비용, 권리 확인, AI 표시는 행동 버튼 바로 옆에 둔다 |

## 3. 앱 토큰 (층 A)

### 3.1 색

주제에서 뽑은 이름 붙인 팔레트 6개. 앱은 라이트가 기본(미리보기는 항상 어두운 "상영관" 무대 위).

| 이름 | 라이트 | 다크 | 토큰 | 용도 |
|---|---|---|---|---|
| 교정지 | #EEF0F2 | #202227 | `--color-canvas` | 페이지 바탕(차가운 회색, 크림 아님) |
| 백지 | #FFFFFF | #2A2D33 | `--color-surface` | 패널, 표, 입력 |
| 인쇄 먹 | #1A1C21 | #ECEDEF | `--color-text`, `--color-primary` | 본문, 주 버튼 배경(라이트) |
| 연필심 | #5E6470 | #A3A8B3 | `--color-text-muted` | 보조 텍스트, 아이콘 |
| 형광 밑줄 | #F5D547 | #F5D547 | `--color-highlight` | 인용 밑줄, 띠지, 선택된 장면, 포커스 링 바깥 고리 |
| 상영관 | #202227 | #141518 | `--color-stage` | 미리보기 무대, 렌더 썸네일 배경 |

| 보조 토큰 | 라이트 | 다크 | 용도 |
|---|---|---|---|
| `--color-border` | #D5D9DF | #3A3E46 | 구분선, 입력 테두리 |
| `--color-border-strong` | #A9AFB8 | #565B65 | 선택 테두리 |
| `--color-primary-fg` | #FFFFFF | #1A1C21 | 주 버튼 글자 |
| `--color-highlight-fg` | #1A1C21 | #1A1C21 | 형광 위 글자(대비 12.9:1) |
| `--color-focus` | #1A1C21 | #ECEDEF | 포커스 링 안쪽 2px(바깥 2px는 `--color-highlight`) |

상태색(색만으로 구분하지 않는다: 배지 = 아이콘 + 글자 + 색)

| 상태 | 라이트 글자/배경 | 다크 글자/배경 | 쓰는 곳 |
|---|---|---|---|
| 성공 | #1F7A50 / #E3F4EC | #6FD3A3 / #173328 | 렌더 완료, compliance 통과 |
| 경고 | #9A5B00 / #FDF1DC | #F2B95C / #3A2C12 | compliance WARN, 만료 임박 |
| 위험 | #B3342B / #FBE7E5 | #F08A80 / #3D1D1A | 실패, FAIL, 크레딧 부족 |
| 정보 | #2C55C9 / #E6EDFC | #8EA9F3 / #1B2643 | 진행 중, 안내 |
| AI | #5E6470 / #EEF0F2 | #A3A8B3 / #2A2D33 | AI 생성 표시(중립색. 강조하지도 숨기지도 않는다) |

대비 확인: 본문 #1A1C21 / #FFFFFF 16.9:1, 보조 #5E6470 / #FFFFFF 6.0:1, 다크 본문 #ECEDEF / #2A2D33 11.6:1(모두 AA 이상, 구현 시 axe로 재확인).

### 3.2 서체

| 역할 | 서체 | 이유 |
|---|---|---|
| 디스플레이(랜딩 제목, 빈 상태 제목) | 나눔명조 ExtraBold | 책 본문 조판의 명조를 제목에만. 크림 배경과 짝짓지 않는다 |
| 본문·UI | IBM Plex Sans KR | 습관적 기본 서체(Pretendard) 대신 교정·편집 도구의 기계적 정확함. tabular-nums로 크레딧·시간 정렬 |
| 숫자·시간(타임코드, 크레딧) | IBM Plex Sans KR `font-variant-numeric: tabular-nums` | 모노스페이스 데이터 라벨을 쓰지 않는다(기본값 5) |

두 가족(명조 + 산세리프)만 쓴다. 영상 서체(4.2절)와 앱 서체는 따로다.

### 3.3 서체 스케일 (앱)

| 토큰 | 크기/행간 | 굵기 | 용도 |
|---|---|---|---|
| `--text-display` | 40/48px | 800(명조) | 랜딩 섹션 제목 |
| `--text-title` | 22/30px | 600 | 화면 제목 |
| `--text-heading` | 16/24px | 600 | 패널 제목 |
| `--text-body` | 14/22px | 400 | 본문, 입력 |
| `--text-small` | 13/20px | 400 | 보조, 표 컴팩트 |
| `--text-micro` | 12/16px | 500 | 배지, 타임코드 |

자간은 기본(0). 전부 대문자 라벨, 아이브로 라벨을 쓰지 않는다(기본값 5, 8).

### 3.4 간격·반경·그림자·모션·밀도

| 토큰 | 값 | 용도 |
|---|---|---|
| `--space-1`~`--space-8` | 4, 8, 12, 16, 24, 32, 48, 64px | 4px 기준 |
| `--radius-control` | 6px | 버튼, 입력 |
| `--radius-panel` | 10px | 패널, 대화상자 |
| `--radius-frame` | 2px | 영상 미리보기 프레임(화면은 각진 물건) |
| `--radius-band` | 0 | 띠지 스트립(종이 띠) |
| `--shadow-panel` | 0 1px 2px rgba(26,28,33,.08) | 패널(위계 낮음) |
| `--shadow-overlay` | 0 12px 32px rgba(26,28,33,.18) | 대화상자, 드롭다운(위계 높음) |
| `--motion-fast` / `--motion-base` | 120ms / 200ms, ease-out | 열기·펼치기·저장 확인만 |
| `--row-compact` / `--row-default` | 32px / 40px | 표 행 높이(Primer식 두 밀도) |

모든 요소에 같은 반경·그림자를 쓰지 않는다(위계에 따라 다르다). 섹션 등장 페이드, 카드 호버 전환은 없다(기본값 11).

### 3.5 다크 모드와 밀도

다크 전환은 `data-theme="dark"` 하나로 통일(`@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *))`). 밀도는 `data-density="compact|default"`.

### 3.6 아이콘

Lucide만. 이모지 아이콘 금지. 장면 종류 아이콘 8개를 고정한다(9장 표의 아이콘 열).

### 3.7 DESIGN.md 초기값

| 항목 | 값 |
|---|---|
| 주 레퍼런스 | 작업실 Atlassian + 패턴 J, 목록·모니터 Primer(B, G, N, M), AI 채팅 Astryx 패턴 |
| 가져올 패턴 | 장면 목록 + 미리보기 + 속성 3단, 단계 배지, 작업 모니터 진행률, 출처 붙는 메시지 스레드 |
| 가져오지 않을 것 | 다중 트랙 타임라인, SaaS 카드 키트, 보라 그라디언트, 크림 + 세리프 + 테라코타, 모노스페이스 데이터 라벨 |
| 색: `--color-canvas` | 라이트 #EEF0F2 / 다크 #202227 (교정지) |
| 색: `--color-surface` | #FFFFFF / #2A2D33 (백지) |
| 색: `--color-text`, `--color-primary` | #1A1C21 / #ECEDEF (인쇄 먹) |
| 색: `--color-text-muted` | #5E6470 / #A3A8B3 (연필심) |
| 색: `--color-highlight` | #F5D547 / #F5D547 (형광 밑줄, 글자는 `--color-highlight-fg` #1A1C21) |
| 색: `--color-stage` | #202227 / #141518 (상영관, 미리보기 무대) |
| 색: `--color-border`, `--color-border-strong` | #D5D9DF·#A9AFB8 / #3A3E46·#565B65 |
| 상태색 | 성공 #1F7A50, 경고 #9A5B00, 위험 #B3342B, 정보 #2C55C9, AI 중립 #5E6470(배경색은 08_DESIGN_SYSTEM.md 3.1절) |
| `--font-display` | 나눔명조 ExtraBold |
| `--font-body` | IBM Plex Sans KR(숫자 tabular-nums) |
| 서체 스케일 | display 40/48, title 22/30, heading 16/24, body 14/22, small 13/20, micro 12/16 |
| `--radius-control` / `--radius-panel` / `--radius-frame` / `--radius-band` | 6 / 10 / 2 / 0px |
| `--shadow-panel` / `--shadow-overlay` | 0 1px 2px rgba(26,28,33,.08) / 0 12px 32px rgba(26,28,33,.18) |
| `--space-*` | 4, 8, 12, 16, 24, 32, 48, 64px |
| 모션 | 120ms / 200ms ease-out, 사용자 행동 응답만 |
| 밀도 | 컴팩트 행 32px / 기본 40px, `data-density` |
| 다크 모드 | `data-theme="dark"` 한 가지 |
| 포커스 | 안쪽 2px `--color-focus` + 바깥 2px `--color-highlight` |

## 4. 브랜드 키트 (사용자 책별, 층 B에만 적용)

### 4.1 표지 팔레트 추출 (결정적, LLM 없음)

| 단계 | 처리(렌더러 `kit.extract`, sharp) |
|---|---|
| 1 | 표지를 256px 긴 변으로 줄이고 알파·여백(가장자리 3% 단색 띠) 제외 |
| 2 | CIELAB 공간 k-means(k=8, 초기값 고정 seed 7, 반복 20) → 비율 2% 미만 군집 버림 |
| 3 | 역할 배정: `background` = 비율 최대 군집, `text` = background와 대비 최대 군집, `accent` = 채도 최대 군집(text·background 제외), `accent2` = 다음 채도, `surface` = background를 명도 ±8 이동 |
| 4 | 대비 보정: text/background 4.5:1 미만이면 text 명도를 0 또는 100 쪽으로 이동해 4.5:1을 맞추고 `adjusted=true` |
| 5 | 결과 `palette`(5개) + 서체 기본값(4.2절 장르 표) → `brand_kits(source='cover_extract')` |

같은 표지 → 같은 팔레트(테스트로 고정). 사용자는 색 칸을 눌러 바꿀 수 있고, 바꾼 색도 대비 검사를 다시 한다.

### 4.2 영상 서체 (OFL 한국어 8종, `brand_kits_font_*_check`)

| 코드 | 서체 | 용도 | 라이선스 |
|---|---|---|---|
| `pretendard` | Pretendard | 본문·자막 기본 | OFL(구현 시 재확인) |
| `noto_sans_kr` | Noto Sans KR | 본문·자막 | OFL |
| `ibm_plex_sans_kr` | IBM Plex Sans KR | 실용서 본문 | OFL |
| `noto_serif_kr` | Noto Serif KR | 소설·에세이 인용 | OFL |
| `gowun_batang` | 고운바탕 | 에세이·시 인용 | OFL |
| `nanum_myeongjo` | 나눔명조 | 소설 제목 | OFL |
| `black_han_sans` | 검은고딕 | 숏폼 훅 제목(디스플레이 전용) | OFL |
| `do_hyeon` | 도현 | 그림책·인사이트 제목(디스플레이 전용) | OFL |

장르 기본 짝(디스플레이 / 본문·자막): 소설 나눔명조 / Pretendard, 실용서 검은고딕 / IBM Plex Sans KR, 에세이 고운바탕 / Pretendard, 시집 고운바탕 / Noto Serif KR, 그림책 도현 / Pretendard, 인사이트 검은고딕 / Pretendard. 서체 파일은 렌더러 이미지와 앱 `public/fonts/`에 같은 버전으로 들어가고, 네트워크 서체를 쓰지 않는다(렌더 결정성).

## 5. 영상 캔버스 (층 B)

### 5.1 포맷

| 코드 | 크기(1080p) | 720p | 용도 | 길이 |
|---|---|---|---|---|
| `vertical_9_16` | 1080x1920 | 720x1280 | 쇼츠·릴스·틱톡·네이버 클립 | 15~90초 |
| `landscape_16_9` | 1920x1080 | 1280x720 | 유튜브, 서점·출판사 상세 | 15~90초 |
| `square_1_1` | 1080x1080 | 720x720 | 인스타 피드 | 15~60초 |
| `portrait_4_5` | 1080x1350 | 720x900 | 인스타 피드(세로) | 15~60초 |
| `cover_loop` | 1080x1920 또는 1080x1080 | - | 표지 루프(서점·프로필) | 5~8초 무한 반복 이음매 |

공통: 30fps, H.264 High, yuv420p, AAC 48kHz 192kbps, 라우드니스 -14 LUFS 정규화(제안), 최대 피크 -1 dBTP.

### 5.2 안전 영역

| 포맷 | 텍스트 안전 영역(여백, 캔버스 대비) | 이유 |
|---|---|---|
| 9:16 | 위 12%, 아래 22%, 왼쪽 6%, 오른쪽 14% | 쇼츠·릴스·틱톡의 상단 바, 하단 캡션·버튼, 오른쪽 아이콘 열(플랫폼별 실측은 구현 시 확인, 미확인) |
| 16:9 | 사방 5%(타이틀 세이프) | 플레이어 컨트롤 |
| 1:1, 4:5 | 사방 6% | 피드 크롭 |
| 표지 루프 | 사방 8% | 프로필 원형 크롭 대비 |

자막·화면 문구·CTA는 안전 영역 안에만 둔다. 작업실 미리보기에 "안전 영역" 토글(포맷별 오버레이, 11.2절 `SafeZoneOverlay`).

### 5.3 그리드

캔버스 짧은 변을 36 단위로 나눈 `u`(1080 기준 30px)를 기본 단위로 쓴다. 모든 여백·간격·글자 크기는 `u`의 배수 또는 0.5 배수다. 포맷이 바뀌어도 비율이 유지된다.

### 5.4 영상 타입 스케일 (`u` 기준, 1080 짧은 변에서 px)

| 토큰 | 크기 | 행간 | 용도 |
|---|---|---|---|
| `title.xl` | 3.2u(96px) | 1.15 | 제목 카드의 책 제목 |
| `hook` | 2.4u(72px) | 1.2 | 훅 문장(2줄 이내) |
| `quote` | 1.8u(54px) | 1.45 | 인용 문장(3줄 이내) |
| `body` | 1.3u(39px) | 1.4 | 내레이션 카드, CTA |
| `caption` | 1.1u(33px) | 1.35 | 자막(2줄, 줄당 16자 권장) |
| `meta` | 0.8u(24px) | 1.3 | 저자·출판사, AI 표시 |

줄 수를 넘으면 컴포지션이 글자 크기를 한 단계 줄이고, 그래도 넘으면 렌더 전에 서버 검사가 "문구가 깁니다"로 막는다(편집기에서 미리 경고).

### 5.5 텍스트 대비 보장

이미지 위 글자는 항상 스크림(이미지 위 반투명 그라데이션 판, 글자 쪽 60% 불투명 키트 `background` 색)을 깔고 대비 4.5:1을 컴포지션이 계산해 맞춘다(스크림 불투명도 0.45~0.85). 장식 그라디언트로 쓰지 않는다.

## 6. 장르 트레일러 문법 6종 (카탈로그 seed와 같음, `2600_trailer.sql` 11절)

| 문법 | 비트(비중) | 템플릿 | 서체 짝 | 모션 기본 | 전환 | 음악 무드 | 이미지 스타일 프리셋 | 내레이션 톤 |
|---|---|---|---|---|---|---|---|---|
| 소설 시네마틱 `novel_cinematic` | 세계와 분위기 20, 인물과 욕망 20, 갈등 25, 질문 15, 제목 20 | `cinematic_basic` | 나눔명조 / Pretendard | 켄번스 인·아웃 교대, 패럴랙스 | 컷, 어두운 페이드 | cinematic_tension | `cinematic_film`: 필름 그레인, 낮은 채도, 측광, 인물은 실루엣 | 낮고 느린 독백 |
| 실용서 문제 해결 `practical_problem` | 문제 25, 약속 20, 목차 30, 저자 10, 행동 15 | `practical_clean` | 검은고딕 / IBM Plex Sans KR | 정지 + 타입 리빌, 팬 | 컷 | upbeat_focus | `editorial_flat`: 평면 일러스트, 키트 색 2개, 그림자 없음 | 명료한 설명 |
| 에세이 문장 `essay_quote` | 정서 장면 25, 문장 하나 30, 문장 둘 25, 제목 20 | `essay_paper` | 고운바탕 / Pretendard | 느린 켄번스, 페이지 넘김 | 페이지 와이프 | calm_piano | `soft_light`: 자연광, 여백 많은 사진풍, 사물 중심 | 문장 낭독(느리게) |
| 시집 타이포그래피 `poetry_typo` | 여백 15, 구절 55, 제목 30 | `poetry_ink` | 고운바탕 / Noto Serif KR | 타입 리빌(글자 단위), 정지 | 먹 번짐 페이드 | ambient_soft | `ink_wash`: 수묵 번짐, 단색 | 낭독(호흡 길게) |
| 그림책 동화 `children_storybook` | 주인공 25, 모험 35, 궁금증 20, 제목 20 | `storybook_page` | 도현 / Pretendard | 페이지 넘김, 패럴랙스 | 페이지 넘김 | playful_light | `storybook_gouache`: 과슈 질감, 둥근 형태, 실존 아동 금지 | 밝고 다정한 낭독 |
| 인사이트 훅 `insight_hook` | 반전 질문 20, 핵심 통찰 45, 그래서 이 책 15, 행동 20 | `insight_kinetic` | 검은고딕 / Pretendard | 키네틱 타입(단어 강조 없이 줄 단위), 빠른 컷 | 컷 | upbeat_focus | `bold_graphic`: 단순 도형, 키트 색 3개 | 빠르고 단단한 설명 |

규칙: 첫 장면은 2초 안에 글자 또는 인물이 나온다(숏폼 이탈 방지). 템플릿 기본 팔레트는 키트가 없을 때만 쓴다(각 템플릿 `params_schema.default_palette`).

## 7. 모션 시스템

### 7.1 모션 프리셋 (`visual.motion`)

| 코드 | 동작 | 기본값 | 상한 |
|---|---|---|---|
| `ken_burns_in` | 확대 + 약한 이동 | 1.00 → 1.08, 이동 2% | 1.15 |
| `ken_burns_out` | 축소 | 1.08 → 1.00 | - |
| `pan_left`, `pan_right` | 가로 이동 | 캔버스 폭 6% | 12% |
| `parallax` | 배경·전경 두 층 다른 속도(전경은 자동 피사체 분리 대신 이미지 하단 40% 크롭 층) | 4% / 8% | - |
| `still` | 정지 | - | - |
| `type_reveal` | 글자 줄 단위 나타남(시집은 글자 단위) | 줄당 0.4초 | 글자 단위 0.05초 |
| `page_turn` | 종이 넘김 전환 | 0.6초 | - |

한 장면에 모션 1개 + 글자 등장 1개까지. 이징은 `--ease-film`: cubic-bezier(0.22, 0.61, 0.36, 1)(제안), 글자 등장은 `--ease-type`: cubic-bezier(0.2, 0, 0, 1).

### 7.2 전환

| 코드 | 길이 | 쓰는 문법 |
|---|---|---|
| `cut` | 0 | 실용서, 인사이트, 소설 일부 |
| `fade_dark` | 8프레임 | 소설 |
| `page_wipe` | 12프레임 | 에세이, 그림책 |
| `ink_fade` | 12프레임 | 시집 |

### 7.3 글자 노출 시간

화면 문구의 최소 노출 = 1.2초 + 글자당 60ms(한글 기준, 제안). 스토리보드 그래프의 `fit_duration`과 편집기 경고가 같은 공식을 쓴다(`packages/trailer-compositions/src/tokens/type.ts`의 `minReadMs`).

### 7.4 자막

| 항목 | 값 |
|---|---|
| 줄 | 2줄 이하, 줄당 16자 권장(9:16), 22자(16:9) |
| 위치 | 안전 영역 하단 기준선 위 |
| 스타일 | `caption` 크기, 흰 글자 + 반투명 먹 판(불투명 0.6), 키트 text 색은 쓰지 않는다(가독성 우선) |
| 시간 | 내레이션 길이에 문장 비례 배분. 제공자가 글자 타이밍을 주면 그 값을 쓴다(ElevenLabs 타임스탬프 응답은 구현 시 확인, 미확인) |
| SRT | 같은 큐로 생성 |

### 7.5 음악·내레이션 믹스

| 항목 | 값(제안) |
|---|---|
| 내레이션 구간 음악 덕킹 | -12dB, 공격 150ms, 해제 400ms |
| 첫 0.5초 | 음악 페이드 인 |
| 엔드카드 | 음악 2초 페이드 아웃 |
| 음악 큐(`music_cue`) | intro(첫 장면), build(갈등), drop(제목 공개), calm(인용), outro(엔드카드). BPM 맞춤 컷(P1)은 drop을 마디에 맞춘다 |

## 8. 이미지 스타일 시스템

### 8.1 스타일 프리셋 (프롬프트 접미어, 영어)

| 코드 | 접미어(요지) |
|---|---|
| `cinematic_film` | cinematic still, 35mm film grain, low saturation, side light, shallow depth of field |
| `editorial_flat` | flat editorial illustration, two-tone, clean shapes, no shadows |
| `soft_light` | soft natural window light, still life, generous negative space |
| `ink_wash` | monochrome ink wash, bleeding edges, paper texture |
| `storybook_gouache` | gouache storybook illustration, rounded forms, warm light |
| `bold_graphic` | bold geometric graphic, three colors, high contrast |

팔레트 주입: 키트 `accent`·`background`·`accent2` hex를 가까운 색 이름으로 바꿔 접미어에 "color palette: ..."로 붙인다.

### 8.2 금지 접미어 (모든 프롬프트 끝, 서버가 붙인다)

`no text, no letters, no watermark, no logo, no real person likeness, no celebrity, no specific artist style`. 이미지 안 글자는 컴포지션이 그린다(이미지 생성 글자는 깨지고 번역되지 않는다).

### 8.3 일관성 검수 기준표 (사람 판정, 렌더 전 선택 체크)

| 항목 | 통과 기준 |
|---|---|
| 팔레트 | 장면 이미지 주조색이 키트 팔레트 범위 안(ΔE 20 이내, 렌더러가 경고를 계산) |
| 질감 | 같은 스타일 프리셋으로 보인다(필름 그레인·평면 등 섞이지 않음) |
| 인물 | 위키 묘사(머리·옷 색)가 장면 사이에 어긋나지 않는다. 얼굴이 크게 보이는 장면은 피한다 |
| 글자 | 이미지 안에 글자 같은 무늬가 없다 |
| 안전 | 실존 인물·상표가 보이지 않는다 |

## 9. 장면 컴포넌트 명세 (`packages/trailer-compositions/src/scenes/`)

| 종류 | 아이콘(Lucide) | 구성(9:16 기준) | 포맷 변환 | 필수 데이터 |
|---|---|---|---|---|
| `title_card` | `BookOpen` | 표지 축소 + 제목(`title.xl`) + 부제·저자(`meta`) 하단 1/3 | 16:9는 왼쪽 표지 / 오른쪽 제목 | book.title |
| `hook_text` | `Zap` | 화면 중앙 훅(`hook`), 배경은 이미지 또는 키트 background | 16:9는 왼쪽 정렬 2/3 폭 | text |
| `quote_card` | `Quote` | 인용(`quote`) + 형광 밑줄(키트 accent가 아니라 고정 형광 #F5D547, 원칙 2) + 장 표기(`meta`, "3장에서") | 줄 폭 최대 28자(9:16), 36자(16:9) | text, quote_ref |
| `image_scene` | `Image` | 전면 이미지 + 모션 + 선택 자막 | `visual.focus`로 크롭 기준점 | image |
| `character_scene` | `UserRound` | 실루엣·뒷모습 이미지 + 인물 이름(`body`) | 같음 | image |
| `narration_card` | `AudioLines` | 단색 배경 + 문구(`body`) + 내레이션 | 같음 | text 또는 narration |
| `cta_card` | `ShoppingBag` | 행동 문구(`body`) + 서점 이름(링크 단축 코드 QR은 16:9만) | 9:16은 "프로필 링크" 안내 | cta |
| `end_card` | `Flag` | 표지 + 제목 + 저자 + CTA 한 줄 + AI 표시(9.1절) + 워터마크(9.2절, free) | 모든 포맷 | book, cta |

### 9.1 엔드카드 AI 표시 규격

| 항목 | 값 |
|---|---|
| 문구 | "AI 생성 이미지·음성 포함"(이미지만이면 "AI 생성 이미지 포함", 음성만이면 "AI 생성 음성 포함") |
| 위치 | 엔드카드 안전 영역 하단, 저자 줄 아래 |
| 크기 | `meta`(0.8u) 이상, 최소 2초 노출 |
| 색 | 흰색 또는 먹색 중 배경과 대비 4.5:1 이상인 쪽 |
| 끄기 | 불가(`renders.ai_label`이 스냅샷 기준으로 강제) |

### 9.2 워터마크 규격 (free, 480p 미리보기)

오른쪽 위 안전 영역 안, "NOMAD Book Trailer"(가칭 D-1) 글자 + 아이콘, `meta` 크기, 흰색 불투명 0.7, 전 구간 표시. 엔드카드에 "무료 플랜으로 제작" 한 줄. 브라우저 미리보기는 같은 워터마크를 오버레이로 그린다.

### 9.3 포스터

제목 장면 중간 프레임(첫 프레임이 아님), 포맷 크기 PNG. 썸네일용으로 제목 글자가 잘리지 않게 안전 영역 검사를 다시 한다.

## 10. 변주 규칙 (반복 대량 생산 위험 줄이기)

같은 채널에 비슷한 영상이 반복되면 플랫폼이 "양산형"으로 볼 수 있다(01_PRD.md 6.6절). 템플릿은 같아도 트레일러마다 아래가 달라지게 한다.

| 변주 축 | 방법(트레일러 seed로 결정적) |
|---|---|
| 모션 순서 | 문법이 허용하는 모션 중 장면별 선택을 seed로 섞는다(같은 모션 연속 3회 금지) |
| 레이아웃 미러 | 텍스트 장면의 좌·우 정렬을 seed로 고른다(16:9) |
| 전환 | 문법 허용 전환 2종 사이 비율 |
| 색 | 책마다 표지 키트(4장) |
| 음악 | 같은 무드 안에서 곡을 순환(직전 3편과 다른 곡 우선) |

같은 책·같은 템플릿으로 7일 안에 3편 이상 만들면 작업실에 "변주 부족" 안내(P1 업로드 경고와 같은 기준).

## 11. 앱 컴포넌트

### 11.1 기본 컴포넌트 (shadcn/ui 재스타일)

Button, IconButton, Input, Textarea, Select, Combobox, Checkbox, Switch, RadioGroup, Tabs, Dialog, Sheet, DropdownMenu, Tooltip, Toast, Badge, Table(컴팩트/기본), Skeleton, Progress, Slider, ColorField, Dropzone, Breadcrumb, EmptyState.

### 11.2 제품 컴포넌트

| 컴포넌트 | 위치 | 역할 | 상태 |
|---|---|---|---|
| `SceneStrip` | `components/studio/` | 띠지 모양 가로 장면 스트립(장면 길이에 비례한 칸, 엔드카드 고정 끝칸, 드래그 순서 변경) | 기본, 선택, 드래그 중, 에셋 없음, 생성 중, 실패 |
| `SceneInspector` | `components/studio/` | 오른쪽 속성 패널: 문구·내레이션·길이·모션·음악 큐, 장면 비용 | 저장 중, 충돌(`TR409`), 읽기 전용(viewer) |
| `PreviewStage` | `components/preview/` | 상영관 무대 위 Remotion Player, 포맷 전환, 안전 영역 토글, 워터마크 오버레이 | 로딩, 재생, 에셋 누락 자리표시 |
| `SafeZoneOverlay` | `components/preview/` | 포맷별 안전 영역(5.2절) 반투명 표시 | 켬/끔 |
| `FormatSwitcher` | `components/preview/` | 5개 포맷 세그먼트 버튼(플랜에 없는 포맷은 잠금 + 업그레이드 안내) | 잠금 |
| `BriefCompare` | `components/brief/` | 브리프 3안 나란히 비교(로그라인, 훅, 인용, 스포일러 메모), 고르기·고쳐 쓰기 | 생성 중, 비교, 선택됨 |
| `QuoteHighlight` | `components/brief/` | 인용 문장 형광 밑줄 + 장 표기 + 검증 배지(원고와 일치/다름) | 검증, 미검증 |
| `CreditCost` | `components/ui/` | 버튼 옆 "약 N 크레딧" + 잔액 부족 상태 | 충분, 부족 |
| `RightsGate` | `components/books/` | 권리 확인 대화상자(고지 버전 표시) | 미확인, 확인됨 |
| `PaletteEditor` | `components/books/` | 키트 색 5칸 + 대비 결과 + 표지 미리보기 | 보정됨 배지 |
| `RenderMonitorRow` | `components/render/` | 렌더 행: 포맷 썸네일, 상태 점, 진행률, 소요 시간, 실패 원인 한 줄 + 원문 로그, 다시 렌더 | 대기, 진행, 완료, 실패, 만료 |
| `ComplianceList` | `components/studio/` | FAIL/WARN 항목, 해당 장면으로 이동, WARN 확인 | FAIL, WARN, 통과 |
| `ChatThread`, `VoiceButton` | `components/ai-chat/`, `components/voice/` | 코치 채팅(출처: 장·문단), 마이크 | 스트리밍, 출처, 오류, 녹음 중, 권한 거부 |

### 11.3 COMPONENTS.md 초기값

| 컴포넌트 | 크기 배리언트 | 종류 배리언트 | 상태 | 토큰 | 미리보기 확인(라이트/다크) |
|---|---|---|---|---|---|
| Button | sm/md/lg(높이 28/36/44px) | primary(먹)/secondary(백지+테두리)/ghost/danger | 기본·호버·포커스·비활성·로딩 | `--radius-control`, `--color-primary`, `--color-focus`+`--color-highlight` | |
| Input, Textarea | md(36px) | 기본 | 기본·포커스·오류·비활성 | `--color-border`, `--color-surface` | |
| Select, Combobox | md | 기본 | 열림·비활성 | 같음 | |
| Dialog, Sheet | md/lg | 기본, 확인(권리·WARN) | 열림 | `--radius-panel`, `--shadow-overlay` | |
| Table | 컴팩트 32px / 기본 40px | 기본 | 빈 상태·로딩·오류 | `--row-*` | |
| Badge | sm | 성공/경고/위험/정보/AI | 아이콘 + 글자 필수 | 상태색 | |
| Progress | sm/md | 결정형, 단계형 | 진행·완료·실패 | 정보·성공·위험 | |
| SceneStrip | 기본 | 편집/읽기 전용 | 선택·드래그·에셋 없음·생성 중·실패 | `--radius-band`(0), `--color-highlight`(선택) | |
| PreviewStage | 9:16/16:9/1:1/4:5 | 편집/공유(승인 링크) | 로딩·재생·에셋 누락 | `--color-stage`, `--radius-frame` | |
| BriefCompare | 3열(1024px 이상) / 탭(이하) | 기본 | 생성 중·선택됨 | `--color-highlight`(인용) | |
| QuoteHighlight | 인라인 | 검증/미검증 | - | `--color-highlight`, 경고색 | |
| CreditCost | sm | 충분/부족 | - | `--text-micro`, 위험색 | |
| RenderMonitorRow | 컴팩트/기본 | 기본 | 대기·진행·완료·실패·만료 | 상태색 | |
| ChatThread(AI 채팅) | 패널/전체 | 기본 | 스트리밍·출처·오류 | `--color-surface` | |
| VoiceButton(음성) | md | 기본 | 녹음 중·권한 거부 | 위험색(녹음 중 점) | |

## 12. 접근성

| 항목 | 기준 |
|---|---|
| 앱 | WCAG AA 대비, 키보드로 장면 이동(←/→), 순서 변경(Alt+←/→), 재생(Space), 포커스 링 토큰 |
| 상태 | 색 + 아이콘 + 글자 |
| 영상 | 자막 기본 켬(번인 + SRT), 글자 대비 4.5:1(스크림), 최소 노출 시간(7.3절), 깜빡임 초당 3회 미만(전환 프리셋에 플래시 없음) |
| 모션 | `prefers-reduced-motion`이면 앱 미리보기 자동 재생 끔(영상 파일 자체는 그대로) |

## 13. 구현 규칙과 작업 지시 예시

규칙: hex는 `tokens.css`와 영상 토큰 TS에만. 컴포넌트에 `bg-[#...]` 금지(린트). 새 토큰은 이 문서와 코드를 같이 바꾸는 task로만. `tailwind.config.js` 금지.

컴포넌트 지시 예시(`DESIGN_SYSTEM.md` 8장 템플릿):

```
대상: SceneStrip
근거: docs/file/03-설계/디자인/DESIGN.md 토큰, COMPONENTS.md SceneStrip 행, 08_DESIGN_SYSTEM.md 11.2절
스택: Next.js 16.2.x, React 19.2, Tailwind CSS v4.x, shadcn/ui(Tailwind v4 지원 버전), dnd-kit(버전 확인)
배리언트: 편집/읽기 전용. 칸 폭 = 장면 길이 비례(최소 48px), 높이 56px, 엔드카드는 오른쪽 고정·드래그 불가
수치: radius = var(--radius-band)(0), 선택 = 아래 3px var(--color-highlight), 칸 사이 2px var(--color-canvas)
금지: hex 직접 사용, tailwind.config.js, 새 토큰 임의 추가, 카드 그림자
검증: /dev/components 라이트/다크 스크린샷, 키보드로 칸 이동·순서 변경, 375px에서 가로 스크롤 컨테이너
```

영상 장면 지시 예시:

```
대상: quote_card 장면 컴포넌트(packages/trailer-compositions/src/scenes/QuoteCard.tsx)
근거: 08_DESIGN_SYSTEM.md 5.2·5.4·9장, 04_API.md 4.3절
스택: Remotion 4.0.x(고정 버전), React 19.2
수치: 글자 quote(1.8u), 행간 1.45, 줄 폭 28자(9:16)/36자(16:9), 밑줄 #F5D547 높이 0.35em 글자 뒤, 장 표기 meta
모션: type_reveal 줄당 0.4초, 장면 길이 = max(입력, minReadMs)
금지: 키트 accent로 밑줄 색 바꾸기, 이미지 생성 글자, 네트워크 서체
검증: 포맷 4종 x 1~3줄 인용 프레임 스냅샷, 안전 영역 오버레이 확인
```

## 14. 검증

| 대상 | 방법 | 작업 |
|---|---|---|
| 앱 토큰·컴포넌트 | `/dev/components` 라이트/다크 x 컴팩트/기본 스크린샷, axe 대비 | TR-06-009, 010(사람), 011 |
| 영상 장면 | 장면 종류 8 x 포맷 4(+표지 루프) 프레임 스냅샷 비교, 안전 영역 침범 자동 검사(글자 상자 좌표) | TR-06-047 |
| 결정성 | 같은 스냅샷 2회 렌더 프레임 해시 일치 | TR-06-047 |
| 키트 추출 | 고정 표지 10장의 팔레트 기대값 | TR-06-021 |
| 사람 검토 | 8.3절 일관성 기준표, 문법 6종 샘플 1편씩 | TR-06-010 |
