# M1 newsroom-cms: 뉴스룸 CMS

작성일 2026-10-15. 소유 표 정본은 `docs/products/local-news/05_DATA_MODEL.md`, RPC·라우트 정본은 `docs/products/local-news/04_API.md`. 이 문서는 모듈 경계·규칙·계약을 적는다. 색인과 경계 규칙은 `README.md`.

## 1. 목적과 범위

신문사 1곳(= `core.organizations` 1행)의 편집국이 기사를 쓰고, 데스크가 승인하고, 예약·즉시 게시하고, 홈 화면을 편집하는 흐름의 정본 모듈이다. 다른 모듈은 기사를 읽기만 한다.

| 구분 | 범위 | 기능 |
|---|---|---|
| MVP(P0) | 신문사 개설 신청·승인, 편집국 초대·역할, 블록 에디터(문단·소제목·사진+캡션+출처·인용·표·YouTube·지도 임베드), 자동 저장·버전, 기사 메타(유형·섹션·지역·태그·바이라인), 데스크 워크플로·엠바고·예약, 홈 편집(템플릿 3종·블록 순서·톱 지정·예약·미리보기), 미디어 라이브러리(alt·출처 필수), 수정 표시 | NW-F-001, 004, 010~014, 017 |
| 확장(P1) | 지면 PDF 보관·지면보기, 속보 바·라이브 기사, 기존 CMS 이관(RSS·CSV·XML·사이트맵), 해지·내보내기 | NW-F-015, 016, 063, 064 |
| 하지 않음 | 코어 조직·멤버 함수 재구현, 이미지 생성 AI(제품 AI 기능은 `docs/products/local-news/02_ARCHITECTURE.md` 소관), 분산조판(언론재단 통합CMS 영역) | - |

## 2. 벤치마크

| 제품 | 가져올 것 | 가져오지 않을 것 | 출처 URL |
|---|---|---|---|
| WordPress 기본 글 상태(Newspack 기반) | `draft`/`pending`(편집자 검토 대기)/`future`(예약)/`publish`의 단순한 상태 집합, 자동 저장 리비전 | `private`, `trash`를 상태로 쓰는 방식(우리는 `archived` + 권한) | https://wordpress.org/documentation/article/post-status/ (2026-10-15 열람 확인) |
| Edit Flow(WordPress 편집 워크플로 플러그인) | 사용자 정의 상태(Pitch·Assigned 등은 확장), 편집 메모(기사별 내부 댓글), 상태 변경 알림, 주간 캘린더, 스토리 버짓(섹션별 진행표) | 플러그인 구조, 사용자 그룹 구독 | https://cdn.jsdelivr.net/wp/plugins/edit-flow/tags/0.6.4/readme.txt (2026-10-15 열람 확인) |
| Arc XP Composer·WebSked | 워크플로 상태를 조직이 설정하는 구조, 기획(피치)·과제 관리와 작성기를 분리 | 대형 언론용 다중 플랫폼 배포, 연 $5만 이상 가격대 | https://docs.arcxp.com/en/products/websked/configuring-websked-settings/configuring-websked-workflow-statuses.html (메뉴 구조만 확인, 본문 미확인) |
| Ghost 에디터 | 카드형 블록, 게시물 편집 이력(저장·수정 시점마다 기록, 이전 버전 복원) | 개인 발행인 중심 정보 구조(섹션·지역 없음) | https://ghost.org/changelog/editor-beta/ (2026-10-15 열람 확인) |
| 엔디소프트(국내 임대형 CMS) | 한국형 홈 구성(헤드 5 + 그리드 + 인기기사), 지면보기 메뉴 | 벤더 로고 강제, 팝업 | https://www.ndsoft.co.kr (조사 에이전트 2026-10-15 열람, 이 문서에서 재확인 안 함) |

결론: 상태는 WordPress처럼 적게, 데스크 기능(편집 메모·버짓 보드·알림)은 Edit Flow처럼, 상태 이름은 고정하되 표시 이름만 신문사가 바꾸게 한다(Arc XP처럼 상태 자체를 늘리는 것은 확장).

## 3. 소유·소비

| 구분 | 내용 |
|---|---|
| 소유 표 | `newspaper_applications`(개설 신청, 05장 SQL에서 추가), `newspapers`, `staff`, `sections`, `regions`, `tags`, `articles`, `article_revisions`, `article_regions`, `article_tags`, `media_assets`, `home_layouts`, `print_editions`, `live_updates` |
| 소유 RPC | `news.request_newspaper`, `news.withdraw_newspaper_request`, `news.approve_newspaper`·`news.reject_newspaper`(service), `news.save_article`, `news.save_media_asset`, `news.save_home_layout`, `news.add_live_update`, `news.read_article`(공개), `news.assert_publishable`(게이트, M7·M6 판정 호출), `news.run_scheduled_publishing`(pg_cron), `news.set_newspaper_profile`, `news.invite_staff`, `news.accept_staff_invite`, `news.set_staff_role`, `news.submit_article`, `news.review_article`, `news.publish_article`, `news.schedule_article`, `news.unpublish_article`, `news.record_article_correction`, `news.publish_home_layout` |
| 쓰는 코어 | org(초대·역할 연동), entitlements(체험 30일), storage(`org-files`, `public-assets`), jobs(큐 `news.publish`: `news.publish_scheduled`·`news.post_publish`, 큐 `news.ingest`: `news.import_*`·`news.media_derive`·`news.export`), audit, ai-gateway(`news.draft`, `news.headline` 등은 AI 기능이 호출) |
| 쓰는 모듈 | M7 `news.is_profile_complete`·라벨·선거 엠바고 판정, M6 wire 계약 판정(모두 DB 함수, 게시 RPC 안에서) |
| 소비자 | M4(브리핑·속보), M5(댓글 대상), M6(배포), M7(통계·정정), M8(검색·조회), 독자 화면(NW-F-020, 021) |

`newspapers`의 필요적 게재사항 컬럼 쓰기는 M1 RPC(`set_newspaper_profile`)가 하고, "완성인가" 판정은 M7 함수가 한다(규칙 소유자와 표 소유자를 나눔).

## 4. 데이터 (요약, 상세는 `docs/products/local-news/05_DATA_MODEL.md`)

| 표 | 핵심 컬럼(요약) | 비고 |
|---|---|---|
| `newspaper_applications` | 신청자, 희망 slug, 제호, 매체 종류, 등록번호·등록일, 발행인, 연락처, 등록증 경로, 상태(`pending`·`approved`·`rejected`·`withdrawn`), 결정 메모 | 승인·반려는 service_role(운영자 서버)만. 등록증은 비공개 버킷 |
| `newspapers` | `org_id`, 상태(`active`·`suspended`·`closed`), 제호, 매체 종류, 등록번호·등록일, 발행인·편집인·청소년보호책임자·개인정보보호책임자 성명, 발행소 주소·전화, 최초 발행일, 윤리강령 URL, `profile_completed_at`(트리거 계산), 댓글 스위치·금칙어(M5 설정, MQ-3) | 조직 1:1. 완성 시각이 null이면 독자 사이트 비공개 |
| `staff` | `org_id`, `user_id`, `role`(publisher·editor·desk·reporter·contributor·ad_manager), 바이라인 이름, 상태 | 코어 `org_members`와 매핑(`publisher`=owner) |
| `sections`, `regions`, `tags` | 슬러그, 이름, 정렬, 활성. `regions`는 시·군·읍면 계층(부모 id) | 지역 칩 탭·지역 페이지 |
| `articles` | 제목·부제·요약, 본문 블록 JSON(`body`), 검색용 평문(`body_text`), `type`(original·wire·press_release·contribution·sponsored), `origin`(human·ai_press_release·import), `status`, 섹션, 대표 이미지, 바이라인, `embargo_until`, `scheduled_for`, `published_at`·`first_published_at`, 공개 수정 시각·사유(`revised_at`·`revision_note`), `is_premium`(M2가 읽음), `comments_enabled`(M5가 읽음), `ai_assisted`·`ai_disclosure`·`sponsor_label`·`is_poll`·`poll_disclosure`(M7 규칙), `wire_contract_id`(M6), `is_breaking`·`is_live`, SEO JSON, 이관 원본(`legacy_id`·`legacy_url`), `search_tsv` | `search_tsv` 컬럼은 이 표에 두고 인덱스·검색 함수는 M8. 라벨·AI·여론조사 표시는 CHECK 제약으로도 강제 |
| `article_revisions` | 기사 id, 종류(save·submit·approve·reject·schedule·publish·unpublish·archive·update·correction·clarification·rebuttal·follow_up), 전이 후 상태, 제목·본문 스냅샷, 메모, 공개 여부, 정정 청구 id | 수정·삭제 불가(append-only). 공개 행은 메모 필수 |
| `media_assets` | 버킷·경로, 종류(image·video·audio·document), MIME, 크기, alt(필수), 캡션, 출처 `credit`(필수)·저작권자, 라이선스, AI 생성 여부·표시 문구, 최초 공개 시각 | alt·출처는 NOT NULL 제약 |
| `home_layouts` | 이름, 템플릿(`traditional`=A·`magazine`=B·`feed`=C), 블록 배열(종류·순서·ON/OFF·지정 기사), 상태(draft·scheduled·published·archived), 게시 예정 시각, 버전 | 게시본은 1개만 `published` |
| `print_editions` | 발행일, 호수, PDF 경로, 면 수 | P1 |
| `live_updates` | 기사 id, 본문, 게시 시각, 작성자, 고정 여부 | P1 |

## 5. 인터페이스

```ts
// src/modules/newsroom-cms/server/index.ts — 계약 예시(구현 파일 아님)
export type ArticleType = 'original' | 'wire' | 'press_release' | 'contribution' | 'sponsored'   // 컬럼 articles.type
export type ArticleStatus = 'draft' | 'submitted' | 'approved' | 'scheduled' | 'published' | 'unpublished' | 'archived'
export type StaffRole = 'publisher' | 'editor' | 'desk' | 'reporter' | 'contributor' | 'ad_manager'

export interface ArticleDraftInput {
  title: string; subtitle?: string; summary?: string; body: Block[]; type: ArticleType
  sectionId: string; regionIds: string[]; tagIds: string[]; byline: string
  heroMediaId?: string; wireContractId?: string; sponsorLabel?: string; isPremium?: boolean; isPoll?: boolean; pollDisclosure?: string
  aiAssisted?: boolean; aiDisclosure?: string; isBreaking?: boolean; commentsEnabled?: boolean
}
export interface NewsroomApi {
  saveDraft(orgId: string, articleId: string | null, input: ArticleDraftInput, requestId: string): Promise<{ articleId: string; revision: number }>
  submit(articleId: string): Promise<void>                                            // rpc news.submit_article
  review(articleId: string, decision: 'approve' | 'reject', note?: string): Promise<void> // rpc news.review_article
  publish(articleId: string): Promise<{ publishedAt: string }>                         // rpc news.publish_article (M7·M6 게이트 포함)
  schedule(articleId: string, at: Date): Promise<void>                                 // rpc news.schedule_article → 잡 news.publish_scheduled(큐 news.publish)
  unpublish(articleId: string, reason: string): Promise<void>
  recordCorrection(articleId: string, input: { note: string; correctionRequestId?: string }): Promise<{ revision: number }>
  publishHomeLayout(orgId: string, layoutId: string, at?: Date): Promise<void>
  // 독자 화면용 읽기(공개, 캐시 태그 news:<org>:article:<id>)
  getPublishedArticle(orgId: string, slug: string): Promise<PublishedArticle | null>   // rpc news.read_article(anon): 게시·엠바고·전재 계약 판정, 프리미엄이면 잠금 표시
}
// 게시 거부: news.assert_publishable 이 SQLSTATE로 알린다(정본 05장 SQL).
// NW002 신문사 비활성, NW003 필요적 게재사항 미완성, NW004 상태·엠바고, NW005 전재 계약, NW006 사람 승인 없음, NW007 선거 공표 금지, 23514 라벨·AI 표시 CHECK
export type PublishBlockReason = 'newspaper_inactive' | 'profile_incomplete' | 'invalid_state' | 'wire_contract_inactive' | 'human_approval_missing' | 'election_embargo' | 'disclosure_missing'
export class PublishBlockedError extends Error { constructor(public reason: PublishBlockReason, public sqlstate: string) { super('publish_blocked') } }
```

| 이벤트 | 발생 | payload(요약) | 구독 |
|---|---|---|---|
| `news.article.submitted` | 제출 | orgId, articleId, by | 데스크 알림 |
| `news.article.approved` / `.rejected` | 데스크 판정 | articleId, note | 작성자 알림 |
| `news.article.published` | 즉시·예약 게시 | articleId, type, sectionId, isBreaking | 잡 `news.post_publish`: M6 피드 캐시, M4 속보 푸시, 발신 웹훅, AI 색인 |
| `news.article.updated` | 게시 후 수정 | articleId, revision, publicNote | M6 캐시·`dateModified` |
| `news.article.unpublished` | 내림 | articleId, reason | M6(사이트맵 제거), M4(예약 발송에서 제외) |
| `news.article.corrected` | 정정 기록 | articleId, correctionRequestId | M7 청구 상태 갱신 |
| `news.home.published` | 홈 게시 | layoutId | 캐시 `news:<org>:home` |

## 6. 상태·규칙

| 현재 | 허용 전이 | 누가 | 조건 |
|---|---|---|---|
| `draft` | `submitted` | 작성자(reporter, contributor는 자기 기사만) | 필수 메타(섹션·유형·바이라인·사진 alt·출처) |
| `submitted` | `approved`, `draft`(반려, 사유 필수) | desk 이상 | - |
| `approved` | `scheduled`, `published`, `draft` | desk 이상(게시는 editor 이상, 제안) | 게시 게이트 통과 |
| `scheduled` | `published`(잡), `approved`(취소) | 잡 `news.publish_scheduled`(service), editor 이상 | 실행 시점에 게이트 재검사 |
| `published` | `published`(수정 = 새 리비전), `unpublished` | desk 이상(수정), editor 이상(내림) | 수정 시 공개 수정 시각·사유 |
| `unpublished` | `draft`, `archived` | editor 이상 | - |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 게시 게이트 | 매체정보 완성(M7), 유형 라벨(sponsored는 광고 라벨, M7), 선거 엠바고(M7), 전재 계약 유효(M6), 대표·본문 이미지 출처 기재, `embargo_until` 경과. 하나라도 실패면 `PublishBlockedError` | 신문법 제21조, 제6조 제3항(`docs/products/local-news/01_PRD.md` 법 절) |
| 반려 표현 | 반려는 `draft`로 되돌리고 리비전 종류 `reject`와 사유로 남긴다(05장 SQL에 `rejected` 상태 없음. 04장 일부 표의 `rejected` 상태 표기와 맞춰야 함) | 05장 SQL |
| 1~3인 신문사 | 신문사 설정으로 "기자 직접 게시"를 켤 수 있다(기본 끔, 제안). 켜도 게이트는 같다 | 인터넷신문 평균 기자 4명(https://www.journalist.or.kr/news/article.html?no=57578) |
| 수정 표시 | 게시 후 본문·제목 변경은 리비전을 남기고 공개 "수정 시각"을 갱신. 사실관계 변경이면 공개 사유 필수(NW-F-017) | Trust Project "Actionable Feedback"(https://thetrustproject.org/trust-indicators/) |
| 보도자료 유형 | AI 초안(NW-F-050)으로 만든 기사는 `press_release`를 유지하고 사람 승인 전 게시 불가 | 언론계 생성형 AI 준칙(https://www.journalist.or.kr/news/article.html?no=57255) |
| 홈 편집 | 그리드 비율·광고 슬롯 크기는 고정, 블록 순서·ON/OFF만 바꾼다(CLS 보호) | `docs/products/local-news/03_SCREENS_UX.md` 템플릿 절 |

## 7. 실패 동작

| 상황 | 동작 |
|---|---|
| 게시 게이트 실패 | RPC가 오류 코드(정본 `04_API.md`)로 거부, 화면에 사유별 수정 링크. 부분 게시 없음 |
| 예약 게시 잡 실패 | `news.publish_scheduled` 3회 재시도 + pg_cron 1분 재enqueue(02장 4절) → 그래도 실패면 기사는 `scheduled`에 남고 데스크·편집인에게 알림. 조용히 넘어가지 않는다 |
| 캐시 무효화 실패 | 게시는 성공으로 두고 무효화 잡을 재시도. 주기 재조정 잡이 최근 게시 기사 태그를 다시 무효화 |
| 자동 저장 충돌(두 사람 동시 편집) | 리비전 번호 비교로 뒤 저장을 거부하고 차이를 보여 준다(잠금은 확장) |
| 이관 잡(`news.import_run`·`news.import_batch`) 일부 실패 | 성공 건만 `draft`로 넣고 실패 목록(원 URL, 사유) 리포트. 자동 게시하지 않는다 |
| 이미지 업로드 MIME·크기 위반 | 서버 재검사로 거부(`docs/products/_platform-core/SECURITY_BASELINE.md:168-178`) |

## 8. 보안·개인정보

| 항목 | 규칙 |
|---|---|
| 권한 | `is_org_member` + `news.staff.role`. contributor는 자기 초안만 SELECT·UPDATE. 상태 컬럼은 RPC로만 변경 |
| 본문 sanitize | 블록 JSON을 서버에서 검증(zod), 임베드는 허용 목록(YouTube nocookie, 지도 제공자)만, 임의 HTML 블록 없음 |
| 이관 SSRF | 원 사이트 크롤·RSS 가져오기는 사설 IP 차단·리다이렉트 제한(`docs/products/_platform-core/SECURITY_BASELINE.md:172`) |
| 등록증 | 비공개 버킷, 운영자·발행인만 서명 URL |
| 감사 | 게시·내림·정정·역할 변경·홈 게시는 `audit_log` |
| 공개 읽기 | 방문자는 `published` 행만(anon SELECT 정책), 엠바고·예약 기사는 보이지 않는다 |

## 9. 수용 기준

| 기능 | 기준 |
|---|---|
| NW-F-001 | 등록증 업로드 → 운영자 승인 → 조직·owner·`staff(publisher)`·체험 엔타이틀먼트가 한 트랜잭션. 반려 시 사유 메일 |
| NW-F-004 | 초대 수락 전에는 콘솔 접근 불가, 역할 변경은 publisher·editor만, 자기 역할 변경 불가(`42501`) |
| NW-F-010 | 자동 저장 간격(제안 10초) 안 손실 0, 리비전 목록에서 복원 가능 |
| NW-F-011, 012 | contributor가 남의 초안을 읽으면 0행, 반려 사유 없으면 거부, 엠바고 전 게시 시도는 거부 |
| NW-F-013 | 예약 게시 시각 ±1분 안에 홈 반영(캐시 무효화 포함) |
| NW-F-014 | alt·출처 없는 미디어는 저장 자체가 거부(NOT NULL), 이관 이미지도 같은 규칙 |
| NW-F-017 | 게시 후 수정 시 상세 페이지에 수정 시각·사유 노출, 리비전 수정·삭제 불가 |
| NW-F-063, 064(P1) | 이관 리포트에 성공·실패 건수, 리디렉션 맵 CSV. 내보내기는 기사·미디어 목록 JSON·CSV |

## 10. 추출 조건

뉴스 워크플로는 추출하지 않는다. 블록 에디터와 블록 렌더러만 두 번째 제품이 쓸 때 `cms`(0800)로 꺼낸다(`README.md` 5장). 그때까지 블록 스키마(`Block` 타입)는 뉴스 전용 블록(바이라인·라이브 등)을 넣지 않고 범용 블록만 담는다.
