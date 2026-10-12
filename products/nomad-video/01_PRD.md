# 01 PRD: NOMAD AI Factory (nomad-video)

근거 약칭: PRD=`NOMAD Shorts Maker/PRD.md`, ADD=`NOMAD Shorts Maker/PRD_add.md`, PRC=`NOMAD Shorts Maker/PRD_pricing.md`, MA=`docs/products/00_MERGE_ANALYSIS.md`, SM/BS/YSM=`docs/reviews/NOMAD_Shorts_Maker.md` / `Nomad-BlogStudio.md` / `Youtube_shots_Maker.md`. 근거 없는 값은 "제안", 외부 사실을 확인하지 않은 값은 "미확인"으로 표시한다.

## 1. 페르소나와 핵심 과제

| 페르소나 | 상황 | 목표 | 좌절 |
|---|---|---|---|
| 민재(29, 1인 숏폼 크리에이터) | 퇴근 후 2시간, YouTube 채널 3개 | 중국 드라마 숏폼을 매일 3편씩 KO/JA/EN으로 올려 광고 수익 | 번역·더빙·자막·업로드를 손으로 하면 1편에 2시간. 채널 정지 위험을 모른다 |
| 수진(35, 커머스 리뷰 채널) | 쿠팡파트너스 수익이 주 수입 | 상품 시연 숏폼마다 랜딩과 제휴 링크를 자동으로 붙인다 | 대가성 문구를 빠뜨려 경고를 받은 적이 있다. 링크 클릭 통계가 흩어져 있다 |
| 태호(41, 음원·플리 채널 운영, 팀 3인) | Lofi 채널 2개 + 플리 채널 1개 | Suno 곡을 단일 곡 영상으로 올리고 무드별 1시간 플리를 주 2회 만든다 | 곡별 저작권 근거와 트랙리스트·타임스탬프 작성이 번거롭다 |

| 핵심 과제 | 측정 |
|---|---|
| 소재 선택부터 업로드까지 한 화면에서 자동으로 끝낸다 | 숏폼 30분, 롱폼 2시간 이내(PRD:720-721) |
| 업로드 전에 채널 위험과 법적 표시를 서버가 강제한다 | compliance 게이트 통과율 95% 이상(PRD:726), 제휴 업로드 대가성 문구 누락 0건 |
| 사용량만큼만 과금하고 실패는 자동 환불한다 | 원장 drift 0, 실패 잡 환불률 100% |

## 2. 범위: MVP와 Phase

확정 결정 7(MA:15)이 범위의 정본이다. 분석 원문의 "MVP는 A, B, C"(MA:725-728)와 "YouTube Live 폐기"(MA:598)는 확정 결정으로 대체되었다.

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
| 제휴 링크·대가성 문구 자동 삽입(전 Track), 링크인바이오 `/lb/[handle]` | MVP | 확정 결정 12, MA:621 |
| compliance 게이트(규칙 + LLM) | MVP | PRD 9-4 |
| Toss 구독·크레딧팩 | MVP | 확정 결정 4 |
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
| VD-F-001 | 가입·부트스트랩 | 통합 | Supabase Auth 이메일+Google. 가입 폼은 `signup_app='video'` 전송. 코어 트리거가 개인 조직·Starter 엔타이틀먼트·100크레딧 지급 | 가입 직후 `session_context('video')`가 `plan_code=starter`, `credit_balance=100` | BS #9, CORE_SPEC 2.2, PRC:23 |
| VD-F-002 | 라우트 보호 | 통합 | `proxy.ts`가 `/dashboard/**`, `/api/**` 보호. 공개 예외: `/`, `/pricing`, `/legal/**`, `/landing/**`, `/lb/**`, `/r/**`, `/api/webhooks/**`, `/billing/success|fail`. Mock 로그인 없음 | 비로그인으로 `/dashboard` 접근 시 `/login` 302, `/landing/x` 200 | SM #6, BS #10 |
| VD-F-003 | 플랜 게이팅 | 디벨롭 | 서버가 `entitled_plan_code` + `plans.features`로 Track, 언어, 채널 수, 플랫폼, 레이더 범위를 판정. DB도 `video.org_has_feature`로 Track D/F 쓰기를 막는다 | Starter 조직이 Track B 생성 요청 시 403 `VD009`. Starter가 `longform_projects` 직접 INSERT 시 42501 | PRC:116-143, SM #13 |
| VD-F-010 | 플레이보드 랭킹 | 디벨롭 | KR/US/JP x 카테고리 x realtime/daily/weekly, 24시간 주기 수집. `weighted_score = views_24h x growth_rate 가중치`. 성장률을 계산할 수 없으면 `growth_rate=null`, `is_estimated=true`로 표시하고 난수를 쓰지 않는다 | 수집 행에 난수 지표 0건. UI에 "추정" 배지 | PRD 3-1, SM #17 |
| VD-F-011 | 채널파인더 | 유지 | 구독자 상한, 최근 평균 조회수 하한, 기간 필터. 등급 S(>=15) A(10~14) B(5~9) C(2~4) D/F(<2) | 같은 입력에 같은 등급(단위 테스트) | PRD 3-2 |
| VD-F-012 | 블링 리포트 | 유지 | 주제 점수 0~100, KO/JA/EN 수익 추정, GEO 키워드, 대본 구조, 추천 Track. 수익 추정에는 근거 출처 1개 이상 필수(DB CHECK). 월 한도 `bling_monthly_limit`(Pro 20, Advanced 무제한) | 출처 없는 리포트 저장 시 23514. Pro 21번째 요청 402가 아니라 429 `VD012` | PRD 3-3, MA:556 |
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
| VD-F-063 | 제휴 제공자 | 신규 | 쿠팡파트너스: API 검색·링크 생성. 텐핑, 네이버쇼핑 커넥트: 공개 API 미확인 → MVP는 사용자가 제공자 화면에서 만든 링크를 붙여 넣어 등록, Phase 2에서 API 확인 후 어댑터 또는 Playwright(제안/확인 필요). 브랜드커넥트: video는 링크 등록만(지원 자동화는 blog 소유) | 제공자별 `capabilities` 표가 UI에 반영 | 확정 결정 12, SHARED_MODULES 17장 |
| VD-F-064 | 유료 프로모션 표시 | 제안 | 업로드 화면에 "유료 프로모션 포함" 체크박스. 제휴 링크가 있으면 체크를 권하는 안내만 하고 자동 체크하지 않는다 | `paid_promotion` 기본 false | 확정 결정 12 |
| VD-F-070 | 채널 연결 | 통합 | OAuth(서버 state, PKCE). 토큰은 `core.encrypted_credentials`. 역할 main/commerce/trend/longform/lofi/playlist/insurance + 언어 KO/JA/EN + 국가. YouTube 활성 채널 수 <= `max_channels`, 그 외 플랫폼은 `features.platforms` | Starter 2번째 YouTube 채널 연결 시 VD003 | ADD 추가 3, SM #5 |
| VD-F-071 | 업로드 | 통합 | resumable 스트리밍 업로드, 재시도 3회, 쿼터 초과 시 같은 언어·역할 대체 채널 → 없으면 다음 쿼터 리셋 시각으로 재예약. 예약 발행 | 300MB 파일 업로드 중 워커 RSS 512MB 이하(제안) | PRD 10-4, SM #18 |
| VD-F-072 | compliance 게이트 | 유지 | 규칙 사전(플랫폼 공통 + `banned_words`) → LLM 판정(compliance:true 플랜). FAIL 차단, WARN은 사용자 확인 RPC 후 진행, LLM 오류는 WARN 처리. Starter는 규칙 단계만(제안) | FAIL 업로드를 approved로 바꾸면 DB VD011 | PRD 9-4, SHARED_MODULES 13장 |
| VD-F-073 | 다국어 GEO 메타 | 통합 | 제목/설명/태그 KO/JA/EN 생성 | 언어판마다 메타 3종 | YSM:98, PRD 10-2 |
| VD-F-074 | 국가별 권장 시각 | 유지 | KO 18~21시 KST, JA 19~22시 JST, EN 18~21시 EST 기본값. Analytics 기반 보정은 Phase 3 | 예약 기본값이 표와 일치 | ADD 추가 8 |
| VD-F-080 | 성과 수집 | 디벨롭 | YouTube Analytics 일 1회 스냅샷. 제휴 클릭은 `core.affiliate_clicks` 집계 | 대시보드 수치가 스냅샷과 일치, 더미 0건 | SM #17, BS #16 |
| VD-F-090 | 결제 | 통합 | 코어 Toss 모듈: 주문 선저장 → 결제창 → confirm. 구독은 빌링키. Advanced는 `adv_pack_*` 할인 팩만 허용(서버 판정) | 금액 위조 요청 PM001. 결제 E2E 통과 | SM #2-3, BS #4-5 |
| VD-F-091 | 크레딧 | 통합 | 선차감 → 잡 → 실패 자동 환불. 잔액 부족 402 + 필요량 표시 | 동시 50요청에 음수 잔액 0 | CORE_SPEC 4장 |
| VD-F-092 | 팀 멤버 | 유지 | Advanced만 초대 화면(최대 5인, `team_members`) | Pro 조직 초대 API 403 | PRC:105 |

## 4. 요금과 크레딧

정본: PRC(확정 결정 8). 모듈러 `seed.sql:209-223`, 모놀리스 `supabase/monolith/seed.sql`과 같다. Track F는 확정 결정으로 추가된 Track이라 PRC에 없다. E와 같은 Suno 엔진을 쓰므로 Pro 이상으로 둔다(모듈러 seed와 같음, 제안).

| 코드 | 가격 | 월 크레딧 | 가입 크레딧 | 이월 | 주요 features |
|---|---|---|---|---|---|
| starter(기본) | 0원 | 0 | 100(1회) | 없음 | tracks A, KO, 채널 1, watermark, youtube |
| basic | 49,000원/월 | 1,200 | 0 | 불가 | A~C, KO, 채널 5, 플레이보드, compliance, 무음컷, 쿠팡 랜딩 |
| pro | 99,000원/월 | 3,000 | 0 | 불가 | A~F, KO/JA/EN, 채널 15, 4개 플랫폼, 레이더 전체, 레이어, Suno, OSMU, 블링 20회 |
| advanced | 149,000원/월 | 5,000 | 0 | 불가 | Pro + 채널 40, 팀 5인, React Flow, API, 블링 무제한, 크레딧팩 30% 할인 |

`core.plans.features` 키 해석(서버만 읽는다):

| 키 | 타입 | 의미 |
|---|---|---|
| `tracks` | text[] | 생성 가능한 Track. DB 정책은 D, F를 `org_has_feature(org,'tracks',x)`로 검사 |
| `languages` | text[] | TTS·메타 생성 언어 |
| `max_channels` | int | 활성 YouTube 채널 상한(트리거 `enforce_channel_limit`) |
| `platforms` | text[] | 연결·업로드 가능한 플랫폼 |
| `watermark` | bool | true면 렌더 워커가 워터마크 강제 |
| `radar` | false 또는 text[] | playboard / channel_finder / bling |
| `compliance` | bool | LLM 판정 단계 사용. false여도 규칙 단계는 필수(제안) |
| `silence_cut`, `layer_composite`, `osmu`, `suno`, `coupang_landing` | bool | 해당 기능 |
| `bling_monthly_limit` | int | 월 블링 리포트 수, -1 무제한, 키 없음 0 |
| `team_members` | int | 조직 활성 멤버 상한 |
| `priority_render` | bool | BullMQ priority 1(기본 100) |
| `react_flow_full`, `api_access` | bool | Phase 2 기능 |
| `credit_discount_pct` | int | 30이면 `adv_pack_*` 구매 허용 |

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
| compliance LLM 검사 / 업로드(채널당) | 1 / 1 | PRD:637-638 |
| 단일 곡 루프 영상 인코딩 | 5 | 제안: 정지 이미지 루프라 롱폼 10분 단가의 절반 |
| 플리 렌더(30/60/180분) | 15 / 30 / 90 | 제안: 롱폼 인코딩 10분당 10의 절반(이미지 1장 + 오디오 연결로 연산이 적음) |
| 플리 메타(트랙리스트·타임스탬프·고정 댓글) / 무드 썸네일 | 2 / 3 | 제안: 트렌드 분석·이미지 단가와 같게 |
| OSMU 하이라이트 3개(선정 + 3개 인코딩) | 2 + 9 | 제안: 분석 2 + 숏폼 인코딩 3 x 3 |
| DSP 유통 패키지 | 0 | 제안: 외부 비용 없음. Distrokid 배포 5크레딧(PRD:636)은 Phase 2 자동 배포에 적용 |

예: Track A 60초, 3언어 = 소싱 1 + STT 5 + TTS 12 + 무음컷 2 + 레이어 3 + 인코딩 9 = 32크레딧(업로드·검사 별도).

크레딧팩(PRC:149-154): pack_500 15,000원 / pack_1000 28,000원 / pack_3000 75,000원 / pack_5000 110,000원. Advanced 전용 adv_pack 4종 10,500 / 19,600 / 52,500 / 77,000원. 모듈러 seed에는 adv_pack이 없어 코어 요청 작업으로 둔다(06장 6절).

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
| 레이트 리밋 | 생성 API 조직당 60회/분, 웹훅 제공자당 600회/분, `/r/[code]` IP 해시당 60회/분, 로그인 IP당 10회/10분, 랜딩 조회수 집계 IP 해시당 1회/10분 | SECURITY_BASELINE 8장, 마지막은 제안 |
| 하트비트 | 60초, `reap_stale_jobs(600)` 10분 | CORE_SPEC 9.2 |

## 6. 법, 개인정보, 금지 문구

| 항목 | 내용 |
|---|---|
| 개인정보 수집 | 이메일, 표시 이름, 결제 식별자(Toss), 연결 채널 식별자와 OAuth 토큰(암호문), 제휴 클릭의 IP 일 단위 솔트 해시·UA·국가. 목적: 서비스 제공, 결제, 업로드, 수익 통계 |
| 보존과 삭제 | 5장 보존 표. 조직 삭제는 soft delete 후 30일 유예 뒤 `purge_organization`(SECURITY_BASELINE 12장). 채널 연결 해제 시 토큰 즉시 폐기(`revoke_credential`) |
| 암호화 대상 | `core.encrypted_credentials`(YouTube/Meta/TikTok 토큰, 쿠팡·제휴 키), `core.billing_keys`. 제품 테이블에 평문 토큰 컬럼 없음 |
| 제3자 제공 | OpenAI/Anthropic(OpenRouter 경유)에 대본·자막 텍스트, DeepL에 번역 텍스트, ElevenLabs에 TTS 텍스트, fal에 이미지 프롬프트, Suno에 곡 프롬프트, 플랫폼(YouTube/Meta/TikTok)에 영상·메타. 개인정보처리방침에 위탁·국외 이전으로 명시 |
| 약관·고지 | 이용약관, 개인정보처리방침, 생성물 권리와 책임(사용자가 원본 권리 근거를 선언하고 책임진다), AI 생성 표시(제안: 업로드 시 플랫폼의 합성 콘텐츠 표시를 기본 체크. 플랫폼 정책 세부는 미확인) |
| 원본 저작권 | Track A/B/C Mode2 원본은 "무료 배포"여도 재가공·수익화 허락이 아니다. 소싱 시 `rights_basis`(public_free/creative_commons/licensed/own) 선택과 근거 메모 필수, 권리자 신고 시 해당 업로드 비공개·삭제 절차(제안: 접수 후 24시간 내 처리). 법률 검토 필요(01장 8절) |
| 음원 권리 | Suno 생성곡의 상업 이용 권리는 Suno 요금제에 따라 다르다(미확인). DSP의 AI 음원 정책도 미확인. 플리 곡은 Suno 생성곡 또는 증빙 업로드한 라이선스 곡만(DB 트리거 VD006) |
| 제휴·광고 | 공정위 "추천·보증 등에 관한 표시·광고 심사지침"에 따라 대가성 문구를 설명란 첫 줄과 고정 댓글 첫 줄에(CORE_SPEC 13.3). 끌 수 없음(DB CHECK `uploads_disclosure_check`). 랜딩·링크인바이오는 CTA·링크 옆에 표시 |
| 플랫폼 약관 | YouTube API 서비스 약관(쿼터, 데이터 삭제 의무 세부 미확인), 다채널 "보험 채널" 운영은 스팸·반복 콘텐츠 정책 위반 위험이 있어 첫 연결 시 위험 고지와 동의 기록(audit `channel.risk_ack`, 제안). 도우인·샤오홍슈 수집은 각 플랫폼 약관 위반 위험 고지. 쿠팡파트너스 운영 정책 준수(문구 원문 사용) |
| 금지 문구(마케팅) | 가상 후기·평점, 미검증 수치(원본 랜딩의 "128,470+ 생성", `NOMAD Shorts Maker/src/app/page.tsx:164`, "-95% 시간단축" DESIGN.md:468), 보장 표현("확정 수익", "100% 통과", "채널 정지 없음"), 타사 상표 오용(YouTube 로고·빨간색 브랜드) |
| 금지 문구(생성물) | 블링 수익 추정은 "추정"과 출처를 항상 표시, 보장 표현 금지. 의료·금융 단정 표현은 compliance 규칙 사전에 등록. 커머스 대본에 허위 효능·최상급 단정("1위", "최저가") 금지 |
| 규제 특례 | 해당 없음(의료·금융·미성년 특례 없음). 단 만 14세 미만 가입 불가(제안) |

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

## 8. 열린 결정

| # | 항목 | 선택지 | 권고 |
|---|---|---|---|
| 1 | 모놀리스 스키마 | (a) `public`(코어 lite 그대로) (b) 제품 스키마 | (a). 사용자 최종 확인 대기 |
| 2 | Track F 허용 플랜 | (a) Pro 이상(seed 현재값) (b) Basic 포함 | (a). Suno 엔진을 쓰는 E와 같은 등급 |
| 3 | Starter compliance | (a) 규칙 단계만 필수 (b) 검사 없음(PRC 그대로) | (a). "업로드 전 검증 필수"(PRD:710)와 플랜표(PRC:28) 충돌을 비용 0인 규칙 단계로 해소 |
| 4 | Advanced 30% 할인 | (a) adv_pack 4종 seed 추가 (b) 코어 주문에 할인 지원 | (a). 코어 변경 없음. 모듈러 seed 갱신은 코어 담당에 요청 |
| 5 | 네이버 로그인 | (a) MVP 제외 (b) naver_id 매핑 + 명시적 연결 | (a). Phase 2에서 (b), 이메일 자동 병합 금지(YSM #3) |
| 6 | 대용량 미디어 저장소 | (a) Supabase `video-media` 버킷 5GB (b) 외부 객체 저장소(R2 등) | (a)로 시작, 월 저장량 1TB 초과 시 (b) 검토(제안) |
| 7 | Track A 원본 권리 | 법률 검토 전 출시 범위 | 권리 근거 선언 + 신고 처리 절차를 갖추고 출시, 법률 검토 병행 |
| 8 | Suno 연동 방식 | 공식 API / 대행 API / 수동 업로드 | 공식 API 확인 전에는 사용자가 생성한 곡 파일 업로드 경로를 함께 둔다(제안) |
| 9 | 유료 프로모션 자동 표시 | 자동 / 안내만 | 안내만(확정 결정 12 "제안") |
| 10 | 텐핑·네이버쇼핑 커넥트 | API / Playwright / 수동 | 수동으로 출시, API 확인 후 결정 |
| 11 | 랜딩·링크인바이오 문구 배치 | `video_description` 재사용 / 코어에 `landing` 배치 추가 | 재사용으로 시작, 코어 요청 등록 |
| 12 | 산출물 보존 기간 | 5장 제안값 | 사용자 확인 필요 |
