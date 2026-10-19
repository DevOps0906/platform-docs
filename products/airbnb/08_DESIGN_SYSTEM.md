# 08 디자인 시스템: Stay(가칭, airbnb)

작성일 2026-10-20. `03_SCREENS_UX.md` 3.9절의 선택(색 토큰, DESIGN.md·COMPONENTS.md 초기값)을 정답 소스 구조에 맞게 확장한 문서다. 공통 규칙은 `docs/products/_design-guide/DESIGN_SYSTEM.md`(이하 공통 규칙)를 따르고 이 문서는 Stay의 값만 적는다. 03장과 값이 다르면 이 문서가 새 기준이며, 코드가 생기면 코드가 이 문서보다 우선한다. 토큰 초안 파일은 [`design/tokens.css`](design/tokens.css)다.

## 0. 정답 소스

| 층 | 정답(코드) | 문서 | 확인 |
|---|---|---|---|
| 토큰 | `apps/web/src/styles/tokens.css`(Tailwind CSS v4 `@theme`, 라이트/다크. 초안은 `design/tokens.css`) | `docs/file/03-설계/디자인/DESIGN.md`(8.1절에서 초기화) | `/dev/components` 라이트/다크 × 컴팩트/기본 스크린샷 |
| 기본 컴포넌트 | `apps/web/src/components/ui/`(shadcn/ui 복사본을 토큰으로 재스타일) | `COMPONENTS.md`(8.2절에서 초기화) | 같은 페이지 |
| 제품 컴포넌트 | `apps/web/src/components/{listing,search,booking,host,chat}/` | 이 문서 5장 | 같은 페이지 + 화면 스크린샷 |

- 피그마는 초안에만 쓰고 정답으로 삼지 않는다. 문서에 피그마 노드 ID, 외부 파일 링크를 남기지 않는다.
- 스택 버전을 항상 적는다: Next.js 16.2.x, React 19.2, Tailwind CSS v4.x(고정), shadcn/ui(Tailwind v4 지원 버전), Lucide. `tailwind.config.js`, v3 문법, 외부 UI 라이브러리 설치는 금지.
- 이 문서의 값 중 "제안"은 사람 비주얼 검토(SY-06-009) 전까지 확정이 아니다.

## 1. 레퍼런스와 방향 (공통 규칙 4장 1단계)

| 화면 성격 | 주 레퍼런스 | 보조 | 가져올 패턴 | 가져오지 않을 것 |
|---|---|---|---|---|
| 게스트 화면(홈, 검색, 상세, 여행) | Humbert & Poyet, Kononenko Architectural Bureau(`REFERENCES.md:282·283`) | - | 사진이 주인공인 큰 비율, 넉넉한 여백, 굵은 제목 + 차분한 본문 | 원본의 빨간 브랜드색(#FF385C 계열), 로고 형태, 아이콘, 카드 배치(01장 D14) |
| 호스트 화면(홈, 숙소, 예약, 달력, 위저드) | Attio 레코드 페이지(`:333`), Linear 키보드 우선(`:336`) | Table data view(`:176`) | 헤더 + 탭 + 속성 사이드바, 빠른 전환, 상태 배지(아이콘 + 글자) | 카드 격자로 모든 정보를 나누는 SaaS 키트 |
| AI 도우미·음성·위키 | Astryx 패턴만(설치하지 않음) | Primer(밀도) | 출처 칩이 붙는 메시지 스레드, 마이크 상태 | 설치·의존 |
| 랜딩 | `DESIGN_PRINCIPLES.md` + `HERO_3D.md` + 03장 4절 | - | 종이 지도 + 솟는 집 핀 | B2B 대시보드 레퍼런스 |

방향 한 줄: 사진이 주인공인 조용한 여행 앱. 모래 백색 바탕, 먹 남청 글자, 솔숲 녹색 하나로 행동을 이끌고 노을 주황은 화면당 한 곳에만 쓴다.

## 2. 원칙과 금지

| 원칙 | 내용 |
|---|---|
| 색 | 행동 색은 accent 하나. highlight는 화면당 한 곳(가격 핀 또는 찜 켜짐). 상태색(success, warning, danger)은 상태 표시에만 |
| 사진 | 사진은 장식하지 않는다. 그림자·테두리 효과·필터 없음. 비율 4:3(카드), 3:2(상세 큰 사진), 1:1(썸네일) |
| 위계 | 굵은 제목(700) 하나 + 본문(400). 중간 굵기를 늘려 위계를 만들지 않는다 |
| 상태 | 색만으로 구분하지 않는다. 아이콘 + 글자를 함께 쓴다 |
| 숫자 | 가격·날짜·인원·별점은 `tabular-nums` |
| 모양 | 반경은 토큰 5개(sm, control, photo, card, pill)만 쓴다. 카드마다 그림자를 주지 않는다 |
| 금지 | hex 직접 사용(`bg-[#...]`), 새 토큰 임의 추가, 이모지 아이콘, 가짜 후기·평점, 보라·파랑 그라데이션, 원본 Airbnb 모방(빨강, 로고, 아이콘, 카드 배치), 외부 사이트 폰트·색 파일 복사 |

## 3. 토큰

모든 대비는 WCAG 2.1 상대 휘도로 계산했다(2026-10-20). 글자 4.5:1(큰 글자 3:1), 비텍스트 3:1이 기준이다.

### 3.1 색 — 라이트

| 토큰 | 이름 | hex | 쓰임 | 대비 |
|---|---|---|---|---|
| `surface` | 모래 백색 | #FAF7F2 | 페이지 배경 | - |
| `surface-raised` | 판면 흰색 | #FFFFFF | 카드, 입력, 시트 | text 14.70:1 |
| `surface-sunken` | 종이 지도 | #F1EBE0 | 지도·우물 영역, 랜딩 히어로 아래쪽 | text 12.39:1 |
| `text` | 먹 남청 | #1F2A2E | 본문·제목 | surface 13.75:1 |
| `text-muted` | 비석 회색 | #5B6670 | 보조 글자, 입력 안내 | surface 5.49 · raised 5.87 · sunken 4.94 |
| `text-subtle` | 안개 회색 | #8A949B | 비활성 글자 전용 | 2.89:1(비활성은 WCAG 면제) |
| `accent` | 솔숲 녹색 | #1F6F5C | 주 버튼, 링크, 선택 | surface 5.64 · raised 6.02 · 흰 글자 6.02 |
| `accent-hover` | 짙은 솔숲 | #195A4B | 버튼 호버 | 흰 글자 8.06 |
| `accent-subtle` | 솔숲 옅은 바탕 | #E0EEE9 | 선택된 칩·행 배경 | accent 글자 5.04 |
| `highlight` | 노을 주황 | #B5541C | 가격 핀, 찜 켜짐(화면당 한 곳) | surface 4.62 · 흰 글자 4.94 |
| `highlight-text` | 짙은 노을 | #9C4515 | 옅은 바탕 위 글자 | highlight-subtle 5.20 |
| `highlight-subtle` | 노을 옅은 바탕 | #F7E4D7 | 강조 배지 배경 | - |
| `line` | 모래 회색 | #D9D3C7 | 구분선(장식, 글자 금지) | 1.39:1 |
| `line-strong` | 돌 회색 | #8A949B | 입력·체크 테두리 | surface 2.89(입력은 테두리 + 안쪽 흰 바탕으로 인지, 포커스 링 별도) |
| `success` / `success-text` | 솔잎 | #2E7D4F / #276B43 | 아이콘·테두리 / 배지 글자 | surface 4.72 · subtle 위 5.52 |
| `success-subtle` | | #E4F1E8 | 배지 배경 | - |
| `warning` / `warning-subtle` | 황토 | #8A5A00 / #F6EBD3 | 경고 글자·배지 | surface 5.55 · subtle 위 5.01 |
| `danger` / `danger-subtle` | 벽돌 | #B42318 / #F9E3E0 | 오류 글자·배지 | surface 6.15 · subtle 위 5.35 |
| `focus-ring` | | #1F6F5C | 포커스 링 2px + 간격 2px | surface 5.64 |
| `overlay` | | #141B1E 48% | 모달·시트 뒷면 | - |

`line-strong` 주의: 입력 테두리는 비텍스트 3:1에 약간 못 미친다(2.89). 입력은 **흰 바탕 + 테두리 + 포커스 링**의 조합으로 인지되게 하고, 사람 검토(SY-06-009)에서 #7C878E(약 3.4:1)로 올릴지 결정한다. 이 문서의 기본값은 03장과 같은 값을 유지한다(제안).

### 3.2 색 — 다크

| 토큰 | hex | 대비 |
|---|---|---|
| `surface` | #141B1E | - |
| `surface-raised` | #1C2528 | text 12.80:1 |
| `surface-sunken` | #0F1416 | text 15.20:1 |
| `text` | #EDE8DF | surface 14.28:1 |
| `text-muted` | #9AA5AB | surface 6.92 · raised 6.21 |
| `text-subtle` | #66727A | 비활성 전용 |
| `accent` / `accent-hover` | #5FB39C / #7CC4AF | surface 6.98 · raised 6.26 |
| `accent-fg` | #0F1416 | accent 위 7.43 · hover 위 9.16 |
| `accent-subtle` | #17302A | accent 글자 5.64 |
| `highlight` / `highlight-subtle` | #E08A55 / #3A2517 | surface 6.58 · subtle 위 5.45 |
| `line` / `line-strong` | #2C373B / #66727A | 장식 / 입력 테두리 |
| `success` / `warning` / `danger` | #5FBF86 / #E0A93B / #F07A6E | surface 7.70 / 8.22 / 6.40 |
| `success-subtle` / `warning-subtle` / `danger-subtle` | #1B2E24 / #33290F / #3A1D1A | 글자 6.35 / 6.76 / 5.63 |
| `focus-ring` | #7CC4AF | surface 8.61 |

다크 버튼은 글자가 어둡다(`accent-fg`). 흰 글자를 쓰지 않는다. 다크 값은 이 문서에서 처음으로 대비를 모두 계산했고, 눈으로 보는 확인은 3단계(사람)에서 한다.

### 3.3 서체와 글자 크기

| 역할 | 서체 | 크기/행 | 굵기 | 쓰임 |
|---|---|---|---|---|
| 서체 | Pretendard Variable(미확인: 라이선스 OFL 확인 전, 없으면 시스템 한글 서체) | - | - | 전체 |
| display | | 40/48(모바일 32/40) | 700 | 랜딩 헤드라인만 |
| h1 | | 32/40(모바일 28/36) | 700 | 화면 제목 |
| h2 | | 24/32 | 700 | 섹션 제목 |
| h3 | | 20/28 | 700 | 카드 그룹 제목 |
| body-lg | | 18/28 | 400 | 숙소 소개 본문 |
| body | | 16/24 | 400 | 기본 |
| small | | 14/20 | 400 | 보조, 표, 폼 라벨(500) |
| caption | | 12/16 | 400 | 사진 설명, 법적 고지, 배지 |

본문 한 줄은 약 65자 이내로 제한한다. 숫자는 `tabular-nums`. 대문자 라벨(영문)에는 자간 0.02em.

### 3.4 간격, 반경, 그림자, 모션, 밀도

| 항목 | 값 |
|---|---|
| 간격 | 4px 기준. 카드 안쪽 16px, 섹션 간 48px(모바일 32px), 컨트롤 간 8px·12px, 페이지 좌우 여백 16px(모바일)·24px(md)·32px(lg 이상) |
| 반경 | sm 6px(배지, 칩 모서리), control 10px(버튼, 입력), photo 12px, card 16px, pill 999px(검색 바, 칩) |
| 그림자 | `shadow-hover`(카드 호버 1단계), `shadow-float`(시트, 팝오버, 지도 위 카드). 사진·일반 카드에는 없음 |
| 모션 | fast 120ms(호버, 포커스), base 200ms(열림·닫힘), slow 320ms(시트 이동). 이징 `cubic-bezier(0.2, 0, 0, 1)`. `prefers-reduced-motion`이면 거의 0 |
| 밀도 | 기본: 행 44px, 컨트롤 40px. 컴팩트(호스트 표): 행 36px, 컨트롤 32px. 게스트 화면은 기본만, 터치 대상 최소 44×44px |
| 분기점 | sm 640, md 768, lg 1024, xl 1280. 호스트 GNB는 1024px 이상에서 고정, 미만은 햄버거(03장 8절) |
| z 순서 | 헤더 30, 시트·드로어 40, 모달 50, 토스트 60, 지도 위 컨트롤 20 |

## 4. 기본 컴포넌트(공통 규칙 4장 2단계, SY-06-008)

기본 세트가 끝난 뒤에 5장의 제품 컴포넌트를 만든다. 모든 컴포넌트는 라이트/다크 × 상태(기본·호버·포커스·비활성·오류·로딩 중 해당되는 것)를 갖는다.

| 컴포넌트 | 배리언트와 크기 | 수치 | 비고 |
|---|---|---|---|
| Button | 종류: primary(accent), secondary(테두리 `line-strong`), ghost, danger. 크기: sm 32 · md 40 · lg 48px | 반경 control, 글자 14/20(sm), 16/24(md·lg) 500, 가로 안쪽 16px(md) | 로딩 중은 글자 유지 + 스피너, 눌러도 중복 전송 안 됨 |
| IconButton | ghost, secondary / 32 · 40 · 44px | 반경 pill, 아이콘 Lucide 20px(stroke 1.75) | `aria-label` 필수 |
| Input · Textarea · Select | default, error / md 40 · lg 48px | 반경 control, 테두리 `line-strong`, 안쪽 12px, 흰 바탕 | 오류는 테두리 `danger` + 메시지(아이콘 + 글자) |
| Combobox(지역 자동완성) | default, error | 목록 최대 높이 320px, 키보드 위아래·엔터·Esc | |
| DateRangePicker | 데스크톱 2개월 / 모바일 전체 화면 시트 | 불가 날짜 비활성(취소선 + `text-subtle`), 선택 구간 `accent-subtle`, 양 끝 `accent` | 화살표 키 이동, 범위 요약을 `aria-live`로 읽음 |
| Counter(인원·침대) | - 숫자 + | 버튼 44px 원형, 최소·최대에서 비활성 | |
| Checkbox · Radio · Switch | 기본 · 오류 | 크기 20px, 선택색 `accent`, 테두리 `line-strong` | 라벨 클릭 가능 |
| Chip | 선택/미선택, 삭제 가능 | 높이 32px, 반경 pill, 선택은 `accent-subtle` + `accent` 글자 | 필터·편의시설 |
| Dialog | sm 400 · md 560px | 반경 card, `overlay` 뒷면, Esc·바깥 클릭 닫기, 포커스 가두기 | |
| Sheet | 도우미 오른쪽 400px(모바일 전체) | `shadow-float`, 머리(제목 + 닫기) 고정 | 03장 3.10절 |
| Toast | success, error, info | 하단 중앙(모바일 하단 전체 폭), 5초, 오류는 닫을 때까지 | `role="status"`/`alert` |
| Tabs | 밑줄형 | 활성 `accent` 2px 밑줄 + `text`, 높이 44px | 호스트 레코드 페이지 |
| Tooltip | - | 지연 300ms, 키보드 포커스에도 표시 | |
| Skeleton | 사진, 줄, 카드 | `surface-sunken` + 천천히 깜빡임(reduced-motion이면 정지) | |
| Progress | 선형, 위저드 단계 | 높이 4px, `accent` | |
| Table(호스트) | 기본 · 컴팩트 | 행 44·36px, 머리글 small 500 `text-muted`, 행 구분선 `line`, 숫자 열 오른쪽 정렬 | 좌우 스크롤은 표 컨테이너 안에서만 |
| Card | 사진 카드, 정보 카드 | 반경 card, 정보 카드는 흰 바탕 + `line` 테두리(그림자 없음), 호버 시 사진 카드만 `shadow-hover` | |
| EmptyState | 아이콘 + 한 문장 + 행동 하나 | 03장 5절 문구 | |

### 4.1 StatusBadge 매핑

아이콘(Lucide 16px) + 글자 + 배경. 색만으로 구분하지 않는다. 글자 크기 caption(12px) 500, 반경 sm, 안쪽 가로 8px.

| 대상 | 상태 | 라벨 | 색 | 아이콘 |
|---|---|---|---|---|
| 숙소 | draft | 작성 중 | muted(`surface-sunken` + `text-muted`) | `pencil` |
| 숙소 | published | 게시됨 | success | `check-circle` |
| 숙소 | unlisted | 비공개 | muted | `eye-off` |
| 숙소 | suspended | 정지됨 | danger | `ban` |
| 예약 | requested | 승인 대기 | warning | `clock` |
| 예약 | confirmed | 확정 | success | `check-circle` |
| 예약 | declined | 거절됨 | danger | `x-circle` |
| 예약 | expired | 기한 만료 | muted | `timer-off` |
| 예약 | canceled_by_guest / canceled_by_host | 게스트 취소 / 호스트 취소 | muted | `circle-slash` |
| 예약 | completed | 완료 | accent | `badge-check` |
| 위키 | draft / published | 초안 / 발행됨 | muted / success | `file-pen` / `file-check` |
| ingest | pending / processing / done / failed | 대기 / 처리 중 / 완료 / 실패 | muted / info(`accent`) / success / danger | `hourglass` / `loader` / `check` / `alert-triangle` |
| AI | AI 초안 | AI 초안 | accent | `sparkles` |

## 5. 제품 컴포넌트

기본 세트(4장) 완성 뒤에 만든다. 이름은 03장 COMPONENTS 초기값과 같다.

| 컴포넌트 | 구성과 규격 | 상태 |
|---|---|---|
| ListingCard | 사진 4:3(반경 photo), 아래 제목(h3 아님, body 700 한 줄), 지역·침대 small `text-muted`, 가격 body 700 + "/ 박" small, 별점(RatingStars). 사진 오른쪽 위 WishlistButton. 카드 전체가 링크 | 기본, 호버(`shadow-hover`), 스켈레톤, 사진 없음(회색 바탕 + 아이콘), 비공개·정지(호스트용 배지) |
| PriceMarker | 지도 위 알약(pill) 가격 표시. 기본 `surface-raised` + `text`, 선택됨 `accent` 바탕 + `accent-fg`, 호버한 카드와 연결 시 `highlight` 바탕(화면당 한 개) | 기본, 선택, 군집(숫자 원), 키보드 포커스 |
| MapPanel | 검색 결과 오른쪽(데스크톱 50%) / 모바일은 "지도 보기" 토글. 지도 컨트롤은 `shadow-float`, 정확한 주소 대신 약 500m 원(주소 비공개, 05장) | 로딩, 지도 키 없음, 결과 0 |
| PhotoGrid | 상세 상단 1 큰 + 4 작은(데스크톱), 모바일은 가로 스와이프 + "사진 N장" 버튼. 간격 8px, 반경 photo | 사진 1~4장일 때 배치 규칙, 전체 보기(Dialog lg) |
| PhotoUploader | 드래그 드롭 영역(`surface-sunken`, 점선 `line-strong`), 썸네일 그리드, 순서 변경(드래그 + 키보드 버튼), 대표 지정 | 업로드 중(진행률), 실패(재시도), 10MB 초과 오류, 변환 중 |
| WizardStepper | 13단계. 데스크톱은 왼쪽 세로 단계 목록 + 완료 체크, 모바일은 상단 "7 / 13" + 진행 막대. 완료 단계만 이동 가능 | 완료, 현재, 잠김, 오류 있음 |
| PriceBreakdown | 박당 요금 × 박 수, 청소비, 서비스 수수료(해당 시), 합계. 합계 body 700 `tabular-nums`. 환불·취소 규정 링크 | 로딩, 날짜 미선택, 불가 날짜 |
| ReservationRow | 호스트 예약함 행: 게스트, 날짜, 인원, 금액, StatusBadge, 승인·거절 버튼(requested일 때만). 만료까지 남은 시간 | 승인 대기 강조(`warning-subtle` 줄 아님, 배지로만), 처리 중, 오류 |
| RatingStars | 별 5개 + 숫자(`tabular-nums`), 평점 없음이면 "아직 후기 없음". 가짜 평점 금지 | 읽기, 입력(키보드 1~5) |
| ReviewItem | 작성자 이름·날짜, 별점, 본문, 호스트 답글(들여쓰기 + `line` 왼쪽 선) | 긴 글 접기, 신고 |
| WishlistButton | 하트 아이콘 버튼 44px. 켜짐 `highlight` 채움(화면당 한 곳 규칙은 상세 화면 기준, 목록에서는 `accent` 채움 허용 — 제안) | 꺼짐, 켜짐, 로그인 필요(로그인 화면 후 복귀) |
| ChatPanel · MessageBubble · CitationChip | 03장 3.10절. 사용자 말풍선 `accent-subtle`, AI 답변은 바탕 없음 + 머리글 "AI가 생성한 답변". CitationChip은 pill, 숙소 정보/하우스 룰/위키 구분 아이콘 | 스트리밍, 근거 없음, 대체 모델 안내, 크레딧 부족 |
| VoiceButton | 마이크 아이콘 44px. 녹음 중 `accent` 링 + "녹음 중 0:12"(빨간 점 대신), 30초 자동 중지 | 대기, 녹음 중, 변환 중, 권한 거부, 첫 사용 고지 |
| ListingDraftCard | 제목 3안 라디오 + 설명 미리보기 + "이 문구 쓰기", "다시 만들기(크레딧)", 배지 "AI 초안" | 생성 중, 실패, 크레딧 부족 |
| WikiArticle | 본문, 사람 수정 블록 왼쪽 표시선(`accent`), 출처 절, 이력 탭, "AI가 정리하고 호스트가 검수한 문서" | 초안, 발행됨 |
| Hero3D | 03장 4.5절. 종이 지도 위 핀. 정지 이미지 대체(저사양·reduced-motion)를 항상 제공 | 로딩, 대체 이미지 |

## 6. 레이아웃 패턴

| 영역 | 패턴 | 규격 |
|---|---|---|
| 게스트 헤더 | 소비자 레이아웃: 로고, 가운데 검색 바(pill), 오른쪽 숙소 올리기·로그인 | 높이 72px(데스크톱), 64px(모바일). 스크롤 시 검색 바만 줄어듦 |
| 검색 결과 | 목록 + 지도(`DASHBOARD_PATTERNS` M 미디어 갤러리 변형) | 데스크톱 목록 50% + 지도 50%, 카드 열 2~3, 모바일 목록 우선 |
| 숙소 상세 | PhotoGrid → 제목·정보 → 오른쪽 예약 카드(sticky, 데스크톱) | 예약 카드 너비 360px, 모바일은 하단 고정 바 |
| 호스트 셸 | 앱 셸(패턴 A) + 레코드 상세(G) + 리스트-상세(B) | 헤더 64px + 좌측 GNB 248px(접힘 64px). 03장 8절 |
| 등록 마법사 | 가운데 폼 최대 640px + 오른쪽 AI 소개 초안 카드 | 단계마다 자동 저장 표시("저장됨 12:31") |

## 7. 접근성과 반응형 체크

| 항목 | 규칙 |
|---|---|
| 대비 | 3장 표를 기준으로 하고 새 색을 만들면 먼저 계산해 이 문서에 넣는다 |
| 포커스 | `focus-ring` 2px + 간격 2px, 모든 상호작용 요소. 포커스 순서는 시각 순서와 같다 |
| 키보드 | 달력 화살표·Home·End·PageUp/Down, 모달 포커스 가두기와 닫으면 원래 위치 복귀, 지도는 키보드로 목록에 접근 가능 |
| 터치 | 최소 44×44px |
| 상태 | 색만으로 표시하지 않는다(4.1절) |
| 사진 | 대표 사진 `alt`는 호스트가 쓴 설명, 없으면 "<숙소 이름> 사진 N" |
| 모션 | reduced-motion이면 3D 히어로는 정지 이미지, 시트 이동은 즉시 |
| 반응형 | 360px에서 가로 스크롤이 없다. 표는 카드형으로 접히거나 컨테이너 안에서만 스크롤 |

## 8. DESIGN.md · COMPONENTS.md 초기값(코드 저장소 `docs/file/03-설계/디자인/`에 둔다)

### 8.1 DESIGN.md

```
# DESIGN: Stay(가칭)
방향: 사진이 주인공인 조용한 여행 앱. 모래 백색 바탕, 먹 남청 글자, 솔숲 녹색 하나로 행동을 이끈다.
강조색(노을 주황)은 화면당 한 곳(가격 핀 또는 찜)만.
레퍼런스: Humbert & Poyet, Kononenko(게스트), Attio, Linear(호스트). 원본 Airbnb 모방 화면의 색·배치는 쓰지 않는다.
스택: Next.js 16.2.x, React 19.2, Tailwind CSS v4.x(고정), shadcn/ui, Lucide. tailwind.config.js 금지.
토큰: apps/web/src/styles/tokens.css (정답). 값 표는 products/airbnb/08_DESIGN_SYSTEM.md 3장.
타이포: Pretendard Variable(라이선스 확인 전), 제목 700, 본문 400, 숫자 tabular-nums.
스케일: display 40 / h1 32 / h2 24 / h3 20 / body-lg 18 / body 16 / small 14 / caption 12.
간격: 4px 기준, 카드 안쪽 16px, 섹션 간 48px(모바일 32px).
반경: 컨트롤 10px, 카드 16px, 사진 12px, 칩 999px.
그림자: 카드 호버 1단계, 떠 있는 층 1단계. 사진에는 없음.
다크: data-theme 하나로 전환. 밀도: 기본/컴팩트(data-density).
```

### 8.2 COMPONENTS.md

```
# COMPONENTS: Stay(가칭)
Button: primary / secondary / ghost / danger, sm 32 · md 40 · lg 48, 기본·호버·포커스·비활성·로딩
IconButton: ghost / secondary, 32 · 40 · 44
Input · Textarea · Select · Combobox: default / error, md 40 · lg 48
DateRangePicker: 불가 날짜 취소선 + 회색, 화살표 키, 모바일 전체 화면 시트
Counter, Checkbox, Radio, Switch, Chip
Dialog(sm 400 · md 560), Sheet(도우미 400px, 모바일 전체), Toast, Tabs, Tooltip, Skeleton, Progress
Table(기본·컴팩트), Card(사진·정보), EmptyState
StatusBadge: 숙소 4 · 예약 7 · 위키 2 · ingest 4 · AI 초안, 아이콘 + 글자
제품 고유: ListingCard, PriceMarker, MapPanel, PhotoGrid, PhotoUploader, WizardStepper, PriceBreakdown,
  ReservationRow, RatingStars, ReviewItem, WishlistButton, ChatPanel, MessageBubble, CitationChip,
  VoiceButton, ListingDraftCard, WikiArticle, Hero3D
```

## 9. 구축 순서와 검증(06장 W1-D)

| 단계 | 작업 | 산출물 | 담당 |
|---|---|---|---|
| 1 | SY-06-007 레퍼런스 분석 | `docs/design/references.md`(이 문서 1장 기준) | Sonnet |
| 2 | SY-06-008 `tokens.css` + 4장 기본 컴포넌트 | `src/styles/`, `src/components/ui/` | Sonnet(Opus 설계) |
| 3 | SY-06-009 사람 비주얼 검토 | `docs/design/review-log.md` | 사람 |
| 4 | 5장 제품 컴포넌트와 화면 작업(W2~) | `src/components/{listing,...}/` | 화면 작업 |

| 검증 | 방법 |
|---|---|
| 토큰 코드 일치 | 3장 표와 `tokens.css` 값 비교(스크립트 또는 눈) |
| 컴포넌트 | `/dev/components` 라이트/다크 × 기본/컴팩트 스크린샷 |
| 대비 | 3장 표의 계산을 새 값이 생길 때 다시 계산 |
| 린트 | 임의 값 `bg-[#...]` 금지 규칙(제안) |

## 10. 미확인과 열린 항목

| 항목 | 상태 |
|---|---|
| Pretendard 라이선스(OFL) | 확인하지 않음. 쓰기 전 확인, 안 되면 시스템 한글 서체로 대체 |
| `line-strong` 입력 테두리 대비 2.89:1 | 사람 검토에서 #7C878E(약 3.4:1)로 올릴지 결정(제안) |
| 다크 토큰의 시각 확인 | 대비 계산만 했고 화면으로 본 적 없음 |
| `design/tokens.css`의 Tailwind v4 컴파일 | 문법은 v4 문서 기준으로 작성. 빌드 확인은 저장소 생성 후 SY-06-008에서 |
| WishlistButton 목록에서 accent 허용 | 제안. highlight "화면당 한 곳" 규칙과 충돌 방지 |
| 최종 브랜드명·로고 | 01장 D1 결정 전. 이 문서는 로고를 정하지 않음 |
