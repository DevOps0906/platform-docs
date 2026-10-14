# M5 community: 댓글·제보·투고·경조사

작성일 2026-10-15. 표 정본 `docs/products/local-news/05_DATA_MODEL.md`, 법 근거 정본 `docs/products/local-news/01_PRD.md` 법 절.

## 1. 목적과 범위

지역 독자가 신문사에 말을 거는 통로를 모은다. 제보·투고는 지역 취재의 원천이고(P0), 경조사(부고·인사·동정·화촉)는 지역신문 고유 콘텐츠이며(P1), 댓글은 운영 부담이 커서 기본 꺼짐으로 둔다(D-6 권고).

| 구분 | 범위 | 기능 |
|---|---|---|
| MVP(P0) | 독자 제보·투고(첨부, 연락처, 동의) → 편집국 제보함(배정·상태·메모) | NW-F-025 |
| 확장(P1) | 댓글(로그인 독자, 1단 답글), 신고, 임시조치(정보통신망법 제44조의2), 금칙어, AI 모더레이션 보조, 기사별 on/off. 경조사 신청 → 편집국 검토 → 게시(유료 옵션) | NW-F-024, 026 |
| 하지 않음 | 비로그인 댓글, 실명 확인(게시판 본인확인제는 2012 위헌), 공감 수 랭킹 노출(조작 위험, 제안), 독자 간 쪽지 | - |

## 2. 벤치마크

| 제품 | 가져올 것 | 가져오지 않을 것 | 출처 URL |
|---|---|---|---|
| Coral(언론사용 오픈소스 댓글) | 사전 검토 모드(직원 제외), 금칙어(자동 거부)와 의심어(신고 대기열로), 대소문자 무시 목록, 독성 점수 임계값을 넘으면 작성자에게 먼저 경고하고 고칠 기회 → 그래도 넘으면 보류, 반려율 높은 작성자는 자동 보류, 대기열 4종(신고·보류·미검토·승인/반려) | Google Perspective API 직접 호출(국외 전송, 우리는 오픈소스 모델 강제) | https://docs.coralproject.net/administration , https://legacy.docs.coralproject.net/talk/toxic-comments (기본 임계값 0.8, 2026-10-15 열람 확인) |
| 한국 지역지 경조사 메뉴(한라일보 '궨당소식', 강원일보 인사·동정·부고·결혼, 옥천신문 축하·부음) | 4종 탭(부고·인사·동정·화촉), 홈 상단 노출 | 메뉴에만 숨기는 구성 | https://www.ihalla.com , https://www.kwnews.co.kr , http://www.okinews.com/ (조사 에이전트 2026-10-15 열람, 이 문서에서 재확인 안 함) |
| Newspack 리스팅 | 부고를 유료 리스팅 상품으로 운영 | - | https://newspack.com/advertising (2026-10-15 열람 확인) |
| 정보통신망법 임시조치 해설 | 권리침해 소명 요청 → 판단 어려우면 30일 이내 접근 차단, 신청인·게시자에게 즉시 통지. 2026-07-07 시행 개정으로 일정 규모 이상 사업자는 이의신청(6개월)·분쟁조정 절차(적용 대상 규모 미확인) | - | https://www.lawtalk.co.kr/posts/177280 (2차 출처, law.go.kr 원문 미확인) |

## 3. 소유·소비

| 구분 | 내용 |
|---|---|
| 소유 표 | `comments`, `comment_reports`, `tips`, `life_events` (금칙어·댓글 스위치 설정은 M1 `newspapers` 컬럼에 있음, 읽기·해석만 M5, MQ-3) |
| 소유 RPC | `news.list_comments`(공개), `news.post_comment`, `news.delete_my_comment`, `news.report_comment`, `news.moderate_comment`, `news.submit_tip`(service)·`news.set_tip_status`(DESK·배정 기자), `news.submit_life_event`(독자)·`news.review_life_event` — 이름은 05장 SQL 기준 |
| 쓰는 코어 | compliance(규칙 단계 금칙어 + LLM 판정 구조, `docs/products/_platform-core/SHARED_MODULES.md:355-376`), ai-gateway(`news.moderation`, 오픈소스 강제), storage(제보 첨부 `org-files`), rate_limit, audit, jobs |
| 쓰는 모듈 | M1(기사 댓글 허용 여부·게시 상태 읽기), M2(작성자 = `readers`, `ensureReader`), M7(선거 모드 댓글 정책) |
| 소비자 | 편집국 제보함·모더레이션 화면, 독자 화면 댓글·경조사 탭, M8(제보 수·댓글 수) |

## 4. 데이터 (요약, 상세 `docs/products/local-news/05_DATA_MODEL.md`)

| 표 | 핵심 컬럼(요약) |
|---|---|
| `comments` | 기사, 독자, 부모 댓글(1단), 본문, 상태(`visible`·`hidden`·`temp_blocked`·`deleted`), 상태 사유, 임시조치 종료 시각(`temp_blocked_until`), 신고 수, AI 판정 라벨(`ok`·`review`·`toxic`), 처리자·시각 |
| `comment_reports` | 댓글, 신고 독자, 사유(`defamation`·`privacy`·`obscene`·`hate`·`spam`·`other`), 상세, 권리침해 소명 여부(`is_rights_claim`), 상태(`open`·`actioned`·`dismissed`), 처리자·시각 |
| `tips` | 종류(`tip`·`contribution`), 독자 id(선택), 연락처(이름·이메일·전화), 익명 희망, 첨부 경로, 동의 시각, 상태, 담당 기자, 내부 메모, 보관 기한(`retention_until`) |
| `life_events` | 종류(`obituary`·`personnel`·`people`·`wedding`), 행사 일시, 신청 독자·전화, 동의 시각, 유료 여부·결제 시각, 상태, 게시 시각, 검토자·메모 |

## 5. 인터페이스

```ts
// src/modules/community/server/index.ts — 계약 예시(구현 파일 아님)
export type CommentStatus = 'visible' | 'hidden' | 'temp_blocked' | 'deleted'   // 정본 05장(04장 일부 표의 'held'는 hidden과 같은 뜻)
export interface CommunityApi {
  postComment(input: { orgId: string; articleId: string; body: string; parentId?: string; requestId: string }): Promise<{ commentId: string; status: CommentStatus }>  // 금칙어면 거부(NW010), 꺼진 댓글 NW009, 레이트 리밋 NW011. AI 판정은 잡 news.ai_moderation(비동기)
  report(input: { commentId: string; reason: 'defamation' | 'privacy' | 'obscene' | 'hate' | 'spam' | 'other'; isRightsClaim: boolean; detail?: string; claimantContact?: string }): Promise<void>
  moderate(commentId: string, action: 'show' | 'hide' | 'temp_block' | 'delete', reason?: string): Promise<void>  // desk 이상, temp_block은 30일 기한 기록
  submitTip(input: { orgId: string; kind: 'tip' | 'contribution'; title: string; body: string; attachmentPaths: string[]; contact: { name?: string; phone?: string; email?: string }; consentVersion: string; turnstileToken: string; requestId: string }): Promise<{ tipId: string; receiptCode: string }>
  submitLifeEvent(input: { orgId: string; kind: 'obituary' | 'personnel' | 'people' | 'wedding'; payload: Record<string, unknown>; paid: boolean; requestId: string }): Promise<{ lifeEventId: string; payment?: { orderId: string } }>
}
```

| 이벤트 | 발생 | 구독 |
|---|---|---|
| `news.comment.posted` | 작성(보류 포함) | 모더레이션 대기열 알림 |
| `news.comment.reported` | 신고 | 데스크 알림(권리침해 소명은 즉시 알림) |
| `news.comment.temp_blocked` | 임시조치 | 신청인·게시자 통지 메일 |
| `news.tip.received` | 제보 접수 | 편집국 알림(내용 미포함, 링크만) |
| `news.life_event.submitted` | 경조사 신청 | 편집국 알림 |
| 구독: `news.reader.withdrawn`(M2) | 그 독자 댓글 작성자 표시를 "탈퇴한 독자"로 | - |
| 구독: `news.election.started`(M7) | 정책에 따라 댓글 사전 검토 강제 등 | - |

## 6. 상태·규칙

| 표 | 전이 |
|---|---|
| `comments` | 작성 → `visible`(금칙어는 저장 전 거부), `visible` → `hidden`(신고 5건 자동·AI `toxic`·데스크), `visible` → `temp_blocked`(권리침해 주장 신고 즉시 30일) → `deleted` 또는 `visible`, 작성자·데스크 → `deleted` |
| `tips` | `new` → `reviewing` → `assigned` → `used`, 또는 `dismissed`·`spam` |
| `life_events` | `pending`(결제 포함 검토 대기) → `approved`(게시) → `archived`, 또는 `rejected`·`withdrawn` |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 댓글 기본 끔 | 신문사 설정 기본 꺼짐, 켜도 기사별로 끌 수 있다(M1 `articles` 컬럼) | D-6 |
| 금칙어 | 신문사 목록(`newspapers.banned_words`, MQ-3) + 플랫폼 공통 목록. 포함하면 `news.post_comment`가 저장 전에 거부(`NW010`, 05장 SQL 기준). 한글 경계는 `\b`를 쓰지 않는다 | Coral 관리 문서, `docs/products/_platform-core/SHARED_MODULES.md:360` |
| AI 판정 | 1차는 비동기: 잡 `news.ai_moderation`(오픈소스 강제 `news.moderation`)이 `moderation_label`을 기록하고 `toxic`이면 `hidden` + 검토 큐(`docs/products/local-news/02_ARCHITECTURE.md` 4절). 판정 오류는 `review`로 남기고 통과(`ok`)로 바꾸지 않는다. Coral식 "작성 전 경고 후 수정 기회"(임계값 0.8)는 확장 제안 | Coral 임계값, `docs/products/_platform-core/SHARED_MODULES.md:364` |
| 임시조치 | 권리침해 주장 신고(`rights_claim`)가 들어오면 `news.report_comment`가 즉시 `temp_blocked`(30일)로 바꾼다(05장 SQL). 서버가 신청인·게시자에게 즉시 통지 → 데스크가 기간 안에 `delete` 또는 `show` 결정. 만료 예정 건은 편집인에게 알림. 일반 신고는 5건 누적 시 자동 `hidden` | 정보통신망법 제44조의2(2차 출처) |
| 제보자 보호 | 연락처·첨부는 desk 이상과 배정 기자만, 기사화되어도 제보자 정보는 기사와 연결하지 않는다. 미사용 제보는 파기 예정일(제안 1년)에 파기 잡 | 제안 |
| 경조사 | 부고는 유족 확인 연락처 필수, 게시 전 편집국 확인. 유료 옵션 결제는 M2와 같은 신문사 Toss 경로 | 제안 |

모더레이션 대기열(Coral 대기열 구성을 우리 상태로 옮김, 제안):

| 대기열 | 조건 | 우선 |
|---|---|---|
| 권리침해 신고 | `comment_reports.is_rights_claim` 이고 `open`(댓글은 이미 `temp_blocked`) | 1(삭제·복원 결정, 통지 의무) |
| 신고됨 | `report_count > 0` 이고 `visible` | 2 |
| 숨김 | `hidden`(신고 5건·AI `toxic`·데스크) | 3 |
| AI 검토 필요 | `moderation_label='review'`(판정 오류 포함) | 4 |
| 임시조치 만료 예정 | `temp_blocked_until`이 3일 안 | 별도 알림 |

## 7. 실패 동작

| 상황 | 동작 |
|---|---|
| AI 모더레이션 장애 | 규칙 단계(금칙어 거부)는 DB에서 그대로 동작, AI 라벨은 `review`로 남겨 검토 큐에 올린다. `ok`로 바꾸지 않는다 |
| 첨부 업로드 실패·MIME 위반 | 제보 본문은 저장하고 첨부 실패 목록을 보여 줌(재시도 가능) |
| 통지 메일 실패 | 임시조치 상태는 유지, 통지 잡 재시도, 실패 시 편집국 화면에 "통지 미완료" 표시 |
| 레이트 리밋 초과 | 429 + 다시 시도 시각 |

## 8. 보안·개인정보

| 항목 | 규칙 |
|---|---|
| 작성자 노출 | 댓글 표시 이름만, 이메일·IP 비노출. IP는 일 솔트 해시만 |
| 제보 열람 | 열람 자체를 감사 로그에 남긴다(누가 언제 열었나) |
| 연락처 | 제보 연락처는 앱 계층 암호화(제안, `docs/products/_platform-core/SECURITY_BASELINE.md:193` 방식) |
| AI 처리 | 제보 원문·댓글은 오픈소스 강제 경로만(국외 제공자로 대체 금지, `docs/products/_platform-core/SECURITY_BASELINE.md:279-300`) |
| 스팸 | 제보·경조사 폼 Turnstile + 허니팟 + IP 해시 레이트 리밋 |

## 9. 수용 기준

| 기능 | 기준 |
|---|---|
| NW-F-025 | 비로그인 제보 가능, 접수 번호 표시, reporter 역할(미배정)은 연락처 열람 불가, 파기일 지난 제보 0건 |
| NW-F-026 | 댓글 꺼진 기사에 작성 시도 거부(`NW009`), 금칙어 댓글 저장 0(`NW010`), 권리침해 신고 즉시 `temp_blocked` → 통지 기록 → 30일 만료 알림, 일반 신고 5건이면 `hidden` |
| NW-F-024 | 경조사 4종 신청 → 검토 → 게시, 유료 옵션 결제 실패 시 신청은 `submitted`에 남음 |

## 10. 추출 조건

공용 `support`(0700, `docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:204`)가 착수되면 제보·투고 접수함을 티켓으로 옮긴다. 댓글 임시조치는 다른 제품이 공개 댓글을 열 때 같은 규칙으로 꺼낼지 결정한다(후보 미확인). 경조사는 뉴스 전용으로 남긴다.
