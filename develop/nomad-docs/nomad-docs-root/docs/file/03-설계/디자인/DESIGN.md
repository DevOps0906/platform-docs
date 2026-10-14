# DESIGN.md — nomad-docs 디자인 토큰 (초기값: 화면설계서 3장에서 복사)

> 정답 소스는 코드다(`apps/web/src/styles/tokens.css`, `apps/web/src/components/ui/`). 이 문서는 코드에서 갱신하고, 다르면 코드가 이긴다.
> 규칙: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`. 출처: `docs/file/03-설계/03_SCREENS_UX.md` 같은 이름의 "초기값" 절.

| 항목 | 값 |
|---|---|
| 주 레퍼런스 | 앱: Atlassian(단계형 폼·보드·상태 lozenge) + Primer(표 밀도). 로그인 후 셸: Attio·HubSpot·Pipedrive·Linear 패턴(3.26절). 랜딩: `HERO_3D.md` + 4장 |
| 가져올 패턴 | 단계형 진행, 칸반 열과 키보드 대안, 고밀도 표, 레코드 페이지(헤더 + 탭 + 오른쪽 속성 사이드바), 활동 타임라인, ⌘K 팔레트, 필터 칩 + 저장된 뷰 |
| 가져오지 않을 것 | 라이브러리 설치(`@atlaskit/*`, `@primer/react`), 각 서비스의 색·로고·아이콘·일러스트, 끌어 놓기로 데이터 상태 바꾸기, 무한 커스텀 필드 |

| 토큰 | 라이트 | 다크(제안, 3단계 사람 검토에서 확정) | 용도 |
|---|---|---|---|
| `--color-canvas` | #E6EBE7 | #141A17 | 페이지 배경(서류철) |
| `--color-surface` | #FBFCFA | #1B2320 | 문서 지면·카드·표 바탕(용지) |
| `--color-text` | #1D2421 | #E3E8E4 | 본문(먹회) |
| `--color-text-muted` | #4F5A55 | #A7B0AB | 보조 글자(대비 4.5:1 이상, 구현 시 측정) |
| `--color-rule` | #8A948F | #3A4440 | 괘선·구분선(글자에 쓰지 않음) |
| `--color-accent` | #1F4E8C | #7FA8E0 | 주 행동·링크·포커스 링(결재청) |
| `--color-seal` | #B3262E | #D0464E | 직인·확정 표시·3D 히어로 직인에만(인주) |
| `--color-success` | #1F7A45 | #4CB97A | 확정 완료, compliance pass |
| `--color-warning` | #8F5B00 | #D9A23B | WARN, 재생성 필요 |
| `--color-danger` | #A3361A | #E07A5F | 오류(인주와 구분) |
| `--color-diff-add` / `--color-diff-remove` | #DCEFE2 / #F6DEDA | #1F3A2A / #3E2523 | Diff 바탕(밑줄·취소선·텍스트 병기) |

| 토큰 | 값 | 용도 |
|---|---|---|
| `--font-display`, `--font-body` | Spoqa Han Sans Neo | UI·제목. 본문 15/24px 400 |
| `--font-doc` | Noto Serif KR | 문서 지면 15/26px |
| `--radius-control` / `--radius-sheet` | 6px / 10px | 입력·버튼 / 카드·시트 |
| `--space-row-compact` / `--space-row-default` | 32px / 40px | 표 행 높이 |
| `--shadow-sheet` | 0 1px 2px 먹회 8%, 0 8px 24px 먹회 6% | 시트·팔레트(다크는 그림자 대신 테두리) |
| 모션 | 위 모션 토큰 | 3.25절 |

밀도: 표·보드는 컴팩트/기본 두 단계(사용자 설정, 기본 = 기본). 다크 전환: `data-theme` 하나(`@custom-variant dark`). 다크는 앱 화면만, 랜딩은 라이트.
