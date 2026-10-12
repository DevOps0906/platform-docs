# 03 화면과 UX: NOMAD AI Factory (nomad-video)

## 1. 정보 구조와 화면 목록

대시보드는 모두 `/dashboard/**` 아래에 둔다. 공개 경로(`/landing`, `/lb`, `/r`)와 겹치지 않게 하기 위해서다(BS #10).

| 경로 | 화면 | 역할 접근 | 플랜 접근 | 우선순위 |
|---|---|---|---|---|
| `/` | 마케팅 랜딩 | 공개 | - | P0 |
| `/pricing` | 요금 | 공개 | - | P0 |
| `/login`, `/signup` | 인증 | 공개 | - | P0 |
| `/legal/terms`, `/legal/privacy` | 약관, 개인정보처리방침 | 공개 | - | P0 |
| `/landing/[slug]` | Track B 공개 랜딩 | 공개 | 소유 조직 Basic+ | P0 |
| `/lb/[handle]` | 링크인바이오 | 공개 | 전 플랜 | P0 |
| `/r/[code]` | 제휴 단축 링크(302) | 공개 | - | P0 |
| `/billing/success`, `/billing/fail` | 결제 복귀 | 로그인 | - | P0 |
| `/dashboard` | 홈(진행 중 잡, 크레딧, 채널 쿼터, 최근 산출물) | 전 역할 | 전 플랜 | P0 |
| `/dashboard/radar` | 레이더(플레이보드/채널파인더/블링 탭) | 전 역할 | Basic+(탭별 플랜) | P0 |
| `/dashboard/sources` | 소싱 목록·추가 | owner/admin/member | 전 플랜 | P0 |
| `/dashboard/shorts`, `/dashboard/shorts/new`, `/dashboard/shorts/[id]` | Track A/B/C 생산 | owner/admin/member(viewer 읽기) | A 전 플랜, B/C Basic+ | P0 |
| `/dashboard/longform`, `/dashboard/longform/[id]` | Track D 스토리보드 | 같음 | Pro+ | P0 |
| `/dashboard/music`, `/dashboard/music/[id]` | Track E 곡 | 같음 | Pro+ | P0 |
| `/dashboard/playlists`, `/dashboard/playlists/[id]` | Track F 큐레이션 | 같음 | Pro+ | P0 |
| `/dashboard/library` | 라이선스 곡 등록 | 같음 | Pro+ | P0 |
| `/dashboard/channels` | 채널 연결·역할·쿼터 | owner/admin(변경), 전 역할(조회) | 전 플랜(수 제한) | P0 |
| `/dashboard/publish`, `/dashboard/publish/[uploadId]` | 업로드 큐·캘린더, 검사·제휴 미리보기 | owner/admin/member | 전 플랜 | P0 |
| `/dashboard/monetize` | 제휴 계정·링크·클릭 통계 | owner/admin(계정), member(링크) | 전 플랜 | P0 |
| `/dashboard/monetize/landings` | 랜딩 관리 | owner/admin/member | Basic+ | P0 |
| `/dashboard/monetize/link-in-bio` | 링크인바이오 편집 | owner/admin | 전 플랜 | P0 |
| `/dashboard/monetize/disclosures` | 대가성 문구 편집(끄기 없음) | owner/admin | 전 플랜 | P0 |
| `/dashboard/analytics` | 채널·게시물·제휴 성과 | 전 역할 | 전 플랜 | P1 |
| `/dashboard/credits` | 잔액·원장 | 전 역할 | 전 플랜 | P0 |
| `/dashboard/billing` | 플랜·결제·크레딧팩 | owner/admin | 전 플랜 | P0 |
| `/dashboard/settings`, `/dashboard/settings/team` | 조직 설정, 팀 | owner/admin | 팀은 Advanced | P1 |
| `/dashboard/automation` | 캔버스(저장만) | owner/admin/member | Advanced | P2 |

## 2. 사용자 플로우

### 2.1 가입 → 부트스트랩 → 첫 생성

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/signup` | 이메일·비밀번호 또는 Google | `signUp(options.data.signup_app='video')` → 코어 트리거가 개인 조직, Starter, 100크레딧 | 이메일 미인증 → 인증 안내 |
| 2 | `/dashboard` | 첫 진입 | `session_context('video')`. `entitled=false`면 `bootstrap_app_for_org` | 프로필 없음 → 로그아웃(기본 admin 금지) |
| 3 | `/dashboard/channels` | YouTube 1채널 연결, 역할·언어 선택, 다채널 위험 고지 동의 | OAuth state 발급 → 콜백에서 state 소비 → 토큰 암호화 → `channels` INSERT | OA001 → "연결을 다시 시작하세요" |
| 4 | `/dashboard/sources` | 도우인 URL 붙여넣기, 권리 근거 선택 | 허용 목록 검사 → 1크레딧 → `source.download` | 도메인 거부 422, 크레딧 부족 402 |
| 5 | `/dashboard/shorts/new` | Track A, KO, 예상 크레딧 확인 후 생성 | 단가 합계 선차감 → 루트 잡 → Flow | VD009(플랜), CR001(402) |
| 6 | `/dashboard/shorts/[id]` | 진행률 관찰 | Realtime `core.jobs` | 실패 시 사유와 환불 원장 표시 |

### 2.2 업로드(compliance + 제휴 삽입)

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/dashboard/shorts/[id]` | "업로드 준비" | 언어판마다 대체 채널 규칙으로 기본 채널 선택, `uploads` draft | 활성 채널 없음 → 채널 연결 안내 |
| 2 | `/dashboard/publish/[uploadId]` | 제휴 상품 연결(쿠팡 검색 또는 링크 붙여넣기) | 단축 링크 생성, 설명란·고정 댓글 첫 줄에 대가성 문구 삽입 미리보기 | 제공자 오류 → 링크·문구 없이 진행 안내 |
| 3 | 같음 | "검사 실행" | 규칙 → LLM(플랜) → verdict | LLM 오류 → WARN |
| 4 | 같음 | WARN이면 사유 확인 후 "확인하고 진행" | `acknowledge_compliance_warning`(감사 기록) | FAIL → 수정 가이드, 진행 버튼 없음 |
| 5 | 같음 | 예약 시각 선택(국가별 권장 기본값) | `scheduled`, 시각에 `upload.youtube` | 쿼터 초과 → 대체 채널 또는 재예약 표시 |

### 2.3 결제

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/dashboard/billing` | Pro 선택 | 서버가 `payment_orders` 선저장(금액은 plans에서) | - |
| 2 | Toss 창 | 카드 등록(빌링키) 또는 결제 | - | 사용자 취소 → `/billing/fail` |
| 3 | `/billing/success` | 대기 | 서버 confirm → `confirm_payment_order` → 엔타이틀먼트 pro, 3,000크레딧 | PM001 → "결제 확인 실패, 승인 취소 요청됨" + 운영 알림 |

### 2.4 Track B 랜딩

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/dashboard/shorts/new` | Track B 생성 | 상품명 파싱 → 쿠팡 검색 → 링크 → `landing_pages` draft | 쿠팡 키 없음 → 계정 연결 안내 |
| 2 | `/dashboard/monetize/landings` | 문구 편집, "공개" | `set_landing_status('published')` | 링크 없음 VD001, Starter VD009 |
| 3 | `/landing/[slug]` | 방문자가 CTA 클릭 | `/r/[code]` → 클릭 기록 → 302 | 비활성 링크 → 랜딩으로 복귀 |

### 2.5 Track F 플리

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/dashboard/playlists` | 무드 "카페", 60분 선택 | `playlists` draft | Pro 미만 → 업그레이드 안내(42501) |
| 2 | `/dashboard/playlists/[id]` | 내 Suno 곡·라이브러리 곡 추가·정렬, 합계 시간 확인 | 남은 시간 계산(목표 대비 ±5%) | 라이선스 만료/수익화 불가 곡 VD006 |
| 3 | 같음 | "렌더" | 메타(트랙리스트·타임스탬프·고정 댓글) + 무드 썸네일 + 연결 렌더 | 실패 → draft 복귀, 자동 환불 |
| 4 | `/dashboard/publish` | `playlist` 역할 채널로 업로드 | 고정 댓글 = 대가성 문구(제휴 있을 때) + 타임스탬프 | - |

### 2.6 Track E 곡과 유통

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/dashboard/music` | 장르·무드·BPM 입력 | 23크레딧 선차감 → `music.generate` | Suno 실패 → 환불 |
| 2 | `/dashboard/music/[id]` | 미리듣기, "유통 패키지 만들기" | ZIP 생성 → `packaged` | - |
| 3 | 같음 | Distrokid에 직접 제출 후 "제출함", ISRC 입력 | `set_music_distribution_status` | 잘못된 전이 22023 |

## 3. 화면별 명세

| 화면 | 목적 | 구성 | 데이터 출처 | 행동 | 크레딧 표시 |
|---|---|---|---|---|---|
| 홈 | 오늘 할 일 파악 | 진행 중 잡(트랙 색 범례), 채널 쿼터 막대, 잔액, 최근 실패와 환불 | `core.jobs`, `video.channels`, `core.credit_balances` | 잡 상세 이동, 재시도(새 요청) | 잔액 상시 |
| 레이더 | 소재 고르기 | 국가·기간 필터 + 고밀도 표, 추정 배지, 블링 리포트(출처 목록 필수 표시) | `video.trend_videos`, `video.radar_reports` | "이 영상으로 소싱", "이 주제로 생성" | 블링 5, 채널파인더 2 |
| 숏폼 생성 | 요청 조립 | 트랙 → 원본/주제 → 언어 → 옵션(무음컷, 레이어) → 예상 크레딧 합계 | 단가표, `org_has_feature` | 생성 | 합계·잔액·부족분 |
| 숏폼 상세 | 진행·결과 | 단계 타임라인, 언어별 미리보기, 산출물 다운로드(서명 URL) | `productions`, `outputs`, `core.jobs` | 업로드 준비, 취소(queued만) | 차감·환불 내역 |
| 롱폼 스토리보드 | 10섹션 편집 | 좌측 섹션 목록 + 우측 대본·이미지 프롬프트 + 미리보기 | `longform_projects`, `longform_sections` | 저장(상태 잠금 시 비활성), 렌더, 하이라이트 | 단계별 |
| 곡 상세 | 곡 관리 | 플레이어, 커버, 루프 영상, 유통 상태 단계 표시 | `music_tracks`, `outputs` | 패키지, 상태 기록 | 생성 23 |
| 플리 상세 | 큐레이션 | 곡 목록(드래그), 합계 시간 막대, 트랙리스트·고정 댓글 미리보기 | `playlists`, `playlist_items`, `music_tracks`, `music_library` | 정렬, 렌더 | 30분 20 / 60분 35 / 180분 95 |
| 라이브러리 | 라이선스 곡 등록 | 음원·증빙 업로드(org-files), 라이선스 유형, 만료일, 수익화 허용 | `music_library` | 등록, 수정 | 없음 |
| 채널 | 연결·역할 | 플랫폼별 목록, 역할·언어·국가, 쿼터 사용률, 상태 | `channels`, `credential_summaries` | 연결, 역할 변경, 일시정지, 해제 | 없음 |
| 업로드 상세 | 게시 전 검사 | 설명란·고정 댓글 미리보기(문구는 잠긴 첫 줄), 검사 결과, 유료 프로모션 체크박스 | `uploads`, `compliance_checks`, `upload_links` | 검사, WARN 확인, 예약, 취소 | 검사 1, 업로드 1/채널 |
| 수익화 | 제휴 관리 | 제공자 카드(capabilities), 링크 표, 클릭 차트 | `core.affiliate_*` | 계정 연결, 링크 등록 | 없음 |
| 대가성 문구 | 문구 편집 | 제공자 x 배치 표, 기본값 대비 차이 | `effective_disclosure` | 편집(10자 이상), 끄기 버튼 없음 | 없음 |

## 4. 메인페이지(랜딩) 디자인 방향

### 4.1 레퍼런스 (`docs/products/_design-guide/REFERENCES.md` nomad-video 절에서만 인용)

| 출처 | URL | 참고 포인트 | 적용 화면 |
|---|---|---|---|
| Awwwards, Physical Matter by Runway (Honorable Mention) | https://www.awwwards.com/sites/physical-matter-by-runway | 히어로를 생성 결과 영상 하나로 연다 | 메인 히어로 |
| Awwwards, Join Radio (SOTD) | https://www.awwwards.com/sites/join-radio | 시간대에 따라 배경과 그래픽이 바뀌는 방식 | Track F 플리 소개, 링크인바이오 |
| Dribbble, Video Editing Dashboard | https://dribbble.com/shots/25186663-Video-Editing-Dashboard | 프로젝트 목록 + 타임라인 + 미리보기 왕복 | 롱폼 스토리보드, 숏폼 상세 |
| Dribbble, YouTube channel Dashboard Sample | https://dribbble.com/shots/25345883-YouTube-channel-Dashboard-Sample | 채널 지표 + 제휴 파트너 목록 한 화면 | 분석, 수익화 |
| Dribbble, Lofi Music Player | https://dribbble.com/shots/11703209-Lofi-Music-Player | 단일 곡 재생 화면 | Track E 곡 상세 |

### 4.2 브리프

| 항목 | 내용 |
|---|---|
| 주제 | 편집 타임라인, 트랙 레인, 번인 자막, 언어판(KO/JA/EN), 채널 그리드, 루프 음원, 큐레이션된 플리 |
| 대상 | 여러 채널을 굴리는 1인 운영자와 소규모 팀 |
| 주된 일 | 첫 화면에서 "소재 하나가 6개 트랙의 결과물로 바뀐다"를 보여 주고 무료 시작(100크레딧)으로 보낸다 |
| 고유 어휘 | 멀티트랙 타임라인, 노란 번인 자막, 플레이헤드, 언어 배지 |
| 피할 인상 | 해커 터미널 모노스페이스 라벨, 큰 숫자 + 그라디언트 히어로, 보라 글로우(REFERENCES nomad-video 피할 인상) |

### 4.3 토큰 플랜

랜딩은 밝은 편집실 화면을 주제로 다시 뽑는다. 대시보드는 다크 베이스(#13131A 계열)를 유지하되 트랙 색은 범례와 함께 쓴다(DESIGN_PRINCIPLES 5단계 사전 진단).

| 이름 | hex | 역할 |
|---|---|---|
| 스크린 화이트 | #F6F7F9 | 랜딩 배경 |
| 편집실 슬레이트 | #1D2228 | 본문·헤드라인 |
| 번인 자막 옐로 | #F2C230 | 자막 하이라이트(대담함의 위치) |
| 타임코드 블루 | #3A5BD9 | 링크·CTA |
| 레코딩 레드 | #E5483B | 진행 중·라이브 표시(소량) |
| 타임라인 그레이 | #C9CED6 | 레인 구분선, 보조 텍스트 배경 |

트랙 범례(대시보드·랜딩 타임라인 공통): A #A78BFA, B #F59E0B, C #F43F5E, D #2563EB, E #00C9A7, F #84CC16(제안, E와 구분). 상태색: 성공 #16A34A, 경고 #D97706, 오류 #DC2626.

| 타입 역할 | 서체 | 비고 |
|---|---|---|
| 디스플레이(한글 헤드라인) | SUIT Variable 800, 자간 -2% | 습관적 기본 서체(Pretendard/Noto) 회피 |
| 본문(한국어) | SUIT Variable 400/500, 16px/1.6 | 줄 길이 80자 미만 |
| 숫자·타임코드 | Archivo(tabular-nums) | 모노스페이스 라벨 대체(기본값 5번 회피) |
| 스케일 | 14 / 16 / 20 / 28 / 40 / 64px | 1.25~1.6 비율 |

레이아웃 두 안 비교:

```
안 1: 타임라인 히어로 (채택)
+------------------------------------------------------------+
| NOMAD AI Factory           요금  예시  로그인  무료로 시작 |
+------------------------------------------------------------+
| 원본 한 편이 언어판, 랜딩, 플리까지 됩니다 (좌측 정렬)      |
| [무료로 시작: 100크레딧]  [예시 결과 보기]                  |
|------------------------------------------------------------|
| 원본  |=====[도우인 클립]=====|                              |
| A KO  |====[번인 자막 KO]=====|  > 실제 산출 영상 9:16 재생  |
| A JA  |====[번인 자막 JA]=====|                              |
| B     |==[상품 컷]==|랜딩 카드|                              |
| F     |곡1|곡2|곡3|곡4|...  60:00                            |
|            ^ 플레이헤드가 로드 시 한 번 지나감               |
+------------------------------------------------------------+
| 6개 트랙 설명: 실제 산출물 썸네일 + 한 줄 설명(카드 아님)   |
| 업로드 전 검사와 대가성 문구 자동 삽입 미리보기             |
| 요금표(PRC 정본) / FAQ / 푸터(약관, 개인정보)               |
+------------------------------------------------------------+

안 2: 결과물 그리드 히어로 (기각: 카드 그리드가 생성형 기본값 4번에 가깝고 "변환"이 보이지 않음)
+------------------------------------------------------------+
| 헤드라인 중앙 정렬                                          |
| [쇼츠][쇼츠][롱폼][곡][플리][랜딩] 6칸 그리드               |
+------------------------------------------------------------+
```

| 원칙 | 내용 |
|---|---|
| 1 | 히어로는 실제 산출물(영상, 자막)로 연다. 일러스트·목업 금지 |
| 2 | 대담함은 노란 번인 자막 하나. 나머지 요소는 조용하게 |
| 3 | 연출된 모션은 플레이헤드 1회 스윕뿐. `prefers-reduced-motion`이면 정지 |
| 4 | 수치는 검증된 것만(요금, 크레딧 단가). 생성 건수·수익 수치 금지 |
| 5 | 대가성 문구 자동 삽입을 기능으로 보여 준다(신뢰 요소) |

### 4.4 제네릭 기본값 회피 검토

| 기본값(DESIGN_PRINCIPLES 5단계) | 원본 상태 | 처리 |
|---|---|---|
| 2. 거의 검은 배경 + 단일 강조색 | 원본 랜딩 #0A0A0F + 민트(`NOMAD Shorts Maker/DESIGN.md` 1장) | 랜딩은 밝은 배경 + 주제색으로 변경. 대시보드만 다크 유지 |
| 5. 모노스페이스 데이터 라벨, 색조 섞인 거의 검정 | JetBrains Mono 숫자 | Archivo tabular-nums, 텍스트는 #1D2228 |
| 6. 큰 숫자 + 그라디언트 히어로 | "128,470+ 생성" + 보라 glow(DESIGN.md:467, :479) | 삭제. 타임라인 히어로 |
| 4. SaaS 카드 키트 | 3-pillar 카드, 6칸 트랙 카드 | 트랙 설명은 타임라인 레인과 행 목록으로 |
| 10. 순서 아닌 번호 표식 | 없음 | 파이프라인 단계에만 번호(실제 순서) |
| 11. 섹션마다 페이드업 | Stitch 랜딩 패턴 | 금지 |
| 7. 한 단어 강조 | - | 헤드라인 강조 없음(자막 옐로는 영상 안에서만) |

카피는 01장 6절 금지 문구 목록을 통과해야 한다. 예: "원본 한 편이 언어판, 랜딩, 플리까지 됩니다"(설명형). 금지 예: "AI로 대량 생산, 40채널로 글로벌 수익화"(수익 암시, 원본 tagline).

## 5. 상태, 오류, 빈 화면

| 상황 | 표시 |
|---|---|
| 잡 진행 | `core.jobs` Realtime으로 단계명 + 퍼센트 + 남은 단계. 연결 끊김 시 10초 폴링 대체 |
| 크레딧 부족(402, CR001) | "크레딧이 12 부족합니다. 크레딧팩을 구매하면 바로 이어서 생성합니다." + 팩 버튼 |
| 플랜 부족(403 VD009 / DB 42501) | "Track D는 Pro 플랜부터 쓸 수 있습니다." + 요금 비교 |
| compliance WARN | 이슈 목록 + 수정 제안 + "확인하고 진행"(확인 기록 남김을 고지) |
| compliance FAIL | 이슈 목록 + 수정 가이드, 진행 버튼 없음 |
| 상태 잠금(VD005) | "렌더 중에는 편집할 수 없습니다. 완료 후 다시 편집하세요." |
| 채널 한도(VD003) | "Starter는 YouTube 채널 1개까지 연결합니다." |
| 실패와 환불 | 실패 단계, 사유, 환불 크레딧과 원장 링크. 장애를 성공처럼 숨기지 않는다 |
| 네트워크 오류 | 재시도 버튼, 요청은 같은 `request_id`로 재전송(중복 차감 없음) |
| 빈 상태 | "아직 연결한 채널이 없습니다. YouTube 채널을 연결하세요." 같이 다음 행동 안내 |

## 6. 접근성과 반응형

| 항목 | 기준 |
|---|---|
| 키보드 | 모든 상호작용 요소 `:focus-visible`, 플리 정렬은 위/아래 버튼 대체 제공 |
| 대비 | 본문 4.5:1 이상(라이트 랜딩, 다크 대시보드 모두). 자막 옐로 위 텍스트는 슬레이트 |
| 색 의존 금지 | 트랙 색에는 항상 A~F 문자 라벨 병기 |
| 반응형 | 375/768/1024/1440px. 대시보드 표는 가로 스크롤 컨테이너, 375px에서 레이더는 카드 목록 |
| 모션 | `prefers-reduced-motion` 존중 |
| 미디어 | 영상 미리보기 자막 트랙 제공, 자동 재생은 음소거 |
