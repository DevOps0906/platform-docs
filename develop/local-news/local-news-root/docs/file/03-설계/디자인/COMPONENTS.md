# COMPONENTS.md — local-news 컴포넌트·배리언트 명세 (초기값: 화면설계서 3장에서 복사)

> 정답 소스는 코드다(`apps/web/src/styles/tokens.css`, `apps/web/src/components/ui/`). 이 문서는 코드에서 갱신하고, 다르면 코드가 이긴다.
> 규칙: `docs/file/03-설계/디자인/DESIGN_SYSTEM.md`. 출처: `docs/file/03-설계/03_SCREENS_UX.md` 같은 이름의 "초기값" 절.

| 컴포넌트 | 배리언트 | 크기 | 상태 | 작업 |
|---|---|---|---|---|
| Button | primary, secondary, ghost, danger | sm 32 / md 36(콘솔) / 44(독자, 터치) / lg 48 | 기본, 호버, 포커스, 비활성, 로딩 | 06장 디자인 시스템 작업 |
| Input·Textarea·Select·Combobox·DateTimeField(KST 표시) | default, error | md 36 / lg 44 | 기본, 포커스, 비활성, 오류 | 같음 |
| Checkbox·Switch·RadioGroup·SegmentedRadio | - | md | 기본, 포커스, 비활성, 오류 | 같음 |
| Dialog·Sheet(400/480px, 모바일 전체 화면)·Toast | - | - | 열림, 닫힘 | 같음 |
| Table | compact 32 / default 40, 숫자 오른쪽 정렬 | - | 빈 상태, 스켈레톤, 행 선택 | 같음 |
| StatusLozenge | 기사(draft, submitted, approved, scheduled, published, updated, unpublished, archived, rejected), 정정 청구(received, notified, accepted, rejected, published, overdue), 광고(draft, active, paused, ended), 도메인(pending, verifying, active, failed, removed), 컴플라이언스(PASS, WARN, FAIL), 잡(queued, running, succeeded, failed) | sm | 아이콘 + 텍스트 | 같음 |
| Tabs·Tooltip·Popover·Progress·Skeleton·Kbd·Stepper | - | - | - | 같음 |
| AppShell | 사이드바 240/56px, 조직 전환기, 상단 AI 잔액 | - | 접힘, 모바일 드로어 | 콘솔 |
| BlockEditor·MetaPanel·ArticleStatusBar·RevisionDiff | 기사 유형 5종 | 메타 패널 360px | 자동 저장 중·저장됨·오류 | 에디터 |
| ReviewQueue·HomeLayoutEditor(BlockList, DevicePreview) | 템플릿 A/B/C | - | 드래그 중, 잠금 블록 | 데스크 |
| ComplianceGauge·ComplianceChecklist·SlaTimer | - | - | PASS·WARN·FAIL, D-n | 준수 |
| ChatPanel·MessageBubble·CitationChip·VoiceButton·DictationMemo·ConsentNoticeDialog | - | Sheet 400px | 스트리밍, 녹음 중, 권한 거부 | AI |
| 독자 블록: UtilityBar, Masthead, Gnb, RegionTabs, BreakingTicker, LeadA·LeadPackageB·LeadCardC, MostRead, LifeEventsTabs, EventsStrip, WeatherAir, SectionBlock, Opinion, PhotoVideo, PublicNotices, LocalListings, NewsletterCta, MembershipCta, TipCta, CorrectionsBlock, Feed, BottomTabBar, LegalFooter | 템플릿별 변형 | 4.6절 그리드 | 빈 데이터 시 블록 숨김(푸터 제외) | 독자 |
| AdSlot | 4.5절 슬롯 키 | IAB 고정 크기, min-height 예약 | 로딩, 소재, 하우스 광고, 빈 슬롯 비접힘 | 광고 |
| ArticleHeader·Byline·CorrectionBanner·AiDisclosure·SponsoredLabel·AudioPlayer·FontSizeControl·RelatedArticles | - | 본문 680px | - | 독자 기사 |
