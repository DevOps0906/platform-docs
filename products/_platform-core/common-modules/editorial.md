# editorial: 콘텐츠 워크플로 (공용모듈 기획서)

작성일 2026-10-15. 상태: 제안. 패키지 `@nomad/editorial`, 스키마 `editorial`(0750~0799), 오류 코드 `ED###`. 출처: local-news M1의 기사 워크플로(작성 → 제출 → 데스크 승인 → 예약 → 게시 → 수정·정정, 수정 이력, 미리보기 토큰)와 M8의 조회 집계. 개발서 `docs/develop/_shared/modules/editorial.md`.

## 1. 문제

블로그 글(nomad-blog), 원고(flora-publishing), 회차(toon-factory), 사이트 소식·사례(website-floria), 문서 승인(nomad-docs), 기사(local-news)는 모두 "초안 → 검토 → 게시 → 수정 이력" 흐름을 가진다. 제품마다 만들면 예약 게시 누락, 동시 편집 덮어쓰기, AI 초안이 사람 승인 없이 게시되는 사고가 각각 생긴다.

## 2. 범위

| 구분 | 내용 |
|---|---|
| MVP | 공통 항목 표(제목·슬러그·블록 본문·요약·대표 이미지·SEO), 상태 기계(제품별 설정), 역할별 전이 권한, 예약 게시(pg_cron 1분 재조정), 수정 이력(스냅샷), 편집 잠금, 미리보기 토큰, AI 표시(사람 승인 필수), 게시 가드(다른 모듈 함수), 조회 집계(시간 버킷) |
| 확장 | 변경 비교(diff) 화면, 공동 편집(실시간), 다국어 버전, 콘텐츠 일정 캘린더, 승인 단계 2단 이상 |
| 제품에 남김 | 기사 유형·바이라인·섹션·지역·지면(local-news), 원고 장·절 구조와 판형(flora), 회차 컷 구성(toon) → 제품 확장 표 |
| 블록 형식 | 본문 블록 JSON 규격은 cms 모듈과 공유한다(`COMMON_MODULES_ROADMAP.md` 4.11절 cms 보강). editorial은 저장·버전만, 렌더러는 cms |

## 3. 데이터 모델

| 표 | 주요 컬럼 | RLS·쓰기 |
|---|---|---|
| `editorial.workflows` | `app_id`, `entry_type`(예 `news.article`, `blog.post`, `site.case`), `states`(jsonb 배열), `transitions`(jsonb: from, to, 허용 역할, 필요한 가드 함수 목록), `requires_human_approval`(bool, 기본 true), `org_id`(null = 제품 기본, org 덮어쓰기 허용 여부는 설정) | 플랫폼 운영자·제품 seed |
| `editorial.entries` | `id`, `org_id`, `app_id`, `entry_type`, `title`, `slug`(org·app·type 안 유일), `body`(jsonb 블록), `excerpt`, `hero_media_id`(→ `media.assets`), `seo`(jsonb: title, description, canonical, noindex), `status`, `scheduled_at`, `published_at`, `first_published_at`, `version`, `author_id`, `origin`(`human`, `ai_draft`, `import`), `ai_assisted`(bool), `labels`(text[], compliance 코드), `locked_by`, `locked_until`, `legacy_id`, `legacy_url`, `meta`(jsonb, 허용 키) | 읽기: 게시본은 공개 뷰 `editorial.public_entries`(anon, 접근 규칙은 membership 판정), 초안은 org 멤버. 쓰기: `editorial.save_draft`, `editorial.transition`, `editorial.schedule`, `editorial.correct` RPC |
| `editorial.revisions` | `entry_id`, `version`, `snapshot`(jsonb: 제목·본문·SEO·라벨), `changed_by`, `reason`(`edit`, `correction`, `ai_suggestion_applied`), `created_at` | 추가만. org 멤버 읽기 |
| `editorial.transitions_log` | `entry_id`, `from_status`, `to_status`, `actor_id`, `actor_kind`(`member`, `service`), `note`, `created_at` | 추가만. 감사용 |
| `editorial.preview_tokens` | `token_hash`, `entry_id`, `version`, `expires_at`(기본 24시간) | 서버만 |
| `editorial.view_counts_hourly` | `entry_id`, `bucket_hour`, `views`, `org_id`, `app_id` | 쓰기: `editorial.increment_views`(service, 묶음 증분), 읽기: 집계 뷰 `editorial.most_viewed(org, app, type, window)` |

상태 기본값(제품이 줄이거나 이름을 바꿀 수 있음): `draft` → `in_review` → `approved` → `scheduled` → `published` → `unpublished` / `archived`. 반려는 `in_review` → `draft`(메모 필수).

오류 코드: `ED001` 허용되지 않은 전이(역할), `ED002` 사람 승인 없이 게시 시도(AI·service 주체), `ED003` 게시 가드 실패(가드 함수 이름과 사유 포함), `ED004` 편집 잠금 충돌, `ED005` 버전 충돌(낙관적 잠금), `ED006` 슬러그 중복, `ED007` 과거 시각 예약.

## 4. 게시 가드 (다른 모듈과의 연결)

`transitions[].guards`에 함수 이름을 적으면 전이 RPC가 순서대로 호출하고 하나라도 거짓이면 `ED003`.

| 가드 예 | 제공 모듈 | 쓰는 제품 |
|---|---|---|
| `compliance.is_profile_complete:kr_newspaper` | compliance | local-news |
| `compliance.labels_ok` | compliance | 광고·AI 콘텐츠가 있는 모든 제품 |
| `media.alt_text_ok` | media | 접근성 필수 제품 |
| `news.election_guard` | local-news(제품 함수) | local-news 선거 모드 |

제품 함수도 가드로 등록할 수 있다(이름이 `<제품 스키마>.` 접두어). editorial은 가드 내용을 모른다. 임의 SQL 실행을 막기 위해 가드는 등록표 `editorial.guard_registry`(함수 이름, 인자 형식, 등록자)에 있는 함수만 호출한다(플랫폼 운영자·제품 seed만 등록).

## 5. 공개 API (TS 계약 예시)

```ts
// @nomad/editorial/server
saveDraft(input: { appId; orgId; entryType; id?; patch: EntryPatch; expectedVersion?: number }): Promise<Entry>
transition(entryId: string, to: Status, opts?: { note?: string }): Promise<Entry>   // 사람 세션만 approved·published로
schedule(entryId: string, at: Date): Promise<void>
correct(entryId: string, patch: EntryPatch, reason: string): Promise<Entry>         // 게시 후 수정, 이력 reason=correction
createPreviewToken(entryId: string): Promise<string>
recordViews(batch: { entryId: string; at: Date }[]): Promise<void>                  // 서버 수집기만
// @nomad/editorial/ui
<EntryStatusBadge /> <TransitionBar entry /> <RevisionList entryId /> <ScheduleDialog />
```

## 6. 이벤트와 잡

| 이벤트 | 잡·구독 |
|---|---|
| `editorial.entry.submitted`, `.approved`, `.rejected` | notify(담당자 알림) |
| `editorial.entry.published`, `.updated`, `.unpublished`, `.corrected` | 잡 `editorial.post_publish`: 캐시 태그 무효화(제품 콜백), search 색인, cms 사이트맵, notify(구독자 알림은 제품이 결정) |
| `editorial.entry.scheduled` | pg_cron 1분: `scheduled_at <= now()`인 항목을 다시 잡으로(유실 대비) |

## 7. AI 규칙

| 규칙 | 내용 |
|---|---|
| 사람 승인 | `requires_human_approval = true`(기본)면 `approved`·`published` 전이는 사람 세션만. service·AI 주체는 `ED002` |
| 표시 | `origin = 'ai_draft'` 또는 `ai_assisted = true`면 compliance `ai_assisted`/`ai_generated` 라벨이 필수(`compliance.labels_ok` 가드) |
| 이력 | AI 제안을 적용하면 `revisions.reason = 'ai_suggestion_applied'` |

## 8. 실패 동작

예약 게시 잡 실패 → 재시도 3회 → 담당자 알림, 상태는 `scheduled` 유지(조용히 게시하거나 건너뛰지 않음). 조회 집계 실패는 화면에 영향 없음, 다음 묶음에서 다시.

## 9. local-news에서 옮기는 것 (추출 시)

| local-news | 공용 | 남는 것(확장 표 `news.articles`) |
|---|---|---|
| `news.articles`의 제목·부제·본문·상태·예약·게시 시각·AI 표시·legacy | `editorial.entries` | `article_type`, `byline`, `section_id`, 지역·태그 연결, `is_poll`, 기사형 광고 여부 |
| `news.article_revisions` | `editorial.revisions` | - |
| `news.publish_article` 등 전이 RPC | `editorial.transition` + 가드 | 신문 전용 가드 함수 |
| `news.article_view_hourly`, `news.increment_article_views`, `news.most_read` | `editorial.view_counts_hourly`, `increment_views`, `most_viewed` | - |

추출 절차는 `docs/products/local-news/modules/README.md` 5장(호환 뷰 한 릴리스 유지).

## 10. 결정 필요

| ID | 결정 | 권고 |
|---|---|---|
| ED-D1 | 본문 에디터 | Tiptap(ProseMirror 기반, 블록 JSON 저장) 권고, Lexical 대안. cms와 같이 결정 |
| ED-D2 | 조회 집계를 editorial에 둘지 analytics로 뺄지 | editorial(콘텐츠 순위가 게시 상태와 붙어 있음). 행동 분석은 analytics 외부 도구 |
| ED-D3 | 공동 편집 | 확장(1차는 잠금 + 낙관적 버전) |
