# M1 newsroom-cms 개발 지시서

작성일 2026-10-15. 기획 정본 `D:/WorkSpace/platform/docs/products/local-news/modules/M1_newsroom-cms.md`, 표 `D:/WorkSpace/platform/docs/products/local-news/05_DATA_MODEL.md`, RPC·라우트 `D:/WorkSpace/platform/docs/products/local-news/04_API.md`. 공통 규칙은 이 폴더 `README.md` 3장.

## 1. 만들 것

| 부분 | 내용 | 우선 |
|---|---|---|
| 개설·편집국 | 개설 신청(등록증 업로드) 화면과 운영자 승인 서버 처리, 편집국 초대·역할 | P0 |
| 기사 작성 | 블록 에디터(문단·소제목·사진·인용·표·YouTube·지도), 10초 자동 저장, 리비전 목록·복원, 메타(유형·섹션·지역·태그·바이라인) | P0 |
| 데스크 | 제출함·승인/반려, 엠바고, 예약 게시 잡, 편집 메모, 스토리 버짓 보드(섹션별 진행표) | P0 |
| 홈 편집 | 템플릿 3종(`traditional`·`magazine`·`feed`), 블록 순서·ON/OFF·톱 지정, 미리보기, 예약 게시 | P0 |
| 미디어 | 업로드, alt·출처 필수, 파생 이미지 생성(워커), 검색 | P0 |
| 확장 | 지면 PDF·지면보기, 속보 바·라이브 타임라인, 이관(`news.ingest`), 내보내기 | P1 |

## 2. 디렉토리·파일

모듈 모양은 이 폴더 `README.md` 3.1절, 경로·잡 이름 정본은 `D:/WorkSpace/platform/docs/products/local-news/02_ARCHITECTURE.md` 2·4절과 `D:/WorkSpace/platform/docs/products/local-news/04_API.md` 2절.

| 경로 | 책임 |
|---|---|
| `apps/web/src/modules/newsroom-cms/server/index.ts` | 공개 API(`NewsroomApi`, `getPublishedArticle`) |
| `.../schema.ts` | `Block` 유니온 zod, `ArticleDraftInput`, 상태·유형 열거(05장 CHECK 값과 같게) |
| `.../server/articles.ts` | 초안 저장(리비전 번호 비교), 상태 전이 RPC 호출, `NW00x` → `PublishBlockedError` 매핑 |
| `.../server/newspapers.ts` | 개설 신청(`news.request_newspaper`), 운영자 승인(service, `news.approve_newspaper`), 매체정보 저장(`news.set_newspaper_profile`) |
| `.../server/media.ts` | 서명 업로드 URL, MIME·크기 재검사, 파생 잡 enqueue |
| `.../server/home.ts` | 홈 레이아웃 저장·게시(`news.publish_home_layout`) |
| `.../components/editor/`, `.../components/render/` | 블록 에디터(클라이언트), 블록 렌더러(서버 컴포넌트, 독자 화면과 공유) |
| `.../cache.ts` | `news:<org>:article:<id>`, `news:<org>:home`, 분류 목록 태그 |
| `worker/src/handlers/news.publish/` | `news.publish_scheduled`(예약 게시), `news.post_publish`(무효화·속보 푸시 enqueue·발신 웹훅·AI 색인 enqueue) |
| `worker/src/handlers/news.ingest/` | `news.media_derive`(파생본 4종, EXIF 위치 제거), P1 `news.import_run`·`news.import_batch`·`news.media_fetch`·`news.export` |
| `apps/web/src/app/api/newsroom/articles/*`, `.../home-layouts/*`, `.../media/*` | 편집국 API(04장 2.2절) |
| `apps/web/src/app/(newsroom)/{articles,desk,home-editor,media,print,import}` | 편집국 화면 |
| `apps/web/src/app/(reader)/_t/[host]/news/[id]/[slug]` 등 | 기사 상세·섹션·지역·태그·기자 페이지(읽기 API만) |

## 3. 구현 순서

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | 마이그레이션 적용(`supabase db reset`), 시드 페르소나(publisher·editor·desk·reporter·contributor) | Studio에서 `news.articles` RLS 켜짐 |
| 2 | `schema.ts` 블록 스키마. 임베드는 허용 도메인(`www.youtube-nocookie.com`, 지도 제공자)만 | 허용 밖 URL 블록 저장 거부 단위 테스트 |
| 3 | 초안 저장 서버 함수: 리비전 번호 낙관적 잠금, 서버 sanitize, `body_text` 평문 추출 | 동시 저장 두 번 중 두 번째가 409 |
| 4 | 제출·승인·반려 RPC 연결, 편집 메모 | contributor가 남의 기사 접근 시 0행 |
| 5 | 게시 RPC 연결과 `PublishBlockedError` 사유별 UI(매체정보·엠바고·메타·전재 계약·라벨·선거·AI 검수. SQLSTATE 값은 05장 SQL 정본, `news.assert_publishable`) | 매체정보 미완성 신문사에서 게시 거부 |
| 6 | 예약 게시: `news.schedule_article` → 잡 `news.publish_scheduled`(`run_after = scheduled_for`) → 실행 시 게이트 재검사. pg_cron 1분 재enqueue 이중 안전장치 | 예약 시각 ±1분 반영 |
| 7 | 게시 직후 같은 요청에서 `revalidateTag`, 이어서 `news.post_publish` 잡(피드·속보 푸시·발신 웹훅·AI 색인) | 독자 화면이 게시 직후 갱신 |
| 8 | 미디어 업로드·`news.media_derive` 잡, alt·출처 필수 폼 | alt·출처 없는 미디어 저장 거부(NOT NULL) |
| 9 | 홈 편집: 템플릿 선택, 블록 드래그, 미리보기(서명된 미리보기 토큰), 예약 게시 | 게시본 1개만 `published` |
| 10 | 게시 후 수정: 리비전 + 공개 수정 시각·사유, `news.record_article_correction` | 상세 페이지 수정 표시 |
| 11 | (P1) 지면 PDF, 라이브 업데이트, 이관 잡, 내보내기 | 9장 기획 수용 기준 |

## 4. 외부 서비스 설정

| 서비스 | 할 일 | 링크 |
|---|---|---|
| Supabase Storage | 버킷 `public-assets`(게시 이미지), `org-files`(등록증·원본). 경로 `<org_id>/news/<entity>/<uuid>.<ext>` | https://supabase.com/docs/guides/storage |
| 이미지 변환 | Supabase 이미지 변환은 Pro 플랜 이상이고 원본 이미지 1,000개당 $5(포함량 초과분)라 사진이 많은 신문사에는 비용이 커진다. 업로드 때 워커가 파생본을 만들어 두는 방식을 기본으로 한다(제안) | https://supabase.com/docs/guides/storage/serving/image-transformations (2026-10-15 열람 확인) |
| YouTube 임베드 | 개인정보 보호 강화 도메인 `youtube-nocookie.com` 사용(제안) | 구현 시 YouTube 도움말로 확인(미확인) |
| 지도 임베드 | 카카오맵·네이버 지도 중 택1, 키·도메인 등록 필요(D-8과 함께) | 미확인(구현 시 각 개발자 센터 확인) |

## 5. 테스트

| 종류 | 항목 |
|---|---|
| 단위 | 블록 스키마, sanitize, 상태 전이 표(허용·거부 전부), 게이트 사유 매핑 |
| RLS | 역할 6종 × 상태 7종 SELECT·UPDATE 매트릭스, 다른 신문사 0행, anon은 `published`만 |
| E2E | 기자 작성 → 데스크 반려 → 수정 제출 → 승인 → 예약 → 자동 게시 → 독자 화면 확인 → 수정 표시 |
| 계약 | `news.article.published` payload zod 통과, `getPublishedArticle`가 엠바고 기사 null |

## 6. 운영 점검표

- [ ] 예약 게시 잡 지연 지표(예정 시각 대비 실제) 대시보드
- [ ] 실패 잡(`news.publish` failed) 알림이 편집인에게 도착
- [ ] 리비전 표 수정·삭제 시도가 거부되는지(append-only) 분기마다 확인
- [ ] 미디어 저장 용량이 플랜 `news_storage_gb`에 가까우면 경고
- [ ] 이관 후 리디렉션 맵 404 비율 점검(P1)

## 7. 자주 나는 문제

| 증상 | 원인 | 조치 |
|---|---|---|
| 게시했는데 홈에 안 보임 | 캐시 태그 무효화 누락 또는 홈 레이아웃이 기사를 고정 지정 | 태그 이름 상수 확인, 재조정 잡 실행 |
| 예약 시각에 게시 안 됨 | 잡 시점에 게이트 실패(매체정보·전재 계약 만료) | 잡 결과 사유 확인, 편집인 알림 수신 여부 |
| 사진이 흐리게 보임 | 파생본 생성 전 원본 축소본 사용 | 파생 잡 상태 확인, 실패 시 재실행 |
| 자동 저장 409 반복 | 두 탭에서 같은 기사 편집 | 다른 탭 닫기 안내, 차이 보기 |
| contributor가 승인 버튼을 봄 | UI만 숨기고 서버 검사 누락 | 서버 RPC 거부가 정본, UI 조건 수정 |
