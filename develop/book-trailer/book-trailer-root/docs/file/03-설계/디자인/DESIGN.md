# DESIGN.md — book-trailer 디자인 토큰 (초기값: 기획서 `docs/file/03-설계/08_DESIGN_SYSTEM.md`에서 복사)

> 정답 소스는 코드다(`apps/web/src/styles/tokens.css`, `apps/web/src/components/ui/`). 이 문서는 코드에서 갱신하고, 다르면 코드가 이긴다.
> 규칙: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`. 출처: `docs/file/03-설계/08_DESIGN_SYSTEM.md` 같은 이름의 "초기값" 절.

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
