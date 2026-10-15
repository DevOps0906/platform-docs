# editorial 개발 지시서 (`@nomad/editorial`)

기획 정본: `products/_platform-core/common-modules/editorial.md`. 공통 규칙·적용 절차: [`README.md`](README.md).

## 1. 만들 것 (v1.0)

공통 항목 표와 제품별 워크플로 설정, 전이 RPC(역할·가드·사람 승인), 예약 게시(잡 + pg_cron 1분 재조정), 수정 이력, 편집 잠금·낙관적 버전, 미리보기 토큰, 조회 묶음 집계와 많이 본 항목, 상태 배지·전이 버튼·이력·예약 컴포넌트. 본문 에디터 자체는 cms와 함께 정하는 블록 규격(ED-D1)을 씁니다.

## 2. 파일

| 경로 | 책임 |
|---|---|
| `sql/0750_editorial.sql` | 표 6개, `transition`(워크플로 jsonb 해석, 가드 함수 동적 호출은 허용 목록 `editorial.guard_registry`만), `increment_views`, `most_viewed` |
| `src/server/entries.ts`, `transition.ts`, `schedule.ts`, `preview.ts`, `views.ts` | 공개 API |
| `src/workflow.ts` | 워크플로 정의 타입과 기본값, 제품이 덮어쓸 수 있는 범위 검사 |
| `worker/handlers/editorial/publish.ts`, `post-publish.ts` | 예약 게시, 게시 후 처리(제품 콜백: 캐시 무효화) |
| `src/ui/` | `EntryStatusBadge`, `TransitionBar`, `RevisionList`, `ScheduleDialog`, `PreviewBanner` |

## 3. 구현 순서

| 순서 | 작업 | 확인 |
|---|---|---|
| 1 | SQL, 가드 등록표(SQL 문자열 실행이 아니라 등록된 함수만 `format('%I.%I')`로 호출) | 미등록 가드 이름 거부 |
| 2 | 전이 RPC: 역할 검사 → 사람 승인 검사(`core.is_service_caller`면 approved·published 거부 `ED002`) → 가드 → 이력·로그 | 전이 표 전부 테스트 |
| 3 | 저장: `expectedVersion` 불일치 `ED005`, 잠금 10분 갱신 | 두 탭 동시 저장 시 하나 실패 |
| 4 | 예약 게시: `schedule` → 잡, pg_cron이 1분마다 누락분 재enqueue(멱등 키 `editorial.publish:<id>:<version>`) | 서버 재시작 중 예약도 1~2분 안 게시 |
| 5 | 게시 후 처리: 제품 콜백(`onPublished`)으로 캐시 태그 무효화, search 색인 잡 | 게시 후 공개 페이지 갱신 |
| 6 | 조회 수집: 서버 Route Handler가 묶음(10초 또는 100건)으로 `increment_views` | 클라이언트 직접 증가 경로 없음 |

## 4. 외부 서비스·공식 문서

| 주제 | 링크 |
|---|---|
| Tiptap(ED-D1 권고) | https://tiptap.dev/docs |
| Lexical(대안) | https://lexical.dev |
| Next.js 캐시 태그 무효화 | https://nextjs.org/docs/app/api-reference/functions/revalidateTag |
| pg_cron | https://supabase.com/docs/guides/database/extensions/pg_cron |

## 5. 제품 주입 값

| 값 | 예 |
|---|---|
| `entryTypes` | nomad-blog `blog.post`, local-news `news.article` |
| `workflow` | 상태·전이·역할(예: blog는 `in_review` 생략), `requiresHumanApproval`(기본 true, 끄려면 사람 결정 기록) |
| `guards` | local-news `compliance.is_profile_complete:kr_newspaper`, `news.election_guard` |
| `onPublished`, `onUnpublished` | 캐시 태그 무효화, 외부 발행(블로그 플랫폼) 잡 enqueue |
| `publicPath(entry)` | 미리보기·사이트맵 URL 생성 |

## 6. 테스트

AI 주체 게시 거부, 반려 메모 필수, 가드 실패 메시지, 예약 시각 과거 거부(`ED007`), 슬러그 중복(`ED006`), 이력 스냅샷 복원, 미리보기 토큰 만료, 조회 집계 봇 필터.

## 7. 자주 나는 문제

| 증상 | 원인·해결 |
|---|---|
| 예약 게시가 몇 분 늦음 | 잡 워커 지연. pg_cron 재조정이 동작하는지, `scheduled_at` 인덱스 확인 |
| 게시했는데 공개 페이지가 그대로 | `onPublished` 캐시 태그 이름이 제품 `cache/tags.ts`와 다름 |
