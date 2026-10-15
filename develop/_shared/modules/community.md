# community 개발 지시서 (`@nomad/community`)

기획 정본: `products/_platform-core/common-modules/community.md`. 공통 규칙·적용 절차: [`README.md`](README.md).

## 1. 만들 것 (v1.0)

대상별 스레드와 정책, 글·답글(1단), 작성자 3종(최종 이용자·조직 멤버·비회원 이름+비밀번호), 금칙어(가림·차단·검수), 사전·사후 검수, 신고, 임시조치와 기한 잡, Turnstile + 레이트 리밋, 댓글·방명록 컴포넌트, 검수 대기열 화면.

## 2. 파일

| 경로 | 책임 |
|---|---|
| `sql/0350_community.sql` | 표 6개, RPC(`ensure_thread`, `create_post`, `edit_post`, `delete_post`, `report`, `moderate`), 공개 뷰 `visible_posts` |
| `src/server/posts.ts`, `moderation.ts`, `guest.ts`(argon2id), `filters.ts`(금칙어·연락처 가림) | 공개 API |
| `worker/handlers/community/temp-action-expiry.ts` | 임시조치 기한 처리 |
| `src/ui/CommentSection.tsx`, `Guestbook.tsx`, `ReportDialog.tsx`, `ModerationQueue.tsx` | 화면 |

## 3. 구현 순서

| 순서 | 작업 | 확인 |
|---|---|---|
| 1 | SQL, 공개 뷰는 `visible`만, 본인 글은 본인에게 | anon이 `pending`·`hidden` 0행 |
| 2 | 작성 경로: Turnstile 서버 검증 → `core.rate_limit_hit` → 금칙어 → 정책 | 봇 토큰 없으면 `CO006` |
| 3 | 비회원 비밀번호: argon2id, 실패 5회 잠금 | 무차별 대입 차단 |
| 4 | 신고 → 대기열 → 임시조치(`temp_actions`) → 기한 잡 | 기한 도래 시 담당자 알림 |
| 5 | 대상 비공개 이벤트 구독 → 스레드 `hidden` | 비공개 기사 댓글 노출 0 |
| 6 | UI: 서버 렌더 + 작성 폼만 클라이언트, 페이지당 20개, 더보기 | 접근성 위반 0 |

## 4. 외부 서비스·공식 문서

| 주제 | 링크 |
|---|---|
| Cloudflare Turnstile | https://developers.cloudflare.com/turnstile/ |
| 비밀번호 해시(OWASP) | https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html |
| 정보통신망법 제44조의2(임시조치) | https://www.law.go.kr |

임시조치 기간·이의 절차는 법무 확인 후 `community.settings.temp_action_days`로만 설정합니다.

## 5. 제품 주입 값

`targetTypes`(예 microweb `microweb.site`, local-news `editorial.entry`), 기본 `policy`(방명록: `guest_allowed: true`, `moderation: 'post'` / 댓글: 로그인 필수), 대상 공개 여부 확인 함수 `isTargetPublic(type, id)`, 추가 가드(local-news 선거 댓글 정책).

## 6. 테스트

정책별 작성 자격(`CO005`), 금칙어 3동작, 연락처 자동 가림, 신고 중복 1회만, 임시조치 복원·삭제, 교차 org 신고 처리 불가, 레이트 리밋(`CO003`).

## 7. 자주 나는 문제

| 증상 | 원인·해결 |
|---|---|
| ISR 페이지에 새 댓글이 늦게 보임 | 댓글 목록은 페이지 캐시와 분리(클라이언트 조회 또는 짧은 캐시 태그) |
| 금칙어가 띄어쓰기로 우회됨 | 비교 전 공백·특수문자 제거 정규화, 원문은 그대로 저장 |
