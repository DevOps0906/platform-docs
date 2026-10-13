# 03 화면과 UX: NOMAD AI Factory (nomad-video)

2026-10-13 개정: AI 채널 코치 채팅, 음성(대화, 받아쓰기, 내레이션 엔진 선택), 채널·브랜드 가이드 위키, 대본 기획 미리보기, 디자인 시스템 항목, 4.5절 3D 히어로를 추가했다. 4.5절의 3D 히어로는 사용자 결정(2026-10-13, 확정 결정 15)으로 기존 4.3절 "플레이헤드 1회 스윕" 히어로 연출을 대체한다.

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
| `/dashboard/monetize/brandconnect` | 브랜드커넥트 클립 캠페인 목록(blog 스캔 결과 중 클립형), blog에서 넘어온 캠페인(handoff), 지원 확인·상태 | owner/admin/member | Pro+(`brandconnect_clip`) | P1 |
| `/dashboard/channels/[id]/clip-consent` | 네이버 클립 자동 업로드 위험 고지·동의(01장 6.5절) | owner/admin | Pro+ | P0 |
| `/dashboard/clients`, `/dashboard/clients/[id]` | 대행 고객 목록·상세(채널, 브랜드 가이드, 생산, 승인 대기, 리포트 탭) | owner/admin(쓰기), 전 역할(조회) | Advanced(`agency`) | P1 |
| `/review/[token]` | 고객 승인 공개 화면(로그인 없음): 미리보기, 제목·설명·해시태그, 대가성 문구, 승인/수정 요청 | 토큰 소지자 | - | P1 |
| `/dashboard/analytics` | 채널·게시물·제휴 성과 | 전 역할 | 전 플랜 | P1 |
| `/dashboard/credits` | 잔액·원장 | 전 역할 | 전 플랜 | P0 |
| `/dashboard/billing` | 플랜·결제·크레딧팩 | owner/admin | 전 플랜 | P0 |
| `/dashboard/settings`, `/dashboard/settings/team` | 조직 설정, 팀 | owner/admin | 팀은 Advanced | P1 |
| `/dashboard/automation` | 캔버스(저장만) | owner/admin/member | Advanced | P2 |
| `/onboarding/ai` | AI 처리 방식 선택(상용 AI 국외 이전 동의 또는 국내 오픈소스만), 외부 서비스(DeepL, fal, Suno) 고지 | owner/admin | 전 플랜 | P0 |
| 채팅 패널(모든 `/dashboard/*` 오른쪽 시트), `/dashboard/chat` | AI 채널 코치(텍스트·음성), 대화 목록 | 전 역할(대화는 본인만) | `features.ai_chat` | P0 |
| `/dashboard/wiki`, `/dashboard/wiki/[...slug]`, `/dashboard/wiki/lint` | 채널·브랜드 가이드 위키(목록·검색, 페이지, 변경 이력, 점검 결과), 가이드 문서 업로드 | 읽기 전 역할, 쓰기·게시 owner/admin | 전 플랜 | P0 |
| `/dashboard/settings/ai` | AI 처리 방식 변경, 기본 내레이션 엔진, 음성 처리 고지 다시 보기 | owner/admin | 전 플랜 | P0 |
| `/dev/components` | 컴포넌트 미리보기(라이트/다크, 디자인 시스템 3단계). 프로덕션 빌드 제외 | 개발 환경만 | - | P0 |

대본 기획 미리보기(정밀 모드)는 별도 경로 없이 `/dashboard/shorts/new`와 `/dashboard/longform/[id]` 안의 패널이다(3.1절).

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

### 2.2.1 네이버 클립 채널 연결과 업로드

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/dashboard/channels` | "네이버 클립 연결", 역할·언어 선택 | 서버 브라우저 세션에서 네이버 로그인 창 표시(비밀번호를 서버가 받지 않음) → 세션을 `CredentialVault`(provider `naver`)에 저장 → `channels` INSERT(`naver_clip`) | Basic 이하 VD004 → 요금 비교, 로그인 실패 → 다시 시도 |
| 2 | `/dashboard/channels/[id]/clip-consent` | 고지문 끝까지 스크롤, 체크 3개, "동의합니다" 입력 | `video.consent_clip_automation_risk(channel, 'clip-2026-10-v1')` + 감사 | 버전 불일치 VD015 → 새 고지문 다시 표시 |
| 3 | `/dashboard/publish/[uploadId]` | 클립 채널 선택, 제휴·브랜드커넥트 연결 | 제목 앞·첫 해시태그·설명 첫 줄에 대가성 문구 미리보기(잠김) | 동의 없음 VD015 → 동의 화면 링크 |
| 4 | 같음 | 예약 | `upload.naver_clip`. 계정 상한(3건/시간, 15건/일)을 넘으면 다음 가능 시각 표시 | 셀렉터 실패 → `failed` + 환불 + "네이버 화면이 바뀌어 자동 업로드가 실패했습니다" |

### 2.2.2 대행 고객 승인

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/dashboard/clients/new` | 고객 등록(패키지, 월 편수, 승인 필요, 담당자 메일) | `clients` INSERT | 같은 이름 409 |
| 2 | `/dashboard/clients/[id]` 채널 탭 | 고객 채널 묶기(소유 구분) | `client_channels` INSERT | 다른 고객에 묶인 채널 409 |
| 3 | `/dashboard/shorts/new` | 고객 선택 후 생산 | `productions.client_id`, 그래프가 그 고객 가이드만 근거로 사용 | - |
| 4 | `/dashboard/publish/[uploadId]` | 검사 통과 후 "고객 승인 요청"(유효 72시간 기본) | 토큰 생성 → `open_client_review` → 업로드 `client_review` → 담당자 메일 | 메일 실패 → 링크를 한 번만 표시하고 복사 안내 |
| 5 | `/review/[token]`(고객) | 미리보기 확인, 승인 또는 수정 요청(코멘트) | `decide_client_review`, 담당자 알림 | 만료·이미 결정 → "사용할 수 없는 링크" |
| 6 | `/dashboard/publish/[uploadId]` | 승인됐으면 예약, 수정 요청이면 코멘트 보고 수정 후 다시 요청 | 승인 → `scheduled` 가능 / 수정 요청 → `draft` | 승인 전 예약 VD016 |

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

### 2.7 AI 채널 코치 채팅

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | 첫 로그인 직후 `/onboarding/ai` | "AI 처리 방식" 선택, 외부 서비스 고지 확인 | `rpc('set_ai_cross_border_ack')`(고지문 버전) | 건너뛰면 국내 오픈소스만으로 시작하고 설정에서 바꿀 수 있다 |
| 2 | 패널 | 질문 입력(1,000자) → 보내기 | 마스킹 → `consume_credits(3, conv:<id>:turn:<n>)` → Dify Chat API(스트리밍, 입력 `platform_conversation_id`) → 질문 분류(`dify.aux`) → HTTP 노드 `/tools/answer`(모드 `coach`) | 402 충전 모달, 429 재시도 시각 |
| 3 | 같은 화면 | 스트리밍 답변과 출처 칩 읽기 | `ai_messages` 2행(citations) → 정산 → 메시지 아래 "2크레딧 사용" | Dify 장애 → `/tools/answer-direct`로 답하고 운영 알림. 모든 제공자 실패 → 선차감 전액 환불 |
| 4 | 같은 화면 | 용어·정책 질문("대가성 문구가 왜 필요한가요?") | 분류 `guide` → Dify 외부 지식(`/dify/retrieval`, `video-guide`) → `wiki.query` 모델 | 근거 없음 → "근거 자료를 찾지 못했습니다" + 위키 검색 링크 |

### 2.8 음성 대화와 대본 받아쓰기

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | 패널 또는 `/dashboard/shorts/new` 주제 입력란 | 마이크 버튼을 처음 누름 | 음성 처리 고지 모달(목적, 원본 미저장, 상용 제공자 사용 시 국외 이전) → 확인 시 `POST /api/voice/consent`(감사 기록) | 거부 → 텍스트 입력 유지 |
| 2 | 같은 화면 | 누르고 말하기(최대 60초, 남은 시간 표시) | MediaRecorder → `POST /api/voice/stt`(feature `voice_chat` 또는 `dictation`, 선차감, `store_audio=false`) → 텍스트 | 권한 거부·미지원 브라우저 안내. STT 실패 시 환불 + "다시 말하기" |
| 3 | 같은 화면 | 변환 텍스트 확인·수정 → 보내기(채팅) 또는 입력란에 반영(받아쓰기) | 2.7절 2~3단계 / 주제 입력란 채움 | - |
| 4 | 같은 화면 | "읽어 주기"(자동 재생 기본 꺼짐) | `POST /api/voice/tts {message_id}` | TTS 실패 → 환불, 텍스트 답변은 그대로 |

### 2.9 내레이션 엔진 선택과 같은 목소리

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/dashboard/shorts/new` 옵션 | 엔진 선택: ElevenLabs / 오픈소스 / 자동. 언어별 보이스 선택 | 선택지는 `resolve_ai_route(narration)` 결과와 언어별 검증 통과 보이스만. 국외 이전 미동의면 ElevenLabs 숨김. 예상 크레딧이 엔진별로 바뀐다 | 선택 불가 언어 → 안내 |
| 2 | 같은 화면 | "샘플 듣기" | 대본 첫 100자를 같은 제공자·보이스로 합성(대체 없음, 선차감 1) | 실패 → 환불, "이 엔진으로 샘플을 만들지 못했습니다" |
| 3 | 같은 화면 | 생성 | 제공자·보이스를 작업 시작 때 고정해 `options.voice`에 기록. 모든 구간 같은 제공자 | 구간 실패 → 그 언어판만 실패 + 환불, 다른 엔진으로 이어 붙이지 않음 |
| 4 | `/dashboard/longform/[id]` | 섹션 재생성 | 기록된 제공자·보이스로만 합성 | 쓸 수 없으면 "전체 섹션을 다시 내레이션하시겠어요? (전체 단가)" 제안 |

### 2.10 정밀 모드 대본 기획

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/dashboard/shorts/new` 또는 롱폼 스토리라인 | "근거 기반 기획(정밀 모드)" 선택 | 예상 크레딧 5(숏폼) / 8(롱폼). 주제 점수 60 게이트 먼저(VD010) | VD009(플랜: `ai_script`), 402 |
| 2 | 기획 미리보기 패널 | 기획안 3안 비교(각도, 훅, 구조, 근거 칩, 추정 배지) 중 하나 선택·수정 | 그래프 `trend → plan`(근거: 트렌드, 내 채널 성과, 브랜드 위키). 근거 없는 수치 없음 | 근거 없음 → "참고할 데이터가 부족해 일반 기획안을 보여 드립니다" |
| 3 | 같은 화면 | "대본 만들기" | `script → metadata → compliance`. 걸린 부분 1회 재작성 | 2회 실패 → 환불 + 걸린 문구 목록 |
| 4 | 업로드 준비 단계 | 제휴 상품 연결 | 대가성 문구는 서버가 첫 줄에 삽입(기존 2.2절). 대본/메타에 문구가 없는 것은 정상 | - |

### 2.11 가이드 위키 게시

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/dashboard/wiki` | 브랜드·채널 문서 업로드(md, 2MB 이하) | 조직 Storage → FastAPI `/rag/ingest` → `ai.rag_ingest` 잡 | 형식 오류 400, 같은 내용 409 |
| 2 | 같은 화면 | 색인 상태 확인 | 색인 완료 → `ai.wiki_ingest` → 새 페이지 `draft` | 실패 → 문서 `failed` + 재시도 |
| 3 | `/dashboard/wiki/[...slug]` | draft 검토, 문단 수정, 게시 | 수정은 FastAPI 경유(`editor_kind='user'`, 사람 소유 표시, `expected_version`), 게시 → `published` | 출처 없는 페이지 게시 불가, 버전 충돌 409 → 최신본 다시 읽기 |
| 4 | `/dashboard/wiki/lint` | 점검 결과 확인 | `ai.wiki_lint` 결과 | - |

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
| 클립 위험 동의 | 자동 업로드 위험 고지 | 고지문 전문(스크롤 끝까지 읽어야 체크 활성), 체크 3개, "동의합니다" 입력란, 현재 동의 상태·철회 버튼 | `channels.automation_consent_*` | 동의, 철회(대기 업로드 취소·환불 안내) | 없음 |
| 브랜드커넥트(클립) | 클립 캠페인 지원 | 캠페인 카드(브랜드, 마감, 보상), 지원 계정(위험 동의 상태), 대상 클립 채널, 지원 메시지(AI 다듬기 선택), 지원서 상태 단계, 선정 시 "이 캠페인 영상 만들기" | blog 스캔 결과, `core.brandconnect_applications` | 지원, 업로드에 연결 | 메시지 다듬기만(blog 단가) |
| 고객 목록 | 대행 현황 | 고객별 이번 달 편수/할당 막대, 승인 대기·수정 요청 수, 다음 리포트일, 상태 배지 | `clients`, `productions`, `uploads`, `client_reviews` | 고객 등록, 상세 이동 | 없음 |
| 고객 상세 | 고객 1곳 운영 | 탭: 개요(계약·패키지·담당자), 채널, 브랜드 가이드(위키 링크), 생산, 승인(요청·결정 이력, 코멘트), 리포트(월별 PDF, 발송 처리) | 위 + `client_reports` | 상태 변경, 채널 묶기, 리포트 생성·발송 처리 | 없음 |
| 고객 승인(공개) | 고객이 게시 전 확인 | 고객사 이름, 9:16 미리보기 플레이어, 제목·설명·해시태그, 대가성 문구 강조, 이름 입력, 승인 / 수정 요청(코멘트) 두 버튼. 운영사 브랜드 최소 표시 | 토큰 → `client_reviews`, `uploads`, `outputs`(서명 URL 10분) | 승인, 수정 요청 | 없음 |

### 3.1 AI 채팅, 음성, 위키, 대본 기획 화면

공통 요소는 `docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:106-110`(음성)과 `docs/file/03-설계/공용코어/LLM_WIKI.md:45`(위키)를 따른다.

| 화면 | 목적 | 구성 | 데이터 출처 | 행동 | 크레딧 표시 |
|---|---|---|---|---|---|
| 채팅 패널 | 채널 코치(성과, 트렌드, 대본, 정책 질문) | 머리: 제목, 연결 컨텍스트 칩(채널·업로드·production, 있으면), 닫기. 본문: 메시지 스레드(스트리밍, 출처 칩, "AI가 생성한 답변", 대체 표시, 정산 크레딧). 바닥: 마이크 버튼, 입력(1,000자, 민감 정보 안내), 보내기, 예상 크레딧과 잔액 | `core.ai_conversations`, `core.ai_messages`(RLS 본인), `POST /api/ai/chat`(SSE) | 보내기, 중지, 출처 열기, 읽어 주기, 새 대화 | "약 3크레딧(정산 후 1~5)", 메시지별 실제 사용량 |
| 대화 목록 `/dashboard/chat` | 지난 대화 | 대화 행: 제목, 연결 컨텍스트, 마지막 시각. 삭제 | `core.ai_conversations` | 열기, 닫기(삭제 요청) | - |
| 음성 입력 | 말로 묻기·받아쓰기 | 누르고 말하기 버튼, 녹음 중 경과 시간 막대, 남은 시간, 변환 텍스트 미리보기·수정 | `POST /api/voice/stt` | 녹음, 취소, 수정 후 보내기 | STT 예상치(오픈소스 1 / ElevenLabs 3) |
| 음성 처리 고지 모달 | 녹음 전 고지 | 목적, 원본 미저장, 처리 제공자(국외 여부), 확인/취소 | `POST /api/voice/consent` | 확인, 취소 | - |
| 내레이션 엔진 선택 | 생산 요청 옵션 | 엔진 3택(ElevenLabs / 오픈소스 / 자동), 언어별 보이스 목록, 샘플 듣기 버튼, "작업 중 다른 엔진으로 바뀌지 않습니다" 안내, 엔진별 예상 크레딧 | `resolve_ai_route(narration)` 결과(서버), 보이스 목록(env) | 선택, 샘플 듣기 | 엔진별 예상치, 샘플 1 |
| 대본 기획 미리보기 | 정밀 모드 결과 검토 | 기획안 3안 카드가 아니라 비교 표(각도, 훅, 구조, 권장 Track), 근거 칩(트렌드 id, 내 업로드, 위키 페이지), 추정 배지(`is_estimated`), 선택·인라인 수정 | `core.ai_runs`(graph `video.script`), `ai_run_steps` | 선택, 수정, 대본 만들기 | 정밀 5 / 8 |
| 위키 목록 `/dashboard/wiki` | 채널·브랜드 가이드 찾기 | 검색, 분류(채널, 톤·용어, 시리즈·포맷), 페이지 행(제목, 요약 1줄, 상태), 문서 업로드 | `core.wiki_pages`(RLS 조직 멤버) | 검색, 열기, 업로드 | ingest 2 |
| 위키 페이지 | 가이드 읽기·수정 | 제목, 요약, 본문, "출처"(문서), "관련"(위키 링크), 사람이 고친 블록 표시, 변경 이력 | 같음 + `core.wiki_revisions` | 수정(FastAPI 경유), 게시, 이력 | 수정 0 |
| 위키 점검 | 주간 점검 결과 | 항목 표(모순, 낡음, 고아, 깨진 링크, 출처 없음) + 수정 제안 | `core.ai_runs`(graph `wiki.lint`) | 제안 반영, 무시, 수동 점검 | 수동 1 |

채팅 패널 와이어프레임(PC 오른쪽 시트 400px, 375px에서는 전체 화면):

```
+------------------------------------------+
| 채널 코치          [채널: 먹방 KO]      [x] |
+------------------------------------------+
| (AI) 최근 4주 같은 주제 평균 조회수는 ...   |
|      출처 [내 업로드 3건] [트렌드 KR 주간]   |
|      추정 포함 . AI가 생성한 답변 . 2크레딧   |
| (나) 훅을 내 채널 톤으로 3개 만들어 줘       |
+------------------------------------------+
| 비밀번호, API 키는 적지 마세요             |
| [마이크] [질문을 입력하세요        ] [보내기]|
| 약 3크레딧(정산 후 1~5) . 잔액 128          |
+------------------------------------------+
```

내레이션 엔진 선택 와이어프레임(숏폼 생성 옵션 안):

```
+--------------------------------------------------------+
| 내레이션 엔진   (o) ElevenLabs  ( ) 오픈소스  ( ) 자동   |
| KO 보이스 [ 보이스 목록 v ]  [샘플 듣기]  AI가 생성한 음성  |
| 작업 중 다른 엔진으로 바뀌지 않습니다.                    |
| 예상 크레딧: 1언어 5 / 3언어 12  (오픈소스 2 / 5)         |
+--------------------------------------------------------+
```

### 3.2 디자인 시스템

`docs/file/03-설계/디자인/DESIGN_SYSTEM.md`를 따른다(9절 제품 문서 반영 규칙). 이 절은 video의 선택만 적는다.

| 항목 | 내용 | 근거 |
|---|---|---|
| 주 레퍼런스 | 앱 화면(홈, 잡 진행, 채널·쿼터, 업로드 큐, 레이더, 분석): **Primer**(높은 정보 밀도, 표·목록·상태 표시, 잡·채널 대시보드). 보조: **Atlassian**(상태 배지·태그, 권한 표시, 모달·시트 중첩, 드래그 정렬 접근성). AI 채팅·음성·위키: Astryx 패턴(존재·라이선스 미확인, 01장 D-19) + Primer 밀도. 랜딩: `DESIGN_PRINCIPLES.md` + `HERO_3D.md` + `REFERENCES.md` nomad-video 절 | `docs/file/03-설계/디자인/DESIGN_SYSTEM.md:51-61` |
| 가져올 것 | Primer: 컴팩트/기본 두 밀도, 상태 라벨(아이콘 + 텍스트), 숫자 열 정렬. Atlassian: 상태 배지, 권한 안내 패턴, 키보드 접근성. Astryx(확인 후): 메시지 스레드 구조, 스트리밍 표시, 출처 칩 | 같은 곳 |
| 가져오지 않을 것 | 라이브러리 설치(`@primer/react`, Astryx 패키지, Atlassian 패키지), Primer 색·Octicons(Lucide 사용), StyleX(Tailwind CSS v4로 재현), 마케팅 랜딩에 B2B 레퍼런스 적용 | `docs/file/03-설계/디자인/DESIGN_SYSTEM.md:14`, `:61` |
| 스택 | Next.js 16.2.x, React 19.2, Tailwind CSS v4(4.x 고정), shadcn/ui(Tailwind v4 지원 버전, 구현 시 확인), Lucide. `tailwind.config.js`와 v3 문법 금지 | `docs/file/03-설계/디자인/DESIGN_SYSTEM.md:63-73` |
| 토큰 파일(정답) | `apps/nomad-video/src/styles/tokens.css`의 `@theme` 블록과 라이트/다크 변수. 의미 기반 이름: `--color-surface`, `--color-surface-raised`, `--color-text`, `--color-text-muted`, `--color-accent`(타임코드 블루), `--color-caption`(번인 자막 옐로, 영상 안·히어로 자막 띠 한정), `--color-record`(레코딩 레드, 소량), `--color-track-a`~`--color-track-f`(범례와 문자 라벨과 함께만), `--color-success`·`warning`·`danger`, `--radius-control`, `--space-row-compact`/`--space-row-default`. 전환은 `data-theme` 하나(랜딩 기본 라이트, 대시보드 기본 다크). 다크용 accent 명도는 3단계 사람 검토에서 확정 | `docs/file/03-설계/디자인/DESIGN_SYSTEM.md:26-37`, 4.3절 |
| 컴포넌트(정답) | `apps/nomad-video/src/components/ui/`(shadcn/ui를 토큰으로 재스타일). hex 직접 사용 금지(린트로 `bg-[#...]` 차단, 제안) | 같은 곳 |
| 문서 | `docs/file/03-설계/디자인/DESIGN.md`(1절 레퍼런스와 방향, 토큰 표), `COMPONENTS.md`(배리언트 표). 코드에서 갱신하고 다르면 코드가 이긴다 | `docs/file/03-설계/디자인/DESIGN_SYSTEM.md:32` |
| 시각 확인 | `/dev/components` 라이트/다크 스크린샷(Storybook은 쓰지 않는다) | `docs/file/03-설계/디자인/DESIGN_SYSTEM.md:33` |
| 작업 순서 | `DESIGN_SYSTEM.md` 4장 1~4단계를 06장 W0~W1에 둔다(VID-06-041, 036, 042, 043 사람 검토, 044). 화면 작업은 4단계 뒤 | `docs/file/03-설계/디자인/DESIGN_SYSTEM.md:39-49` |

기본 컴포넌트와 배리언트(수치는 제안, 3단계 사람 검토에서 확정):

| 컴포넌트 | 배리언트 | 크기 | 상태 |
|---|---|---|---|
| Button | primary(타임코드 블루), secondary, ghost, danger | sm 32 / md 36 / lg 40px | 기본, 호버, 포커스, 비활성, 로딩 |
| Input, Textarea, Select | default, error | md 36 / lg 44px | 기본, 포커스, 비활성, 오류 |
| SegmentedControl(Track 선택, 엔진 선택), Checkbox, Switch | - | md | 기본, 포커스, 비활성 |
| Dialog, Sheet(채팅 패널, 모바일 전체 화면), Toast | - | Sheet 400px / 전체 | 열림, 닫힘 |
| Table | compact(행 32px), default(행 40px) | - | 빈 상태, 로딩 스켈레톤, 가로 스크롤 |
| StatusBadge | 잡(queued, processing, partial, ready, failed, canceled), 업로드(draft, checking, blocked, awaiting_confirm, approved, scheduled, uploading, published, failed, canceled), compliance(pass, warn, fail), 위키(draft, published, archived) | sm | 아이콘 + 텍스트(색만으로 구분하지 않음) |
| TrackBadge | A~F | sm | 문자 라벨 + 색 |
| Tabs, Tooltip, Progress, Skeleton | - | - | - |

제품 고유 컴포넌트(기본 세트 뒤): JobTimeline, QuotaBar, ChannelCard, PlaylistItemRow(위/아래 이동 버튼 포함), DisclosureLine(잠긴 첫 줄), ChatPanel, MessageBubble, CitationChip, VoiceButton, VoiceEnginePicker, ScriptPlanPreview, WikiArticle, Hero3D.

## 4. 메인페이지(랜딩) 디자인 방향

### 4.1 레퍼런스 (`docs/file/03-설계/디자인/REFERENCES.md` nomad-video 절에서만 인용)

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
| 1 | 히어로는 실제 산출물의 정지 프레임(자체 제작 샘플, 01장 D-17)으로 만든 타일로 연다. 일러스트·목업 금지 |
| 2 | 대담함은 노란 번인 자막 하나. 나머지 요소는 조용하게 |
| 3 | 연출된 모션은 히어로의 3D 파이프라인 하나(4.5절)뿐이다. 다른 섹션 모션 없음. `prefers-reduced-motion`이면 정지 이미지. (2026-10-13 사용자 결정으로 "플레이헤드 1회 스윕"에서 변경) |
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

### 4.5 3D 히어로 (영상 타일 파이프라인)

정본은 `docs/file/03-설계/디자인/HERO_3D.md`(기기 구성 `:5-15`, 성능 예산 `:32-41`, 구현 규칙 `:43-55`, 수용 기준 `:70-75`)이고, 이 절은 video 소재(`:83`)와 장면만 정한다. 사용자 결정(2026-10-13)으로 4.3절의 타임라인 히어로 연출(플레이헤드 1회 스윕)을 이 장면이 대체한다. 헤드라인, CTA, 하단 구성(트랙 설명, 요금, FAQ)은 4.3절 그대로다.

| 기기 | 구성(HERO_3D 1절) | video 장면 |
|---|---|---|
| PC(1280px 이상) | 풀 3D. 제목·CTA는 HTML 오버레이 | 소싱 레인 → 가공 게이트 → 다채널 슬롯 전체. 동시 타일 약 18개(제안) |
| 태블릿(768~1279px) | 풀 3D, DPR 상한 1.5, 터치 드래그로 시점 이동 | PC와 같음 |
| 모바일(767px 이하) | HTML 즉시 표시 + 가벼운 3D를 첫 화면 뒤 로드 | 타일 5개, 한 줄 흐름(소싱 → 가공 → 배포가 가로 한 줄), 갈라짐 없이 자막 띠만 붙는다. 슬롯 3개 |
| 대체 | WebGL 미지원, 저사양(HERO_3D 1.1절 로딩 전 판정), `prefers-reduced-motion`, 데이터 절약 모드, `NEXT_PUBLIC_HERO3D_ENABLED=false`, 로딩 뒤 30fps 미만 지속(런타임 강등) | 같은 구도의 정지 렌더 이미지(`public/hero/pipeline.avif`, WebP 대체, 크기 지정으로 레이아웃 이동 없음) |

장면 연출(PC·태블릿):

| 단계 | 계기 | 3D | HTML |
|---|---|---|---|
| 0 첫 화면 | 페이지 로드 | 없음. 같은 구도의 정지 이미지 자리(레이아웃 이동 없음) | 헤드라인(LCP 요소), CTA, 단계 레이블 "소싱 → 가공 → 배포"(순서가 실제이므로 번호 표식 허용, 4.4절) |
| 1 소싱 | 동적 import 완료 | 가로(16:9) 원본 클립 타일이 왼쪽 소싱 레인에서 느리게 들어온다. 타일 면은 자체 제작 샘플의 정지 프레임(D-17) | 레이블 "소싱" |
| 2 가공 | 타일이 게이트에 도달 | 게이트(타임코드 블루 윤곽)를 지나며 9:16 세로로 바뀌고 번인 자막 띠(옐로)가 붙은 뒤 KO·JA·EN 3장으로 갈라진다 | 레이블 "가공", 언어 배지 KO JA EN(HTML, 타일을 따라가지 않고 게이트 옆 고정) |
| 3 배포 | 갈라진 타일이 슬롯으로 이동 | 채널 슬롯(타임라인 그레이 윤곽, 18개 제안)에 안착하며 슬롯이 블루로 한 번 점등. 레코딩 레드 점은 게이트 위 1개만 | 레이블 "배포" |
| 4 순환 | 3 이후 | 새 원본 타일이 계속 들어오는 느린 루프. 화면 밖·탭 숨김이면 렌더 중단. [흐름 멈춤] 토글로 정지 | 변화 없음 |

reduced-motion이면 0~4단계 없이 정지 이미지만 보인다. 생성 건수·수익·"N개 채널" 같은 숫자를 장면에 넣지 않는다(01장 6절 금지 문구).

| 요소 | 토큰(4.3절) | 비고 |
|---|---|---|
| 장면 배경 | 스크린 화이트 #F6F7F9 | 그라디언트 없음, 보라 글로우 없음 |
| 원본 클립 타일 본체·테두리 | 편집실 슬레이트 #1D2228 | 면에 샘플 프레임 텍스처(아틀라스 1장) |
| 번인 자막 띠 | 번인 자막 옐로 #F2C230 | 3D에서 옐로를 쓰는 유일한 요소(대담함의 위치) |
| 소싱 레인·슬롯 윤곽 | 타임라인 그레이 #C9CED6 | |
| 게이트 윤곽, 안착 점등 | 타임코드 블루 #3A5BD9 | |
| 진행 점 | 레코딩 레드 #E5483B | 소량(점 1개) |
| 트랙 색 A~F | 쓰지 않는다 | 문자 라벨 없이 색만으로 의미를 전달하지 않기 위해 |

| 항목 | video 결정 |
|---|---|
| 위치 | `apps/nomad-video/src/components/hero3d/`(`PipelineScene`, `TileInstances`, `GateFrame`, `ChannelSlots`, `MobileRow`, `StaticFallback`, `useHeroTier`), 정지 이미지 `public/hero/` |
| 형상 | 코드 생성 도형(`PlaneGeometry` 인스턴싱, 윤곽 선). 외부 glTF 없음. 텍스처는 샘플 프레임 아틀라스 1장(KTX2 또는 WebP, 128px x 4프레임, 약 40KB 제안) |
| 글자 | 3D 안에 글자를 넣지 않는다(레이블과 언어 배지는 HTML). 번들과 접근성을 위해서다 |
| 로딩·렌더 | `next/dynamic`(`ssr: false`), 화면 밖·탭 숨김이면 정지(HERO_3D 3절) |
| 저사양 판정 | 로딩 전에 `saveData`, reduced-motion, WebGL 시험 생성, GPU 등급(렌더러 문자열), `deviceMemory`·`hardwareConcurrency`(4 이하 낮음)를 조합한다. `deviceMemory`가 없는 Safari·Firefox에서 undefined를 고사양으로 보지 않는다(`docs/file/03-설계/디자인/HERO_3D.md:17-30`) |
| 태블릿 기울기 | iOS Safari는 [기울여 보기] 버튼 탭으로 권한을 요청하고, 거부·미지원이면 터치 드래그만 쓴다 |
| 공용 키트 | 공용 3D 장면 키트 `packages/ui-3d`(제안) 위에 video 소재만 얹는다. 키트가 아직 없으면 같은 인터페이스로 `hero3d/` 안에 두고 키트가 생기면 옮긴다(06장 R-V8) |
| 예산 | 3D 번들+에셋 PC·태블릿 1MB, 모바일 300KB 이하, 60fps / 30fps 이상, LCP 2.5초(HERO_3D 2절) |
| 접근성 | 캔버스 `aria-hidden`, 단계 레이블은 HTML `ol`, [흐름 멈춤] 키보드 조작, reduced-motion 정지 이미지 |
| 검증 | PC·태블릿·모바일 스크린샷 3종, Lighthouse 모바일·데스크톱, 프레임 측정, 고문(Fable) 디자인 검토(HERO_3D 4절) |
| 피할 인상 | 해커 터미널 모노스페이스 라벨, 큰 숫자 + 그라디언트, 보라 글로우(REFERENCES nomad-video), 흔한 네온 그리드·지구본(HERO_3D 3절) |

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
| AI 답변 생성 중 | 스트리밍 + 중지 버튼. HTTP 노드 경로는 "근거를 찾는 중" 표시 |
| 대체 모델로 답함 | 답변 아래 작은 표시 "다른 AI 모델로 답했습니다" |
| AI 실패(모든 제공자) | 오류 띠 + 환불 확인 "답변을 만들지 못해 3크레딧을 돌려드렸습니다. 잠시 뒤 다시 물어보세요" |
| 근거 없음 | "근거 자료를 찾지 못했습니다. 위키에서 찾아보세요" + 검색 링크. 근거 없는 수치는 말하지 않는다 |
| 국외 이전 미동의(오픈소스 사용 중) | 채팅 패널 상단 한 줄 + 설정 링크 "국내 오픈소스 AI로 답하고 있습니다. 설정에서 바꿀 수 있습니다" |
| 하루 채팅 한도 | 입력 비활성 "오늘 질문 200개를 모두 썼습니다. 내일 다시 이용하세요" |
| 마이크 권한 거부 | 마이크 버튼 비활성 + 안내 "마이크 권한이 꺼져 있습니다. 텍스트로 입력하세요" |
| 음성 미지원 브라우저 | 마이크 버튼 숨김 |
| 음성 변환 실패 | 환불 + "말씀을 알아듣지 못했습니다. 다시 말하거나 입력해 주세요" |
| 내레이션 구간 실패 | 그 언어판 실패 + 그 언어분 환불 + "다른 목소리로 바꾸지 않았습니다. 같은 엔진으로 다시 시도하거나 엔진을 바꿔 새로 만드세요" |
| 선택한 엔진 사용 불가 | 엔진 선택지 비활성 + 사유(국외 이전 미동의, 서버 점검, 언어 미지원) |
| 정밀 모드 근거 부족 | 일반 기획안으로 대체했음을 표시(정밀 단가 중 근거 기획분 환불 여부는 01장 4.1절 정산 규칙: 차액 없음, 실행 실패만 환불) |
| 3D 로딩 실패 | 정지 이미지로 조용히 교체 |
| 위키 버전 충돌 | 409 "다른 곳에서 먼저 수정되었습니다. 최신본을 불러와 다시 병합하세요" |
| 클립 위험 동의 없음(VD015) | "이 네이버 클립 채널은 자동 업로드 위험 안내에 동의해야 업로드할 수 있습니다" + 동의 화면 버튼(owner/admin만 활성) |
| 클립 업로드 상한 | "이 계정은 이번 시간에 3건을 올렸습니다. 14:00 이후로 예약됩니다" |
| 클립 자동 업로드 실패 | "네이버 화면이 바뀌어 자동 업로드를 하지 못했습니다. 크레딧 1을 돌려드렸습니다" + 수동 업로드용 파일·문구 다운로드 |
| 고객 승인 필요(VD016) | "이 채널은 ○○ 고객 채널이라 고객 승인 후 예약할 수 있습니다" + 승인 요청 버튼 |
| 고객 수정 요청 | 업로드 상단 띠에 고객 코멘트, 작성자, 시각 + "수정 후 다시 승인 요청" |
| 승인 링크 만료 | 담당자에게 "승인 링크가 만료되었습니다" 알림 + 다시 요청 버튼. 고객 화면은 "사용할 수 없는 링크입니다. 담당자에게 문의하세요" |
| 리포트 지표 미제공 | 수집하지 않는 지표는 0이 아니라 "미제공"과 이유(플랫폼이 제공하지 않음) |

## 6. 접근성과 반응형

| 항목 | 기준 |
|---|---|
| 키보드 | 모든 상호작용 요소 `:focus-visible`, 플리 정렬은 위/아래 버튼 대체 제공 |
| 대비 | 본문 4.5:1 이상(라이트 랜딩, 다크 대시보드 모두). 자막 옐로 위 텍스트는 슬레이트 |
| 색 의존 금지 | 트랙 색에는 항상 A~F 문자 라벨 병기 |
| 반응형 | 375/768/1024/1440px. 대시보드 표는 가로 스크롤 컨테이너, 375px에서 레이더는 카드 목록 |
| 모션 | `prefers-reduced-motion` 존중 |
| 미디어 | 영상 미리보기 자막 트랙 제공, 자동 재생은 음소거 |
| 3D 히어로 | 캔버스 `aria-hidden`, reduced-motion 정지 이미지, [흐름 멈춤] 토글, 3D 로딩 전에 제목·CTA 사용 가능, 단계 레이블은 HTML |
| 채팅 | 메시지 목록 `aria-live="polite"`(스트리밍은 완료 때 한 번 읽음), 출처 칩 키보드 접근, 375px에서 전체 화면 시트 |
| 음성 | 음성은 텍스트 입력의 대안이고 모든 기능은 음성 없이 쓸 수 있다. 녹음 중 상태를 텍스트로도 표시. 샘플·읽어 주기 플레이어는 스페이스(재생/정지) |
