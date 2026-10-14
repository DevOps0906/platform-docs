# COMPONENTS.md — nomad-docs 컴포넌트·배리언트 명세 (초기값: 화면설계서 3장에서 복사)

> 정답 소스는 코드다(`apps/web/src/styles/tokens.css`, `apps/web/src/components/ui/`). 이 문서는 코드에서 갱신하고, 다르면 코드가 이긴다.
> 규칙: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`. 출처: `docs/file/03-설계/03_SCREENS_UX.md` 같은 이름의 "초기값" 절.

| 컴포넌트 | 배리언트 | 크기 | 상태 | 작업 |
|---|---|---|---|---|
| Button | primary, secondary, ghost, danger | sm 32 / md 36 / lg 40px | 기본, 호버, 포커스, 비활성, 로딩 | DC-06-009 |
| Input·Textarea·Select·Combobox·DateField·MoneyInput | default, error | md 36 / lg 44px | 기본, 포커스, 비활성, 오류 | DC-06-009 |
| Checkbox·Switch·RadioGroup·SegmentedRadio | - | md | 기본, 포커스, 비활성, 오류 | DC-06-009 |
| Dialog·Sheet(400/480px)·Toast | - | - | 열림, 닫힘 | DC-06-009 |
| Table | compact 32px, default 40px, 숫자 오른쪽 정렬 | - | 빈 상태, 스켈레톤, 행 선택 | DC-06-009 |
| StatusLozenge | 프로젝트·문서·요구사항·생성 실행·내보내기·연동·compliance·파이프라인 단계 | sm | 아이콘 + 텍스트 | DC-06-009 |
| Tabs·Tooltip·Popover·Progress·Skeleton·Kbd·Stepper·Tag | - | - | - | DC-06-009 |
| AppShell | 내비 펼침 240px / 접힘 56px, 상단 명령 막대 48px | - | 모바일은 하단 탭 4개 + 햄버거 | DC-06-011 |
| CommandPalette | 검색, 명령, 최근 | 640px 폭 | 열림, 결과 없음, 로딩 | DC-06-061 |
| PipelineBoard·StageColumn·PipelineCard | board, table | 열 280px, 카드 높이 자동 | 기본, 포커스, 단계 이동 애니메이션, 재생성 필요 배지 | DC-06-061 |
| RecordHeader·RecordSidebar·ActivityTimeline | 거래처, 프로젝트 | 사이드바 320px | 기본, 접힘, 빈 타임라인 | DC-06-061 |
| SavedViewBar | 필터 칩, 정렬, 열 선택 | - | 기본, 변경됨(저장 안 됨) | DC-06-061 |
| GenerationProgress(StageRail·SectionLane·SheetAssembler) | 단일, 패키지 | 오버레이 560px / 패키지 전체 폭 | 대기, 진행, 완료, 실패, 취소, reduced-motion | DC-06-062 |
| Hero3D·HeroVideo | 실시간 3D, 영상, 정지 이미지 | 전체 폭 | 로딩, 재생, 일시정지, 강등 | DC-06-045 |
