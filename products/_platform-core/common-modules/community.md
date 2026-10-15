# community: 댓글·방명록·신고·임시조치 (공용모듈 기획서)

작성일 2026-10-15. 상태: 제안. 패키지 `@nomad/community`, 스키마 `community`(0350~0399), 오류 코드 `CO###`. 출처: local-news M5의 댓글·신고·임시조치·금칙어(`docs/products/local-news/modules/M5_community.md`). 제보·투고 접수함은 support(0700), 경조사는 local-news 전용으로 남긴다. 개발서 `docs/develop/_shared/modules/community.md`.

## 1. 문제

기사 댓글(local-news), 모바일 청첩장 방명록(microweb-studio), 행사 Q&A 검수(live-poll), 회차 댓글(toon-factory), 질문 게시판(study-note)은 모두 "이용자가 쓴 글을 대상에 붙이고, 신고받고, 숨긴다". 국내 서비스는 권리침해 신고 시 임시조치(정보통신망법 제44조의2) 절차를 갖춰야 하고, 비회원 방명록은 스팸이 많다. 제품마다 만들면 신고 처리 기록과 임시조치 기한이 제각각이 된다.

## 2. 범위

| 구분 | 내용 |
|---|---|
| MVP | 대상별 스레드(대상 종류·id), 글·답글(1단), 작성자 3종(최종 이용자, 조직 멤버, 비회원 이름+비밀번호), 사전·사후 검수, 금칙어(가림·차단·검수 보냄), 신고, 임시조치(기한), 숨김·삭제, 레이트 리밋 + Cloudflare Turnstile, 운영 화면(검수 대기열) |
| 확장 | 공감·추천, 정렬(인기순), AI 유해성 점수(AI 게이트 경유, 판정은 사람), 멘션, 이미지 첨부(media), 실명 확인 연동 |
| 제품에 남김 | 선거 기간 댓글 정책(local-news, 가드 함수로 연결), 라이브 Q&A 실시간 전달(live-poll의 실시간 채널) |

## 3. 데이터 모델

| 표 | 주요 컬럼 | RLS·쓰기 |
|---|---|---|
| `community.threads` | `id`, `org_id`, `app_id`, `target_type`(예 `editorial.entry`, `microweb.site`, `poll.event`), `target_id`, `status`(`open`, `closed`, `hidden`), `policy`(jsonb: `who`=`anyone`/`end_users`/`members_only`/`disabled`, `moderation`=`pre`/`post`, `guest_allowed`, `max_length`) | 읽기: 공개 대상이면 anon. 쓰기: `community.ensure_thread`(service), `community.set_thread_policy`(org admin) |
| `community.posts` | `id`, `thread_id`, `parent_id`, `author_kind`(`end_user`, `member`, `guest`), `author_id`, `guest_name`, `guest_secret_hash`(argon2id), `body`, `status`(`pending`, `visible`, `hidden`, `temp_blocked`, `deleted`), `masked`(bool), `ip_hash`, `ua_hash`, `created_at`, `edited_at` | 읽기: `visible`만 공개 뷰. 본인 글은 상태와 무관하게 본인에게. 쓰기: `community.create_post`, `community.edit_post`, `community.delete_post`(본인·비밀번호 확인), `community.moderate`(org 멤버 역할) |
| `community.reports` | `post_id`, `reporter_kind`, `reporter_id`, `reason`(`spam`, `abuse`, `privacy`, `defamation`, `copyright`, `other`), `detail`, `status`(`received`, `accepted`, `rejected`), `handled_by` | 신고자 본인 생성, org 멤버 처리 |
| `community.temp_actions` | `post_id`, `requested_by`(신고 id 또는 외부 요청 메모), `reason`, `starts_at`, `ends_at`, `status`(`active`, `restored`, `deleted`), `author_objection`(재게시 요청 내용) | org 멤버. 기한 도래는 잡 |
| `community.banned_words` | `org_id`(null = 플랫폼 공통), `app_id`, `word`, `action`(`mask`, `block`, `review`) | org admin |
| `community.settings` | `org_id`, `app_id`, `enabled`, 기본 `policy`, `temp_action_days`(기본값은 법무 확인 후), `guest_daily_limit` | org admin |

오류 코드: `CO001` 스레드 닫힘·비활성, `CO002` 금칙어 차단, `CO003` 레이트 리밋, `CO004` 비회원 비밀번호 불일치, `CO005` 작성 자격 없음(정책), `CO006` 봇 검증 실패.

## 4. 흐름

| 상황 | 동작 |
|---|---|
| 작성 | Turnstile 검증(비회원·최종 이용자) → `core.rate_limit_hit` → 금칙어 검사(`mask`면 가려서 저장, `block`이면 `CO002`, `review`면 `pending`) → 정책이 `pre`면 `pending` |
| 신고 | 신고 누적 또는 권리침해 신고 → 검수 대기열 → 담당자가 임시조치 결정 → `temp_blocked` + `temp_actions` 행 |
| 임시조치 종료 | 기한 도래 잡 → 작성자 이의(재게시 요청)가 받아들여지면 `restored`, 아니면 담당자가 삭제. 기간·절차의 법정 기준은 법무 확인 후 `settings.temp_action_days`로 |
| 대상 비공개 | 대상(기사·사이트)이 비공개되면 스레드 `hidden`(이벤트 구독) |

## 5. 공개 API (TS 계약 예시)

```ts
// @nomad/community/server
ensureThread(input: { appId; orgId; targetType; targetId; policy?: Partial<ThreadPolicy> }): Promise<Thread>
createPost(input: { threadId; parentId?; author: Author; body; turnstileToken? }): Promise<Post>
report(input: { postId; reporter: Reporter; reason: ReportReason; detail? }): Promise<void>
moderate(postId: string, action: 'approve' | 'hide' | 'temp_block' | 'restore' | 'delete', note?: string): Promise<void>
// @nomad/community/ui
<CommentSection threadId /> <Guestbook threadId guest /> <ModerationQueue appId />
```

## 6. 이벤트

`community.post.created`, `.reported`, `.temp_blocked`, `.restored`, `.deleted`, `community.thread.closed`. 담당자 알림은 notify.

## 7. 개인정보·보안

| 항목 | 규칙 |
|---|---|
| 노출 | 작성자 표시는 닉네임 또는 이름 일부 가림. 이메일·전화번호는 본문에서 자동 가림(정규식) |
| IP | 해시만 저장(차단 판정용). 원문 IP 저장 금지 |
| 비회원 비밀번호 | argon2id 해시, 실패 5회 잠금 |
| 수사기관 요청 등 | 이 모듈 범위 밖. 운영 절차 문서로(제품 운영 SOP) |

## 8. 실패 동작

금칙어 사전 로드 실패 → 글을 `pending`으로(통과시키지 않음). Turnstile 서버 오류 → 비회원 작성만 잠시 막고 안내 문구, 로그인 이용자는 레이트 리밋만 적용.

## 9. local-news에서 옮기는 것

| local-news | 공용 | 남는 것 |
|---|---|---|
| `news.comments`, `news.comment_reports` | `community.posts`, `community.reports` | - |
| 임시조치 상태 `hidden`·기한 | `community.temp_actions` | - |
| `newspapers.banned_words`, `comments_enabled`(MQ-3) | `community.banned_words`, `community.settings` | - |
| `news.tips` | support(0700) | - |
| `news.life_events` | - | local-news 전용 |
| 선거 기간 댓글 정책 | 가드 함수 `news.election_comment_policy` | local-news |

## 10. 결정 필요

| ID | 결정 | 권고 |
|---|---|---|
| CO-D1 | 비회원 글 허용 기본값 | 방명록류만 허용, 댓글류는 로그인 필수 |
| CO-D2 | 임시조치 기본 기간 | 법무 확인 전 미정(설정값으로만) |
| CO-D3 | AI 유해성 점수 | 확장. 점수는 대기열 정렬에만 쓰고 자동 삭제하지 않음 |
