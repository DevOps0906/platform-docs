# 코드 기반 영상 렌더 · 디자인 스킬 · 유튜브 링크 요약 — 제품별 적용 후보

작성 2026-11-11. **후보 기록이며 결정이 아니다.**

> **확인 범위**: TikTok 영상 2편은 자동 접근이 차단되어 vidIQ 분석 결과로만 확인했다. 저장소·패키지는 소개 페이지만 읽었고 코드를 실행하지 않았다. 별 개수·수치·모델명("Fable 5.5")·라이선스는 모두 미검증이다. 원문 노트(`ai-course-references` 레포의 `research-notes/`)와 SceneFlow 레포의 `docs/reference/CODE_RENDER_AND_YOUTUBE_INTAKE.md`가 같은 조사를 다룬다.

## 1. 조사 요약

| 묶음 | 내용 |
|---|---|
| 코드 기반 영상 | 영상 생성 AI 대신 코드로 영상을 만드는 방식 2가지. hyperframes(HeyGen 오픈소스, HTML/CSS → 모션 영상 렌더)와, Claude가 한 번의 프롬프트로 코드를 생성해 브라우저에서 재생한 81초 2D 애니메이션 사례(@chetaslua, 제작자 주장) |
| 디자인 스킬 | 10월 GitHub 트렌딩에 오른 코딩 AI 스킬: `taste-skill`(디자인 감각 부여), `impeccable`(보라 그라데이션·너무 작은 라벨·카드 속 카드·전부 Inter 폰트 같은 "AI 티"를 감지·수정). 소개 내용만 확인 |
| 유튜브 링크 요약·캡처 | 후보 3개(모두 MIT): YT2(링크 → 장면 전환별 키프레임 + 구간 요약 HTML), digestvid(전사 + 요약 + 중간 지점 스크린샷 1장), claude-video(Claude Code용 프레임·자막 추출). 사용자가 말한 readray는 검색에서 확인하지 못했고 비슷한 서비스는 Lilys AI, SecondB 등 |

## 2. 제품별 적용 후보

● 기획에 이미 해당 기능이 있음 / ○ 후보(제품 개발 착수 때 채택 여부 결정) / - 해당 없음. 제품 기획서는 이번에 고치지 않았다.

| 제품 | 코드 기반 렌더 | 디자인 스킬 | 유튜브 링크 요약·캡처 | 비고 |
|---|---|---|---|---|
| sceneflow | ○ Phase 2(D-30) 비교 후보 | ○ | ○ 샷 경계 검출(Phase 2) 참고 | MVP 렌더는 FFmpeg 하나(SF-2). 자세한 판단은 SceneFlow 레포 `docs/reference/` |
| book-trailer | ○ Remotion 대안으로 비교 | ○ | - | 기획의 렌더러는 Remotion. Remotion 라이선스 조건은 `Tauri/README.md`에 먼저 확인하라고 적혀 있음. hyperframes 라이선스도 같은 방식으로 확인 |
| study-note | - | ○ | ○ 원문 입력 방식에 유튜브 강의 링크 추가 검토 | 현재 입력은 수업·회의 원문 붙여넣기와 강의 녹음 → 노트 생성 |
| 그 외 제품 | - | ○ 화면 개발 때 "AI 티" 점검 후보 | - | 해당 기능이 기획에 없음 |

## 3. 이 저장소에서 하지 않는 것

- 디자인 기준 문서는 이 저장소에서 고치지 않는다. 디자인 스킬을 기준에 반영할지는 [nomad-design-modules](https://github.com/DevOps0906/nomad-design-modules)에서 정한다(README 9장).
- 제품 기획서(`products/<제품>/`)와 생성물(`develop/*/*-root/`)은 이번에 고치지 않았다.
- 외부 저장소 코드를 복사하지 않는다. 라이선스는 도입 전에 각각 확인한다.

## 4. 검증 순서 (비용 낮은 순)

1. 원본 저장소를 직접 열어 라이선스·요구 사항·수치를 확인한다(hyperframes, taste-skill, impeccable, YT2).
2. hyperframes로 템플릿 1개, YT2로 영상 3~5개(한국어 포함)를 로컬에서 돌려 품질을 본다.
3. 결과가 좋은 후보만 해당 제품의 개발 착수 때 채택 여부를 정하고, 채택하면 그 제품 기획서에 반영한다.

## 5. 위험 (유튜브 링크 소싱, 미검증)

- 서버에서 영상을 내려받는 방식은 차단될 수 있다. 다른 개발자가 yt-dlp 차단으로 유튜브 요약 서비스를 중단했다고 밝힌 사례가 있다.
- 내려받은 영상을 상업 서비스로 제공하는 것은 약관·저작권 이슈가 있을 수 있어 제품에 넣기 전에 확인이 필요하다.
- 대안으로 자막 기반 요약만 서버에서 처리하거나, 크롬 확장으로 사용자 브라우저에서 자막을 가져오는 구조가 거론된다.

## 출처

- TikTok @ai__scene: https://www.tiktok.com/@ai__scene/video/7702320492631444757
- TikTok @ai.trend.kr: https://www.tiktok.com/@ai.trend.kr/video/7703754885195648276
- https://github.com/bhopy/YT2 · https://pypi.org/project/digestvid/0.2.1 · https://github.com/bradautomates/claude-video
- https://news.hada.io/topic?id=26041 (SecondB.ai) · https://news.hada.io/topic?id=21519 (yt-dlp 차단 사례)
