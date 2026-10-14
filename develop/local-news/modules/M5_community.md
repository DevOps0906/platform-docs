# M5 community 개발 지시서

작성일 2026-10-15. 기획 정본 `D:/WorkSpace/platform/docs/products/local-news/modules/M5_community.md`, 표 `D:/WorkSpace/platform/docs/products/local-news/05_DATA_MODEL.md`. 금칙어·LLM 판정 구조는 코어 compliance(`docs/file/03-설계/공용코어/SHARED_MODULES.md` 13장), AI 보안은 `docs/file/03-설계/공용코어/SECURITY_BASELINE.md` 16장.

## 1. 만들 것

| 부분 | 내용 | 우선 |
|---|---|---|
| 제보·투고 | 공개 폼(첨부·연락처·익명 희망·동의), 접수 번호, 편집국 제보함(배정·상태·내부 메모), 보관 기한 파기 잡 | P0 |
| 댓글 | 기사별 댓글(로그인 독자, 1단 답글), 금칙어 거부, AI 독성 판정(비동기 라벨), 신고 5건 자동 숨김 | P1 |
| 신고·임시조치 | 신고(사유·권리침해 주장), 권리침해 주장은 즉시 임시조치 30일(DB), 모더레이션 대기열, 통지·만료 알림 | P1 |
| 경조사 | 부고·인사·동정·화촉 신청 폼, 검토·게시, 유료 옵션 결제, 홈 4종 탭 블록 | P1 |

## 2. 디렉토리·파일

모듈 모양은 이 폴더 `README.md` 3.1절, 경로·잡 이름 정본은 `D:/WorkSpace/platform/docs/products/local-news/02_ARCHITECTURE.md` 2·4절과 `D:/WorkSpace/platform/docs/products/local-news/04_API.md` 2절.

| 경로 | 책임 |
|---|---|
| `apps/web/src/modules/community/server/index.ts` | `CommunityApi` |
| `.../server/tips.ts` | Turnstile 검증 → 첨부 서명 업로드(`/api/r/tips/uploads`, 10분, 10MB) → `news.submit_tip`(service). 연락처 앱 계층 암호화(제안) |
| `.../server/comments.ts` | `news.post_comment`(댓글 스위치·금칙어·레이트 리밋은 DB가 판정: `NW009`·`NW010`·`NW011`) → `news.ai_moderation` 잡 enqueue. 공개 목록은 `news.list_comments`(anon) |
| `.../server/moderation.ts` | 대기열 조회, `news.moderate_comment`(show·hide·temp_block·delete), `news.report_comment` 결과가 `temp_blocked`면 신청인·게시자 통지 메일 enqueue |
| `.../server/life-events.ts` | `news.submit_life_event`(service, 추가 제안), 유료 옵션 결제는 M2 `server/toss.ts` 재사용 |
| `.../components/` | 댓글 스레드, 신고 대화상자, 제보·경조사 폼, 4종 탭 블록, 편집국 대기열·제보함 |
| `apps/api` 쪽 `news.ai_moderation` 처리 | FastAPI(오픈소스 강제 `news.moderation`)가 `moderation_label` 기록(02장 4절) |
| 주기 작업 | 임시조치 만료 예정 알림, 제보 `retention_until` 파기(위치는 06장 작업에서 정함, 제안: `news.stats` 큐 일 1회) |
| `apps/web/src/app/api/r/{tips,life-events}`, `.../api/r/comments/*` | 독자 API(04장 2.1절) |
| `apps/web/src/app/api/newsroom/{comments,tips,life-events}/*` | 편집국 API |

## 3. 구현 순서

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | 제보 폼(비로그인 가능): Turnstile + 허니팟 + IP 해시 레이트 리밋, 첨부는 `org-files`(서명 업로드, MIME·크기 재검사) | 접수 번호 표시, 제보 알림에 본문 미포함 |
| 2 | 제보함: 상태 전이, 배정, 내부 메모, 열람 감사 | 미배정 reporter 연락처 열람 불가 |
| 3 | 파기 잡: 보관 기한 지난 제보 행·첨부 삭제 | 시드로 만료 건 0 |
| 4 | (P1) 댓글 스위치: `newspapers.comments_enabled`(기본 꺼짐) AND `articles.comments_enabled` | 꺼진 기사 작성 거부 |
| 5 | 금칙어(신문사 `newspapers.banned_words` + 플랫폼 공통 목록): DB가 거부(`NW010`), 화면은 거부 사유 안내. 한글 경계 처리(`\b` 금지) 테스트 | 금칙어 댓글 저장 0 |
| 6 | AI 판정: `news.ai_moderation` 잡이 `moderation_label` 기록, `toxic`이면 `hidden` + 대기열. 판정 오류는 `review`로 남김(`ok`로 바꾸지 않음). Coral식 작성 전 경고는 확장 | 장애 주입 시 `ok` 0 |
| 7 | 신고(권리침해 주장 → 즉시 `temp_blocked` 30일, 일반 5건 → `hidden`)·대기열·통지 | 통지 실패 시 "통지 미완료" 표시 |
| 8 | 선거 모드 구독: `news.election.started`면 정책(`comment_policy`)대로 댓글 중지 | 기간 중 작성 거부 |
| 9 | 경조사: 신청 → (결제) → 검토 → 게시, 4종 탭 블록 | 결제 실패 시 신청 유지 |

## 4. 외부 서비스 설정

| 서비스 | 할 일 | 링크 |
|---|---|---|
| Cloudflare Turnstile | 사이트 키·시크릿 발급, 신문사 도메인(서브도메인 와일드카드·커스텀 도메인) 등록 방식 확인(위젯 도메인 상한 미확인) | https://developers.cloudflare.com/turnstile/ (구현 시 확인) |
| AI 모더레이션 | 공용 ai-gateway feature `news.moderation`을 오픈소스 강제로 라우팅. 상용 독성 API(예: Coral이 쓰는 Google Perspective)는 댓글 원문이 국외로 나가므로 쓰지 않음 | https://legacy.docs.coralproject.net/talk/toxic-comments (비교용, 2026-10-15 열람 확인) |
| 모더레이션 운영 참고 | 대기열 구성, 사전 검토, 반려율 기반 자동 보류 | https://docs.coralproject.net/administration (2026-10-15 열람 확인) |
| 법령 원문 | 정보통신망법 제44조의2(임시조치), 2026-07-07 시행 개정(이의신청) 적용 대상 규모 | https://www.law.go.kr (이 도구로 접근 불가, 미확인) |

## 5. 테스트

| 종류 | 항목 |
|---|---|
| 단위 | 금칙어 매칭(한글 어절·띄어쓰기 변형, SQL 함수와 같은 케이스 표 공유), AI 라벨 분기, 임시조치 기간 계산(KST) |
| RLS | 독자는 자기 댓글 수정·삭제만, `hidden`·`temp_blocked` 댓글 anon 비노출, 제보 연락처는 desk 이상·배정 기자만 |
| E2E | 비로그인 제보 → 편집국 배정 → 사용 처리, 독자 댓글 → 신고(권리침해) → 임시조치 → 통지 → 복원 |
| 보안 | 제보 첨부 경로 조작 시도(다른 org 경로) 거부, 레이트 리밋 429 |

## 6. 운영 점검표

- [ ] 모더레이션 대기열 24시간 초과 건 알림
- [ ] 임시조치 만료 예정 건 주간 목록
- [ ] 제보 파기 잡 실행 기록, 첨부 고아 파일 0
- [ ] AI 판정 오류율(보류로 빠진 비율) 주간 확인
- [ ] 금칙어 목록 변경 감사 기록

## 7. 자주 나는 문제

| 증상 | 원인 | 조치 |
|---|---|---|
| 댓글이 전부 보류됨 | AI 판정 장애로 기본 보류 | ai-gateway 상태 확인, 장애 중 안내 문구 |
| 정상 댓글이 금칙어로 거부 | 부분 문자열 매칭(예: 지명 안 금칙어) | 어절 경계 규칙·예외 목록 |
| 제보 첨부 업로드 실패 | 큰 동영상, MIME 불일치 | 크기 상한 안내, 링크 제출 대안 |
| 통지 메일이 안 감 | M4 발신 도메인 미인증 | M4 지시서 4장 |
