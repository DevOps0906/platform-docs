# COMPONENTS.md — book-trailer 컴포넌트·배리언트 명세 (초기값: 기획서 `docs/file/03-설계/08_DESIGN_SYSTEM.md`에서 복사)

> 정답 소스는 코드다(`apps/web/src/styles/tokens.css`, `apps/web/src/components/ui/`). 이 문서는 코드에서 갱신하고, 다르면 코드가 이긴다.
> 규칙: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`. 출처: `docs/file/03-설계/08_DESIGN_SYSTEM.md` 같은 이름의 "초기값" 절.

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
