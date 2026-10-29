# 01 PRD: SceneFlow (sceneflow)

근거 약칭: PRD=`NOMAD Shorts Maker/PRD.md`, ADD=`NOMAD Shorts Maker/PRD_add.md`, PRC=`NOMAD Shorts Maker/PRD_pricing.md`, MA=`docs/products/00_MERGE_ANALYSIS.md`, SM/BS/YSM=`docs/reviews/NOMAD_Shorts_Maker.md` / `Nomad-BlogStudio.md` / `Youtube_shots_Maker.md`. 근거 없는 값은 "제안", 외부 사실을 확인하지 않은 값은 "미확인"으로 표시한다.

2026-10-13 개정: 확정 결정 13~17(`docs/products/00_MERGE_ANALYSIS.md:21-25`)에 따라 AI 계층(채널 코치 채팅, RAG, 채널·브랜드 가이드 위키, LangGraph `video.script`), 음성(음성 대화, 오픈소스 TTS 내레이션 선택, Whisper STT의 공용 음성 구조 편입), 상용/오픈소스 모델 이원화와 국외 이전 동의, 3D 히어로를 MVP에 넣었다. 설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `docs/design-module/_design-guide/HERO_3D.md`, `DESIGN_SYSTEM.md`이고 이 문서는 제품 요구만 정한다. 기능 ID는 `VD-F-100`번대(AI), 열린 결정은 `D-13` 이후다(기존 #1~#12는 `D-1`~`D-12`와 같다).

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
| Track C Mode1(대본→이미지→켄번스), Mode2(원본 재편집) | MVP (2026-10-18: 10장 Track S로 통합, SF-1) | 확정 결정 7 |
| Track D 롱폼 10섹션 + OSMU 하이라이트 3개 | MVP (2026-10-18: 10장 Track S로 통합, SF-1) | 확정 결정 7 |
| Track E Lofi 단일 곡(Suno) + 단일 곡 루프 영상 + DSP 유통 패키지(수동 제출) | Phase 2(2026-10-18, SF-3) | 확정 결정 7. 관리 단위는 곡 |
| Track F 플레이리스트(30분/1시간/3시간, 트랙리스트·타임스탬프·무드 썸네일·고정 댓글) | Phase 2(2026-10-18, SF-3) | 확정 결정 7. 관리 단위는 플레이리스트 프로젝트 |
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
| 랜딩 3D 히어로(소싱 → 가공 → 다채널 배포 영상 타일 파이프라인) | MVP | 확정 결정 15(`docs/products/00_MERGE_ANALYSIS.md:23`), `docs/design-module/_design-guide/HERO_3D.md:83` |
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
| VD-F-002 | 라우트 보호 | 통합 | `proxy.ts`가 `/dashboard/**`, `/api/**` 보호. 공개 예외: `/`, `/pricing`, `/legal/**`, `/landing/**`, `/lb/**`, `/r/**`, `/review/**`·`/api/review/**`(대행 고객 승인, 토큰, VD-F-123), `/api/webhooks/**`, `/billing/success\|fail`, `/login`, `/api/dev/login`(A, 판정이 거짓이면 404), `/auth/callback`(B). 쿠키 역할 Mock 금지, 개발용 로그인은 `AUTH_ROADMAP.md` 2장의 로컬 시드 계정만(`/api/dev/login`, 배포 환경 404) | 비로그인으로 `/dashboard` 접근 시 `/login` 302, `/landing/x` 200, 배포 빌드에서 `/api/dev/login` 404 | SM #6, BS #10, 확정 결정 22 |
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
| VD-F-110 | 3D 히어로 | 신규 | 랜딩 히어로: PC·태블릿은 원본 클립 타일이 소싱 레인에서 들어와 가공 게이트에서 언어판(KO/JA/EN) 타일로 갈라지며 번인 자막 띠가 붙고 다채널 슬롯에 안착하는 풀 3D, 모바일은 타일 수를 줄인 1줄 흐름, WebGL 미지원·저사양·`prefers-reduced-motion`은 정지 이미지(03장 4.5절). 사용자 결정 2026-10-13으로 기존 "플레이헤드 1회 스윕" 연출을 대체한다 | `HERO_3D.md` 4절 수용 기준 전부: 기기별 3종 동작, 3D 번들+에셋 PC·태블릿 1MB/모바일 300KB 이하, LCP 2.5초, 제목·입력·CTA가 3D 전에 보이고 키보드로 사용 가능, 3종 스크린샷 고문 검토 통과. 생성 건수·수익 같은 미검증 수치 0 | `docs/design-module/_design-guide/HERO_3D.md:5-81`, `:83` |
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

정본: PRC(확정 결정 8). 가격은 모두 VAT 포함(B2C SaaS, 2026-10-14 `Price_Plans/_common/PRICING_PRINCIPLES.md` 7장). 단계별 가격 계획(런칭 할인, 연간 결제, 중·장기 인상)은 `Price_Plans/sceneflow/PRICE_PLAN.md` 6장이며 이 표를 바꾸지 않는다. 모듈러 `seed.sql:209-223`, 모놀리스 `supabase/monolith/seed.sql`과 같다. Track F는 확정 결정으로 추가된 Track이라 PRC에 없다. E와 같은 Suno 엔진을 쓰므로 Pro 이상으로 둔다(모듈러 seed와 같음, 제안).

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

크레딧팩(PRC:149-154): pack_500 15,000원 / pack_1000 28,000원 / pack_3000 75,000원 / pack_5000 110,000원. Advanced 전용 adv_pack 4종 12,000 / 22,400 / 60,000 / 88,000원(정가의 20% 할인. 2026-10-14 30% → 20%: 30% 할인팩은 상용 TTS·채팅 작업에서 70% 매출총이익률에 못 미칠 수 있다, `Price_Plans/sceneflow/PRICE_PLAN.md` 3.2절). 모듈러 seed에도 adv_pack이 반영되었다(2026-10-13, 모놀리스 seed와 일치).

AI 키 4개(`ai_chat`, `ai_chat_turns_per_day`, `voice_chat`, `ai_script`)는 2026-10-13에 추가했다. 모놀리스는 `supabase/monolith/seed.sql`의 플랜 4행에, 모듈러는 `docs/products/_supabase-modular/migrations/1200_video.sql` 11절의 병합 UPDATE에 있다(모듈러 `seed.sql` 반영은 06장 6절 R-V1). 플랜 가격·월 크레딧·팩은 바꾸지 않았다.

### 4.1 AI·음성 크레딧 단가 (2026-10-13, 제안)

기존 단가표(위)와 크레딧팩은 바꾸지 않는다. 제공자 단가는 코어 seed `core.ai_model_prices`(`docs/products/_supabase-modular/seed.sql:228-246`: LLM 상용 1k 입력 1cr·출력 4cr, 오픈소스 0.2·0.5cr, STT ElevenLabs 3cr/분·오픈소스 0.5cr/분, TTS ElevenLabs 5cr/천 자·오픈소스 1cr/천 자, 모두 제안값)이고 이 표는 그 값을 video 기능에 적용한 것이다. 계산 상수는 `apps/sceneflow/src/server/ai-pricing.ts`(기존 `priceOf`와 같은 이유로 코드 상수, VID-06-046 소유). 선차감과 정산 규칙은 `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130`, 음성 단가는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104`를 따른다.

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
| 3D 히어로 | 3D 번들+에셋 PC·태블릿 1MB, 모바일 300KB 이하, 60fps / 30fps 이상 | `docs/design-module/_design-guide/HERO_3D.md:32-41` |
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
   SceneFlow는 회원님의 네이버 계정으로 클립 크리에이터 PC 웹에 로그인해 화면을 자동으로 조작합니다.
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
| D-19 | 채팅 화면 레퍼런스 Astryx | 존재·라이선스 확인 후 패턴만 사용 / 확인 실패 시 Primer + shadcn/ui 패턴 | 확인 전까지 미확인(`docs/design-module/_design-guide/DESIGN_SYSTEM.md:11`). VID-06-041에서 확인 결과를 기록 |
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

2절 머리말(인증 범위)의 단계별 상세다. 2절 표에 행을 넣으면 4장 줄 번호가 밀려 외부 참조(`Price_Plans/sceneflow/PRICE_PLAN.md:13`의 `01_PRD.md:140-233`)가 어긋나므로 표 대신 이 절에 둔다. "로그인"은 이 제품 사용자(크리에이터, 대행 운영팀)의 계정 로그인만 뜻한다. 채널 연결 OAuth(YouTube·Meta·TikTok, `core.oauth_states`, VD-F-070)와 네이버 클립 업로드용 네이버 로그인 세션(Playwright, `CredentialVault` provider `naver`, VD-F-075)은 사용자 로그인과 별개이며 이 단계의 영향을 받지 않는다.

| 단계 | 범위 | 언제 | 켜지는 로그인 | 우선순위 | 작업 |
|---|---|---|---|---|---|
| A | MVP 개발 | W0부터 G1까지 | 로컬 Supabase 시드 계정(페르소나) 원클릭 로그인. 제공자 버튼 없음. 쿠키 역할 Mock 금지 | P0 | VID-06-004 |
| B | 공개 베타 전 필수 | G1(`AUTH_ROADMAP.md` 4장) 통과 후 | Google + 이메일(D-28). 배포 환경에서 Mock 차단 | P0 | VID-06-063 |
| C1 | 출시 후 | G2(`AUTH_ROADMAP.md` 6장) 통과 후 | 카카오(Supabase 기본 제공자 `kakao`) | P1(`AUTH_ROADMAP.md` 8장 sceneflow 행) | VID-06-064 |
| C2 | 출시 후 | G2 통과 후, C1과 병렬 가능 | 네이버(`custom:naver` 또는 브리지, D-27) | P1 | VID-06-065 |
| 해당 없음 | 로그인 없는 흐름 | 단계와 무관 | 공개 랜딩 `/landing/[slug]`, 링크인바이오 `/lb/[handle]`, 단축 링크 `/r/[code]` 방문자, 대행 고객의 승인 화면 `/review/[token]`(토큰 소지자, VD-F-123)에는 로그인 버튼을 추가하지 않는다. 고객사 담당자는 계정을 만들지 않고 시드 페르소나도 없다. 고객 포털 로그인(D-24 (b), D-25 (c))은 Phase 2이며 이 로드맵 범위 밖이다 | - | - |

Apple 로그인과 매직링크는 이 로드맵 범위 밖이다(`AUTH_ROADMAP.md` 1장).

## 10. 스토리보드 엔진 (2026-10-18 추가, 스토리보드 디벨롭)

2026-10-18 개정(스토리보드 디벨롭): 사용자 확정 결정 SF-1~SF-4(10.1절)에 따라 Track C Mode1(원본 없이 생성)과 Track D(롱폼)를 **Track S(스토리보드 트랙)** 하나로 합쳤다. Track C Mode2(원본 재편집)는 Track A의 옵션으로 흡수하고, Track E·F는 Phase 2로 옮겼다. 이제 트랙은 A, B, S, E, F다. 기존 장의 줄 수는 바꾸지 않았다. 범위 이동은 2절 표의 Track C·D·E·F 행과 `docs/products/00_MERGE_ANALYSIS.md:15`(확정 결정 7)에 같은 줄로 적었다. 기존 VD-F-032(Track C, `docs/products/sceneflow/01_PRD.md:90`), VD-F-040(Track D, `:94`), VD-F-041(OSMU, `:95`)은 지우지 않고 이 장의 VD-F-130~142가 대체한다. 다른 장에 남은 "Track A~F" 표기와 이 장이 다르면 이 장을 따른다. 스토리보드 구조는 book-trailer 스토리보드(`docs/products/book-trailer/01_PRD.md:82-85`, `:102`)와 toon-factory 콘티 그래프(`docs/products/toon-factory/01_PRD.md:136`)를 이식했다. 렌더 엔진은 FFmpeg 하나다(VD-F-033 유지). 다른 문서는 "01장 10.2절 VD-F-13x"로 인용한다. 화면은 03장, API는 04장, 데이터는 05장, 작업은 06장의 끝에 붙인 새 장이 맡는다.

### 10.1 확정 결정과 새 페르소나

| ID | 확정 결정(2026-10-18, 사용자) |
|---|---|
| SF-1 | Track C Mode1과 Track D를 Track S(스토리보드 트랙) 하나로 합친다. Track C Mode2(원본 재편집)는 Track A와 같은 파이프라인이므로 Track A의 옵션으로 흡수한다. 트랙은 A, B, S, E, F |
| SF-2 | MVP 렌더 엔진은 FFmpeg 하나(VD-F-033 유지). Remotion(장면 모션 그래픽)은 Phase 2에 검토한다(D-30, book-trailer와 렌더러 공용화 검토 포함) |
| SF-3 | Track E(Lofi 음원)와 Track F(플레이리스트)는 Phase 2로 옮긴다. 기획·DB는 지우지 않고 범위만 옮긴다 |
| SF-4 | 첫 고객은 지식·역사 채널 운영자다. 대행사(지훈 페르소나)는 그다음이다 |

핵심 가치: **스토리보드 하나로 롱폼 1편 + 장면 단위 쇼츠 여러 편 + 언어판(KO/JA/EN)을 만든다.**

| 페르소나 | 상황 | 목표 | 좌절 |
|---|---|---|---|
| 현우(44, 한국사·지식 유튜브 채널 운영, 1인) | 혼자 대본·이미지·편집·업로드를 한다. 첫 고객군(SF-4) | 주 1편 10~15분 롱폼과 거기서 뽑은 쇼츠 5편을 꾸준히 올린다 | 롱폼 한 편 대본·이미지·편집에 하루가 걸리고, 쇼츠는 따로 다시 만들어야 한다. 사실 확인과 출처 정리가 번거롭다 |

| 핵심 과제 | 측정 |
|---|---|
| 주제에서 마스터 컷까지 한 흐름으로 끝낸다 | 롱폼 10분 1언어, 스토리보드 생성부터 마스터 컷 ready까지 p90 2시간 이내(5장 롱폼 값, PRD:721) |
| 같은 스토리보드에서 쇼츠를 뽑는다(쇼츠를 따로 만들지 않는다) | 쇼츠 5편 추출 요청부터 5편 ready까지 p90 30분 이내(제안) |
| 장면 하나만 고친다(전체를 다시 만들지 않는다) | 장면 다시 만들기 비용 = 그 장면 단가만(10.4절) |
| 사실 주장에 출처를 붙인다 | 출처 없는 사실 주장 장면이 사용자 확인 없이 업로드된 건수 0 |

트랙 대응표:

| 기존 | 2026-10-18 이후 | 기능 요구 |
|---|---|---|
| Track A | Track A 그대로 + "원본 재편집" 옵션(기존 Track C Mode2) | VD-F-030, VD-F-032 Mode2 부분 |
| Track B | 그대로 | VD-F-031 |
| Track C Mode1 | Track S 쇼츠 형식 | VD-F-130~141 |
| Track D | Track S 롱폼 형식 | VD-F-130~141, 이전은 VD-F-142 |
| Track E, F | Phase 2(SF-3) | VD-F-050, 051 그대로(범위만 이동) |

### 10.2 기능 요구사항과 수용 기준

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| VD-F-130 | 스토리보드 프로젝트 만들기 | 신규 | 순서: 형식(`shorts`/`longform`) → 길이 프리셋(10.3절) → 템플릿(10.3절 5종) → 주제 → 언어(KO/JA/EN, 플랜 `languages` 안). 화면비 기본값은 형식이 정한다(쇼츠 9:16, 롱폼 16:9). 화면비·해상도·fps 선택은 11장 VD-F-143. 롱폼 길이는 `storyboard_max_minutes` 이하. 대행 조직은 `client_id`를 붙일 수 있고 VD-F-122 규칙을 따른다. 주제 점수 게이트(VD-F-013)를 그대로 쓴다 | 점수 59 요청 시 409 `VD010` + `alternatives` 3개. `storyboard=false` 조직 403 `VD009`. Basic 조직의 20분 롱폼 요청 403 `VD009`. 성공 시 `video.storyboards` 1행(status `draft`, version 1) | VD-F-013(`docs/products/sceneflow/01_PRD.md:85`), TR-F-031(`docs/products/book-trailer/01_PRD.md:83`) |
| VD-F-131 | 스토리보드 생성 | 신규(VD-F-032 Mode1, VD-F-040 대체) | 대본은 그래프 `video.script`(VD-F-103)를 재사용한다. 사용자가 대본을 확인하면 그래프 `video.storyboard`가 대본 + 템플릿 비트 + 목표 길이로 장면 목록 JSON을 만든다. 장면마다 종류(`scene_kind`), 길이, 화면 문구(160자 이하), 내레이션(600자 이하), 시각 설명(600자 이하), 모션 프리셋, 음악 큐, 챕터(롱폼), 쇼츠 후보 표시, 사실 주장 여부(`source_required`). 마지막 노드는 compliance(6장 금지 문구 + 10.5절). 결과 저장은 서버 RPC `video.apply_storyboard_result`만 한다. 잡 `storyboard.generate`. 전체 다시 생성은 장면을 교체하고 version을 1 올린다 | 장면 길이 합계 = 목표 길이 ±10%. 그래프가 범위를 벗어나면 1회 재작성, 그래도 벗어나면 run `failed` + 환불(`VD017`). 장면 수: 쇼츠 3~12, 롱폼 분당 3~8, 최대 240(초과 `VD018`). 실행 1건 = `core.ai_runs` 1행 + 노드별 `ai_run_steps`. 출처 없는 수치 0(VD-F-103 규칙). 다시 생성 후 version +1 | TR-F-031(`docs/products/book-trailer/01_PRD.md:83`), TN-F-052 콘티 그래프(`docs/products/toon-factory/01_PRD.md:136`), VD-F-032(`docs/products/sceneflow/01_PRD.md:90`), VD-F-040(`:94`), VD-F-103(`:116`) |
| VD-F-132 | 장면 편집 | 신규 | 문구·내레이션·길이·시각 설명·모션·음악 큐·챕터 수정, 장면 추가·삭제·순서 변경, 쇼츠 후보 표시. 사용자 RPC `video.save_scene(p_scene_id, p_revision, p_patch)`, `video.reorder_scenes`, `video.add_scene`, `video.delete_scene`, `video.set_shorts_candidate`. 장면 저장은 장면 `revision`, 순서 변경·추가·삭제는 스토리보드 `revision`으로 낙관적 동시성을 지킨다. 편집 중에는 길이 합계가 잠시 범위를 벗어나도 저장하고 상단 게이지로 경고한다(제안). 범위 검사는 렌더 요청 때 서버가 한다. 편집 저장은 0크레딧 | 두 탭에서 같은 장면을 고치면 늦은 쪽이 `VD409`를 받고 최신본을 다시 불러온다. status `rendering`일 때 편집 `VD020`. 241번째 장면 추가 `VD018`. 다른 조직 장면 저장 0행(RLS) | TR-F-032(`docs/products/book-trailer/01_PRD.md:84`), toon 컷 저장(`docs/products/_supabase-modular/migrations/2000_toon.sql:476-497`), VD-F-040 섹션 편집(`docs/products/sceneflow/01_PRD.md:94`) |
| VD-F-133 | 장면 단위 다시 만들기 | 디벨롭(TR-F-033 이식) | 장면 하나의 이미지 또는 내레이션(언어 하나)만 다시 만든다(`{part: image\|narration, lang?}`, 잡 `scene.image`, `scene.narration`). 이전 소재는 `superseded`로 남긴다. 내레이션은 같은 목소리 규칙(VD-F-106)을 따른다: 그 스토리보드에 처음 기록된 제공자·보이스를 쓴다. 이전 소재로 되돌리기 1단계는 P1 | 비용은 그 장면 단가만(이미지 3, 내레이션 1, 10.4절). 다시 만든 뒤 같은 장면·종류·언어의 `ready` 소재는 1행, 나머지는 `superseded`. 보이스가 다르면 422 `VD013`. 실패하면 그 장면분 환불 1행 | TR-F-033(`docs/products/book-trailer/01_PRD.md:85`), VD-F-106(`docs/products/sceneflow/01_PRD.md:119`) |
| VD-F-134 | 장면 소재 | 신규 | `image` 장면: AI 이미지(fal, 기존 이미지 단가), 사용자 이미지 업로드, 같은 조직의 기존 이미지 재사용(`reused_from_asset_id`, 0크레딧). `clip` 장면: 사용자 원본·업로드 클립, 권리 근거(`rights_basis`, VD-F-020의 4종) 필수. `text_card`·`title` 장면: 렌더 워커가 글자 카드를 그린다(이미지 생성 없음). `video.scene_assets`는 서버 쓰기만, `storage_path`는 자기 조직 폴더 CHECK. AI가 만든 소재는 `ai_generated=true` | 권리 근거 없는 clip 소재 `VD019`. 다른 조직 경로 23514. 사용자 세션의 직접 INSERT 42501. 재사용 이미지는 원장 행을 만들지 않는다. 업로드 파일 상한은 5장 원본 상한(500MB) | VD-F-020(`docs/products/sceneflow/01_PRD.md:86`), VD-F-032 fal 이미지(`:90`) |
| VD-F-135 | 브라우저 미리보기 | 신규 | 편집기 오른쪽 타임라인에서 장면 이미지·오디오를 순서대로 재생한다. 모션 프리셋은 브라우저 변환으로 근사한다(제안). 서버 렌더 없음, 0크레딧, 다운로드 경로 없음 | 미리보기가 잡·원장 행을 만들지 않는다. 화면에 다운로드 버튼이 없다. 미리보기 시작 2초 안 첫 프레임(제안) | TR-F-051(`docs/products/book-trailer/01_PRD.md:103`). book-trailer의 Remotion Player 대신 SF-2에 따라 렌더러 없는 브라우저 재생만 둔다 |
| VD-F-136 | 스토리보드 렌더 | 신규(VD-F-040 인코딩 대체) | FFmpeg로 마스터 컷 1개를 렌더한다(잡 `storyboard.render`, media-worker cpu 큐). 장면 순서대로 이미지 + 모션(zoom·pan, 켄번스), clip, 글자 카드를 잇고 내레이션·BGM·자막을 얹는다. 자막·레이어 순서와 단일 엔진 규칙은 VD-F-033. 언어판은 언어마다 내레이션·자막만 바꿔 렌더한다. 렌더 전 서버 검사: 길이 합계 ±10%, 모든 장면 소재 ready, clip 권리 근거. 렌더마다 스냅샷(VD-F-139). Starter 워터마크 규칙(VD-F-034) 유지. 산출물은 `video.outputs.storyboard_cut_id`로 연결 | 범위 밖 합계 `VD017`. 렌더 중 편집 `VD020`. 같은 스냅샷으로 다시 렌더하면 장면 순서·길이가 같다(프레임 해시 비교는 제안). 10분 1언어 p90 2시간 이내(5장). 언어판 1개 실패 시 그 언어분만 환불(VD-F-035) | VD-F-033(`docs/products/sceneflow/01_PRD.md:91`), VD-F-040(`:94`), TR-F-050(`docs/products/book-trailer/01_PRD.md:102`) |
| VD-F-137 | 쇼츠 추출 | 신규(VD-F-041 대체) | 마스터 컷 ready 뒤, 그래프 `video.shorts_pick`이 쇼츠 후보 장면에서 연속 장면 묶음과 훅 문구를 제안한다(잡 `storyboard.shorts`). 사용자가 고른 묶음을 9:16 컷(`storyboard_cuts.kind=short`)으로 렌더한다. 최대 10편, 플랜 `shorts_extract_max` 이하. 16:9 이미지 장면의 세로 구도는 다시 만들기(이미지 단가) 또는 크롭 중 고른다(기본값은 D-32). `text_card`·`title` 장면은 9:16으로 다시 그린다(0크레딧, 제안). 컷 길이는 60초 이하(제안: 기존 VD-F-041 규칙 유지) | 11번째 컷 `VD021`. 플랜 한도 초과 403 `VD009`(제안). 컷의 `scene_ids`가 연속이 아니면 22023. 컷마다 `outputs` 1행 | VD-F-041(`docs/products/sceneflow/01_PRD.md:95`), TR-F-050 멀티포맷(`docs/products/book-trailer/01_PRD.md:102`) |
| VD-F-138 | 출처 칸과 사실 확인 경고 | 신규 | 장면마다 출처 칸(최대 5개: 제목, URL, 메모). 그래프가 사실 주장 장면에 `source_required=true`를 표시한다. 출처 점검(잡 `storyboard.source_check`)이 출처 없는 사실 주장 장면을 WARN으로 표시한다. WARN은 업로드 compliance에서 사용자 확인 후 진행한다(VD-F-072 WARN 규칙과 같음). FAIL 승격 여부는 D-33. 업로드 설명란에 "참고 자료" 목록을 자동으로 넣는다(대가성 문구 첫 줄 규칙 다음). 그래프는 출처 URL을 지어내지 않는다: 근거 id(RAG·검색 결과)가 있는 출처만 제안한다 | 편집기 상단에 출처 경고 수가 보인다. 출처 없는 사실 주장 장면이 있는 업로드는 compliance verdict WARN. 설명란에 장면 출처 목록이 있다. `has_affiliate=true`면 첫 줄은 여전히 대가성 문구(DB CHECK) | VD-F-072(`docs/products/sceneflow/01_PRD.md:105`), VD-F-103 근거 id 규칙(`:116`) |
| VD-F-139 | 스토리보드 버전과 렌더 스냅샷 | 신규 | 렌더 요청마다 서버 RPC `video.snapshot_storyboard`가 장면 내용과 소재 참조를 `video.storyboard_snapshots`에 1행 저장한다. 스냅샷은 읽기 전용이며 버전별로 열람한다 | 렌더마다 스냅샷 1행. 스냅샷 UPDATE·DELETE 42501. 이전 버전을 열면 그때의 장면 목록이 보인다 | TR-F-050 렌더 시점 스냅샷(`docs/products/book-trailer/01_PRD.md:102`) |
| VD-F-140 | 음성 지시 편집(11장 VD-F-146 AI 편집 지시의 음성 입력으로 흡수, MVP로 올림) | 신규, P1 → MVP(11장) | 편집기 마이크 버튼. 받아쓰기(공용 음성 규칙: 60초, 원본 미저장, 첫 사용 고지) → 텍스트 확인 → 서버가 편집 패치로 바꾼다("3번 장면 더 짧게") → 사용자가 변경 내용을 보고 적용한다(`save_scene`과 같은 경로). 확인 없이 적용하지 않는다 | 사용자 확인 전 장면 변경 0. `voice_jobs.store_audio=false` 100%. 크레딧: STT는 4.1절 단가, 패치 변환 1(제안) | VD-F-104(`docs/products/sceneflow/01_PRD.md:117`), VD-F-107(`:120`) |
| VD-F-141 | 스토리보드 템플릿 5종 | 신규 | `video.storyboard_templates`에 운영자 seed 5종(10.3절). 템플릿은 비트(이야기 단계와 비중)와 기본 장면 길이를 가진다. 쇼츠·롱폼 모두에 쓴다. 사용자 템플릿 만들기는 MVP에 없다 | 비트 비중 합계 100(seed 검사). `status`가 비활성인 템플릿은 선택지에 없다. 사용자 세션의 템플릿 쓰기 42501 | TR-F-030 문법 카탈로그(`docs/products/book-trailer/01_PRD.md:82`) |
| VD-F-142 | 기존 Track D 데이터 이전 경로 | 신규(개발 착수 전 정리 작업) | `longform_projects`/`longform_sections`/`longform_highlights` → `storyboards`/`scenes`/`storyboard_cuts` 대응표와 이전 스크립트를 만든다. 섹션 1개 → `image` 장면 1개(섹션 이미지·내레이션을 소재로), 하이라이트 1개 → `short` 컷 1개. 기존 테이블은 지우지 않고 "Track S로 대체" 주석을 단다. 삭제 시점은 D-34 | 대응표가 05장 새 장에 있다. 새 Track D 생성 경로 0(API는 Track S로 안내). 이전 스크립트 dry-run에서 섹션 수 = 장면 수 | VD-F-040(`docs/products/sceneflow/01_PRD.md:94`), VD-F-041(`:95`) |

### 10.3 Track S 흐름, 형식 프리셋, 장면 종류, 템플릿

```
주제(레이더·주제 점수 60 게이트, VD-F-013 유지) → 대본(video.script 그래프 재사용)
 → 스토리보드 생성(video.storyboard 그래프) → 장면 편집·장면 다시 만들기 → 장면 소재 생성
 → 미리보기(브라우저 타임라인, 서버 렌더 없음) → 렌더(FFmpeg, 마스터 컷)
 → 쇼츠 추출(쇼츠 후보 장면 → 9:16 컷) → 언어판(TTS·자막) → compliance → 업로드
```

Track S는 `video.productions`를 쓰지 않고 `video.storyboards`를 쓴다(05장 새 장). 업로드·compliance·제휴 문구 경로는 기존과 같다(VD-F-062, 071, 072).

| 형식 | 화면비 | 길이 프리셋 | 장면 수 |
|---|---|---|---|
| 쇼츠(`shorts`) | 9:16 | 15 / 30 / 45 / 60 / 90초 | 3~12장면 |
| 롱폼(`longform`) | 16:9 | 3 / 5 / 10 / 20 / 30 / 60분(기본 10분) | 분당 3~8장면, 한 스토리보드 최대 240장면 |

공통 규칙: 장면 길이 합계 = 목표 길이 ±10%(`VD017`). 60분 롱폼은 분당 3장면(180장면) 이상이 되어야 하므로 최대 240장면 안에서 장면당 평균 15~20초가 된다.

| 장면 종류(`scene_kind`) | 내용 | 소재 |
|---|---|---|
| `image` | 이미지 + 화면 이동 효과 | AI 이미지, 사용자 이미지, 재사용 이미지 |
| `clip` | 사용자 원본·업로드 클립 | 업로드 클립. 권리 근거 필수(`VD019`) |
| `text_card` | 글자 카드: 제목·목차·인용·숫자 | 렌더 워커가 그린다. 숫자 카드는 출처 필수(`source_required=true`) |
| `title` | 오프닝·챕터 제목 | 렌더 워커가 그린다 |

엔드카드는 MVP에 없다. 채널 끝화면은 YouTube 기능을 쓴다. 모션 프리셋(`motion_preset`): `zoom_in`, `zoom_out`, `pan_left`, `pan_right`, `static`.

| 템플릿(`template_code`) | 이름 | 비트와 비중(제안) | 롱폼 기본 장면 길이(제안) |
|---|---|---|---|
| `knowledge_explainer` | 지식 해설 | 훅 10 / 질문 제시 15 / 설명 50 / 정리 15 / 다음 편 예고 10 | 10초 |
| `history_documentary` | 역사 다큐 | 오프닝 10 / 시대 배경 20 / 사건 전개 40 / 전환점 15 / 의미와 평가 15 | 12초 |
| `list_topn` | TOP N 리스트 | 훅 10 / 항목 N개 75 / 정리 15 | 10초 |
| `story_radio` | 사연 라디오 | 사연 소개 15 / 전개 50 / 고민·반전 20 / 맺음 15 | 15초 |
| `product_review` | 제품 리뷰 | 훅 10 / 제품 소개 20 / 장단점 45 / 총평 25 | 8초 |

`product_review`는 리뷰형 구성만 주며 Track B와 연계하지 않는다. 제휴 링크를 붙이면 기존 대가성 문구 규칙(VD-F-062)이 그대로 걸린다. 쇼츠의 장면 길이는 기본 장면 길이를 쓰지 않고 목표 길이를 장면 수로 나눠 다시 계산한다(제안).

### 10.4 크레딧 단가 (제안)

이 절이 Track S 단가의 정본이다. 가격 플랜 문서(`Price_Plans/sceneflow/PRICE_PLAN.md`)는 이 절을 인용한다. 기존 4장·4.1절 단가는 바꾸지 않았다.

| 작업 | 크레딧 | 근거 |
|---|---|---|
| 대본(쇼츠 / 롱폼) | 3 / 5 | 기존 그대로: 4장 `AI 대본(숏폼)`(`docs/products/sceneflow/01_PRD.md:184`), `롱폼 스토리라인`(`:187`), 4.1절 빠른 모드(`:209`) |
| 스토리보드 생성 쇼츠 / 롱폼 10분당 | 4 / 8 | 제안: 대본 단가에 장면 분할·사실 주장 표시·compliance 노드가 더해진다. 롱폼은 10분 단위 올림(제안) |
| 스토리보드 다시 생성(전체) | 생성과 같음 | 제안 |
| 장면 이미지 1장(생성·다시 만들기) | 3 | 기존 이미지 단가(`:184`) |
| 장면 내레이션 다시 만들기(1장면 1언어) | 1 | 제안 |
| 이미지 재사용, 미리보기, 편집 저장 | 0 | 제안 |
| 렌더 | 숏폼 언어당 3, 롱폼 10분당 10 | 기존 인코딩 단가(`:185`) |
| 내레이션 TTS | 4.1절 단가 그대로: 쇼츠는 숏폼 1언어 ElevenLabs 5 / 오픈소스 2, 롱폼 10분 언어당 ElevenLabs 5 / 오픈소스 2 | `:215`, `:216` |
| 쇼츠 추출 | 선정·훅 2 + 컷당 인코딩 3(세로 구도 다시 만들기는 이미지 단가 추가) | 기존 OSMU 단가 구조(`:194`) |
| 출처 점검 LLM(스토리보드 1회) | 1 | compliance LLM 검사 단가와 같게(`:189`) |
| 음성 지시 편집 패치 변환(P1) | 1 | 제안. 받아쓰기 STT는 4.1절(`:212`) |

예시(롱폼 10분, KO, 40장면, 새 이미지 30장 + 재사용 10장): 대본 5 + 스토리보드 8 + 이미지 90 + TTS 5(ElevenLabs) + 렌더 10 + 출처 점검 1 = 119크레딧. 쇼츠 5편 추출 +17(선정 2 + 인코딩 15) = 136크레딧. 업로드·compliance 검사는 별도다. 이미지가 합계의 약 3분의 2를 차지하므로 재사용 기본값과 D-31이 단가 조정의 핵심이다. 가격 플랜 작업자가 원가와 목표 매출총이익률 70%(`Price_Plans/_common/PRICING_PRINCIPLES.md` 4.2절)로 검증하고, 플랜 포함 크레딧이 모자라면 대안(이미지 재사용 기본값, D-31)을 제시한다. 실패 환불은 기존 규칙(VD-F-035, 4.1절 실패 환불 행)을 따른다: 장면 이미지 하나가 실패하면 그 장면분만 환불한다.

**이익률 주의(2026-10-18, `docs/Price_Plans/sceneflow/PRICE_PLAN.md` 11.3절):** 위 단가 그대로면 롱폼 10분 + 쇼츠 5편(136크레딧)의 원가가 약 1,932원이라 매출총이익률이 basic 60.1%, pro 50.7%, advanced 45.3%로 공용 기준 70%(`docs/Price_Plans/_common/PRICING_PRINCIPLES.md` 4.2절)에 못 미친다. 저가 이미지 모델 기본값(D-31)과 롱폼 TTS 글자 수 과금(D-36)을 함께 적용하면 151크레딧·원가 약 1,134원으로 basic 78.9%, pro 73.9%, advanced 71.1%가 된다. 개발 전 가격 확정 때 D-31·D-36·D-37을 함께 정한다.

플랜 키(`plans.features`, 서버만 읽는다. 키 추가는 VID-06-001 경로):

| 키 | 타입 | Starter | Basic | Pro | Advanced | 비고 |
|---|---|---|---|---|---|---|
| `storyboard` | bool | false | true | true | true | 제안: 기존 Track C가 Basic부터였다 |
| `storyboard_max_minutes` | int | 0 | 10 | 30 | 60 | 제안. 현우의 10~15분 롱폼은 Pro부터 |
| `shorts_extract_max` | int | 0 | 3 | 10 | 10 | 제안. Starter 0은 이번에 정한 제안값 |

### 10.5 법, 고지, 금지 문구 (Track S)

6장 표는 그대로 적용된다. 아래는 Track S에서 더하는 규칙이다.

| 항목 | 내용 |
|---|---|
| 출처 표시 | 장면 출처(VD-F-138)를 업로드 설명란 "참고 자료"에 자동으로 넣는다. 그래프는 근거 id가 없는 출처 URL을 만들지 않는다. 출처가 다른 사람의 글·사진이면 인용 범위를 넘는 전재를 하지 않도록 화면 문구는 요약으로 쓴다(제안). 출처 사이트의 이용 조건은 사용자가 확인한다 |
| AI 생성 이미지 표시 | `ai_generated=true` 소재가 하나라도 있으면 업로드 화면에서 플랫폼의 합성 콘텐츠 표시를 기본 체크한다(6장 약관·고지 행과 같음, API 지원 여부 미확인). 설명란에 "이 영상에는 AI로 만든 이미지·음성이 포함되어 있습니다" 문구를 기본으로 넣는다(제안). 「인공지능 발전과 신뢰 기반 조성 등에 관한 기본법」의 표시 의무 대응은 toon-factory와 같은 입장이다(`docs/products/toon-factory/01_PRD.md:307`, 조문·시행령 세부 미확인) |
| 역사 사실 단정 주의 | 그래프와 대본은 논쟁이 있는 해석을 사실로 단정하지 않는다("~라는 견해가 있다"와 출처). 연도·인물·수치는 출처가 있는 것만 화면 문구로 쓴다. 실존 역사 인물을 AI 이미지로 그린 장면은 "AI 재현 이미지" 표기를 기본으로 넣는다(제안). 생존 인물의 AI 이미지는 만들지 않는다(제안, toon-factory 실존 인물 금지와 같은 방향) |
| 원본 클립 권리 근거 | `clip` 장면은 `rights_basis`(public_free/creative_commons/licensed/own)와 근거 메모가 필수다(`VD019`). "무료 배포"는 재가공·수익화 허락이 아니다(6장 원본 저작권 행). CC 라이선스는 조건(저작자 표시, 비영리 등)을 사용자가 확인하고, 비영리 조건 클립을 수익화 채널에 쓰려 하면 경고한다(제안). 공공 기록물·공공누리 자료의 출처 표시 조건은 미확인 |
| 금지 문구(생성물) | 출처 없는 역사 수치·연도 단정, 가상 증언·가상 인터뷰를 실제 기록처럼 쓰기, 특정 집단 비하, "교과서가 숨긴 진실" 같은 근거 없는 음모 단정(제안), 6장 금지 문구 전부 |
| 금지 문구(마케팅) | "하루 만에 롱폼 완성 보장", "조회수 보장", "사실 확인 완료"(출처 점검은 경고 도구이며 사실을 보증하지 않는다), 미검증 생성 건수 |

### 10.6 KPI (제안)

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| 스토리보드 렌더 완료율 | 60%(제안) | 마스터 컷 ready 스토리보드 / 생성된 스토리보드 | 3개월 |
| 롱폼당 쇼츠 추출 수 | 평균 3편 이상(제안) | `storyboard_cuts`(kind `short`) ready / 롱폼 마스터 컷 ready | 3개월 |
| 장면 다시 만들기 비율 | 측정만(목표 없음) | `scene_assets` superseded 수 / 전체 장면 수 | 월 |
| 출처 없는 사실 주장 장면 비율 | 측정만, 감소 추세 확인 | 업로드 시점 WARN 장면 / `source_required=true` 장면 | 월 |
| 롱폼 처리 시간 | 10분 1언어 p90 2시간 이내 | 스토리보드 생성 시작 ~ 마스터 컷 ready | 상시(5장) |
| 미리보기 서버 렌더 | 0건 | 미리보기 경로의 잡·원장 행 | 상시 |
| 첫 고객군 유료 전환 | 15%(제안, 7장 유료 전환율과 같게) | `knowledge_explainer`·`history_documentary` 사용 조직 중 Basic 이상 구독 | 3개월 |

### 10.7 열린 결정

| # | 항목 | 선택지 | 권고 |
|---|---|---|---|
| D-30 | Remotion 도입과 book-trailer 렌더러 공용화 시점 | (a) MVP는 FFmpeg만, Phase 2에 장면 모션 그래픽용 Remotion과 book-trailer 렌더러 공용화를 함께 검토 (b) MVP부터 Remotion | (a). SF-2로 확정. Remotion 라이선스 조건과 서버 렌더 원가는 미확인이며 Phase 2 검토 때 확인한다 |
| D-31 | 이미지 생성 단가 하향(오픈소스 이미지 모델 경로) | (a) fal 기존 단가 3 유지 + 재사용 기본 ON (b) 오픈소스 이미지 모델 자체 서빙 경로를 더해 낮은 단가 제공 | (a)로 시작(제안). (b)는 가격 플랜 검증에서 플랜 포함 크레딧이 모자라다고 나오면 연다. 모델 가중치의 상업 이용 라이선스 확인 전에는 채택하지 않는다 2026-10-18 가격 검토: 저가 이미지 모델을 기본(장면 이미지 3크레딧 유지), 고품질 모델은 5크레딧 선택으로 두는 안(SF-P-2, 같은 문서 11.3절) |
| D-32 | 쇼츠 세로 구도 기본값 | (a) 크롭(0크레딧) (b) 다시 만들기(이미지 단가) | (a)(제안). 비용이 들지 않는다. 얼굴·글자가 잘리는 장면은 화면에서 다시 만들기를 권한다. 글자 카드·제목 장면은 어느 쪽이든 9:16으로 다시 그린다 |
| D-33 | 출처 없는 사실 주장 장면의 판정 | (a) WARN(사용자 확인 후 진행) (b) FAIL(차단) | (a)(제안). 출시 3개월 데이터(10.6절 비율)를 보고 `history_documentary`부터 (b)를 검토한다 |
| D-34 | 기존 Track D 테이블 삭제 시점 | (a) VD-F-142 이전 확인 직후 다음 마이그레이션에서 삭제 (b) Phase 2까지 유지 | (a)(제안). 앱 코드와 운영 데이터가 없으므로 이전 대상이 없을 가능성이 높다. 삭제는 스키마 소유 규칙(VID-06-001)을 따른다 |
| D-35 | Track S 배경음악(BGM) 출처 | (a) 운영자가 상업 이용 라이선스를 확인한 BGM 묶음을 제공(장면 `music_cue`는 묶음 안 곡 이름) (b) 조직이 올린 라이선스 곡만 (c) MVP는 음악 없음, Phase 2에 (a) | (a)(제안). 기존 `music_library`는 Track F용이라 SF-3에 따라 Phase 2로 갔으므로, Track S용 BGM은 라이선스 근거 칸이 있는 별도 묶음으로 둔다. 확정 전까지 렌더는 음악 없이도 완료되어야 한다(06장 9.6절) |
| D-36 | 롱폼 내레이션 TTS 과금 방식 | (a) 정액(롱폼 10분 언어당 ElevenLabs 5 / 오픈소스 2, 4.1절) 유지 (b) 글자 수 과금(4.1절 "대본 읽어 주기" 단가와 같은 천 자 단위, 10분 약 3,300자면 ElevenLabs 약 20) | (b)(제안). 정액이면 롱폼 TTS 원가가 크레딧 가치를 넘는다(`docs/Price_Plans/sceneflow/PRICE_PLAN.md` 11.3절, SF-P-1) |
| D-37 | Basic 쇼츠 추출 한도(`shorts_extract_max`) | (a) 3 (b) 5 | (b)(제안). 첫 고객 현우의 주 1세트(롱폼 + 쇼츠 5편) 목표를 Basic에서 막는 것은 크레딧이 아니라 이 한도다(같은 문서 11.4절, SF-P-3) |

## 11. AI 자동편집과 화면비·해상도 (2026-10-18 추가, 경쟁사 벤치마킹)

10장 Track S 위에 얹는 장이다. 기존 장의 줄 수는 바꾸지 않았고, 10장 VD-F-130·140 두 줄만 같은 줄 안에서 이 장을 가리키도록 고쳤다. **SceneFlow의 주력 기능은 AI 자동편집이다(확정 SF-5).** 스토리보드는 AI가 편집할 수 있는 구조(장면·챕터·쇼츠 구간·출처)를 처음부터 갖고 있다는 점이 경쟁사와 다른 출발점이다.

### 11.1 확정 결정

| # | 결정 | 내용 |
|---|---|---|
| SF-5 | 주력 기능 = AI 자동편집 | 랜딩·온보딩·편집기 첫 화면의 중심은 "말로 지시하면 AI가 편집안을 만들고, 확인하면 실행"이다. 스토리보드 생성은 그 재료를 만드는 단계로 설명한다 |
| SF-6 | AI는 편집 명령 목록(EDL)만 만든다 | LLM은 영상·이미지 파일을 직접 고치지 않는다. 11.4절 허용 명령만 담은 JSON을 만들고, 서버가 스키마·권한·한도를 검사한 뒤 사용자 승인으로 실행한다. 허용 목록 밖 명령은 실행하지 않는다(`VD023`) |
| SF-7 | 승인 전 변경 0, 실행 전 비용 표시 | 모든 AI 편집(지시, 자동 다듬기, 무음 컷, 리테이크, B-roll)은 같은 "편집안 → 변경 미리보기 + 예상 크레딧 → 승인(일부 선택 가능) → 실행 → 되돌리기" 흐름을 쓴다 |
| SF-8 | 화면비는 형식과 분리 | 화면비 4종(16:9, 9:16, 1:1, 4:5)을 고른다. 형식은 길이·장면 수 규칙만 정한다. 해상도 720p/1080p/1440p/2160p(4K), fps 24/30/60은 플랜 상한 안에서 고른다 |

벤치마킹 요약(2026-10-18 조사, 2차 출처 포함, 수치는 공식 페이지 재확인 필요): Descript Underlord(자연어 편집, 필러·리테이크 제거), Vrew(무음 구간 제거, 자막 기반 편집, 한국어), Opus Clip(하이라이트 점수, 추적 리프레임), FireCut(리테이크 목록에서 골라 승인), Submagic(키워드 강조 자막, Magic Zoom, B-roll 빈도), Wisecut(자동 덕킹), invideo AI(모든 AI 변경 승인 후 반영·되돌리기), Premiere·DaVinci(Auto/Smart Reframe, 음성 보정). 경쟁사가 약한 곳: 실행 전 비용 예측(Descript 도움말은 같은 프롬프트도 실행마다 크레딧이 다르다고 안내), 한국어 자연어 편집(VEED Magic Cut 영어만, Vrew 자연어 명령 미확인), 사실 검증 표시, 점수 근거 공개. 출처는 11.10절.

### 11.2 기능 요구사항과 수용 기준

| ID | 기능 | 단계 | 요구사항 | 수용 기준 | 벤치마크 |
|---|---|---|---|---|---|
| VD-F-143 | 화면비·해상도·fps 설정 | MVP | 새로 만들기 첫 단계(형식 다음)에서 화면비를 고른다. 쇼츠: 9:16(기본), 1:1, 4:5. 롱폼: 16:9(기본), 9:16(세로 롱폼), 1:1. 해상도 720p/1080p(기본)/1440p/2160p, fps 24/30(기본)/60. 롱폼은 쇼츠 추출 화면비(`shorts_aspect`, 9:16 기본)도 고른다. 렌더 전에는 설정 패널에서 바꿀 수 있다. 플랜 상한(11.6절 키) 밖 값은 잠금 표시. 픽셀 크기는 짧은 변 기준(1080p 세로 = 1080x1920, 4:5 = 1080x1350) | 롱폼 4:5 요청 23514. Basic 조직 2160p 요청 `VD009`. 렌더 중 설정 변경 `VD020`. 렌더된 스토리보드의 설정을 바꾸면 status `ready`(다시 렌더 필요 표시). 출력물 `outputs.width/height/fps`가 설정과 같다 | Opus·Submagic·CapCut 화면비 4종, Kapwing·Descript Free 720p / 유료 4K |
| VD-F-144 | 화면비 변형본(리포맷) | MVP | 마스터 컷이 ready면 같은 장면 전체를 다른 화면비로 다시 렌더한 변형본을 만든다(컷 kind `variant`, 화면비마다 1개, 최대 3개, 플랜 `aspect_variants_max`). 장면 이미지는 컷 화면비 이미지가 있으면 쓰고, 없으면 크롭(장면 초점 기준, 0크레딧) 또는 다시 만들기(이미지 단가) 중 고른다(D-32 기본 크롭). `text_card`·`title`은 새 화면비로 다시 그린다(0크레딧) | 변형본 화면비 = 마스터 화면비면 22023. 4번째 변형본 `VD022`. 변형본마다 `outputs` 언어당 1행. 크롭 장면은 스냅샷 `crop_from`에 원본 화면비가 남는다 | Opus·CapCut Auto Reframe, Premiere 시퀀스 복제. 차별: 크롭 대신 장면 이미지를 새 화면비로 다시 생성 |
| VD-F-145 | 크롭 초점과 세이프존 | MVP | 장면마다 크롭 초점(`focus_x`, `focus_y`, 0~1)을 이미지 위 점으로 정한다. 기본은 가운데. 편집기 미리보기에 플랫폼 UI 세이프존 겹쳐 보기(YouTube 쇼츠·릴스·틱톡, 제안 값은 02장 11장). 자막·화면 문구 기본 위치는 화면비마다 세이프존 안 | 초점 저장은 `save_scene`(0크레딧). 세이프존 밖에 놓인 화면 문구는 편집기 경고(차단 아님). 범위 밖 초점 23514 | Opus 추적 리프레임(실사), Premiere Auto Reframe. 피사체 자동 추적은 Phase 2(11.3절) |
| VD-F-146 | AI 편집 지시(자연어 → 편집안) | MVP | 편집기 오른쪽 "AI 편집" 패널에 텍스트(또는 VD-F-140 음성 받아쓰기)로 지시한다. 예: "3번 장면 2초 줄이고 5·6번 순서 바꿔", "챕터 바뀔 때마다 페이드 넣어", "임진왜란 연도 나오는 장면 글자 크게", "쇼츠는 반전 장면부터 45초로". 서버가 현재 스토리보드 요약 + 지시를 FastAPI 그래프 `video.edit_plan`에 보내고, 그래프는 11.4절 허용 명령 배열(최대 100개)과 사람이 읽는 변경 요약을 돌려준다. 같은 입력이면 같은 편집안이 나오도록 온도 0, 출력 스키마 고정(제안). 편집안은 `video.edit_plans`에 `proposed`로 저장되고 화면은 명령마다 전·후 비교, 예상 크레딧(다시 만들기 명령만 비용 발생), 영향 장면을 보여준다. 사용자가 명령을 골라 승인하면 사용자 RPC `video.apply_edit_plan`이 비용 없는 명령을 한 트랜잭션으로 적용하고, 비용 있는 명령(`regenerate`)은 Route Handler가 선차감 후 잡으로 실행한다 | 승인 전 장면 변경 0. 허용 밖 명령·스키마 오류 `VD023`(그 편집안 전체를 실행하지 않음). 편집안 생성 후 스토리보드가 바뀌었으면(revision 불일치) 적용 시 `VD409` + "다시 제안받기". 일부 명령만 고르면 고른 것만 적용. 편집안 1건 = `core.ai_runs` 1행. 해석 실패 시 명령 0 + "지시를 이해하지 못했습니다" + 환불 | Descript Underlord, invideo AI(승인 후 반영), Captions AI Edit. 차별: 실행 전 비용 확정, 한국어 지시 |
| VD-F-147 | 원클릭 AI 자동 다듬기 | MVP | 버튼 하나로 편집안을 만든다(실행은 VD-F-146과 같은 승인). 규칙 + LLM: (1) 내레이션 길이에 맞춘 장면 길이 조정(내레이션 끝 + 300ms, 제안) (2) 정지 이미지 장면에 모션 프리셋 자동 배정(같은 모션 3연속 금지, 제안) (3) 챕터 경계에 전환(`fade` 500ms, 제안) (4) 인명·연도·지명 자막 강조어 지정 (5) BGM 덕킹·음량 정규화 켜기 (6) 쇼츠 후보 표시. 조직 편집 프리셋(VD-F-155)이 있으면 그 값을 쓴다 | 다듬기 편집안은 `source=auto_polish`. 적용 후 길이 합계가 ±10% 안(밖이면 길이 조정 명령을 빼고 경고). 같은 스토리보드·같은 revision이면 같은 편집안. 결과가 명령 0개면 "다듬을 곳이 없습니다" + 크레딧 정산 0 | Submagic Magic Zoom·전환, Wisecut 자동 덕킹, Descript 편집 선호 기억 |
| VD-F-148 | 무음·군더더기 말 자동 컷 | MVP | 대상: `clip` 장면(사용자 업로드 영상·녹음) 소재. 미디어 워커가 Whisper 단어 타임스탬프(`video.stt` = `oss-voice`, 원본 국외 전송 없음)와 FFmpeg `silencedetect`로 무음 구간과 한국어 군더더기 말(기본 사전: "음", "어", "그", "저", "뭐지", "이제" 등 운영자 seed, 조직이 추가)을 찾는다. 설정: 최소 무음 길이(기본 500ms), 앞뒤 여유(기본 120ms), 강도(보수·보통·강하게). 결과는 잘라낼 구간 목록 편집안(`remove_ranges`)이며 구간마다 소리 듣기 후 개별 해제할 수 있다. 어절 중간을 자르지 않는다(단어 경계에만 컷) | 컷 경계가 단어 타임스탬프 경계와 일치(테스트 샘플). 승인 전 소재 변경 0, 원본 파일은 지우지 않는다(구간 정보만 저장, 비파괴). 클립 STT 결과는 `video.clip_transcripts`에 1행. 크레딧: 클립 1분당 기존 무음 컷 2(4장, `:182`) + STT는 기존 파이프라인 STT 5(`:180`) 중 STT분만 3(제안, 번역 없음) | Vrew 무음 구간 제거, VEED Magic Cut(영어만), Gling, TimeBolt. 차별: 한국어 필러 사전, 어절 경계 컷 |
| VD-F-149 | 자막 자동 생성과 키워드 강조 | MVP | 자막 타이밍은 TTS 정렬(내레이션) 또는 Whisper 단어 타임스탬프(클립)로 만든다. 장면마다 강조어 최대 10개(`caption_emphasis`): 그래프가 인명·연도·지명·숫자를 기본 제안한다. 자막 스타일 3종(`clean`, `bold_box`, `word_pop`(말하는 단어 강조), 제안). 한자 병기 옵션(역사 용어 뒤 괄호 한자, 그래프가 근거 없는 한자를 만들지 않도록 운영자 용어집에 있는 것만, 제안). 위치는 화면비 세이프존 안. 레이어 순서·단일 엔진은 VD-F-033 | 강조어가 장면 내레이션에 없는 단어면 저장 거부 22023. 한자 병기는 용어집 항목만(용어집 밖 0). 자막 스타일 변경은 0크레딧(렌더에 포함) | Submagic·Opus 키워드·이모지 강조, Descript 단어 강조. 차별: 한자 병기, 역사 고유명사 |
| VD-F-150 | 문장 단위 내레이션 다시 만들기와 발음 사전 | MVP | 장면 내레이션 중 한 문장만 다시 만든다(같은 목소리 규칙 VD-F-106, 잡 `scene.narration` 재사용, 문장 범위만 교체 후 이어 붙임). 조직 발음 사전(`video.pronunciation_lexicon`: 표기 → 읽기, 예: "광해군" → "광:해군", "1592년" → "천오백구십이 년")을 TTS 직전 텍스트 치환으로 적용한다(제공자 발음 사전 API는 미확인이라 치환 방식, 제안). 사전은 조직 안에서 모든 스토리보드에 적용 | 문장 다시 만들기 1크레딧(장면 내레이션 단가와 같음). 다시 만든 문장 앞뒤 이음매에서 무음 100ms 이하(제안 측정). 사전 항목 최대 2,000개(제안), 중복 표기 23505 | Descript Regenerate·Overdub(사용자 목소리 복제는 범위 밖) |
| VD-F-151 | 편집 되돌리기와 편집 기록 | MVP | 적용된 편집안마다 영향받은 장면의 이전 상태를 저장한다(`edit_plans.undo_state`). "되돌리기"는 가장 최근 적용 편집안부터 순서대로, 스토리보드당 최근 20건까지(제안). 적용 뒤 다른 편집이 같은 장면을 바꿨으면 그 편집안은 되돌릴 수 없다(`VD409`, 먼저 뒤 편집을 되돌리라고 안내). 다시 만들기로 생긴 소재는 되돌리면 이전 소재를 ready로 돌린다(크레딧 환불 없음) | 되돌리기 후 장면 내용이 적용 전 스냅샷과 같다(필드 비교). 되돌리기 0크레딧. 편집 기록 목록에 지시 원문·적용 명령 수·적용자·시각 | invideo AI 되돌리기, Descript 응답 단위 되돌리기 |
| VD-F-152 | 쇼츠 적합도 점수(근거 공개) | P1 | VD-F-137 `video.shorts_pick` 결과에 컷마다 적합도 0~100과 근거 태그(훅 문장, 반전, 질문, 숫자·연도, 감정 단어, 길이 적합)를 붙인다. 화면 이름은 "쇼츠 적합도(참고용)". 조회수 예측이라고 쓰지 않는다 | 점수마다 근거 태그 1개 이상. 금지 문구 "바이럴 보장", "조회수 예측"(10.5절에 추가). 크레딧은 기존 선정 2에 포함 | Opus Clip 바이럴 점수(근거 비공개). 차별: 근거 공개 |
| VD-F-153 | 리테이크 감지와 테이크 선택 | P1 | 업로드 녹음·클립에서 같은 문장을 여러 번 말한 구간을 Whisper 전사 유사도로 묶어 목록으로 보여준다. 사용자가 미리 듣고 하나를 고르면 나머지를 `remove_ranges` 편집안으로 만든다(VD-F-146 승인 흐름) | 기본 선택은 마지막 테이크(제안). 고른 테이크 외 구간만 편집안에 들어간다. 크레딧 1(클립 10분당, LLM 묶음 판정, 제안) | FireCut 리테이크 목록, Descript, Submagic |
| VD-F-154 | 자동 챕터·제목·설명 | P1 | 롱폼 마스터 컷 ready 뒤 챕터 타임스탬프(장면 `chapter` 경계, 스냅샷 기준)와 제목 후보 3개·설명 초안을 만든다. YouTube 챕터 규칙(첫 타임스탬프 0:00, 3개 이상, 각 10초 이상)을 만족하지 않으면 챕터 블록을 넣지 않는다. 설명란 순서: 대가성 문구 첫 줄(VD-F-062) → 설명 → 챕터 → 참고 자료(VD-F-138) | 타임스탬프가 스냅샷 장면 시작 시각과 같다. 금지 문구 0. 크레딧 1(제안) | Gling·Descript·FireCut 챕터 |
| VD-F-155 | 조직·고객별 편집 프리셋 | P1 | 페이싱(장면 기본 길이 배수), 자막 스타일, 전환 기본값, 모션 자동 배정 여부, BGM 음량, 군더더기 말 추가 단어, 기본 화면비·해상도를 프리셋으로 저장한다. 대행 조직은 고객(`client_id`)마다 프리셋을 둔다(고객 A 프리셋을 고객 B에 쓰지 않는다, 08장 규칙). 새 스토리보드와 자동 다듬기가 기본 프리셋을 쓴다 | 프리셋 저장 0크레딧. 다른 고객 프리셋 적용 시도 `VD002`. 조직당 20개(제안) | Descript 편집 선호 기억(2026-06) |
| VD-F-156 | 자동 B-roll 제안 | P1 | 설명이 긴 장면(내레이션 15초 이상, 제안)에 보조 장면을 끼우는 편집안을 만든다: 연표 카드·인물 카드·지도 설명 카드(`text_card` 템플릿, 0크레딧) 또는 AI 이미지(이미지 단가). 빈도 슬라이더(적게·보통·많이). 사실 주장 카드는 `source_required=true` | 편집안 명령은 `add_scene` + `set_text`만. 추가 후 장면 수 한도(VD018)·길이 합계를 넘으면 그 명령을 빼고 안내. 제안 2크레딧 + 승인한 AI 이미지 장면 단가 | Submagic B-roll 빈도, Opus·Kapwing Smart B-roll |
| VD-F-157 | 자동 썸네일 3안 | P1 | 마스터 컷 프레임 또는 장면 이미지 + 제목 문구(30자 이하)로 썸네일 3안을 만든다(16:9, 1280x720, 렌더 워커 글자 합성). AI 이미지 새로 만들기는 선택(이미지 단가). 문구는 10.5절 금지 문구 검사 | 3안 2크레딧(제안). 금지 문구가 든 안 0. 업로드 화면에서 1개 선택 | 업계 일반(경쟁사별 확인은 미확인) |
| VD-F-158 | NLE 내보내기 | P1 | 렌더 스냅샷을 FCPXML(Final Cut·DaVinci)과 Premiere XML로 내보낸다. 장면 소재·내레이션·자막(SRT) 묶음 zip. 렌더 컷의 장면 순서·길이·전환이 XML과 같다 | 내보내기 0크레딧(제안), 플랜 `nle_export`(Pro 이상, 제안). 서명 URL 24시간 | Gling·TimeBolt·Opus XML 내보내기 |
| VD-F-159 | 연도·인물 표기 일관성 점검 | P1 | VD-F-138 출처 점검 잡에서 같은 인물·사건의 연도·이름 표기가 장면마다 다르면 WARN을 더한다(예: 3번 장면 1592년, 12번 장면 1593년 임진왜란 발발) | 출처 점검과 같은 1크레딧 안. WARN만(D-33 규칙). 사실이라고 보증하는 문구 0 | 경쟁사 사례 찾지 못함(미확인). 차별 기능 |

### 11.3 Phase 2로 미루는 것

| 기능 | 이유 | 벤치마크 |
|---|---|---|
| 피사체 추적 리프레임(실사 클립) | 첫 고객은 AI 이미지 위주라 초점 한 점으로 충분. 추적 모델 운영 비용 큼 | Opus, CapCut, Premiere Auto Reframe |
| 업로드 클립 장면 감지 | Track S는 장면을 스토리보드가 정한다 | Kapwing Find Scenes |
| 번역 더빙·립싱크 | 언어판(TTS 교체)은 이미 있다. 립싱크는 실사에만 의미 | Captions, Kapwing, VEED |
| 비트 싱크 컷 | 지식·역사 채널에서 중요도 낮음 | CapCut AutoCut |
| 멀티캠 자동 전환 | 대담형 콘텐츠 한정 | AutoPod, DaVinci SmartSwitch |
| 사용자 목소리 복제 | 동의·도용 위험, 별도 동의 절차 필요 | Descript Overdub |

### 11.3.1 Phase 2 결정 근거 요약

MVP는 "스토리보드 구조를 아는 편집"에 집중한다. 실사 영상 분석(추적·장면 감지·멀티캠)은 첫 고객군(현우, 지식·역사 채널)의 주 소재가 AI 이미지와 내레이션이라 우선순위가 낮다.

### 11.4 편집 명령 허용 목록 (EDL, 정본)

그래프 출력·서버 검사·`apply_edit_plan`이 같은 목록을 쓴다. 명령 객체는 `{id, op, scene_id?, args}`이고, `id`는 편집안 안에서 1부터의 번호다.

| `op` | 인자 | 실행 위치 | 크레딧 | 비고 |
|---|---|---|---|---|
| `set_duration` | `{duration_ms}`(1,000~60,000) | `apply_edit_plan` | 0 | "2초 줄여"는 그래프가 새 값으로 바꿔 넣는다 |
| `move_scene` | `{to_ord}` | 같음 | 0 | 여러 개면 서버가 최종 순서를 한 번에 계산 |
| `delete_scene` | `{}` | 같음 | 0 | 마지막 장면 삭제 22023 |
| `add_scene` | `{after_ord, kind, duration_ms, on_screen_text?, visual_prompt?, narration?}` | 같음 | 0(소재 없음) | 소재 생성은 별도 `regenerate` |
| `set_text` | `{field: narration\|on_screen_text\|visual_prompt\|chapter, value}` | 같음 | 0 | 내레이션이 바뀌면 그 장면 내레이션 소재 superseded(10장 규칙) |
| `set_motion` | `{preset}` | 같음 | 0 | 10.3절 5종 |
| `set_transition` | `{name, ms}` | 같음 | 0 | `cut`, `fade`, `dissolve`, `fadeblack`, `slideleft`, `slideup`, `zoomin`, `wipeleft`, 200~1,500ms |
| `set_focus` | `{x, y}` | 같음 | 0 | 0~1 |
| `set_music_cue` | `{cue}` | 같음 | 0 | 10장 큐 5종 |
| `set_caption_emphasis` | `{words[]}`(10개 이하) | 같음 | 0 | 내레이션 안 단어만 |
| `set_clip_trim` | `{in_ms, out_ms}` | 같음 | 0 | clip 장면만 |
| `remove_ranges` | `{ranges: [{start_ms, end_ms, reason: silence\|filler\|retake\|user}]}` | 같음 | 0(분석 비용은 VD-F-148·153에서 이미 정산) | clip 장면만, 비파괴 |
| `set_shorts_candidate` | `{value}` | 같음 | 0 | 롱폼만 |
| `propose_short` | `{scene_ids[], hook_text}` | 같음(`storyboard_cuts` proposed 1행) | 0(렌더는 VD-F-137 단가) | 연속 장면, 한도 VD021 |
| `set_render` | `{aspect?, resolution?, fps?, shorts_aspect?}` | 같음 | 0 | 플랜 상한 VD009 |
| `set_style` | `{caption_style?, caption_hanja?, bgm_level_db?, loudnorm?}` | 같음 | 0 | 스토리보드 단위 |
| `regenerate` | `{part: image\|narration\|sentence, lang?, sentence_index?, aspect?}` | Route Handler(선차감 → 잡) | 이미지 3, 내레이션 1, 문장 1 | 승인 화면에 합계 표시 |

검사 규칙: 한 편집안의 명령 수 100개 이하, 같은 장면에 같은 `op`가 두 번이면 뒤의 것만 남기고 경고, 대상 장면이 스토리보드에 없으면 `VD023`, 형식에 맞지 않는 명령(쇼츠 형식의 `propose_short`)은 `VD023`. LLM이 만든 텍스트 값(`set_text`)은 10.5절 금지 문구 compliance를 다시 통과해야 한다.

### 11.5 크레딧 단가 (제안)

이 절이 11장 기능 단가의 정본이다. 10.4절 단가는 바꾸지 않았다.

| 작업 | 크레딧 | 근거 |
|---|---|---|
| AI 편집 지시 1회(편집안 생성) | 1 | 10.4절 음성 지시 패치 변환 1과 같게. 받아쓰기 STT는 4.1절 |
| 원클릭 자동 다듬기 | 쇼츠 1 / 롱폼 10분당 2 | 제안: 스토리보드 전체를 읽는 LLM 1회 |
| 편집안 적용·일부 적용·되돌리기·프리셋 저장 | 0 | 제안 |
| 무음·군더더기 말 분석(클립 1분당) | STT 3 + 무음 컷 2 | 제안: 4장 STT+번역 5에서 번역 제외, 무음 컷 2(`:182`) |
| 문장 단위 내레이션 다시 만들기 | 1 | 10.4절 장면 내레이션 다시 만들기와 같게 |
| 렌더 해상도·fps 배수 | 1080p30 = 1배, 1440p 1.5배, 2160p 2배, 60fps 1.5배(곱, 올림) | 제안: 4K60은 1080p30 대비 처리량 약 8배라 원가 측정 후 확정(D-41) |
| 4K 이미지 업스케일(1440p 이상 렌더의 AI 이미지 1장) | 1 | 제안: D-39 |
| 화면비 변형본 렌더 | 그 길이의 렌더 단가와 같음 + 다시 만들기를 고른 장면 이미지 단가 | 10.4절 렌더 단가 |
| 쇼츠 적합도 점수 | 0(선정 2에 포함) | 10.4절 |
| 리테이크 감지(클립 10분당) | 1 | 제안 |
| 자동 챕터·제목·설명 | 1 | 제안 |
| 자동 B-roll 제안 | 2 + 승인한 AI 이미지 장면 3 | 제안 |
| 자동 썸네일 3안 | 2(+ AI 이미지 새로 만들기 3) | 제안 |
| NLE 내보내기, 일관성 점검 | 0 / 0(출처 점검 1에 포함) | 제안 |

예시(현우, 롱폼 10분 1080p30, 10.4절 136크레딧 세트에 더함): 자동 다듬기 2 + 편집 지시 5회 5 + 문장 다시 만들기 4 + 챕터·제목 1 + 9:16 세로 변형본 렌더 10 = +22크레딧. 같은 세트를 2160p로 렌더하면 렌더 10이 20으로, AI 이미지 30장 업스케일 +30. 4K는 크레딧이 크게 늘어나므로 편집기에서 렌더 전에 합계를 보여준다(03장 9장).

### 11.6 플랜 키 (`plans.features`, 서버만 읽는다. 키 추가는 VID-06-001 경로)

| 키 | 타입 | Starter | Basic | Pro | Advanced | 비고 |
|---|---|---|---|---|---|---|
| `render_max_resolution` | text | `720p` | `1080p` | `2160p` | `2160p` | 제안. 벤치마크: Free 720p / 유료 1080p / 상위 4K |
| `render_max_fps` | int | 30 | 30 | 60 | 60 | 제안 |
| `render_4k60` | bool | false | false | false | true | 제안. Pro는 4K30 또는 1080p60까지 |
| `aspect_variants_max` | int | 0 | 1 | 3 | 3 | 제안 |
| `ai_edit` | bool | false | true | true | true | 제안. Starter는 스토리보드가 없다(10.4절) |
| `nle_export` | bool | false | false | true | true | 제안(P1) |
| `edit_presets_max` | int | 0 | 3 | 20 | 20 | 제안(P1) |

### 11.7 법, 고지, 금지 문구 (11장 추가분)

| 항목 | 내용 |
|---|---|
| 업로드 클립 STT | 원본 오디오는 `video.stt` = `oss-voice`로만 처리한다(국외 전송 없음, 6장). 전사 단어는 그 조직 안에서만 쓴다 |
| 원본 비파괴 | 무음·리테이크 컷은 구간 정보만 저장하고 원본 파일을 고치거나 지우지 않는다 |
| 점수 표현 | 쇼츠 적합도는 "참고용"으로 표시한다. 금지: "바이럴 보장", "조회수 예측", "알고리즘 최적화 보장" |
| 썸네일 문구 | 10.5절 금지 문구 + 사실과 다른 과장(예: 없는 "최초 공개") 금지. AI 이미지 썸네일은 AI 생성 표시 규칙(10.5절) 적용 |
| 마케팅 금지 | "편집 시간 90% 절감" 같은 미검증 수치, "AI가 알아서 완벽 편집", 경쟁사 이름을 쓴 비교 우위 단정 |
| 목소리 | 사용자 목소리 복제는 하지 않는다(11.3절). 문장 다시 만들기는 스토리보드에 고정된 TTS 목소리만 쓴다 |

### 11.8 KPI (제안)

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| AI 편집안 승인율 | 60%(제안) | 적용된 편집안(일부 포함) / 생성된 편집안 | 3개월 |
| 명령 일부 해제율 | 측정만 | 승인 화면에서 해제된 명령 / 제안 명령 | 월 |
| 되돌리기율 | 15% 이하(제안) | 되돌린 편집안 / 적용된 편집안 | 월 |
| 지시 해석 실패율 | 5% 이하(제안) | 명령 0 또는 `VD023` 편집안 / 전체 | 월 |
| 편집 지시 사용 스토리보드 비율 | 70%(제안, SF-5 검증) | 편집안 1건 이상 적용 스토리보드 / 렌더된 스토리보드 | 3개월 |
| 변형본 생성률 | 측정만 | 변형본 1개 이상 / 마스터 ready 스토리보드 | 3개월 |

### 11.9 열린 결정

| # | 항목 | 선택지 | 권고 |
|---|---|---|---|
| D-38 | 프리미엄 이미지 경로 | (a) 저가 모델만(D-31) (b) 저가 기본 + 고품질 선택(GPT Image 2 medium 등, 장면 8크레딧) + 초안 미리보기(저품질 1크레딧) | (b)(제안). 2026-10-18 조사에서 GPT Image 2 medium이 Text-to-Image Arena 1위(Elo 1,381, 2026-08 기준), 1024² 약 $0.053. 썸네일·핵심 장면에만 쓰도록 장면 단위 선택. 단가는 가격 검증 뒤 확정 |
| D-39 | 1440p 이상 렌더의 AI 이미지 처리 | (a) 업스케일(1장 1크레딧) (b) 처음부터 고해상도 생성(이미지 단가 상승) | (a)(제안). 1080p 렌더는 업스케일 없음 |
| D-40 | 자동 다듬기 실행 시점 | (a) 스토리보드 생성 직후 자동으로 편집안만 만들어 둔다(승인 필요) (b) 버튼을 눌렀을 때만 | (b)(제안). 사용자가 원하지 않는 크레딧 사용을 막는다. 온보딩에서 첫 1회 무료 체험(제안) |
| D-41 | 해상도·fps 배수 확정 | (a) 11.5절 제안 배수 (b) 렌더 원가 측정 후 재산정 | (b). 개발 W5 렌더 벤치에서 1080p30 대비 처리 시간을 재고 확정한다 |
| D-42 | 군더더기 말 기본 강도 | (a) 보수(명확한 "음·어"만) (b) 보통 | (a)(제안). 말투를 해치지 않는 쪽에서 시작 |
| D-43 | 세로 롱폼(9:16 롱폼) 업로드 대상 | (a) YouTube 일반 영상으로 업로드 (b) 숨김 | (a)(제안). 쇼츠 길이를 넘으면 쇼츠가 아닌 일반 영상이 된다(플랫폼 판정 기준 미확인) |
| D-44 | 피사체 추적 리프레임 도입(Phase 2) | (a) 오픈소스 검출 모델 자체 운영 (b) 외부 API | 결정 보류. 실사 클립 사용 비율을 보고 정한다 |

### 11.10 벤치마킹 출처 (2026-10-18 조사)

- Descript Underlord: https://help.descript.com/hc/en-us/articles/36803785502221-Underlord-beta-Your-AI-co-editor-in-Descript , 편집 선호 기억: https://www.createwith.com/tool/descript/updates/descripts-underlord-now-remembers-your-editing-preferences-across-projects
- CapCut: https://www.capcut.com/help/auto-cut-in-capcut , https://www.capcut.com/tools/auto-reframe
- Opus Clip: https://www.opus.pro/pricing
- VEED Magic Cut: https://support.veed.io/en/articles/11589317-magic-cut
- Vrew 무음 구간 제거: https://vrew.ai/en/feature/auto-silence-removal
- FireCut 리테이크: https://firecut.ai/features/remove-repetition
- Kapwing: https://www.kapwing.com/pricing
- Submagic: https://www.submagic.co/de/features/auto-video-editor
- invideo AI: https://invideo.io/make/ai-video-editor-web
- Premiere Pro: https://helpx.adobe.com/premiere-pro/using/whats-new.html
- DaVinci Resolve 21(2차 출처): https://nofilmschool.com/davinci-resolve-21
- Wisecut(2차 출처): https://sendshort.ai/guides/wisecut-review/
- Text-to-Image Arena 2026-08(2차 출처): https://www.blogdumoderateur.com/ia-10-generateurs-images-performants-aout-2026/
- GPT Image 2 가격(2차 출처): https://aireiter.com/blog/gpt-image-2-api-pricing
- OpenAI Videos API·Sora 2 종료(2026-09-24, 2차 출처): https://techjacksolutions.com/ai-brief/openai-videos-api-sora-2-deprecated-september-2026/

## 12. 대시보드 셸·GNB 결정 대기 (2026-10-19 추가, 03장 10장)

03장 10장(헤더 + 좌측 GNB + 홈 구성)에서 사용자 결정이 필요한 항목이다. 결정 전에는 03장 10.1절 기본값으로 시안과 문서를 둔다. SceneFlow 전용이고 다른 제품에는 적용하지 않는다.

| 번호 | 항목 | 선택지 | 기본값(제안) |
|---|---|---|---|
| D-45 | 대시보드 포인트 색 | (a) 민트 #00C9A7(원본 Shorts Maker 토큰) (b) 타임코드 블루(현재 03장 3.2절) | (a)(제안). 원본 브랜드를 이어 간다. Track E 민트와 겹치므로 E는 문자 라벨로 구분. 결정 전 정본은 (b) |
| D-46 | 작업 현황 메뉴 따로 두기 | (a) `/dashboard/jobs` 메뉴 (b) 홈 안 잡 목록만 | (a)(제안). 원본 BS "작업" 메뉴와 YSM 5단계 스튜디오를 잇는다 |
| D-47 | 자동화 캔버스 메뉴 노출 | (a) Advanced 잠금 + "저장만" 배지로 보인다 (b) 실행 기능 전까지 숨긴다 | (a)(제안). 잠금 메뉴는 업셀 경로가 된다. 실행은 Phase 2 |
| D-48 | YSM Track C "SaaS"의 뜻 | 원본 확인 필요 | 미확인. 확인 전까지 GNB에 자리를 두지 않는다 |
