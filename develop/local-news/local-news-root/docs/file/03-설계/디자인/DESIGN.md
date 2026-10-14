# DESIGN.md — local-news 디자인 토큰 (초기값: 화면설계서 3장에서 복사)

> 정답 소스는 코드다(`apps/web/src/styles/tokens.css`, `apps/web/src/components/ui/`). 이 문서는 코드에서 갱신하고, 다르면 코드가 이긴다.
> 규칙: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`. 출처: `docs/file/03-설계/03_SCREENS_UX.md` 같은 이름의 "초기값" 절.

| 항목 | 값 |
|---|---|
| 주 레퍼런스 | 편집국: Atlassian(워크플로·상태·드래그) + Primer(밀도). 독자 사이트: 국내외 언론사 홈 벤치마크(03장 4.1절), 템플릿 A/B/C |
| 가져올 패턴 | 한국형 리드(톱 + 헤드라인 리스트), 많이 본 뉴스, 시군 칩 탭, 경조사 4탭, 광고 슬롯 공간 예약, 법정 푸터 |
| 가져오지 않을 것 | 팝업·전면 광고, 날개 광고의 상시 노출(1600px 이상에서만), 벤더 로고 강제, 낚시성 배너 |
| 테넌트 규칙 | 허용 목록(`brand`, `brand-foreground`, `brand-hover`, `brand-subtle`, `accent`, `accent-foreground`, `focus-ring`, `sidebar`, `sidebar-foreground`, `chart-1`~`5`, `radius-control`, `radius-card`)만 덮어쓴다. 아래 고정 토큰은 바꾸지 않는다 |

| 토큰 | reader 라이트 | reader 다크 | 용도 |
|---|---|---|---|
| `--color-background` | #F1F3F5 지면 회색 | #14181F | 블록 바깥 바탕(고정) |
| `--color-surface` | #FFFFFF 판면 | #1C222B | 기사·블록 바탕(고정) |
| `--color-text` | #1B2330 인쇄 먹(흰 바탕 15.8:1) | #E6E9EE | 본문·제목(고정) |
| `--color-text-muted` | #5A6472(6.0:1) | #A9B1BC | 시각·바이라인·광고 라벨(고정) |
| `--color-rule` | #C9CED6 괘선 | #3A4452 | 블록 구분선(글자에 쓰지 않음) |
| `--color-brand` | #12457A 제호 남청(흰 글자 9.7:1) | #7FB0E6(먹 글자 7.8:1) | 테넌트 기본값. 링크, 주 버튼, 활성 탭 |
| `--color-accent` | `brand` 파생 | 파생 | 테넌트 보조 강조 |
| `--color-breaking` | #B42318 호외 적(흰 글자 6.6:1) | #F27B70(먹 글자 6.7:1) | 속보 바·LIVE 라벨에만(고정, 테넌트 변경 불가) |
| `--color-surface-sponsored` | #F4F6F9 | #222A35 | 기사형 광고 바탕(고정) |
| `--color-success` / `--color-warning` / `--color-danger` | #1E7A4C / #9A6200 / #B3261E | #5BC08A / #E0A845 / #F07A6E | 상태(고정) |

| 토큰 | newsroom·ops 라이트 | 다크 | 용도 |
|---|---|---|---|
| `--color-background` | #F6F7F9 | #14181F | 셸 바탕 |
| `--color-surface` | #FFFFFF | #1C222B | 표·패널 |
| `--color-text` / `--color-text-muted` | #1B2330 / #566070(5.9:1) | #E6E9EE / #A9B1BC | 글자 |
| `--color-brand` | #1F5FA8 데스크 청(흰 글자 6.4:1) | #7AA7E0 | 주 행동·포커스. 콘솔은 플랫폼 색(테넌트 로고만 사이드바에 표시) |
| 상태 | 위 reader와 같음 | 같음 | lozenge |

| 토큰 | 값 | 용도 |
|---|---|---|
| `--font-heading` | 프리셋별(Noto Serif KR, 본명조, 나눔명조, Pretendard). 4.7절 | 독자 제목 |
| `--font-body` | Pretendard(동적 서브셋) | 독자 본문·UI, 콘솔 전체 |
| `--text-article` | 17px / 1.8(최소, 제안), 글자 크기 단계 17·19·21·24px | 기사 본문 |
| `--radius-control` / `--radius-card` | 6px / 8px(reader 사진은 2px) | 버튼·입력 / 카드 |
| `--space-row-compact` / `--space-row-default` | 32px / 40px | 콘솔 표 행 |
| `--container-max` / `--rail-width` / `--gutter` | 1200px / 300px / 24px(xs 16px) | 독자 그리드(4.6절) |
| `--motion-fast` / `--motion-base` | 120ms / 200ms, reduced-motion이면 0ms | 콘솔 응답 모션만. 독자 사이트 자동 모션 없음 |
