# 01 PRD: NOMAD AI Factory (nomad-video)

근거 약칭: PRD=`NOMAD Shorts Maker/PRD.md`, ADD=`NOMAD Shorts Maker/PRD_add.md`, PRC=`NOMAD Shorts Maker/PRD_pricing.md`, MA=`docs/products/00_MERGE_ANALYSIS.md`, SM/BS/YSM=`docs/reviews/NOMAD_Shorts_Maker.md` / `Nomad-BlogStudio.md` / `Youtube_shots_Maker.md`. 근거 없는 값은 "제안", 외부 사실을 확인하지 않은 값은 "미확인"으로 표시한다.

2026-10-13 개정: 확정 결정 13~17(`docs/products/00_MERGE_ANALYSIS.md:21-25`)에 따라 AI 계층(채널 코치 채팅, RAG, 채널·브랜드 가이드 위키, LangGraph `video.script`), 음성(음성 대화, 오픈소스 TTS 내레이션 선택, Whisper STT의 공용 음성 구조 편입), 상용/오픈소스 모델 이원화와 국외 이전 동의, 3D 히어로를 MVP에 넣었다. 설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `docs/products/_design-guide/HERO_3D.md`, `DESIGN_SYSTEM.md`이고 이 문서는 제품 요구만 정한다. 기능 ID는 `VD-F-100`번대(AI), 열린 결정은 `D-13` 이후다(기존 #1~#12는 `D-1`~`D-12`와 같다).

2026-10-13 2차 개정(확정 결정 18, 19, 21): (1) 업로드 채널에 **네이버 클립**(`naver_clip`)을 추가한다. 공식 업로드 API를 찾지 못해(2026-10-13 조사, 미확인) Playwright 브라우저 자동화로 게시하고, owner/admin의 위험 동의(고지문 `clip-2026-10-v1`)를 채널마다 받는다(VD-F-075, D-23). (2) 브랜드커넥트 지원을 blog 전용에서 범용으로 넓힌 코어 변경(`core.brandconnect_applications.target_kind`, `source_app`)에 맞춰 video가 **클립 캠페인 지원을 요청**하고 선정 영상에 대가성 문구를 강제한다(VD-F-063). (3) 숏폼 **직접 대행 사업**의 내부 도구로 쓰도록 대행 고객(clients), 고객 채널 묶음, 고객 승인, 월간 리포트를 넣는다(VD-F-120~126). 외부 대행사 판매·화이트라벨은 Phase 2(D-24). 사업 운영 기준은 `08_AGENCY_OPERATIONS.md`.

## 1. 페르소나와 핵심 과제

| 페르소나 | 상황 | 목표 | 좌절 |
|---|---|---|---|
| 민재(29, 1인 숏폼 크리에이터) | 퇴근 후 2시간, YouTube 채널 3개 | 중국 드라마 숏폼을 매일 3편씩 KO/JA/EN으로 올려 광고 수익 | 번역·더빙·자막·업로드를 손으로 하면 1편에 2시간. 채널 정지 위험을 모른다 |
| 수진(35, 커머스 리뷰 채널) | 쿠팡파트너스 수익이 주 수입 | 상품 시연 숏폼마다 랜딩과 제휴 링크를 자동으로 붙인다 | 대가성 문구를 빠뜨려 경고를 받은 적이 있다. 링크 클릭 통계가 흩어져 있다 |
| 지훈(37, 숏폼 대행 운영 PD, 팀 4인) | 고객사 8곳의 YouTube·클립 채널을 월 리테이너로 운영 | 고객별 채널·브랜드 가이드를 나눠 생산하고, 고객 승인 후 예약하고, 월말 리포트를 보낸다 | 승인 요청을 카톡·메일로 주고받다 버전이 섞이고, 리포트를 엑셀로 손으로 만든다 |
| 태호(41, 음원·플리 채널 운영, 팀 3인) | Lofi 채널 2개 + 플리 채널 1개 | Suno 곡을 단일 곡 영상으로 올리고 무드별 1시간 플리를 주 2회 만든다 | 곡별 저작권 근거와 트랙리스트·타임스탬프 작성이 번거롭다 |

| 핵심 과제 | 측정 |
|---|---|
| 소재 선택부터 업로드까지 한 화면에서 자동으로 끝낸다 | 숏폼 30분, 롱폼 2시간 이내(PRD:720-721) |
| 업로드 전에 채널 위험과 법적 표시를 서버가 강제한다 | compliance 게이트 통과율 95% 이상(PRD:726), 제휴 업로드 대가성 문구 누락 0건 |
| 사용량만큼만 과금하고 실패는 자동 환불한다 | 원장 drift 0, 실패 잡 환불률 100% |

## 2. 범위: MVP와 Phase

확정 결정 7(MA:15)이 범위의 정본이다. 분석 원문의 "MVP는 A, B, C"(MA:725-728)와 "YouTube Live 폐기"(MA:598)는 확정 결정으로 대체되었다. 인증·조직·세션·라우트 보호는 MVP이고 로그인 수단은 단계로 켠다(확정 결정 22, 2026-10-14, `docs/products/_platform-core/AUTH_ROADMAP.md` 0장·8장): MVP 개발은 Mock(Stage A, 로컬 시드 계정), 공개 베타 전 Google(+이메일)(Stage B, P0), 카카오·네이버는 G2 후(Stage C, C1 카카오 P1, C2 네이버 P1). 대행 고객 승인 화면(`/review/[token]`)은 단계와 무관하게 로그인 없음. 단계표는 9절(이 표에 행을 넣지 않은 이유는 9절 머리말).

| 기능 | 범위 | 근거 |
|---|---|---|
| Track A 중국 드라마 숏폼(KO/JA/EN 더빙, 강조 자막) | MVP | 확정 결정 7, MA:22-28 |
| Track B 커머스 숏폼 + `/landing/[slug]` | MVP | 확정 결정 7, 12 |
| Track C Mode1(대본→이미지→켄번스), Mode2(원본 재편집) | MVP | 확정 결정 7 |
| Track D 롱폼 10섹션 + OSMU 하이라이트 3개 | MVP | 확정 결정 7 |
| Track E Lofi 단일 곡(Suno) + 단일 곡 루프 영상 + DSP 유통 패키지(수동 제출) | MVP | 확정 결정 7. 관리 단위는 곡 |
| Track F 플레이리스트(30분/1시간/3시간, 트랙리스트·타임스탬프·무드 썸네일·고정 댓글) | MVP | 확정 결정 7. 관리 단위는 플레이리스트 프로젝트 |
| MODULE 0 레이더(플레이보드, 채널파인더, 블링) | MVP | PRD 3장, MA:550-557 |
| YouTube 다채널(최대 40), IG Reels, TikTok, Threads 업로더 | MVP | PRD 10장, SHARED_MODULES 11장 |
| 네이버 클립 업로더(Playwright, 위험 동의 필수, Pro 이상) | MVP | 확정 결정 18. 공식 API 미확인(D-23) |
| 브랜드커넥트 클립 캠페인 지원 요청 + 선정 영상 대가성 문구 강제 | MVP | 확정 결정 19. 지원 제출은 blog 소유 어댑터(`brandconnect.apply`, `source_app='video'`) |
| 대행 운영: 고객·고객 채널, 고객 승인 링크, 고객별 브랜드 가이드, 월간 리포트 PDF, 고객별 생산 현황 | MVP(Advanced, `features.agency`) | 확정 결정 21, `08_AGENCY_OPERATIONS.md` |
| 외부 대행사 판매(화이트라벨, 고객 포털 로그인, 고객별 과금) | Phase 2 | D-24 |
| 제휴 링크·대가성 문구 자동 삽입(전 Track), 링크인바이오 `/lb/[handle]` | MVP | 확정 결정 12, MA:621 |
| compliance 게이트(규칙 + LLM) | MVP | PRD 9-4 |
| Toss 구독·크레딧팩 | MVP | 확정 결정 4 |
| AI 채널 코치 채팅(트렌드·채널 성과·과거 대본 질문), 제품별 Dify 채팅 앱 `video-chat` | MVP | 확정 결정 13, 14(`docs/products/00_MERGE_ANALYSIS.md:21-22`) |
| RAG(트렌드, 채널 성과, 과거 대본) + 채널·브랜드 가이드 위키(제품 지식 위키) | MVP | 확정 결정 13, `docs/products/_platform-core/LLM_WIKI.md:37-47` |
| LangGraph `video.script`(트렌드 검색 → 기획 → 대본 → 메타데이터 → compliance) | MVP | 확정 결정 13, `docs/products/_platform-core/AI_ARCHITECTURE.md:109-119` |
| 음성 대화, 대본 받아쓰기, 오픈소스 TTS 내레이션 선택(ElevenLabs와 병행), Whisper STT의 공용 음성 구조 편입 | MVP | 확정 결정 16(`docs/products/00_MERGE_ANALYSIS.md:24`) |
| 상용/오픈소스 모델 이원화, 온보딩 국외 이전 동의 | MVP | 확정 결정 17(`docs/products/00_MERGE_ANALYSIS.md:25`), `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| 랜딩 3D 히어로(소싱 → 가공 → 다채널 배포 영상 타일 파이프라인) | MVP | 확정 결정 15(`docs/products/00_MERGE_ANALYSIS.md:23`), `docs/products/_design-guide/HERO_3D.md:83` |
| 비회원 AI 상담(랜딩 채팅) | Phase 2 | 제안: 비로그인 상담은 운영자 예산과 강한 레이트 리밋이 필요하다(`docs/products/_platform-core/AI_ARCHITECTURE.md:130`) |
| Distrokid 자동 배포 | Phase 2 | 확정 결정 7 |
| YouTube 24시간 라이브 | Phase 2 | 확정 결정 7 |
| ElevenLabs 보이스 클로닝 | Phase 2 | 확정 결정 7 |
| React Flow 자동화 캔버스 실행, n8n/Make 브릿지 | Phase 2(제안) | 제안: 엔진이 공용 automation-core에 있고 MVP 트랙은 고정 파이프라인으로 충분하다. 저장 테이블(`workflows`)만 MVP에 둔다 |
| YouTube "유료 프로모션 포함" 플래그 자동 설정 | 제안(미확정) | 확정 결정 12 |
| 텐핑·네이버쇼핑 커넥트 API 자동 링크 생성 | 제안/확인 필요. MVP는 수동 링크 등록 | 확정 결정 12, 공개 API 미확인 |
| Phase 3(제안) | 썸네일 A/B 자동 실험, fal 이미지→비디오, 국가별 최적 시각 자동 학습 | PRD 7장 STEP 5 "[예정]", ADD 추가 8 |

### Track E와 F의 구분 (확정, MA:22-33)

| 항목 | Track E Lofi 음원 | Track F 플레이리스트 |
|---|---|---|
| 상품 | 곡 자체(DSP 유통 대상) | 상황·무드 큐레이션 영상 |
| 관리 단위 | 곡(`video.music_tracks`) | 플레이리스트 프로젝트(`video.playlists` + `video.playlist_items`) |
| 장르 | lofi / chill / ambient / white_noise | 제한 없음. 무드: cafe, drive, study, sleep, work, rain, healing, workout, other(제안) |
| 영상 | 단일 곡 루프 영상(곡 길이, 16:9) | 곡 N개를 30/60/180분 영상으로 연결 |
| 곡 출처 | Suno 생성곡만 | Suno 자체 생성곡 또는 라이선스 증빙이 있는 라이브러리 곡만(`video.music_library`) |
| 부가 산출물 | 커버, DSP 유통 패키지(메타데이터+음원+커버 ZIP) | 트랙리스트, 타임스탬프, 무드 썸네일, 고정 댓글 |
| 채널 역할 | `lofi` | `playlist` |
| 메뉴/색 | "Lofi 음원" / 민트 #00C9A7 | "플레이리스트" / 라임 #84CC16(제안) |
| 크레딧 | 곡 생성 15 + 루프 영상 인코딩(4장) | 렌더 시간 비례(4장) + 메타 생성 |
| 공유 | Suno 생성 엔진, Python 인코딩 워커만 공유 | 같음 |

## 3. 기능 요구사항과 수용 기준

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| VD-F-001 | 가입·부트스트랩 | 통합 | Supabase Auth. 로그인 수단은 단계로 켠다(확정 결정 22, 9절): MVP 개발은 Mock(Stage A, 로컬 시드 계정 `owner` 등으로 실제 JWT), 공개 베타 전 Google + 이메일(Stage B, P0), 카카오·네이버는 G2 후(Stage C, P1). 이메일 가입 폼은 `signup_app='video'` 전송, OAuth 첫 로그인은 `/auth/callback`의 `finishLogin`이 `bootstrap_app_for_org('video')`를 1회 호출. 코어 트리거가 개인 조직·Starter 엔타이틀먼트·100크레딧 지급 | 가입 직후(A: `owner` 페르소나, B: 새 Google 계정) `session_context('video')`가 `plan_code=starter`, `credit_balance=100`. B는 `AUTH_ROADMAP.md` 5.3절 B-1~B-6, C1은 7.1.3절, C2는 7.2.4절을 그대로 따른다 | BS #9, CORE_SPEC 2.2, PRC:23, 확정 결정 22 |
| VD-F-002 | 라우트 보호 | 통합 | `proxy.ts`가 `/dashboard/**`, `/api/**` 보호. 공개 예외: `/`, `/pricing`, `/legal/**`, `/landing/**`, `/lb/**`, `/r/**`, `/review/**`·`/api/review/**`(대행 고객 승인, 토큰, VD-F-123), `/api/webhooks/**`, `/billing/success|fail`, `/login`, `/api/dev/login`(A, 판정이 거짓이면 404), `/auth/callback`(B). 쿠키 역할 Mock 금지, 개발용 로그인은 `AUTH_ROADMAP.md` 2장의 로컬 시드 계정만(`/api/dev/login`, 배포 환경 404) | 비로그인으로 `/dashboard` 접근 시 `/login` 302, `/landing/x` 200, 배포 빌드에서 `/api/dev/login` 404 | SM #6, BS #10, 확정 결정 22 |
| VD-F-003 | 플랜 게이팅 | 디벨롭 | 서버가 `entitled_plan_code` + `plans.features`로 Track, 언어, 채널 수, 플랫폼, 레이더 범위를 판정. DB도 `video.org_has_feature`로 Track D/F 쓰기를 막는다 | Starter 조직이 Track B 생성 요청 시 403 `VD009`. Starter가 `longform_projects` 직접 INSERT 시 42501 | PRC:116-143, SM #13 |
| VD-F-010 | 플레이보드 랭킹 | 디벨롭 | KR/US/JP x 카테고리 x realtime/daily/weekly, 24시간 주기 수집. `weighted_score = views_24h x growth_rate 가중치`. 성장률을 계산할 수 없으면 `growth_rate=null`, `is_estimated=true`로 표시하고 난수를 쓰지 않는다 | 수집 행에 난수 지표 0건. UI에 "추정" 배지 | PRD 3-1, SM #17 |
| VD-F-011 | 채널파인더 | 유지 | 구독자 상한, 최근 평균 조회수 하한, 기간 필터. 등급 S(>=15) A(10~14) B(5~9) C(2~4) D/F(<2) | 같은 입력에 같은 등급(단위 테스트) | PRD 3-2 |
| VD-F-012 | 블링 리포트 | 유지 | 주제 점수 0~100, KO/JA/EN 수익 추정, GEO 키워드, 대본 구조, 추천 Track. 수익 추정에는 근거 출처 1개 이상 필수(DB CHECK). 월 한도 `bling_monthly_limit`(Pro 20, Advanced 100. 2026-10-14 무제한 폐지, Price_Plans 반영) | 출처 없는 리포트 저장 시 23514. Pro 21번째 요청 402가 아니라 429 `VD012` | PRD 3-3, MA:556 |
| VD-F-013 | 주제 점수 게이트 | 유지 | Track C Mode1, Track D는 점수 60 미만이면 생성 거부하고 대안 주제 3개 제시 | 점수 59 요청 시 409 `VD010` + `alternatives` 3개 | PRD:225-226, :247 |
| VD-F-020 | 소싱 | 통합 | 도우인/샤오홍슈/YouTube/TikTok URL. 도메인 허용 목록, yt-dlp 인자 앞 `--`, 하위 프로세스 타임아웃 300초(제안). Track A 60초 이내·좋아요 6K+, Track B 120초 이내·3K+ 권장 필터. 사용자가 권리 근거(`rights_basis`) 선택 필수. pHash 중복 차단 | 허용 목록 밖 URL 422. 같은 원본 재요청 시 기존 소스 반환 | PRD 4-5장, BS #19, YSM #14 |
| VD-F-021 | 원본 24시간 삭제 | 유지 | 원본은 `ready` 후 24시간 뒤 `purge_expired_sources()`로 표시하고 워커가 Storage 객체 삭제 | `purge_after` 경과 10분 내 status=purged, 객체 없음 | PRD:706, CORE_SPEC 10장 |
| VD-F-030 | 숏폼 생산(Track A) | 통합 | 원본 → 워터마크 제거 → STT(Whisper large-v3) → 번역(DeepL + LLM 후처리 "도파민형") → TTS(ElevenLabs, 백업 OpenAI TTS-1-HD) → 무음컷(-30dB/0.5초) → ASS 자막 + 강조 자막 → 언어별 MP4(1080x1920) | 60초 원본 KO/JA/EN 3판이 30분 이내 `outputs` 3행 ready | PRD 4장, ADD 추가 4-5 |
| VD-F-031 | 숏폼 생산(Track B) | 통합 | Track A 파이프라인 + 상품명 파싱 + "리뷰어 톤" + 랜딩 자동 생성(VD-F-060) | 완료 시 `landing_pages` draft 1행, 제휴 링크 1개 이상 | PRD 5장 |
| VD-F-032 | 숏폼 생산(Track C) | 통합 | Mode1: 대본(훅 15초/본문 30초/CTA 5초) → fal 이미지 3~5장 → 켄번스 → TTS → 자막+BGM. Mode2: Track A 파이프라인과 같은 것 | Mode1 요청에 원본 없음 허용, Mode2는 원본 필수(422) | PRD 6장, MA:592 |
| VD-F-033 | 레이어 합성 | 유지 | 순서 고정: 원본 → ASS → 강조 자막 → 리액션 → 배경 템플릿(선택). FFmpeg 단일 엔진(Remotion/CapCut 제외). Pro 이상 | 레이어 순서 단위 테스트 | ADD 추가 5, MA:580 |
| VD-F-034 | 워터마크 | 유지 | Starter는 렌더 워커가 플랜을 읽어 워터마크 강제. 클라이언트 값 무시 | Starter 산출물 `outputs.watermark=true` | PRC:30 |
| VD-F-035 | 진행률·부분 실패 | 신규 | 루트 잡 1개 + 단계 자식 잡. 언어별 실패는 그 언어분 크레딧만 부분 환불, 상태 `partial` | 3언어 중 JA 실패 시 JA분 환불 원장 1행, 나머지 ready | SHARED_MODULES 4장 |
| VD-F-040 | 롱폼(Track D) | 통합 | 카테고리 knowledge/radio/viral_remake, 길이 3~60분(기본 10). 주제 점수 → 3막 스토리라인(사용자 편집) → 10섹션 대본·이미지 프롬프트 → 섹션당 이미지 1장 → 켄번스 → 내레이션(언어별) + Whisper 역방향 자막 → BGM(라이브러리 또는 Suno) → 인코딩 → 썸네일 → GEO 메타 | 10분 롱폼 1언어가 2시간 이내 ready. 섹션 편집은 draft/storyboard/review 상태에서만(VD005) | PRD 7장 |
| VD-F-041 | OSMU | 디벨롭 | 롱폼 ready 후 핵심 구간 3개(각 60초 이하)를 LLM이 고르고 9:16 리프레임 쇼츠 생성 | 하이라이트 3행, 각 `end-start<=60` | PRD:267 |
| VD-F-050 | Lofi 곡 생성(Track E) | 통합 | 장르 4종, 프롬프트, 무드, BPM. Suno 생성(공식 공개 API 여부 미확인, 4장 참조) → 커버 이미지 → 단일 곡 루프 영상(16:9, 곡 길이) | 곡 1개당 `music_tracks` 1행 + `outputs(kind=music_loop)` 1행 | MA:29 |
| VD-F-051 | DSP 유통 패키지 | 신규 | MVP는 자동 배포 없음. 메타데이터(제목, 장르, AI 생성 여부), WAV/MP3, 커버를 ZIP으로 만들고 사용자가 Distrokid에 수동 제출 후 상태(submitted/live/rejected/takedown)와 ISRC를 기록 | 패키지 생성 시 `distribution_status=packaged`. 잘못된 전이(none→live)는 22023 | 확정 결정 7 |
| VD-F-060 | Track B 랜딩 | 통합 | `/landing/[slug]` ISR 1시간. 상품명 + YouTube 임베드 + 특징 3개 + CTA + 관련 상품 3개. 대가성 문구를 CTA 위에 표시. 공개는 `set_landing_status`(제휴 링크 필수, Basic 이상) | 공개 랜딩 응답에 대가성 문구 포함. 비공개 slug는 404 | PRD:181-190, SM #12 |
| VD-F-061 | 링크인바이오 | 유지 | `/lb/[handle]` 공개 허브. 항목 link/landing/affiliate/video. 제휴 항목 옆에 대가성 문구 | 비공개 프로필 404. 제휴 항목에 문구 렌더 | MA:621 |
| VD-F-062 | 제휴 링크 자동 삽입 | 신규 | 모든 Track 업로드에서 연결된 제휴 링크를 `/r/[code]` 단축 URL로 설명란과 고정 댓글에 넣고, 대가성 문구를 설명란 첫 줄과 고정 댓글 첫 줄에 넣는다. 문구는 끌 수 없고 편집만(owner/admin). 링크 생성 실패 시 링크와 문구 모두 넣지 않고 업로드는 진행 | `has_affiliate=true`인데 첫 줄이 문구가 아니면 DB 23514. 링크 0개면 문구 0 | 확정 결정 12, CORE_SPEC 13장 |
| VD-F-063 | 제휴 제공자 | 신규 | 쿠팡파트너스: API 검색·링크 생성. 텐핑, 네이버쇼핑 커넥트: 공개 API 미확인 → MVP는 사용자가 제공자 화면에서 만든 링크를 붙여 넣어 등록, Phase 2에서 API 확인 후 어댑터 또는 Playwright(제안/확인 필요). 브랜드커넥트(2026-10-13 개정, 결정 19): 클립형 캠페인(`campaign_type='clip'`)은 video 화면에서 고르고 지원 메시지를 확인하면 서버가 `core.create_brandconnect_application(account, campaign, target_url=클립 채널 URL, target_kind='clip', source_app='video', brand, product, category, message)`(9개 인자, 위험 동의나 video 엔타이틀먼트가 없으면 42501, 테이블 CHECK가 clip↔video 조합만 허용)을 호출하고, 코어가 잡 `brandconnect.apply`(payload `{application_id, source_app:'video'}`)를 넣는다. 실제 제출은 blog가 소유한 Playwright 어댑터가 한다(video는 어댑터를 갖지 않는다). blog 캠페인 탐색에서 클립형 캠페인을 고르면 blog의 `POST /api/brandconnect/handoff`가 video로 넘기고, video는 `POST /api/brandconnect/handoff/accept`로 받아 지원 확인 화면을 연다(04장 2절). 계정 연결·위험 동의(`consent_brandconnect_risk`)는 코어 공용이라 blog에서 이미 동의한 계정을 그대로 쓴다. 선정(accepted)된 지원서를 업로드에 연결하면(`uploads.brandconnect_application_id`) 제휴 링크가 없어도 대가성 문구가 필수다 | 제공자별 `capabilities` 표가 UI에 반영. 지원서가 연결된 업로드는 문구 없이 저장 불가(DB 23514). 위험 동의가 없는 계정으로 지원 요청 시 42501 | 확정 결정 12, 19, SHARED_MODULES 17장, `CORE_SPEC.md` 13장 |
| VD-F-064 | 유료 프로모션 표시 | 제안 | 업로드 화면에 "유료 프로모션 포함" 체크박스. 제휴 링크가 있으면 체크를 권하는 안내만 하고 자동 체크하지 않는다 | `paid_promotion` 기본 false | 확정 결정 12 |
| VD-F-070 | 채널 연결 | 통합 | OAuth(서버 state, PKCE). 토큰은 `core.encrypted_credentials`. 역할 main/commerce/trend/longform/lofi/playlist/insurance + 언어 KO/JA/EN + 국가. YouTube 활성 채널 수 <= `max_channels`, 그 외 플랫폼은 `features.platforms`. 네이버 클립은 OAuth가 아니라 네이버 로그인 세션을 `core.encrypted_credentials`(provider `naver`)에 암호화 저장하고 연결 직후 상태는 "위험 동의 필요"(VD-F-075) | Starter 2번째 YouTube 채널 연결 시 VD003. Basic 조직의 `naver_clip` 연결 시 VD004 | ADD 추가 3, SM #5 |
| VD-F-071 | 업로드 | 통합 | resumable 스트리밍 업로드, 재시도 3회, 쿼터 초과 시 같은 언어·역할 대체 채널 → 없으면 다음 쿼터 리셋 시각으로 재예약. 예약 발행 | 300MB 파일 업로드 중 워커 RSS 512MB 이하(제안). `naver_clip`은 잡 `upload.naver_clip`(VD-F-075) | PRD 10-4, SM #18 |
| VD-F-072 | compliance 게이트 | 유지 | 규칙 사전(플랫폼 공통 + `banned_words`) → LLM 판정(compliance:true 플랜). FAIL 차단, WARN은 사용자 확인 RPC 후 진행, LLM 오류는 WARN 처리. Starter는 규칙 단계만(제안) | FAIL 업로드를 approved로 바꾸면 DB VD011 | PRD 9-4, SHARED_MODULES 13장 |
| VD-F-073 | 다국어 GEO 메타 | 통합 | 제목/설명/태그 KO/JA/EN 생성 | 언어판마다 메타 3종 | YSM:98, PRD 10-2 |
| VD-F-074 | 국가별 권장 시각 | 유지 | KO 18~21시 KST, JA 19~22시 JST, EN 18~21시 EST 기본값. Analytics 기반 보정은 Phase 3 | 예약 기본값이 표와 일치 | ADD 추가 8 |
| VD-F-075 | 네이버 클립 자동 업로드 | 신규 | 공식 업로드 API를 찾지 못했다(2026-10-13, PC 웹 업로드만 확인: https://www.dioramarketing.co.kr/blog/naver-clip-pc-upload-guide). `packages/sns-uploader`의 `naver-clip` 어댑터가 Playwright로 클립 크리에이터 PC 웹에 로그인해 9:16 영상·제목·설명·해시태그를 올린다(잡 `upload.naver_clip`, 원본 `NOMAD Shorts Maker/src/skill/playwright-engine/naver-login.ts` 재사용). 채널마다 owner/admin이 6.5절 고지문을 읽고 `video.consent_clip_automation_risk(channel, 'clip-2026-10-v1')`로 동의해야 업로드를 만들 수 있다. 고지문 버전이 바뀌면 재동의 전까지 새 업로드 거부, 철회(`revoke_clip_automation_consent`)하면 대기 중 업로드 잡은 서버가 취소·환불. 계정당 1시간 3건, 하루 15건(제안), 업로드 사이 무작위 지연 없음(사람처럼 보이게 꾸미지 않는다). 대가성 문구는 새 배치 값 없이 코어 `video_description` 배치 문구(`effective_disclosure`)를 `injectDisclosure(..., { target: 'title_hashtag' })`로 제목 앞(`disclosure_title`)과 첫 해시태그(`disclosure_hashtag`), 설명 첫 줄에 넣는다(공정위 추천·보증 심사지침 2024 개정: 영상은 제목·영상 내·첫 해시태그). 어댑터·잡·`naver-login.ts` 재사용은 `SHARED_MODULES.md` 11장 정의를 따르고 여기서 다시 정의하지 않는다. 화면 구조가 바뀌어 셀렉터가 실패하면 재시도 1회 후 `failed` + 업로드 크레딧 환불, 운영 알림 | 동의 없는 채널에 업로드 INSERT 시 DB VD015. 제휴·브랜드커넥트 업로드의 제목 앞 문구·첫 해시태그가 없으면 DB 23514. 셀렉터 실패 시 환불 원장 1행. 공식 API가 확인되면 어댑터만 교체(D-23) | 확정 결정 18, `docs/products/_platform-core/SHARED_MODULES.md` 11장 |
| VD-F-080 | 성과 수집 | 디벨롭 | YouTube Analytics 일 1회 스냅샷. 제휴 클릭은 `core.affiliate_clicks` 집계 | 대시보드 수치가 스냅샷과 일치, 더미 0건 | SM #17, BS #16 |
| VD-F-090 | 결제 | 통합 | 코어 Toss 모듈: 주문 선저장 → 결제창 → confirm. 구독은 빌링키. Advanced는 `adv_pack_*` 할인 팩만 허용(서버 판정) | 금액 위조 요청 PM001. 결제 E2E 통과 | SM #2-3, BS #4-5 |
| VD-F-091 | 크레딧 | 통합 | 선차감 → 잡 → 실패 자동 환불. 잔액 부족 402 + 필요량 표시 | 동시 50요청에 음수 잔액 0 | CORE_SPEC 4장 |
| VD-F-092 | 팀 멤버 | 유지 | Advanced만 초대 화면(최대 5인, `team_members`) | Pro 조직 초대 API 403. Stage A는 Advanced 팀 페르소나 `adv_owner`·`adv_member`(05장 10절)로 확인 | PRC:105 |
| VD-F-100 | AI 채널 코치 채팅 | 신규 | 로그인 사용자 전용. 대시보드 채팅 패널에서 "지난달 조회수가 떨어진 이유", "이 주제의 최근 트렌드", "내 채널 톤으로 훅 3개"를 묻는다. 근거는 조직 컬렉션(`video-performance`, `video-scripts`, `video-brand`)과 채널·브랜드 가이드 위키, 운영자 컬렉션(`video-trends`, `video-guide`)이다. 대화 매핑 경로(조직 데이터), 스트리밍, 답변마다 출처, "AI가 생성한 답변" 표시. 메시지 1,000자, 대화당 50턴(제안). 크레딧은 턴 선차감 후 정산(4.1절) | 답변에 출처 1개 이상 또는 "근거 자료를 찾지 못했습니다" 표시. 수치(조회수, 성장률)는 출처 없이 말하지 않는다. 응답이 전달되지 않은 턴은 선차감 전액 환불. 잔액 부족 402(`CR001`). Dify 장애 시 `/tools/answer-direct`로 답한다. 다른 사용자의 대화 id로 이어 쓰면 404 | `docs/products/_platform-core/AI_ARCHITECTURE.md:44-56`, `:121-130` |
| VD-F-101 | RAG: 트렌드·채널 성과·과거 대본 | 신규 | 조직 컬렉션 3개: `video-performance`(업로드별 `analytics_snapshots` 요약: 제목, 채널, 언어, 조회·시청 시간 변화), `video-scripts`(완료된 productions·longform의 대본과 스토리라인), `video-brand`(위키 원본 문서). 운영자 컬렉션 2개(제품 공통 지식, 조직 구분 없음): `video-trends`(`trend_videos` 일 1회 요약, `is_estimated` 표시 포함), `video-guide`(Track 사용법, 플랫폼 정책 요약). 임베딩은 모두 오픈소스(`video.rag`, `video.knowledge`, 대체 없음, 02장 5절). 색인은 `analytics.sync`와 생산 완료 뒤 잡으로 자동 실행한다. 운영자 컬렉션은 Dify에 외부 지식 API로만 노출하고 조직 데이터는 노출하지 않는다 | 평가셋 40문항(제안)에서 상위 8개 안 정답 청크 재현율 0.8 이상(제안). 다른 조직 컬렉션 요청 42501. 외부 지식 응답에 사용자 조직 데이터 0. `is_estimated=true` 트렌드는 답변에서 "추정"으로 표시. 난수·더미 지표 색인 0 | `docs/products/_platform-core/AI_ARCHITECTURE.md:94-107` |
| VD-F-102 | 채널·브랜드 가이드 위키 | 신규 | 조직·앱 단위 제품 지식 위키(조직 간 공유 없음). 원본: 사용자가 올린 브랜드·채널 문서, 채널 설정(역할, 언어, 국가), 조직 금지어(`banned_words`), 성과 상위 대본. ingest가 `entity`(채널), `concept`(톤·용어·금지어), `topic`(시리즈·포맷), `index` 페이지를 만든다. 사람이 고친 블록은 사람 소유로 표시되어 ingest가 덮어쓰지 않고, 저장은 `expected_version` 낙관적 잠금, 문서 1건당 갱신 페이지는 5개까지(`docs/products/_platform-core/LLM_WIKI.md:30-31`, `:47`). 주 1회 lint. 대본 그래프와 채팅이 근거로 쓴다 | 새 페이지는 `draft`로 만들고 owner/admin이 게시한 뒤에만 그래프 근거로 쓴다. 사람 소유 블록 수정 0. 버전 충돌 409. 출처 없는 페이지 게시 불가 | `docs/products/_platform-core/LLM_WIKI.md:12-47` |
| VD-F-103 | 대본 그래프 `video.script` | 디벨롭(VD-F-032, 040 확장) | FastAPI 그래프 5노드: `trend`(트렌드 검색: `video-trends` RAG + `trend_videos` 정형 조회) → `plan`(기획: 채널 성과·브랜드 위키 근거로 각도, 훅, 구조, 권장 Track) → `script`(Track B/C Mode1은 훅 15초/본문 30초/CTA 5초, Track D는 스토리라인과 10섹션) → `compliance`(규칙 사전 + `banned_words` + 금지 문구, 걸린 부분만 1회 재작성) → `metadata`(제목·설명·태그 KO/JA/EN, 제휴 링크 슬롯). **제휴 링크와 대가성 문구는 그래프가 쓰지 않는다**: `metadata`는 설명란 첫 줄과 고정 댓글 첫 줄에 `effective_disclosure` 문구가 들어갈 자리만 비워 두고, 실제 삽입은 기존 업로드 경로(VD-F-062)가 한다. 모드 2가지: 빠른 모드(`trend`·`plan` 건너뜀, 기존 `ai.script` 단가), 정밀 모드(전체 5노드) | 그래프 1회 = `core.ai_runs` 1행 + 노드별 `ai_run_steps`. 대본에 출처 없는 수치 0(`trend`가 준 근거 id만 인용). 생성물에 대가성 문구와 비슷한 문장이 있으면 compliance가 제거. `has_affiliate=true` 업로드의 첫 줄은 기존 DB CHECK(`uploads_disclosure_check`)가 보장. 걸린 부분 1회 재작성, 2회 실패면 run `failed` + 환불. 주제 점수 60 미만 게이트(VD-F-013)는 그래프 앞에서 유지 | `docs/products/_platform-core/AI_ARCHITECTURE.md:109-119`, 확정 결정 12 |
| VD-F-104 | 음성 대화 | 신규 | 채팅 패널의 마이크 버튼(누르고 말하기). 발화 최대 60초(제안). STT(`voice_chat`, 오픈소스 우선) → 변환 텍스트 미리보기·수정 → 전송 → 답변 → "읽어 주기"(TTS, ElevenLabs 우선, 자동 재생 기본 꺼짐). 녹음 원본은 저장하지 않는다. 첫 사용 때 음성 처리 고지를 확인받는다 | 60초가 되면 녹음 자동 중지. `voice_jobs.store_audio=false` 100%. 마이크 권한을 거부해도 텍스트 채팅 정상. 고지 확인 없이 STT 호출 시 403 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:40-48`, `:85-95`, `:106-110` |
| VD-F-105 | Whisper STT의 공용 음성 구조 편입 | 디벨롭(VD-F-030) | 파이프라인 STT(`media.stt`, 원본 영상 오디오·롱폼 내레이션 역방향 자막)는 Python 미디어 워커의 Whisper를 유지하되 라우팅 기능 `video.stt`(오픈소스 `oss-voice`로 고정)에 편입한다. 공용 음성 서버와 같은 모델 계열(faster-whisper)·무음 감지(silero-vad)로 맞추고, 호출마다 `core.ai_usage`(kind `stt`, provider `oss-voice`, `audio_seconds`, feature `video.stt`)를 기록한다. 대화형 짧은 발화(음성 대화, 받아쓰기)는 Next.js `/api/voice/*` → 공용 음성 서버 `/stt`로 처리한다. 두 경로의 경계는 02장 2절 | 파이프라인 STT 호출 100%가 `ai_usage`에 stt 행을 남긴다. 원본 오디오가 ElevenLabs 등 국외 제공자로 가는 경로 0건. 60초 중국어 클립 세그먼트 반환 유지(VID-06-012) | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:5-20`, `:50-62` |
| VD-F-106 | 오픈소스 TTS 내레이션 선택 + 같은 목소리 규칙 | 디벨롭(VD-F-030, 040) | 생산 요청의 옵션 `voice.provider`: `elevenlabs`, `oss-voice`, `auto`(체인 순서로 작업 시작 때 쓸 수 있는 첫 제공자). 선택한 제공자와 보이스는 **작업 시작 때 하나로 고정**하고 한 언어판(숏폼) 또는 한 롱폼의 모든 구간에 같은 제공자·같은 보이스를 쓴다. 중간 실패는 다른 제공자로 대체하지 않고 그 언어판 실패 + 그 언어분 환불(VD-F-035). 롱폼 섹션 재생성은 첫 섹션의 제공자·보이스(`longform_sections.narration_paths`에 기록)를 따르고, 그 제공자를 쓸 수 없으면 전체 섹션 재내레이션을 제안한다. 국외 이전 미동의 조직은 ElevenLabs가 체인에서 빠져 오픈소스만 선택된다. 언어별 오픈소스 보이스는 KO/JA/EN 품질 검증을 통과한 것만 선택지에 노출한다(D-15) | 한 언어판 `voice_jobs`(feature `narration`)의 `provider_id`·`voice_id`가 모두 같고 `fallback_from` null. 3구간 중 2구간째 강제 실패 시 산출물 미생성 + 그 언어분 환불 1행. 재생성 섹션의 보이스가 기존과 다르면 거부(422 `VD013`) | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:47`, `:63-73` |
| VD-F-107 | 대본 받아쓰기, 샘플 듣기 | 신규 | (a) 생산 요청의 주제·대본 입력란 마이크 버튼: 음성을 받아 써 준다(`dictation`, 60초, 원본 미저장). (b) 보이스 선택 옆 "샘플 듣기": 대본 첫 100자를 선택한 제공자로 합성해 들려준다(`narration`, 대체 없음). (c) 대본 검수용 "읽어 주기"(`voice_chat` tts) | 받아쓰기 텍스트는 사용자가 수정해 보낼 수 있다. 샘플 듣기에서 쓴 제공자와 본 작업의 제공자가 같다. 샘플은 저장하지 않는다 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:106-110` |
| VD-F-108 | AI 라우팅과 국외 이전 동의 | 신규 | 첫 로그인 직후 온보딩에서 "AI 처리 방식"을 고른다: 상용 AI 사용(국외 이전 동의) 또는 국내 오픈소스만. 동의하면 `core.set_ai_cross_border_ack(org, true, 고지문 버전)`을 호출하고 설정에서 철회한다. 기능별 기본 체인은 02장 5절(seed와 일치). 동의가 없으면 모든 AI·음성 기능이 오픈소스 제공자만 쓴다. 코어 제공자 목록에 없는 외부 서비스(DeepL, fal, Suno)는 라우팅 대상이 아니므로 같은 화면에서 별도 항목으로 고지한다(6장, D-21) | 미동의 조직의 `ai_usage.provider_id`에 상용 제공자 0. 철회 직후 다음 요청부터 상용 0. 고지문 버전이 `ai_org_settings`에 남는다 | `docs/products/_platform-core/AI_ARCHITECTURE.md:86`, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:553-575` |
| VD-F-109 | AI 크레딧 선차감·정산 | 신규 | 채팅 턴·음성·위키·그래프 정밀 모드는 시작 때 예상 크레딧을 `consume_credits`로 선차감하고 끝나면 실제 사용량으로 정산한다(차액 추가 차감 또는 `refund_credits`). 기존 생산 합계에 묶이는 그래프 빠른 모드·내레이션은 정액(4.1절) | 1시간 넘게 지난 `ai_usage` 중 `settled_at is null` 0행. 같은 멱등 키 재요청 시 차감 1회. 원장 drift 0 | `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130` |
| VD-F-110 | 3D 히어로 | 신규 | 랜딩 히어로: PC·태블릿은 원본 클립 타일이 소싱 레인에서 들어와 가공 게이트에서 언어판(KO/JA/EN) 타일로 갈라지며 번인 자막 띠가 붙고 다채널 슬롯에 안착하는 풀 3D, 모바일은 타일 수를 줄인 1줄 흐름, WebGL 미지원·저사양·`prefers-reduced-motion`은 정지 이미지(03장 4.5절). 사용자 결정 2026-10-13으로 기존 "플레이헤드 1회 스윕" 연출을 대체한다 | `HERO_3D.md` 4절 수용 기준 전부: 기기별 3종 동작, 3D 번들+에셋 PC·태블릿 1MB/모바일 300KB 이하, LCP 2.5초, 제목·입력·CTA가 3D 전에 보이고 키보드로 사용 가능, 3종 스크린샷 고문 검토 통과. 생성 건수·수익 같은 미검증 수치 0 | `docs/products/_design-guide/HERO_3D.md:5-81`, `:83` |
| VD-F-111 | AI 출력 규칙(대본·채팅·메타) | 신규 | 6장 금지 문구와 6.1절 AI 대화 규칙을 그래프 compliance 노드와 `/tools/answer` 후처리에 같은 규칙 파일(`packages/video-rules/banned.json`, 제안 위치)로 적용한다. 수익·조회수 보장, 가상 후기, "1위"·"최저가" 단정, 의료·금융 단정, 타사 상표 오용 문구를 차단한다. 제휴 대가성 문구를 LLM이 쓰거나 지우지 못하게 한다 | 금지 문구 평가셋 30문항(제안) 위반 0. 대가성 문구 첫 줄 규칙 위반 업로드 0 | `docs/products/_platform-core/AI_ARCHITECTURE.md:117`, 확정 결정 12 |

### 3.1 대행 운영(직접 대행 + 내부 도구, 확정 결정 21)

숏폼 제작·채널 운영을 고객사 대신 해 주는 사업을 운영사(또는 Advanced 조직)가 이 제품으로 돌린다. 고객은 로그인하지 않고 승인 링크와 리포트 PDF만 받는다. 사업 기준(패키지, 가격, 계약 문서, 법적 위험)은 `08_AGENCY_OPERATIONS.md`, 계약·견적 문서 생성은 nomad-docs `shorts_agency` 패키지가 맡는다.

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| VD-F-120 | 대행 고객 관리 | 신규 | `video.clients`: 고객사·브랜드명, 사업자번호, 담당자 연락처, 패키지(`produce` 제작만 / `produce_upload` 제작+업로드 / `full_ops` 풀 운영), 계약 기간, 월 편수(`monthly_quota`), 승인 필요 여부, 리포트 발송일. owner/admin만 생성·수정, 상태(active/paused/ended)는 `video.set_client_status` RPC로만. 플랜 `features.agency`(Advanced) 필요 | 비 Advanced 조직의 고객 INSERT 42501. 다른 조직 멤버 조회 0행. status 직접 UPDATE 42501. ended → active 22023 | 결정 21 |
| VD-F-121 | 고객 채널 묶음 | 신규 | `video.client_channels`로 연결 채널을 고객에 묶는다. 한 채널은 한 고객에만. 소유 구분 `client`(고객 계정을 위임받음) / `agency`(운영사 계정으로 개설). 고객 계정 위임은 nomad-docs의 "채널 계정 접근·운영 위임 동의서" 서명 후에만 연결한다(운영 절차, DB 미강제) | 같은 채널을 두 고객에 묶으면 23505. 다른 조직 채널 연결 VD002 | 결정 21 |
| VD-F-122 | 고객별 생산·브랜드 가이드 | 디벨롭(VD-F-102) | 생산 요청에 `client_id`를 붙이고, 대본 그래프 `plan`·`compliance` 노드가 그 고객의 브랜드 가이드(`clients.brand_wiki_ref` 위키 문서, `brand_guide_path` 원본)와 금지어를 근거로 쓴다. 고객 A의 가이드가 고객 B 생산에 섞이지 않게 그래프 입력에 `client_id`를 넣고 위키 검색을 그 범위로 좁힌다 | 고객 B 생산의 근거 목록에 고객 A 문서 0. 다른 조직 고객 id 지정 VD002 | 결정 21, VD-F-102 |
| VD-F-123 | 고객 승인 | 신규 | 고객 채널(`review_required=true`)의 업로드는 compliance 통과(`approved`) 뒤 바로 예약할 수 없고 `client_review` 단계를 거친다. 서버가 32바이트 무작위 토큰을 만들어 sha256 해시만 `video.client_reviews`에 저장(`video.open_client_review`, service_role)하고 링크 `/review/[token]`을 고객 담당자에게 메일로 보낸다. 고객은 로그인 없이 미리보기(서명 URL 10분)·제목·설명·해시태그·대가성 문구를 보고 승인 또는 수정 요청(코멘트 2,000자)을 남긴다(`video.decide_client_review`). 링크 유효기간 기본 72시간, 최대 14일. 수정 요청이면 업로드가 `draft`로 돌아간다 | 승인 전 예약 시 DB VD016. 같은 링크로 두 번 결정 VD008. 만료 링크는 `expired`로 닫히고 결정 불가. 사용자 세션에서 `token_hash` 조회 42501. 공개 라우트 IP 해시당 30회/10분(제안) | 결정 21 |
| VD-F-124 | 월간 성과 리포트 | 신규 | 매월 `clients.report_day`에 지난달 리포트 잡 `client_report.build`: `analytics_snapshots`(조회, 시청 시간, 좋아요·댓글), 업로드 준수율(게시 편수 / `monthly_quota`), 구독 순증(채널 지표를 수집하는 플랫폼만), 완주율(제공 플랫폼만, 없으면 "미제공"), 제휴 클릭(`core.affiliate_clicks`), 상위·하위 영상 3개, 다음 달 계획 메모. PDF는 core `exports` 버킷, 표 데이터는 `client_reports.kpis`. 발송은 담당자 확인 후 수동(`sent`) | 리포트 수치가 스냅샷 집계와 일치(단위 테스트). 수집하지 않는 지표는 0이 아니라 "미제공". 같은 고객·같은 달 리포트 1행(재생성은 덮어쓰기) | 결정 21, `08_AGENCY_OPERATIONS.md` 5장 |
| VD-F-125 | 대행 대시보드 | 신규 | `/dashboard/clients`: 고객별 이번 달 편수/할당, 승인 대기, 수정 요청, 예약·게시, 다음 리포트일. 고객 상세에서 채널·가이드·생산·업로드·리포트 탭 | 고객 8곳·채널 20개에서 첫 화면 p95 1초(제안) | 결정 21 |
| VD-F-126 | 대행 감사 기록 | 신규 | 고객 생성·상태 변경, 승인 요청·결정, 리포트 발송을 감사 기록(`client.status`, `upload.client_review_open`, `upload.client_review_decide`, `client_report.sent`)으로 남긴다. 고객 분쟁 시 "누가 언제 승인했는가"를 증빙한다 | 승인된 업로드마다 감사 2행(요청·결정) | 결정 21, CORE_SPEC 감사 절 |

## 4. 요금과 크레딧

정본: PRC(확정 결정 8). 가격은 모두 VAT 포함(B2C SaaS, 2026-10-14 `Price_Plans/_common/PRICING_PRINCIPLES.md` 7장). 단계별 가격 계획(런칭 할인, 연간 결제, 중·장기 인상)은 `Price_Plans/nomad-video/PRICE_PLAN.md` 6장이며 이 표를 바꾸지 않는다. 모듈러 `seed.sql:209-223`, 모놀리스 `supabase/monolith/seed.sql`과 같다. Track F는 확정 결정으로 추가된 Track이라 PRC에 없다. E와 같은 Suno 엔진을 쓰므로 Pro 이상으로 둔다(모듈러 seed와 같음, 제안).

| 코드 | 가격 | 월 크레딧 | 가입 크레딧 | 이월 | 주요 features |
|---|---|---|---|---|---|
| starter(기본) | 0원 | 0 | 100(1회) | 없음 | tracks A, KO, 채널 1, watermark, youtube |
| basic | 49,000원/월 | 1,200 | 0 | 불가 | A~C, KO, 채널 5, 플레이보드, compliance, 무음컷, 쿠팡 랜딩 |
| pro | 99,000원/월 | 3,000 | 0 | 불가 | A~F, KO/JA/EN, 채널 15, 5개 플랫폼(네이버 클립 포함), 레이더 전체, 레이어, Suno, OSMU, 블링 20회, 브랜드커넥트 클립 캠페인 |
| advanced | 149,000원/월 | 5,000 | 0 | 불가 | Pro + 채널 40, 팀 5인, React Flow, API, 블링 월 100회, 크레딧팩 20% 할인, 대행 운영(`agency`) |

`core.plans.features` 키 해석(서버만 읽는다):

| 키 | 타입 | 의미 |
|---|---|---|
| `tracks` | text[] | 생성 가능한 Track. DB 정책은 D, F를 `org_has_feature(org,'tracks',x)`로 검사 |
| `languages` | text[] | TTS·메타 생성 언어 |
| `max_channels` | int | 활성 YouTube 채널 상한(트리거 `enforce_channel_limit`) |
| `platforms` | text[] | 연결·업로드 가능한 플랫폼: `youtube`, `instagram`, `tiktok`, `threads`, `naver_clip`(2026-10-13 추가, Pro·Advanced) |
| `brandconnect_clip` | bool | 브랜드커넥트 클립 캠페인 지원 요청(VD-F-063). Pro·Advanced |
| `agency` | bool | 대행 운영 기능(VD-F-120~126). Advanced |
| `watermark` | bool | true면 렌더 워커가 워터마크 강제 |
| `radar` | false 또는 text[] | playboard / channel_finder / bling |
| `compliance` | bool | LLM 판정 단계 사용. false여도 규칙 단계는 필수(제안) |
| `silence_cut`, `layer_composite`, `osmu`, `suno`, `coupang_landing` | bool | 해당 기능 |
| `bling_monthly_limit` | int | 월 블링 리포트 수, 키 없음 0. -1(무제한)은 쓰지 않는다(2026-10-14, `Price_Plans/_common/PRICING_PRINCIPLES.md` 6장 무제한 금지). Advanced 100 |
| `team_members` | int | 조직 활성 멤버 상한 |
| `priority_render` | bool | BullMQ priority 1(기본 100) |
| `react_flow_full`, `api_access` | bool | Phase 2 기능 |
| `credit_discount_pct` | int | 0보다 크면 `adv_pack_*` 구매 허용. Advanced 20(2026-10-14, 30에서 변경) |
| `ai_chat` | bool | AI 채널 코치 채팅 허용. 키가 없으면 true로 읽는다 |
| `ai_chat_turns_per_day` | int | 사용자당 하루 채팅 턴 상한(공정 사용). 키가 없으면 200(제안) |
| `voice_chat` | bool | 음성 대화·받아쓰기 허용. 키가 없으면 true |
| `ai_script` | bool | 그래프 `video.script` 정밀 모드(트렌드·성과 근거 기획) 허용. Starter false, Basic 이상 true(제안: Starter는 Track A만이고 근거 기획이 필요한 Track이 없다). 빠른 모드는 모든 플랜 |

크레딧 단가(PRD 13장, ADD 추가 10). 서버 `priceOf` 상수가 정본이며 코어는 단가를 모른다.

| 작업 | 크레딧 | 근거 |
|---|---|---|
| 소싱 1건 | 1 | PRD:621 |
| 트렌드 분석 1회 / 블링 리포트 | 2 / 5 | PRD:622-623 |
| STT + 번역(원본 1분당) | 5 | PRD:624 |
| TTS 1언어 / 3언어 | 5 / 12 | PRD:625-626 |
| 무음 컷 / 레이어 합성 | 2 / 3 | PRD:627-628 |
| AI 대본(숏폼) / 이미지 1장 | 3 / 3 | PRD:629-630 |
| 인코딩 숏폼(언어당) / 롱폼(10분당) | 3 / 10 | PRD:631-632 |
| 쿠팡 랜딩 생성 | 3 | PRD:633 |
| 롱폼 스토리라인 | 5 | PRD:634 |
| Suno 곡 생성 | 15 | PRD:635 |
| compliance LLM 검사 / 업로드(채널당) | 1 / 1 | PRD:637-638. 네이버 클립 업로드도 1(제안) |
| 고객 승인 링크 / 월간 리포트 PDF | 0 / 0 | 제안: 대행 운영은 Advanced 구독에 포함. 리포트 원가는 운영사 부담 |
| 단일 곡 루프 영상 인코딩 | 5 | 제안: 정지 이미지 루프라 롱폼 10분 단가의 절반 |
| 플리 렌더(30/60/180분) | 15 / 30 / 90 | 제안: 롱폼 인코딩 10분당 10의 절반(이미지 1장 + 오디오 연결로 연산이 적음) |
| 플리 메타(트랙리스트·타임스탬프·고정 댓글) / 무드 썸네일 | 2 / 3 | 제안: 트렌드 분석·이미지 단가와 같게 |
| OSMU 하이라이트 3개(선정 + 3개 인코딩) | 2 + 9 | 제안: 분석 2 + 숏폼 인코딩 3 x 3 |
| DSP 유통 패키지 | 0 | 제안: 외부 비용 없음. Distrokid 배포 5크레딧(PRD:636)은 Phase 2 자동 배포에 적용 |

예: Track A 60초, 3언어 = 소싱 1 + STT 5 + TTS 12 + 무음컷 2 + 레이어 3 + 인코딩 9 = 32크레딧(업로드·검사 별도).

크레딧팩(PRC:149-154): pack_500 15,000원 / pack_1000 28,000원 / pack_3000 75,000원 / pack_5000 110,000원. Advanced 전용 adv_pack 4종 12,000 / 22,400 / 60,000 / 88,000원(정가의 20% 할인. 2026-10-14 30% → 20%: 30% 할인팩은 상용 TTS·채팅 작업에서 70% 매출총이익률에 못 미칠 수 있다, `Price_Plans/nomad-video/PRICE_PLAN.md` 3.2절). 모듈러 seed에도 adv_pack이 반영되었다(2026-10-13, 모놀리스 seed와 일치).

AI 키 4개(`ai_chat`, `ai_chat_turns_per_day`, `voice_chat`, `ai_script`)는 2026-10-13에 추가했다. 모놀리스는 `supabase/monolith/seed.sql`의 플랜 4행에, 모듈러는 `docs/products/_supabase-modular/migrations/1200_video.sql` 11절의 병합 UPDATE에 있다(모듈러 `seed.sql` 반영은 06장 6절 R-V1). 플랜 가격·월 크레딧·팩은 바꾸지 않았다.

### 4.1 AI·음성 크레딧 단가 (2026-10-13, 제안)

기존 단가표(위)와 크레딧팩은 바꾸지 않는다. 제공자 단가는 코어 seed `core.ai_model_prices`(`docs/products/_supabase-modular/seed.sql:228-246`: LLM 상용 1k 입력 1cr·출력 4cr, 오픈소스 0.2·0.5cr, STT ElevenLabs 3cr/분·오픈소스 0.5cr/분, TTS ElevenLabs 5cr/천 자·오픈소스 1cr/천 자, 모두 제안값)이고 이 표는 그 값을 video 기능에 적용한 것이다. 계산 상수는 `apps/nomad-video/src/server/ai-pricing.ts`(기존 `priceOf`와 같은 이유로 코드 상수, VID-06-046 소유). 선차감과 정산 규칙은 `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130`, 음성 단가는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104`를 따른다.

| 작업 | 선차감(예상) | 정산 | 상용 경로 예 | 오픈소스 경로 예 | 멱등 키 |
|---|---|---|---|---|---|
| 대본 그래프 빠른 모드(Track B/C Mode1 숏폼 / Track D 스토리라인) | 3 / 5 (기존 `AI 대본`, `롱폼 스토리라인` 단가 그대로) | 정액. 차액 없음. `ai_usage`에 원가만 기록 | Claude 우선 | `oss-llm` | 기존 생산 요청 `consume:video:<request_id>`에 포함 |
| 대본 그래프 정밀 모드(트렌드·성과 근거 기획 포함) | 5 / 8 (제안: 기존 단가 + 근거 기획 2 / 3) | 정액. 상한 초과 원가는 운영사 부담 | 같음 | 같음 | `run:<ai_run_id>` |
| AI 채널 코치 채팅 1턴 | 3 | 실제 토큰 × 단가 + Dify 보조 노드 오버헤드 0.5, 올림. 최소 1, 상한 5 | 약 3~5 | 약 1~2 | `conv:<id>:turn:<n>` |
| 음성 질문·받아쓰기 STT(60초 이하) | 분 단위 올림: 오픈소스 1, ElevenLabs 3 | 실제 `audio_seconds` | 3 | 1 | `voice:<voice_job_id>` |
| 대본 읽어 주기 TTS | 글자 수 천 자 단위 올림 × (오픈소스 1, ElevenLabs 5) | 실제 `characters` | 600자 5 | 600자 1 | `voice:<voice_job_id>` |
| 샘플 듣기(100자 이하) | 최소 단위 1 | 실제 | 1 | 1 | `voice:<voice_job_id>` |
| 내레이션 TTS 숏폼 1언어 / 3언어 | ElevenLabs 5 / 12 (기존 `TTS` 단가), 오픈소스 2 / 5 (제안: 코어 단가비 1:5와 최소 단위를 반영해 기존의 약 40%) | 정액. 언어당 대본 1,000자 초과분은 천 자 단위 추가(제안) | 5 / 12 | 2 / 5 | 기존 생산 요청에 포함 |
| 내레이션 TTS 롱폼(언어당 10분) | ElevenLabs 5 (기존 04장 롱폼 렌더 합계), 오픈소스 2 | 정액 | 5 | 2 | 기존 롱폼 렌더 요청에 포함 |
| 파이프라인 STT(원본 1분당) | 기존 `STT + 번역` 5 그대로 | 정액. 오픈소스 Whisper 원가는 `ai_usage`(provider `oss-voice`)에 기록만 | - | 5 | 기존 생산 요청에 포함 |
| 위키 ingest(문서 1건) | 2 | 실제 사용량 | 약 2 | 약 1 | `run:<ai_run_id>` |
| 위키 lint 수동 실행 / 주간 자동 | 1 / 0 | 실제 / 자동은 운영사 부담, 기능별 일일 상한 안에서(`docs/products/_platform-core/LLM_WIKI.md:47`) | - | - | `run:<ai_run_id>` |
| RAG 자동 색인(성과·과거 대본) | 0 (사용자 과금 없음) | 조직당 월 청크 상한 20,000(제안) 초과 시 색인 보류 | - | 임베딩 원가는 운영사 부담 | `run:<ai_run_id>` |
| 운영자 컬렉션(`video-trends`, `video-guide`) 색인 | 사용자 과금 없음. 운영자 조직 지갑에서 사용량 차감 | 사용량 | - | - | `run:<ai_run_id>` |
| 위키·가이드 열람, 채팅 기록 열람 | 0 | - | - | - | - |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 경로별 단가 | 국외 이전에 동의하지 않은 조직은 체인에 오픈소스만 남으므로 오픈소스 단가가 자동 적용된다. 화면은 실제로 고른 경로의 예상치를 보여 준다 | `docs/products/_supabase-modular/migrations/0008_core_ai.sql:452-460` |
| 실패 환불 | 사용자에게 결과가 전달되지 않은 실패는 선차감 전액 환불. 내레이션은 구간 하나라도 실패하면 그 언어판 전체 실패(VD-F-035 부분 환불 규칙) | `docs/products/_platform-core/AI_ARCHITECTURE.md:129` |
| 정산 시점 | 응답·작업 종료 직후. 스트림이 끊기면 선차감을 남기고 정산 잡이 `settled_at is null` 행을 5분 주기로 처리(제안) | `docs/products/_platform-core/AI_ARCHITECTURE.md:128` |
| 표시 | 보내기 전 "약 3크레딧(정산 후 1~5)", 보이스 선택에 엔진별 예상치, 정산 결과는 메시지 아래와 원장 표에 | 제안 |
| 공정 사용 | 사용자당 하루 200턴(`features.ai_chat_turns_per_day`) | 제안 |

환불 정책(제안): 크레딧팩은 결제 후 7일 이내 미사용분 전액 환불, 구독은 다음 결제일부터 해지(당월 크레딧 유지). 근거 없음, 전자상거래법 청약철회 기준 확인 필요.

## 5. 비기능 요구사항

| 항목 | 값 | 근거 |
|---|---|---|
| 숏폼 처리(60초 원본, 3언어) | p90 30분 이내 | PRD:720 |
| 롱폼(10분, 1언어) | p90 2시간 이내 | PRD:721 |
| 플리 렌더(3시간) | p90 90분 이내 | 제안: 정지 이미지 + 오디오 연결은 실시간보다 빠르다 |
| API 응답 | 조회 p95 300ms, 생성 요청(큐 투입까지) p95 1초 | 제안 |
| 동시 생산(조직) | Starter 1, Basic 3, Pro 5, Advanced 10 | 제안: 서버 상수. features 키 추가는 코어 seed 요청 |
| 워커 동시성 | STT GPU 워커 1, FFmpeg 워커 CPU 코어 수 - 1 | YSM:128 |
| 하위 프로세스 타임아웃 | yt-dlp 300초, demucs 900초, FFmpeg 숏폼 600초·롱폼 3,600초·플리 7,200초 | 제안(YSM #14 대응) |
| 파일 상한 | 원본 500MB, 라이브러리 음원 50MB(org-files), 산출물 5GB(video-media 버킷) | 제안 |
| 보존 | 원본 24시간, 중간 산출물 7일, 최종 산출물 Starter 30일·유료 90일 후 삭제(게시 URL은 유지), 분석 스냅샷 1년, 감사 2년 | PRD:706, CORE_SPEC 11장, 나머지 제안 |
| 가용성 | 웹 99.5%/월, 워커 큐 지연 p95 5분 | 제안 |
| 레이트 리밋 | 생성 API 조직당 60회/분, 웹훅 제공자당 600회/분, `/r/[code]` IP 해시당 60회/분, 로그인 IP당 10회/10분, 랜딩 조회수 집계 IP 해시당 1회/10분, 네이버 클립 업로드 계정당 3건/시간·15건/일, 고객 승인 공개 라우트 IP 해시당 30회/10분 | SECURITY_BASELINE 8장, 마지막 3개는 제안 |
| 하트비트 | 60초, `reap_stale_jobs(600)` 10분 | CORE_SPEC 9.2 |
| AI 레이트 리밋 | 채팅 사용자당 20턴/분 + 하루 200턴, STT 사용자당 10회/분, 샘플 듣기 사용자당 20회/시간, 그래프 실행 조직당 30회/시간, 잡 토큰 발급 120회/분 | 제안: `docs/products/_platform-core/SECURITY_BASELINE.md:278-305` 기준 |
| AI 입력 상한 | 채팅 메시지 1,000자, 대화당 50턴, 음성 발화 60초·5MB, 샘플 100자, 위키 문서 1건 2MB | 제안 |
| AI 응답 시간 | 채팅 첫 토큰 p95 5초(Dify HTTP 노드 경로는 전체 답 도착 후 표시라 "근거를 찾는 중" 표시), 그래프 정밀 모드 p95 90초, 샘플 듣기 p95 5초 | 제안 |
| 공용 음성 서버 한도 | 요청당 STT 10분, TTS 5,000자, 파일 50MB. 이를 넘는 파이프라인 STT(롱폼 역방향 자막, 원본 500MB)는 미디어 워커가 처리한다(02장 2절) | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:61` |
| 3D 히어로 | 3D 번들+에셋 PC·태블릿 1MB, 모바일 300KB 이하, 60fps / 30fps 이상 | `docs/products/_design-guide/HERO_3D.md:32-41` |
| AI 기록 보존 | Dify 대화 로그 30일, `core.ai_messages`는 대화 삭제 또는 조직 삭제 후 30일, 성과·대본 컬렉션은 해당 업로드·생산물 삭제 시 함께 삭제 | `docs/products/_platform-core/AI_ARCHITECTURE.md:69`(제안 30일) |

## 6. 법, 개인정보, 금지 문구

| 항목 | 내용 |
|---|---|
| 개인정보 수집 | 이메일, 표시 이름, 결제 식별자(Toss), 연결 채널 식별자와 OAuth 토큰(암호문), 제휴 클릭의 IP 일 단위 솔트 해시·UA·국가, 로그인 제공자 식별자(단계별: Stage B Google 계정 식별자·이름·프로필 이미지 URL, Stage C1 카카오 계정 식별자·닉네임·프로필 이미지·비즈 앱이면 이메일, Stage C2 네이버 고유 id·이메일·이름·프로필 이미지. 제공자 토큰은 저장하지 않음, `AUTH_ROADMAP.md` 5.2·7.1.1·7.2.3절). 목적: 서비스 제공, 결제, 업로드, 수익 통계, 로그인 |
| 보존과 삭제 | 5장 보존 표. 조직 삭제는 soft delete 후 30일 유예 뒤 `purge_organization`(SECURITY_BASELINE 12장). 채널 연결 해제 시 토큰 즉시 폐기(`revoke_credential`) |
| 암호화 대상 | `core.encrypted_credentials`(YouTube/Meta/TikTok 토큰, 쿠팡·제휴 키), `core.billing_keys`. 제품 테이블에 평문 토큰 컬럼 없음 |
| 제3자 제공 | OpenAI/Anthropic(OpenRouter 경유)에 대본·자막 텍스트, DeepL에 번역 텍스트, ElevenLabs에 TTS 텍스트, fal에 이미지 프롬프트, Suno에 곡 프롬프트, 플랫폼(YouTube/Meta/TikTok)에 영상·메타. 개인정보처리방침에 위탁·국외 이전으로 명시. AI 계층 추가(2026-10-13): 상용 AI 제공자(LLM: Anthropic, OpenAI, Google, OpenRouter / 음성: ElevenLabs)는 국외 이전에 동의한 조직의 요청에만 쓴다. 보내는 범위: 대본·주제·채팅 메시지, 채널 성과 요약(제목, 조회·시청 시간 수치), 브랜드 가이드 문서, 트렌드 요약, 대본 읽어 주기·내레이션 텍스트, 음성 질문 오디오(STT). 연결 채널의 OAuth 토큰, 이메일, 결제 정보, 원본 영상·오디오는 어떤 AI 제공자에도 보내지 않는다. 오픈소스 LLM·임베딩·음성 서버와 Dify는 운영사가 자체 운영한다(서버 위치·위탁 여부 구현 시 확인) |
| 약관·고지 | 이용약관, 개인정보처리방침, 생성물 권리와 책임(사용자가 원본 권리 근거를 선언하고 책임진다), AI 생성 표시(제안: 업로드 시 플랫폼의 합성 콘텐츠 표시를 기본 체크하고, AI 합성 음성 내레이션이 들어간 영상은 특히 권한다. YouTube의 합성·변형 콘텐츠 표시 항목의 API 지원 여부와 TikTok·Meta의 AI 생성 라벨 정책은 미확인, 구현 시 확인). 채팅 답변마다 "AI가 생성한 답변", 샘플·읽어 주기 플레이어에 "AI가 생성한 음성입니다", 위키 페이지에 "AI가 정리한 문서(사람이 수정한 블록은 표시)". 다른 모델로 대체된 답변은 "다른 AI 모델로 답했습니다" 표시 |
| 원본 저작권 | Track A/B/C Mode2 원본은 "무료 배포"여도 재가공·수익화 허락이 아니다. 소싱 시 `rights_basis`(public_free/creative_commons/licensed/own) 선택과 근거 메모 필수, 권리자 신고 시 해당 업로드 비공개·삭제 절차(제안: 접수 후 24시간 내 처리). 법률 검토 필요(01장 8절) |
| 음원 권리 | Suno 생성곡의 상업 이용 권리는 Suno 요금제에 따라 다르다(미확인). DSP의 AI 음원 정책도 미확인. 플리 곡은 Suno 생성곡 또는 증빙 업로드한 라이선스 곡만(DB 트리거 VD006) |
| 제휴·광고 | 공정위 "추천·보증 등에 관한 표시·광고 심사지침"에 따라 대가성 문구를 설명란 첫 줄과 고정 댓글 첫 줄에(CORE_SPEC 13.3). 끌 수 없음(DB CHECK `uploads_disclosure_check`). 랜딩·링크인바이오는 CTA·링크 옆에 표시. 네이버 클립(고정 댓글 없음)은 제목 앞 + 첫 해시태그 + 설명 첫 줄(2024 개정 지침: 영상은 제목·영상 내·첫 해시태그 표시, 2025-12 개정 Q&A 안내서 https://www.ajunews.com/view/20251202085042877). 브랜드커넥트 선정 영상은 제휴 링크가 없어도 같은 규칙. 대행 영상은 광고주가 고객사이므로 고객 브랜드 협찬 표시("[광고] ○○ 제공")를 기본값으로 둔다(08 문서 6장) |
| AI 가상인물 광고 | 공정위가 2026-04 AI 가상인물이 추천·보증하는 광고에 "가상인물" 표시를 의무화하는 개정안을 행정예고했다(최종 확정 미확인). AI 합성 인물·아바타가 상품을 추천하는 영상은 확정 전이라도 "AI 가상인물" 표시를 기본으로 넣는다(제안) |
| 플랫폼 약관 | YouTube API 서비스 약관(쿼터, 데이터 삭제 의무 세부 미확인), 다채널 "보험 채널" 운영은 스팸·반복 콘텐츠 정책 위반 위험이 있어 첫 연결 시 위험 고지와 동의 기록(audit `channel.risk_ack`, 제안). 네이버 클립은 공식 API 없이 브라우저 자동화로 게시하므로 네이버 이용약관·클립 운영정책의 자동화 조항 위반 위험이 있다(조항 원문 미확인, 6.5절 고지와 동의). 대행에서 고객 계정을 위임받아 운영할 때는 고객의 위임 동의서와 계정 소유자 확인을 먼저 받는다. 도우인·샤오홍슈 수집은 각 플랫폼 약관 위반 위험 고지. 쿠팡파트너스 운영 정책 준수(문구 원문 사용) |
| 금지 문구(마케팅) | 가상 후기·평점, 미검증 수치(원본 랜딩의 "128,470+ 생성", `NOMAD Shorts Maker/src/app/page.tsx:164`, "-95% 시간단축" DESIGN.md:468), 보장 표현("확정 수익", "100% 통과", "채널 정지 없음"), 타사 상표 오용(YouTube 로고·빨간색 브랜드) |
| 금지 문구(생성물) | 블링 수익 추정은 "추정"과 출처를 항상 표시, 보장 표현 금지. 의료·금융 단정 표현은 compliance 규칙 사전에 등록. 커머스 대본에 허위 효능·최상급 단정("1위", "최저가") 금지. AI 계층 추가: 출처 없는 조회수·성장률·수익 수치 생성 금지(근거 id가 있는 수치만 인용), 존재하지 않는 고객 후기·평점·"써 봤더니" 체험담 생성 금지(상품 정보 밖의 사용 경험 서술 포함), "이 대본대로 하면 조회수가 오른다" 같은 성과 보장 금지, 제휴 대가성 문구를 대본·설명에서 생략하거나 비슷한 문장으로 대체하는 일 금지 |
| 규제 특례 | 해당 없음(의료·금융·미성년 특례 없음). 단 만 14세 미만 가입 불가(제안) |

### 6.1 AI·음성 개인정보 판단과 대화 규칙 (2026-10-13)

| 항목 | 판단 | 이유와 처리 |
|---|---|---|
| 채널 성과·대본·브랜드 문서 | 조직 영업정보. 개인정보는 아니지만 외부 유출 시 손해가 크다 | 상용 제공자는 국외 이전 동의 조직에만 쓴다. 강제 오픈소스는 두지 않는다(`force_open_source=false`, 품질 우선). 동의가 없으면 `resolve_ai_route`가 상용을 걸러 낸다(`docs/products/_supabase-modular/migrations/0008_core_ai.sql:419-476`) |
| 원본 영상·오디오 | 제3자 저작물과 제3자 목소리(도우인·샤오홍슈 크리에이터)를 담고 있다 | 파이프라인 STT는 `video.stt`를 오픈소스 `oss-voice` 단일로 고정해 국외 제공자로 보내지 않는다. 원본은 24시간 뒤 삭제(VD-F-021). 화자 식별·음성 특징 추출·복제를 하지 않는다 |
| 채팅·받아쓰기 자유 입력 | 사용자가 이메일, 전화번호, 계정 정보를 적을 수 있다 | 입력란에 "비밀번호, API 키, 개인정보를 적지 마세요" 안내. 보내기 전 서버가 이메일·전화번호·카드·계정 번호 형식을 마스킹한다(제안) |
| 채널 토큰 | `core.encrypted_credentials`에만 있다 | 어떤 AI 입력에도 넣지 않는다. 그래프 입력의 채널은 `channel_id`와 이름·역할·언어만 |
| Dify 보조 노드 | 조직을 알 수 없어 동의를 확인할 수 없다 | `dify.aux`는 오픈소스 강제(`force_open_source=true`, 02장 5절) |
| 보이스 클로닝 | 본인 목소리가 아닌 복제는 초상·음성 권리 침해 위험 | MVP 미제공. Phase 2도 본인 신원 확인 + 동의가 있을 때만. 타인(유명인, 원본 배우)의 목소리 복제는 제공하지 않는다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:80`) |

| 고지·동의 | 시점 | 기록 |
|---|---|---|
| 상용 AI 국외 이전 | 첫 로그인 직후 온보딩(`/onboarding/ai`), 설정에서 변경. 코어 제공자 목록에 없는 외부 서비스(DeepL, fal, Suno)는 같은 화면의 별도 항목(D-21) | `core.ai_org_settings`(고지문 버전) |
| 음성 처리 고지(녹음) | 첫 마이크 사용 직전. 녹음 목적, 원본 미저장, 상용 제공자 사용 시 국외 이전 | 녹음 원본을 저장하지 않으므로 `voice_jobs.store_audio=false`이고 보관 동의는 받지 않는다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:85-95`). 고지 확인은 감사 기록(`write_audit`, action `voice.notice_ack`, 고지문 버전을 메타데이터에)으로 남긴다(제품 동의 테이블을 만들지 않음) |
| 제3자 녹음 고지 | 해당 없음: 이 제품은 강의 녹음처럼 타인의 목소리를 사용자가 녹음해 저장하는 기능이 없다. 파이프라인 원본의 제3자 음성은 위 표 처리 | - |
| AI 생성 표시 | 채팅·읽어 주기·샘플·위키·업로드 화면 | 6장 약관·고지 행 |

AI 대화 추가 규칙(6장 금지 문구에 더해 채팅·대본에 적용):

| 분류 | 금지 | 대신 |
|---|---|---|
| 성과 보장 | "이렇게 하면 조회수 10만", "수익 보장" | "최근 같은 주제 평균 조회수는 N(출처, 추정 여부)이며 보장되지 않습니다" |
| 수치 생성 | 근거 없는 수치, 난수 지표 | 근거 id가 있는 수치만. 없으면 "근거 자료를 찾지 못했습니다" |
| 제휴 | 대가성 문구를 쓰지 않거나 지우거나 우회 표현으로 바꾸기 | 문구는 서버가 삽입(`effective_disclosure`). 채팅은 규칙을 안내만 한다 |
| 플랫폼 정책 | 정지 회피, 보험 채널로 반복 업로드 유도, 약관 우회 | 정책 위험 안내(6장 플랫폼 약관 행) |
| 타인 권리 | 원본 배우·크리에이터 목소리 복제 권유, 권리 근거 없는 재가공 권유 | 권리 근거 선언 안내(VD-F-020) |
| 개인정보 요구 | 비밀번호, 토큰, 카드번호 요구 | 묻지 않는다 |

### 6.5 네이버 클립 자동 업로드 위험 고지 (버전 `clip-2026-10-v1`)

nomad-blog의 채널 자동 게시 고지(`ch-2026-10-v1`)와 같은 구조다. 채널마다 owner/admin이 끝까지 읽고 체크 3개 + "동의합니다"를 직접 입력한 뒤 `video.consent_clip_automation_risk`를 호출한다. 고지문 버전은 `video.clip_notice_version()`과 화면 상수를 함께 바꾼다.

```
네이버 클립 자동 업로드 위험 안내

1. 네이버 클립은 외부 프로그램용 공식 업로드 API를 제공하지 않는 것으로 확인되었습니다(2026-10-13 기준).
   NOMAD AI Factory는 회원님의 네이버 계정으로 클립 크리에이터 PC 웹에 로그인해 화면을 자동으로 조작합니다.
2. 네이버 이용약관과 클립 운영정책은 자동화 프로그램 사용을 제한할 수 있습니다. 다음 불이익이 생길 수 있습니다.
   - 클립 업로드 제한, 노출 제한, 계정 보호조치 또는 이용 정지
   - 클립 크리에이터 선정·혜택, 브랜드커넥트 활동, 수익 정산 제한
3. 회사는 위 불이익을 막거나 보상할 수 없습니다. 업로드 횟수 상한(계정당 1시간 3건, 하루 15건)을 지켜도 위험은 남습니다.
4. 광고·협찬 영상은 제목 앞과 첫 해시태그에 대가성 표시가 자동으로 들어가며 끌 수 없습니다.
5. 동의는 이 채널에만 적용되며 설정에서 언제든 철회할 수 있습니다. 철회하면 예약된 클립 업로드는 취소되고 크레딧은 환불됩니다.
```

| 체크 항목 | 문구 |
|---|---|
| 1 | 공식 API가 아닌 브라우저 자동화로 게시된다는 점을 이해했습니다 |
| 2 | 계정 제한·정지와 정산 제한 위험을 회사가 보상하지 않는다는 점을 이해했습니다 |
| 3 | 이 계정의 소유자이거나 소유자에게서 운영을 위임받았습니다 |

## 7. KPI

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| 가입 사용자 | 500명 | `core.profiles` 중 video 엔타이틀먼트 | 출시 후 3개월(PRD:718) |
| 유료 전환율 | 15% | basic 이상 구독 조직 / 가입 조직 | 3개월(PRD:719) |
| 월 생성 영상 | 5,000건 | `outputs` ready 수 | 3개월(PRD:722) |
| 연결 채널 | 평균 5채널/조직 | 활성 `channels` | 3개월(PRD:723) |
| 제휴 클릭 | 월 10,000회 | `core.affiliate_clicks`(봇 제외) | 3개월(PRD:724) |
| Track E 곡 | 월 50곡 | `music_tracks` ready | 3개월(PRD:725 Suno 배포 음원) |
| Track F 플리 | 월 40개 | `playlists` ready | 3개월(제안) |
| compliance 통과율 | 95% 이상 | 첫 검사 PASS 비율 | 상시(PRD:726) |
| 대가성 문구 누락 | 0건 | 제휴 링크 있는 업로드 중 문구 없음(DB로 불가능해야 함) | 상시 |
| 원장 drift | 0 | `credit_ledger_reconciliation` | 매일 |
| AI 채팅 사용률 | 활성 조직의 30%(제안) | `core.ai_conversations` 1개 이상 조직 / 월 업로드 1건 이상 조직 | 3개월 |
| 정밀 모드 대본 채택률 | 정밀 모드 결과로 생산을 이어 간 비율 50% 이상(제안) | `ai_runs`(graph `video.script`) 대비 `productions` | 3개월 |
| 오픈소스 내레이션 선택 비율 | 측정만(목표 없음) | `voice_jobs`(feature `narration`) provider 비율 | 3개월 |
| 미정산 AI 사용 | `settled_at is null` 1시간 초과 0건 | `core.ai_usage` | 상시 |
| 네이버 클립 업로드 성공률 | 90% 이상(제안) | `uploads`(platform `naver_clip`) published / (published + failed) | 주 |
| 고객 승인 리드타임 | 중앙값 24시간 이내(제안) | `client_reviews.decided_at - created_at` | 월 |
| 대행 업로드 준수율 | 고객별 95% 이상(제안) | 게시 편수 / `clients.monthly_quota` | 월 |

## 8. 열린 결정

| # | 항목 | 선택지 | 권고 |
|---|---|---|---|
| D-1 | 모놀리스 스키마 | (a) `public`(코어 lite 그대로) (b) 제품 스키마 | (a). 사용자 최종 확인 대기 |
| D-2 | Track F 허용 플랜 | (a) Pro 이상(seed 현재값) (b) Basic 포함 | (a). Suno 엔진을 쓰는 E와 같은 등급 |
| D-3 | Starter compliance | (a) 규칙 단계만 필수 (b) 검사 없음(PRC 그대로) | (a). "업로드 전 검증 필수"(PRD:710)와 플랜표(PRC:28) 충돌을 비용 0인 규칙 단계로 해소 |
| D-4 | Advanced 30% 할인 | (a) adv_pack 4종 seed 추가 (b) 코어 주문에 할인 지원 | (a). 코어 변경 없음. 모듈러 seed 갱신은 2026-10-13 반영 완료. 할인율은 결정됨(2026-10-14, Price_Plans 반영): 20%(12,000 / 22,400 / 60,000 / 88,000원) |
| D-5 | 네이버 로그인 | (a) MVP 제외 (b) naver_id 매핑 + 명시적 연결 | 해소: 결정 22로 C2 확정(G2 후, VID-06-065, 경로는 8.1절 D-27). 이메일 자동 병합 금지(YSM #3) 유지 |
| D-6 | 대용량 미디어 저장소 | (a) Supabase `video-media` 버킷 5GB (b) 외부 객체 저장소(R2 등) | (a)로 시작, 월 저장량 1TB 초과 시 (b) 검토(제안) |
| D-7 | Track A 원본 권리 | 법률 검토 전 출시 범위 | 권리 근거 선언 + 신고 처리 절차를 갖추고 출시, 법률 검토 병행 |
| D-8 | Suno 연동 방식 | 공식 API / 대행 API / 수동 업로드 | 공식 API 확인 전에는 사용자가 생성한 곡 파일 업로드 경로를 함께 둔다(제안) |
| D-9 | 유료 프로모션 자동 표시 | 자동 / 안내만 | 안내만(확정 결정 12 "제안") |
| D-10 | 텐핑·네이버쇼핑 커넥트 | API / Playwright / 수동 | 수동으로 출시, API 확인 후 결정 |
| D-11 | 랜딩·링크인바이오 문구 배치 | `video_description` 재사용 / 코어에 `landing` 배치 추가 | 재사용으로 시작, 코어 요청 등록 |
| D-12 | 산출물 보존 기간 | 5장 제안값 | 사용자 확인 필요 |
| D-13 | 파이프라인 STT 일원화 방식(VD-F-105) | (a) 미디어 워커의 Whisper 유지 + `video.stt` 라우팅·사용량 기록, 대화형 발화만 공용 음성 서버 (b) 파이프라인 STT도 공용 음성 서버 `/stt`로 일원화(10분·50MB 한도 상향과 워커의 토큰 발급 경로 필요) | (a)(제안). 원본 60초 클립은 한도 안이지만 롱폼 역방향 자막(최대 60분)과 원본 500MB가 공용 서버 한도를 넘는다. 한도 상향이 확인되면 재검토 |
| D-14 | OpenAI TTS-1-HD 백업 처리 | (a) 제거하고 체인을 `elevenlabs → oss-voice`로 대체 (b) 코어 `openai` 제공자 kinds에 `tts` 추가 요청 | (a)(제안). 코어 제공자 `openai`는 `llm`만이다(`docs/products/_supabase-modular/seed.sql:216`). 요청 R-V2를 열어 두고 (a)로 진행 |
| D-15 | 오픈소스 TTS 내레이션 모델과 언어 범위 | (a) KO 먼저, JA·EN은 품질 검증 통과 시 노출 (b) 3언어 동시 | (a)(제안). 후보는 `VOICE_ARCHITECTURE.md` 4.1절(코드·가중치 라이선스와 3언어 품질 확인 전 채택하지 않음). 통과 전 JA·EN은 ElevenLabs만 선택 가능 |
| D-16 | 같은 목소리 규칙의 범위 | (a) 언어판(숏폼)·롱폼 프로젝트 단위 (b) 채널 시리즈 단위까지 보이스 고정 | (a)(제안). (b)는 채널·브랜드 가이드 위키에 "채널 보이스" 항목을 두고 권고만 표시하는 선에서 시작 |
| D-17 | 3D 히어로 타일 질감 | (a) 자체 제작 샘플 영상의 정지 프레임만 (b) 단색 타일 | (a)(제안). 도우인 등 제3자 원본 프레임은 쓰지 않는다. 샘플은 운영사가 권리를 가진 자체 제작물 |
| D-18 | 트렌드 RAG 수집 범위 | (a) 플레이보드·SerpApi 지표 요약 + 출처 링크만 색인 (b) 제목·본문 전문 색인 | (a)(제안). 제공자 약관의 재가공·보관 허용 범위는 미확인이므로 확인 전까지 요약 지표만. 약관이 금지하면 해당 출처 제외 |
| D-19 | 채팅 화면 레퍼런스 Astryx | 존재·라이선스 확인 후 패턴만 사용 / 확인 실패 시 Primer + shadcn/ui 패턴 | 확인 전까지 미확인(`docs/products/_design-guide/DESIGN_SYSTEM.md:11`). VID-06-041에서 확인 결과를 기록 |
| D-20 | 파이프라인 LLM 단계(translate, analyze, bling, compliance LLM)의 경로 | (a) FastAPI 1노드 그래프 `video.step`으로 등록해 서명 토큰 경로 사용 (b) 코어에 단일 호출 엔드포인트 추가 요청(R-V4) 후 사용 | (a)(제안). 코어 엔드포인트가 생기면 (b)로 옮긴다. 어느 쪽이든 LLM 키는 FastAPI에만 둔다 |
| D-21 | 코어 제공자 목록에 없는 외부 서비스(DeepL, fal, Suno)의 국외 이전 고지 | (a) 온보딩 국외 이전 화면에 별도 항목으로 고지하고 동의 없으면 해당 기능 비활성 (b) 약관·처리방침 고지만 | (a)(제안). 라우팅 레지스트리 편입은 코어 요청 R-V3 |
| D-23 | 네이버 클립 업로드 방식(VD-F-075) | (a) Playwright 자동 업로드 + 위험 동의 (b) 업로드 패키지(영상·메타·문구)만 만들고 사용자가 PC 웹에서 직접 올림 (c) 공식 API | (a)로 확정(사용자 결정 2026-10-13). 공식 업로드 API·파트너 제휴가 확인되면 (c)로 어댑터만 교체한다. 셀렉터 실패율이 주 10%를 넘으면 (b)를 대체 경로로 연다(제안) |
| D-24 | 대행 기능 외부 판매 | (a) 내부 도구로만(운영사·Advanced 조직) (b) Phase 2에 대행사용 플랜(고객 포털 로그인, 화이트라벨 도메인, 고객별 과금·크레딧 분리) | (a)로 시작(사용자 결정 2026-10-13: 직접 대행 + 내부 도구). 직접 대행 고객 10곳 이상 운영 뒤 (b) 검토 |
| D-25 | 고객 승인 링크 수단 | (a) 메일 링크(토큰 72시간) (b) 카카오 알림톡 (c) 고객 포털 로그인 | (a)(제안). (b)는 발신 프로필·템플릿 심사가 필요하고 (c)는 D-24 (b)와 함께 |
| D-22 | 내레이션 TTS 호출 위치와 ElevenLabs 키 | (a) 오케스트레이터(서버 전용 TS 워커)가 `packages/core-voice`로 호출 (b) Next.js Route Handler만 호출(요청 시간 한도 안에서만 가능) | (a)(제안). 롱폼 10분 x 3언어 합성은 요청-응답 시간 안에 끝나지 않는다. `VOICE_ARCHITECTURE.md:79`의 "Next.js 서버에서만"을 "브라우저와 클라이언트 번들 밖의 서버 전용 프로세스"로 넓히는 확인을 코어에 요청(R-V6). 오픈소스 음성 서버 호출에는 잡에 묶인 서명 토큰이 필요하다(R-V5) |

### 8.1 인증 단계 결정 (2026-10-14, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md`다. 아래는 이 제품에서 정해야 할 것만 둔다. D-26은 위 표의 D-25 다음 번호다.

| # | 항목 | 선택지 | 권고 |
|---|---|---|---|
| D-26 | 카카오 이메일 정책(C1, `AUTH_ROADMAP.md` 7.1.2절) | (a) 비즈 앱 전환 후 `account_email` 필수 동의 (b) 이메일 없이 허용(결제·알림 전에 연락 이메일을 따로 받음) | (a). 영수증·알림 메일·Google 가입자와의 계정 연결이 Google과 같아진다. 운영 주체의 사업자등록이 있으면 전환 비용은 서류 입력뿐(`AUTH_ROADMAP.md` 7.1.2절). (b)는 전환 전 임시로만 |
| D-27 | 네이버 로그인 경로(C2) | (a) Supabase 커스텀 OAuth2 `custom:naver` (b) 서버 브리지 + 코어 `staged/0010_core_auth_identity_links.sql` | VID-06-065 첫 단계 스파이크(0.5일, `AUTH_ROADMAP.md` 7.2.2절)의 결과로 정한다. 커스텀 OAuth2가 네이버의 중첩 응답(`response.id`, `response.email`)을 읽는지는 미확인. 결과는 task `log.md` `[DECISION]`과 `NAVER_AUTH_PATH`에 남긴다 |
| D-28 | 이메일+비밀번호 가입 유지 여부 | (a) 유지(Google과 함께 B단계에서 켬) (b) 제거(Google·카카오·네이버만) | (a). VD-F-001의 기존 결정(이메일+Google)을 바꾸지 않는다. 이메일 가입 화면·메일 인증·비밀번호 재설정 화면은 Stage A에서 만들지 않고 B 작업(VID-06-063)이 만든다 |
| D-29 | 로그인용 Google OAuth 클라이언트와 채널 연결용(YouTube) OAuth 클라이언트 | (a) 별도 클라이언트(로그인은 Supabase 콜백, 범위 `openid email profile`만. 채널은 앱 콜백 `/api/channels/callback/youtube`와 YouTube 범위) (b) 한 클라이언트에 리디렉션 URI 두 개 | (a)(제안). 로그인 동의 화면에 YouTube 범위가 섞이지 않게 한다. 두 클라이언트가 같은 Google Cloud 프로젝트의 동의 화면을 공유하는지, 그때 검증 범위가 어떻게 되는지는 미확인. 환경변수 이름이 겹친다: 채널용은 앱 env `GOOGLE_CLIENT_ID/SECRET`(02장 8절), 로그인용은 `supabase/config.toml`의 `env(GOOGLE_CLIENT_ID)`(`AUTH_ROADMAP.md` 3.4절). 같은 셸에서 `supabase start`와 앱을 띄우면 값이 섞이므로 채널용 이름을 `YOUTUBE_CLIENT_ID/SECRET`로 바꿀지 VID-06-063 전에 정한다(제안) |

D-5(네이버 로그인)는 결정 22로 C2 확정되어 해소했다. 기존 표에 카카오 관련 열린 결정은 없었다.

## 9. 인증 단계 범위 (2026-10-14 추가, 확정 결정 22)

2절 머리말(인증 범위)의 단계별 상세다. 2절 표에 행을 넣으면 4장 줄 번호가 밀려 외부 참조(`Price_Plans/nomad-video/PRICE_PLAN.md:13`의 `01_PRD.md:140-233`)가 어긋나므로 표 대신 이 절에 둔다. "로그인"은 이 제품 사용자(크리에이터, 대행 운영팀)의 계정 로그인만 뜻한다. 채널 연결 OAuth(YouTube·Meta·TikTok, `core.oauth_states`, VD-F-070)와 네이버 클립 업로드용 네이버 로그인 세션(Playwright, `CredentialVault` provider `naver`, VD-F-075)은 사용자 로그인과 별개이며 이 단계의 영향을 받지 않는다.

| 단계 | 범위 | 언제 | 켜지는 로그인 | 우선순위 | 작업 |
|---|---|---|---|---|---|
| A | MVP 개발 | W0부터 G1까지 | 로컬 Supabase 시드 계정(페르소나) 원클릭 로그인. 제공자 버튼 없음. 쿠키 역할 Mock 금지 | P0 | VID-06-004 |
| B | 공개 베타 전 필수 | G1(`AUTH_ROADMAP.md` 4장) 통과 후 | Google + 이메일(D-28). 배포 환경에서 Mock 차단 | P0 | VID-06-063 |
| C1 | 출시 후 | G2(`AUTH_ROADMAP.md` 6장) 통과 후 | 카카오(Supabase 기본 제공자 `kakao`) | P1(`AUTH_ROADMAP.md` 8장 nomad-video 행) | VID-06-064 |
| C2 | 출시 후 | G2 통과 후, C1과 병렬 가능 | 네이버(`custom:naver` 또는 브리지, D-27) | P1 | VID-06-065 |
| 해당 없음 | 로그인 없는 흐름 | 단계와 무관 | 공개 랜딩 `/landing/[slug]`, 링크인바이오 `/lb/[handle]`, 단축 링크 `/r/[code]` 방문자, 대행 고객의 승인 화면 `/review/[token]`(토큰 소지자, VD-F-123)에는 로그인 버튼을 추가하지 않는다. 고객사 담당자는 계정을 만들지 않고 시드 페르소나도 없다. 고객 포털 로그인(D-24 (b), D-25 (c))은 Phase 2이며 이 로드맵 범위 밖이다 | - | - |

Apple 로그인과 매직링크는 이 로드맵 범위 밖이다(`AUTH_ROADMAP.md` 1장).
