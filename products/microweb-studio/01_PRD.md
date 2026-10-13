# 01 PRD: Microweb Studio

2026-10-13 개정: 확정 결정 13~17(`docs/products/00_MERGE_ANALYSIS.md:21-25`)에 따라 AI 계층(템플릿·문구 RAG, 이벤트 종류별 문구 위키, LangGraph `microweb.invitation_copy`, Dify 제작 상담 채팅), 음성(제작 상담 음성 대화, 청첩장 인사말 음성, 하객 음성 방명록), 상용/오픈소스 모델 이원화와 국외 이전 동의, 쇼룸 3D 히어로를 MVP에 넣었다. 설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`, `docs/products/_design-guide/HERO_3D.md`, `DESIGN_SYSTEM.md`이고 이 문서는 제품 요구만 정한다. "제안"은 원본과 리뷰에 근거가 없어 이 문서가 새로 정한 값이다.

## 1. 페르소나와 핵심 과제

| 페르소나 | 상황 | 목표 | 좌절 |
|---|---|---|---|
| 운영자 "한결"(스튜디오 대행 제작자, 1인) | 문의를 받아 청첩장을 대신 만들어 준다. 지금은 커플마다 코드(`constants.ts`)를 고쳐야 한다(`docs/reviews/premium-wedding-invitation.md:71`) | 문의 1건을 3일 안에 게시까지 끝낸다 | 문의가 버튼만 있고 저장되지 않는다(`docs/reviews/webcraft-agency-simulator.md:33`). 사진과 지도가 AI 가짜라 고객에게 내놓을 수 없다(`premium-wedding-invitation.md:60`) |
| 예비부부 "서윤"(대행 고객) | 결혼 3개월 전, 모바일 청첩장을 맡기고 싶다 | 시안을 휴대폰으로 확인하고 수정 요청 후 승인한다 | 계정을 또 만들기 싫다. 계좌번호와 전화번호가 검색에 노출될까 걱정한다 |
| 하객 "민호" | 카카오톡으로 링크를 받았다 | 일시·장소를 확인하고, 길을 찾고, 축의금을 보내고, 축하 글을 남긴다 | 첫 화면이 몇 초 회색이다(`premium-wedding-invitation.md:59`). 지도가 실제와 다르다 |
| (2단계) 셀프 사용자 "지아" | 초대 코드를 받은 예비부부 | 직접 편집하고 결제 후 바로 게시한다 | 대행비 부담 |

| 핵심 과제 | 설명 |
|---|---|
| T1 다중 고객 엔진 | 한 코드베이스로 `/i/:slug` 여러 건을 데이터(블록 JSON)로 렌더한다(`premium-wedding-invitation.md:85`, `:103`) |
| T2 대행 파이프라인 | 문의 → 제작 주문 → 시안 확인 → 결제 확인 → 게시 → 만료를 한 화면(`/studio`)에서 추적한다(`docs/products/00_MERGE_ANALYSIS.md:1079-1081`) |
| T3 하객 안전 | 공개 페이지는 게시본만 보이고, 하객 쓰기는 레이트 리밋과 스팸 검사를 거치며, 개인정보는 기간이 지나면 내려간다 |

## 2. 범위: MVP와 Phase

| 기능 | 범위 | 근거 |
|---|---|---|
| 청첩장 템플릿 1종(`wedding_classic`)과 블록 엔진 | MVP | `00_MERGE_ANALYSIS.md:1091` "청첩장만 출시 후 확장"(권고, 채택) |
| `/i/:slug` 공개 페이지, slug별 OG 메타, 카카오 공유 | MVP | `00_MERGE_ANALYSIS.md:1037-1038` |
| 방명록(Supabase), 참석 여부(RSVP) | MVP | `00_MERGE_ANALYSIS.md:1033`. RSVP는 제안(이유: 하객 수 파악이 대행 고객의 공통 요청이며 같은 쓰기 경로를 재사용) |
| AI 축하말(전용 엔드포인트) | MVP | `00_MERGE_ANALYSIS.md:1092` 권고 B |
| 운영자 편집기 `/studio`, 사진 업로드 | MVP | `00_MERGE_ANALYSIS.md:1062`, `premium-wedding-invitation.md:104` |
| 쇼룸 `/`, `/portfolio`, `/pricing`, `/simulator`, `/templates`, `/contact` | MVP | `00_MERGE_ANALYSIS.md:1012-1020` |
| 견적 문의 저장과 리드 관리, 제작 주문 장부(수기 결제 기록) | MVP | 확정 결정 11(대행 시작), `00_MERGE_ANALYSIS.md:1058` |
| 고객 시안 확인 링크 `/p/:token` | MVP | 신규(제안). 이유: 대행 고객은 계정이 없으므로 승인 기록이 필요 |
| 돌잔치·부고장 템플릿 | Phase 2 | `00_MERGE_ANALYSIS.md:1091` |
| 셀프서비스 편집 + Toss 크레딧팩 발행 | Phase 2 | 확정 결정 11 |
| 히어로 AI 보정 1회 | Phase 3 | `00_MERGE_ANALYSIS.md:1092` 권고 "C는 2단계로" → 셀프서비스 뒤로 |
| 나머지 9개 모델(미니 홈피, 행사 안내 등) | Phase 3 이후 | nexus 카탈로그에 "준비 중"으로만 노출 |
| 청첩 문구·사이트 구성 제안 LangGraph `microweb.invitation_copy`, 템플릿·문구 예시 RAG | MVP | 확정 결정 13(`docs/products/00_MERGE_ANALYSIS.md:21`) |
| 이벤트 종류별 문구 위키(제품 지식 위키) | MVP | 확정 결정 13, `docs/products/_platform-core/LLM_WIKI.md:37-47` |
| 제작 상담 AI 채팅(스튜디오 로그인 사용자), 제품별 Dify 앱 `microweb-chat` | MVP | 확정 결정 13, 14(`docs/products/00_MERGE_ANALYSIS.md:21-22`) |
| 음성 대화(제작 상담 음성 질문, 답변 읽어 주기) | MVP | 확정 결정 16(`docs/products/00_MERGE_ANALYSIS.md:24`) |
| 청첩장 인사말 음성(TTS 또는 호스트 녹음) | MVP | 확정 결정 16 |
| 하객 음성 방명록(STT 자막, 하객 고지·동의, 익명 엄격 제한) | MVP | 확정 결정 16, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:94-95` |
| 상용/오픈소스 모델 이원화, 온보딩 국외 이전 동의 | MVP | 확정 결정 17(`docs/products/00_MERGE_ANALYSIS.md:25`), `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| 쇼룸 3D 히어로(봉투 → 청첩장 카드 → 미니 사이트) | MVP | 확정 결정 15(`docs/products/00_MERGE_ANALYSIS.md:23`), `docs/products/_design-guide/HERO_3D.md:86` |
| 쇼룸 비로그인 방문자 AI 상담 | Phase 2 | 제안: 운영자 예산과 강한 레이트 리밋이 필요하다(`docs/products/_platform-core/AI_ARCHITECTURE.md:130`). MVP 쇼룸은 `/contact` 문의로 이끈다 |
| 사용자 보이스 선택, 본인 음성 복제 | Phase 2 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:80`. 타인(유명인, 고인) 음성 복제는 제공하지 않는다 |

## 3. 기능 요구사항과 수용 기준

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| MW-F-001 | 블록 엔진 | 신규 | 템플릿은 `allowed_blocks`/`required_blocks`를 가진다. 사이트 `content`는 `{theme, blocks:[{type, props}]}` JSON(256KB 이하). 블록 17종: hero, greeting, hosts, calendar, gallery, location, transport, contacts, accounts, wreath, guestbook, rsvp, bgm, notice, share, timeline(돌), memorial/funeral_info(부고). `greeting` 블록은 선택 `voice_asset_id`(MW-F-031), `guestbook` 블록은 선택 `voice_enabled`, `voice_public`(MW-F-032) | 필수 블록이 빠진 content로 게시 요청하면 422가 반환된다. 모르는 블록 타입은 zod가 거부한다 | `00_MERGE_ANALYSIS.md:1078`, `premium-wedding-invitation.md:100` |
| MW-F-002 | 히어로 | 디벨롭 | 업로드한 실제 사진 1~5장 캐러셀, 5초 전환, 크로스페이드. 방문 시 AI 호출 0건 | 하객 페이지 네트워크 로그에 LLM/이미지 생성 요청이 없다 | `premium-wedding-invitation.md:94` |
| MW-F-003 | 오시는 길 | 디벨롭 | 주소, 좌표, 카카오/네이버 지도 딥링크, 대중교통/주차 텍스트. 지도는 카카오맵 임베드(정적 지도 API 약관은 미확인) | AI 생성 지도 이미지가 코드에 없다. 딥링크가 좌표로 열린다 | `premium-wedding-invitation.md:79` |
| MW-F-004 | 연락처·계좌 | 유지 | tel/sms 링크, 계좌 복사, 신랑측/신부측(side_a/side_b) 아코디언. 게시 전 공개 동의(`disclosure_consent_at`) 필수 | 동의 없이 게시 요청하면 MW006 | `premium-wedding-invitation.md:32` |
| MW-F-005 | 갤러리 | 디벨롭 | 최대 30장(플랜 `max_gallery_photos`), 라이트박스, lazy 로딩, 400/800/1600w webp | 30장 페이지의 LCP 이미지 외에는 `loading="lazy"` | `premium-wedding-invitation.md:105` |
| MW-F-006 | 방명록 | 디벨롭 | 이름 1~20자, 본문 1~500자, URL 금지, 같은 IP 해시 10분 3건, 사이트당 하루 500건, 같은 본문 1시간 중복 금지. 숨김/스팸 처리와 삭제는 운영자만 | 4번째 연속 작성은 `rate_limited`. 하객 화면에 삭제 버튼이 없다 | `premium-wedding-invitation.md:65`, `:98-99` |
| MW-F-007 | AI 축하말 | 디벨롭 | 입력은 관계 5종과 어조 2종(정중/친근, 제안)뿐이다. 하객 이름은 모델에 보내지 않는다(이름은 방명록 입력란에만 쓴다). 고정 라우팅 기능 `microweb_greeting`(FastAPI 그래프 `microweb.guest_greeting`: `guard` → `draft` → `compliance`, 02장 5.2절)과 고정 프롬프트, 결과 200자 이하. IP 해시당 시간 5회, 사이트당 30일 300회(제안). 실패 시 "자동 작성에 실패했습니다. 직접 입력해 주세요" | 6번째 호출은 429. 실패 시 고정 문구로 위장하지 않는다. 모델 요청 본문에 하객 이름 0(테스트). 클라이언트가 기능·모델·헤더를 지정할 수 없다 | `premium-wedding-invitation.md:95`, `:70` |
| MW-F-008 | RSVP | 신규(제안) | 이름, 측, 참석(yes/no/undecided), 인원 1~10, 식사, 메시지 200자. 예식 시각 이후 마감. 운영자 CSV 내보내기 | 예식 후 제출하면 `closed`. 하객은 다른 응답을 볼 수 없다 | 제안 |
| MW-F-009 | 공유와 OG | 디벨롭 | 링크 복사, Web Share, 카카오 공유(환경변수 키, 공식 SRI). slug별 og:title/description/image(1200x630) | 카카오 디버거에서 slug별 제목과 이미지가 다르게 나온다 | `premium-wedding-invitation.md:96`, `:88` |
| MW-F-010 | 배경음악 | 유지 | 자체 호스팅 라이브러리 또는 업로드 mp3(10MB 이하), 기본 꺼짐, 사용자 탭으로 재생 | 자동 재생하지 않는다 | `premium-wedding-invitation.md:105` |
| MW-F-011 | 공개 범위 | 신규 | 공개 페이지는 게시 스냅샷만 읽는다. 기본 `noindex`, robots.txt에서 `/i/`, `/p/` 차단. 만료 기본값 예식 + 90일, 최대 + 365일 | 초안 사이트 slug는 404. 만료 뒤 10분 안에 410 | `00_MERGE_ANALYSIS.md:1083` |
| MW-F-012 | 사이트 생성·편집 `/studio` | 신규 | 템플릿 선택, slug(4~40자, 소문자/숫자/하이픈, 예약어 금지), 블록 편집, 실시간 모바일 미리보기, 자동 저장 3초 | 첫 게시 뒤 slug 변경은 MW002 | `premium-wedding-invitation.md:104` |
| MW-F-013 | 사진 업로드 | 신규 | jpeg/png/webp 15MB 이하, 서버가 매직바이트 재검사, EXIF(GPS 포함) 제거 후 파생본 생성. HEIC는 Phase 2(변환 지원 미확인) | EXIF가 남은 파일은 `ready`가 될 수 없다(DB 제약) | `00_MERGE_ANALYSIS.md:1080` |
| MW-F-014 | 게시 | 신규 | 대행: 결제된 제작 주문 + 고객 승인 필요(재게시는 면제). 셀프: 크레딧 차감 원장 필요. 게시 잡이 파생본을 `public-assets`로 복사 후 스냅샷 생성 | 결제 전 게시 요청은 MW008, 실패 시 크레딧 자동 환불 | `00_MERGE_ANALYSIS.md:1079` |
| MW-F-015 | 게시 중단·만료·보관 | 신규 | 중단은 owner/admin, 만료는 스케줄(10분), 공개 파생본 삭제 잡. 보관 30일 뒤 하객 데이터 삭제 | 중단 즉시 anon 조회 0행 | 제안 |
| MW-F-016 | 시안 확인 링크 | 신규(제안) | 토큰 48자 hex, DB에는 sha256만, TTL 기본 7일·최대 14일. 고객이 이름 입력 후 "이 시안으로 진행" | 만료 토큰은 MW013 | 제안 |
| MW-F-017 | 견적 문의 `/contact` | 디벨롭 | 이름, 연락처(전화 또는 이메일), 종류, 템플릿/등급/업종, 시뮬레이터 선택값, 예식일, 메시지 2000자, 개인정보 수집 동의 필수, 허니팟, IP 해시 10분 3건 | 동의 없으면 `invalid`. 운영자에게 이메일 알림 1건 | `webcraft-agency-simulator.md:113`, `00_MERGE_ANALYSIS.md:1058` |
| MW-F-018 | 리드 관리 | 신규 | 상태 new → contacted → quoted → won/lost, spam. 1년 뒤 자동 삭제, 삭제 요청 즉시 삭제 | 허용되지 않은 전이는 MW001 | `00_MERGE_ANALYSIS.md:1081` |
| MW-F-019 | 제작 주문 장부 | 신규 | quoted → paid(결제수단·참조 필수) → in_production → delivered → closed, 취소/환불. 카드번호 저장 금지 | 12자리 이상 숫자열 참조는 거부 | `00_MERGE_ANALYSIS.md:1079` |
| MW-F-020 | 템플릿 카탈로그 `/templates` | 통합 | nexus 12개 모델. beta/released는 "만들기", planned(phase2/3)는 "준비 중" 시안, backlog는 숨김 | 카탈로그가 DB `templates`에서 렌더된다 | `nexus-micro-web-builder.md:108`, `00_MERGE_ANALYSIS.md:1041` |
| MW-F-021 | 포트폴리오 `/portfolio` | 디벨롭 | 실제 납품작만(WebSite 엔트리 포함). 고객 게시 동의와 이미지가 없으면 게시 불가(DB 제약). 상세페이지 탭 유지 | picsum URL이 코드에 없다 | `00_MERGE_ANALYSIS.md:1048` |
| MW-F-022 | 가격표 `/pricing` | 통합 | 웹 제작 4등급 + 마이크로웹 템플릿 가격대 한 표. 할인 표시는 실제 정가 판매 이력이 있을 때만 | 근거 없는 "50% 할인" 문구가 없다 | `00_MERGE_ANALYSIS.md:1050` |
| MW-F-023 | 시뮬레이터 `/simulator` | 유지 | 업종 9 x 등급 4, 디바이스 3종. "이 조합으로 상담받기"가 선택값을 `/contact`에 넘긴다. Custom의 병원·교육은 admin-suite 데모 링크(Phase 2) | 선택값이 리드 `simulator` jsonb에 저장된다 | `webcraft-agency-simulator.md:30`, `00_MERGE_ANALYSIS.md:1053` |
| MW-F-024 | 초대제 베타 | 신규 | Supabase Auth 공개 가입 끔, 운영자가 초대 메일 발송, `studio_access` 허용 목록 | 엔타이틀먼트만 있고 허용 목록이 없는 조직은 `/studio`에서 0행, `create_site` 42501 | 브리프, 05장 3절 |
| MW-F-025 | 셀프서비스(Phase 2) | 신규 | `studio_access.mode='self_service'`, 발행 1건 = 템플릿 `self_publish_credits` 차감 | 잔액 부족 402, 게시 실패 시 환불 행 1개 | 확정 결정 11 |
| MW-F-026 | 청첩 문구·구성 제안 | 신규 | 편집기 "AI로 문구 제안"이 FastAPI 그래프 `microweb.invitation_copy`를 실행한다: `intake`(입력 정리, LLM 없음) → `retrieve`(템플릿·문구 예시 RAG + 문구 위키) → `draft_copy`(인사말·안내 문구 초안 3안) → `propose_composition`(블록 순서, 필수 블록, 테마 제안 JSON) → `compliance`(금지 문구, 템플릿 `allowed_blocks`/`required_blocks`와 블록 zod 스키마 검사, 걸린 안만 1회 재작성). 입력은 이벤트 종류, 어조, 월/계절, 호칭 토큰(`{{신랑}}`, `{{신부}}`, `{{혼주}}`), 운영자 메모 500자뿐이고 실명·전화·계좌·사진은 보내지 않는다. 결과는 `sites.content`에 자동 반영하지 않고 운영자가 안마다 "적용"을 눌러야 블록 props에 들어간다(사람 승인 지점). 크레딧은 실행 전 선차감 후 정산(4.1절) | 1회 실행 = `core.ai_runs` 1행 + 노드별 `ai_run_steps`. 제안 JSON이 템플릿 필수 블록을 모두 포함하고 모르는 블록 타입 0개. 금지 문구 규칙 위반 0(평가셋 30건, 제안). 모델 요청 본문에 실명·전화·계좌 패턴 0(테스트). 실패 시 선차감 전액 환불, 같은 `request_id` 재전송 차감 1회. "적용" 전 `sites.content` 변경 0 | `docs/products/_platform-core/AI_ARCHITECTURE.md:109-119`, 02장 5.2절 |
| MW-F-027 | 템플릿·문구 예시 RAG | 신규 | 운영자가 작성한 문구 예시·표현 가이드(`content/copy/`)와 템플릿 카탈로그 설명(블록 구성, 어조 가이드)을 지식 조직(`MICROWEB_KNOWLEDGE_ORG_ID`)의 컬렉션 `microweb-copy`, `microweb-templates`(kind `rag`)에 색인한다. 임베딩은 오픈소스(`microweb_knowledge`, 대체 없음). 고객의 실제 청첩 문구·이름·연락처는 색인하지 않는다(`contains_pii=false`만). 조직 구분 없는 제품 공통 지식이라 Dify에는 외부 지식 API(`/dify/retrieval`)로만 노출하고 그래프와 `/tools/answer`는 FastAPI 안에서 같은 컬렉션을 검색한다 | 평가셋 40문항(제안)에서 상위 8개 안 정답 청크 재현율 0.8 이상(제안). 색인 전 검사에서 전화·계좌·이메일 패턴 0건. 외부 지식 응답에 사용자 조직 데이터 0. 원고 항목마다 작성자·검수일·라이선스 메타데이터 | `docs/products/_platform-core/AI_ARCHITECTURE.md:58-66`, `:94-107` |
| MW-F-028 | 이벤트 종류별 문구 위키 | 신규 | 문구 코퍼스를 원본으로 위키 ingest가 종류별 페이지를 만든다: `wedding/*`(인사말 어조, 혼주 표기, 계좌 안내 문구, 방명록 안내), `dol/*`, `obituary/*`, `concepts/*`(호칭, 존대 표기), `index`(지식 조직, app `microweb`). 새 페이지는 `draft`로 만들고 운영자가 검수해 `published`로 바꾼다. 운영자가 고친 블록은 사람 소유로 표시해 ingest가 덮어쓰지 않고 저장은 `expected_version` 낙관적 잠금, 문서 1건당 갱신 페이지 5개까지. 스튜디오 사용자는 `published` 페이지를 `/studio/wiki`에서 읽고 문구 제안·채팅의 근거로 쓴다(공개 웹에는 노출하지 않는다) | 스튜디오 화면에 `draft` 0. 페이지마다 "출처" 절. `dol/*`, `obituary/*`는 해당 템플릿이 beta로 전환되기 전까지 `published` 0. 출시 시 lint 깨진 링크 0 | `docs/products/_platform-core/LLM_WIKI.md:21-47` |
| MW-F-029 | 제작 상담 AI 채팅 | 신규 | 스튜디오(로그인 사용자) 우측 시트에서 제작 상담을 한다. 범주: 템플릿 고르기, 블록 구성, 문구 어조, 제작 절차와 대행 가격 범위(`templates` 카탈로그 값), 게시·만료·공개 동의 규칙, 하객 기능 설정. 근거는 코퍼스·위키·카탈로그이고 사이트 컨텍스트는 블록 종류·글자 수·상태만 쓴다(이름·연락처·계좌 본문 제외). 스트리밍, 답변마다 출처, "AI가 생성한 답변" 표시. 메시지 1,000자, 대화당 50턴(제안). 크레딧은 턴 선차감 후 정산(4.1절). 비로그인 쇼룸 상담은 Phase 2 | 답변에 출처 1개 이상 또는 "근거 자료를 찾지 못했습니다". 응답이 전달되지 않은 턴은 선차감 전액 환불. 잔액 부족 402(`CR001`). Dify 장애 시 `/tools/answer-direct`로 답한다. 다른 사용자의 대화 id로 이어 쓰면 404. 가격 답변의 금액이 `templates` 범위와 일치(평가셋) | `docs/products/_platform-core/AI_ARCHITECTURE.md:44-56`, `:121-130` |
| MW-F-030 | 음성 대화(제작 상담) | 신규 | 채팅 패널 마이크 버튼(누르고 말하기), 발화 최대 60초(제안). STT(`voice_chat`, 오픈소스 우선) → 변환 텍스트 미리보기·수정 → 전송 → 답변 → "읽어 주기"(TTS, ElevenLabs 우선, 자동 재생 기본 꺼짐). 녹음 원본은 저장하지 않는다. 첫 사용 전 음성 처리 고지 확인 | 60초가 되면 녹음 자동 중지. `voice_jobs.store_audio=false` 100%. 마이크 권한을 거부해도 텍스트 채팅 정상. 고지 확인 없이 STT 호출 시 403 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:40-48`, `:85-95`, `:106-110` |
| MW-F-031 | 청첩장 인사말 음성 | 신규 | 인사말 블록에 음성 인사를 붙인다. (a) 운영자가 인사말 본문(600자 이하, 제안)을 TTS(`microweb_voice_greeting`, 기본 보이스 1종)로 mp3 생성 → 들어 보고 확정. (b) 호스트(신랑·신부·혼주) 본인 목소리 녹음 업로드(60초 이하), 서버가 mp3로 변환. 둘 다 `site_assets` kind `voice`(mp3, 15MB 이하)로 저장하고 게시 때 하객 페이지에서 재생 버튼으로 제공한다(자동 재생 없음). TTS 결과는 편집 시 1회 생성한 파일을 재생하고 하객 방문마다 호출하지 않는다. AI 생성 음성은 플레이어에 "AI가 생성한 음성입니다"를 표시한다. 호스트 녹음은 본인 음성 확인과 공개 동의(01장 6절)가 있을 때만 게시. 타인(유명인, 고인) 음성 복제 없음 | 하객 페이지 네트워크 로그에 TTS/STT 요청 0건. 자동 재생 0. 공개 동의 없이 voice 자산이 있는 사이트 게시 요청 시 MW006. AI 생성 음성 플레이어에 표시 문구 존재. 재생성은 다시 선차감 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:75-83`, 01장 6절 |
| MW-F-032 | 하객 음성 방명록 | 신규 | 방명록 블록 옵션 `voice_enabled`(기본 꺼짐)를 켜면 하객이 30초(제안) 이내 음성 메시지를 남긴다. 순서: 녹음 전 하객 고지 모달(녹음됨, 호스트가 들음, 공개 재생 여부, 문자 변환, 보관 기간, 삭제 요청 방법, 만 14세 미만 보호자 동의) 확인 → 녹음 → 서버 STT(`microweb_guestbook_voice`, 오픈소스 강제) → 자막 미리보기·수정 → 이름 입력 후 제출. 자막이 방명록 `body`가 되고 음성 원본은 `voice-audio`에 보관(`store_audio=true`, `consent_kind='third_party_notice'`, 고지문 버전 기록, `expires_at` = 사이트 공개 만료 + 30일, 제안). 재생은 호스트 전용이 기본이고 블록 옵션 `voice_public`을 켜면 다른 하객도 재생한다. 익명 쓰기 엄격 제한: IP 해시당 10분 2건·하루 5건, 사이트당 하루 50건·30일 100건, 서명된 방문자 쿠키 필수, 허니팟, Origin 검사. 하객 크레딧 0, 비용은 `ai_usage`에 쌓이며 사이트 소유 조직이 부담 | 고지 확인 없이 업로드 시 403. 오픈소스 외 제공자로 간 `ai_usage` 0. `consent_kind`·`notice_version` 없는 보관 작업은 DB가 거부(23514). 10분 안 3번째 녹음 429. 숨김 처리한 항목의 음성 재생 404. 만료 후 `expire_voice_audio`로 파일 삭제. 음성 없이도 텍스트 방명록 정상 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:85-95`, `docs/products/_platform-core/SECURITY_BASELINE.md:297` |
| MW-F-033 | AI 라우팅과 국외 이전 동의 | 신규 | 스튜디오 첫 진입 온보딩에서 "AI 처리 방식"을 고른다: 상용 AI 사용(국외 이전 동의) 또는 국내 오픈소스만. 동의하면 `core.set_ai_cross_border_ack(org, true, 고지문 버전)`을 호출하고 설정에서 언제든 철회한다. 기능별 기본 체인은 02장 5.1절(seed와 일치). 동의가 없으면 모든 AI·음성 기능이 오픈소스 제공자만 쓴다. 하객 음성 STT는 동의와 무관하게 항상 오픈소스다 | 미동의 조직의 `ai_usage.provider_id`에 상용 제공자 0. 철회 직후 다음 요청부터 상용 0. 고지문 버전이 `ai_org_settings.cross_border_notice`에 남는다 | `docs/products/_platform-core/AI_ARCHITECTURE.md:86`, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:553-575` |
| MW-F-034 | AI 크레딧 선차감·정산 | 신규 | 문구 제안 실행, 채팅 턴, STT, TTS는 시작 전에 예상 크레딧을 `consume_credits`로 선차감하고 끝나면 실제 사용량으로 정산한다. 하객 기능(축하말, 음성 방명록)은 0 크레딧이며 비용은 `ai_usage`에 쌓이고 사이트당 상한으로 제한한다. 대행 모드(스튜디오 조직)의 AI 비용 처리는 열린 결정 D-9 | 1시간 넘게 지난 `ai_usage` 중 `settled_at is null` 0행. 같은 멱등 키 재요청 시 차감 1회. 원장 drift 0 | `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130` |
| MW-F-035 | AI 출력 규칙 | 신규 | 6절 금지 문구와 청첩장 규칙을 그래프 compliance 노드와 `/tools/answer` 후처리에 같은 규칙 파일(`content/rules/banned.json`)로 적용한다: 전화·계좌·주소 생성 금지, 보장 표현, 타사 상표, 가상 후기, 미검증 수치, 부고장에서 축하 표현. 자해·자살 언급은 상담 전화 안내로 전환한다 | 평가셋 30문항(제안) 위반 0. 위기 신호 테스트 문장 5개 모두 안내 문구로 응답 | `docs/products/_platform-core/AI_ARCHITECTURE.md:117` |
| MW-F-036 | 쇼룸 3D 히어로 | 신규 | `/` 히어로: PC·태블릿은 봉투가 열리고 청첩장 카드가 펼쳐져 미니 사이트(실제 엔진으로 렌더한 샘플)가 되는 풀 3D, 모바일은 제목·CTA를 HTML로 즉시 표시하고 봉투가 열리는 가벼운 3D만 첫 화면 뒤에 자동 로드, WebGL 미지원·저사양·`prefers-reduced-motion`은 정지 이미지(03장 4.6절). 이 히어로는 사용자 결정(2026-10-13)으로 기존 "휴대폰 화면 iframe" 안을 대체했다 | `HERO_3D.md` 4절 수용 기준 전부: 기기별 3종 동작, 3D 번들+에셋 PC·태블릿 1MB/모바일 300KB 이하, LCP 2.5초, 제목·CTA가 3D 전에 보이고 키보드로 사용 가능, 3종 스크린샷 고문 검토 통과 | `docs/products/_design-guide/HERO_3D.md:5-75`, `:86` |

## 4. 요금과 크레딧

정본: 대행가는 nexus 원본 기획값(`nexus-micro-web-builder/CLAUDE.md:120-135`)과 webcraft 가격표(`webcraft-agency-simulator/frontend/constants.ts:139-162`). 셀프서비스 크레딧은 이 문서의 제안이다(확정 결정 8에 microweb 항목 없음).

| 플랜 코드 | 가격 | 월 크레딧 | 가입 크레딧 | 이월 | features | 비고 |
|---|---|---|---|---|---|---|
| `free`(기본) | 0 | 0 | 0 | 아니오 | 아래 표 | 대행·셀프 모두 이 플랜. 매출은 대행비와 크레딧팩 |

| features 키 | 의미 | free 값 |
|---|---|---|
| `guestbook` | 방명록 블록 사용 | true |
| `rsvp` | RSVP 블록 사용 | true |
| `ai_greeting` | AI 축하말 사용 | true |
| `ai_greeting_per_site_30d` | 사이트당 30일 AI 호출 상한 | 300 (제안) |
| `bgm_upload` | mp3 업로드 | true |
| `max_gallery_photos` / `max_hero_photos` | 사진 수 상한 | 30 / 5 (제안) |
| `custom_slug` | slug 직접 지정 | true |
| `ai_copy` | 문구·구성 제안(MW-F-026) 사용. 키가 없으면 true로 읽는다 | true |
| `ai_copy_runs_per_site_30d` | 사이트당 30일 문구 제안 실행 상한. 키가 없으면 20 | 20 (제안) |
| `ai_chat` | 제작 상담 채팅(MW-F-029) 허용. 키가 없으면 true | true |
| `ai_chat_turns_per_day` | 사용자당 하루 채팅 턴 상한(공정 사용). 키가 없으면 100 | 100 (제안) |
| `voice_chat` | 음성 대화(MW-F-030) 허용. 키가 없으면 true | true |
| `voice_greeting` | 인사말 음성(MW-F-031) 허용. 키가 없으면 true | true |
| `guestbook_voice` | 하객 음성 방명록(MW-F-032) 허용. 키가 없으면 true | true |
| `guestbook_voice_per_site_30d` | 사이트당 30일 하객 음성 메시지 상한. 키가 없으면 100 | 100 (제안) |

모듈러 `seed.sql`의 microweb `free` 행은 2026-10-13부터 모놀리스 seed와 같은 features를 담는다. 서버는 키가 없을 때를 대비해 위 값을 코드 기본값으로 둔다.

AI·음성 키 8개는 2026-10-13에 추가했다. 모놀리스는 `supabase/monolith/seed.sql`의 `free` 행에, 모듈러는 `docs/products/_supabase-modular/migrations/1500_microweb.sql:1589-1592`의 병합 UPDATE에 있다(모듈러 `seed.sql` 반영은 06장 6절 요청 R-8).

| 상품(대행, `production_orders`) | 가격 | 근거 |
|---|---|---|
| 모바일 청첩장 | 80,000 ~ 250,000원 | `nexus-micro-web-builder/frontend/data/models.ts:21-24` |
| 돌잔치(Phase 2) | 40,000 ~ 100,000원 | `models.ts:34` |
| 부고장(Phase 2) | 30,000 ~ 60,000원 | `models.ts:47` |
| 웹 제작 Basic / Pro / Premium / Custom | 50~75만 / 150~200만 / 400~600만 / 상담 | `webcraft-agency-simulator/frontend/constants.ts:142-159`의 할인가. 정가 대비 할인 표기는 금지(6절) |

| 셀프 크레딧 단가(Phase 2, 제안) | 크레딧 | 이유 |
|---|---|---|
| 청첩장 1건 발행(재게시 무료) | 30 | 대행 기본가 80,000원의 약 40%. 운영자 노동이 빠짐 |
| 돌잔치 1건 | 20 | 대행가 비율 유지 |
| 부고장 1건 | 10 | 대행가 비율 유지, 긴급 수요 |
| AI 축하말 | 0 | 하객 기능이라 과금 주체가 없다. 비용은 `core.ai_usage`로 추적 |

| 크레딧팩(Phase 2 전 비활성) | 크레딧 | 가격 |
|---|---|---|
| `pack_30` | 30 | 30,000원 |
| `pack_60` | 60 | 57,000원 |

환불(제안): 대행 착수(in_production) 전 전액, 착수 후 50%, 게시 뒤 불가. 크레딧팩은 미사용분만 7일 안에 환불(코어 `adjust` 함수 요청, `CORE_SPEC.md` 5.4).

### 4.1 AI·음성 크레딧 단가 (2026-10-13, 제안)

발행 단가(위 표)와 크레딧팩은 바꾸지 않는다. 제공자 단가는 코어 seed `core.ai_model_prices`(`docs/products/_supabase-modular/seed.sql:228-246`: LLM 상용 1k 입력 1cr·출력 4cr, 오픈소스 0.2·0.5cr, STT ElevenLabs 3cr/분·오픈소스 0.5cr/분, TTS ElevenLabs 5cr/천 자·오픈소스 1cr/천 자, 모두 제안값)이고, 이 표는 그 값을 microweb 기능에 적용한 것이다. 선차감과 정산 규칙은 `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130`, 음성 단가는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104`을 따른다. 계산 상수는 코드 `src/server/ai-pricing.ts`. 코어 seed 단가는 크레딧 1개가 약 400원인 제품(astro) 기준이라 이 제품의 크레딧(1개 = 1,000원 기준, 위 크레딧팩)과 가치가 달라 환산 상수를 제품 코드에 둔다(D-10).

| 작업 | 선차감(예상) | 정산 | 상용 경로 예 | 오픈소스 경로 예 | 멱등 키 |
|---|---|---|---|---|---|
| 문구·구성 제안 1회(그래프 5노드) | 2 | 실제 원가를 크레딧으로 환산해 올림, 최소 1, 상한 2(초과분 운영사 부담) | 2 | 1 | `run:<run_id>` |
| 제작 상담 채팅 1턴(텍스트) | 1 | 최소 1, 상한 2(Dify 보조 노드 오버헤드 포함, 초과분 운영사 부담) | 1~2 | 1 | `conv:<id>:turn:<n>` |
| 음성 질문 STT(60초 이하) | 오픈소스 1 / ElevenLabs 3 | 실제 `audio_seconds` | 3 | 1 | `voice:<voice_job_id>` |
| 답변 읽어 주기 TTS | 답변 글자 수 × 단가, 천 자 단위 올림 | 실제 `characters` | 600자 답변 5 | 600자 답변 1 | `voice:<voice_job_id>` |
| 인사말 음성 TTS(600자 이하) | 천 자 단위 올림: ElevenLabs 5 / 오픈소스 1 | 실제 `characters` | 5 | 1 | `voice:<voice_job_id>` |
| 호스트 녹음 업로드·mp3 변환 | 0(AI 아님) | - | - | - | - |
| 하객 AI 축하말 | 0 | `ai_usage` 기록, 사이트 30일 300회 상한 | - | 오픈소스 먼저 | - |
| 하객 음성 방명록 STT | 0 | `ai_usage` 기록, 사이트 30일 100건 상한 | 사용 안 함(오픈소스 강제) | 30초 약 0.25cr 원가 | - |
| 위키 열람, 코퍼스 색인, 위키 ingest·lint | 사용자 과금 없음. 지식 조직 지갑에서 사용량 차감 | 사용량 | - | - | `run:<id>` |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 경로별 단가 | 국외 이전에 동의하지 않은 조직은 체인에 오픈소스만 남으므로 오픈소스 단가가 자동 적용된다. 화면은 실제로 고른 경로의 예상치를 보여 준다 | `docs/products/_supabase-modular/migrations/0008_core_ai.sql:452-460` |
| 대행 모드 | 대행(`studio_access.mode='agency'`)은 스튜디오 조직의 내부 비용이라 권고안은 0 크레딧 호출 + `ai_usage` 기록 + 공정 사용 상한(`ai_copy_runs_per_site_30d`, `ai_chat_turns_per_day`)이다. 위 선차감 값은 셀프서비스(`self_service`) 사용자에게 적용한다 | D-9 |
| 실패 환불 | 사용자에게 결과가 전달되지 않은 실패는 선차감 전액 환불 | `docs/products/_platform-core/AI_ARCHITECTURE.md:129` |
| 정산 시점 | 응답·작업 종료 직후 정산. 스트림이 끊기면 선차감을 남기고 정산 잡이 `settled_at is null` 행을 5분 주기로 처리(제안) | `docs/products/_platform-core/AI_ARCHITECTURE.md:128` |
| 하객 기능 | 하객은 과금 주체가 아니다. 비용은 사이트 소유 조직의 `ai_usage`로 추적하고 사이트당 상한과 IP 레이트 리밋으로 막는다 | `docs/products/_platform-core/AI_ARCHITECTURE.md:130` |
| 표시 | 보내기 전 "약 1크레딧(정산 후 1~2)", 문구 제안 버튼에 예상치, 정산 결과는 메시지 아래와 원장 표에 | 제안 |

## 5. 비기능 요구사항

| 항목 | 값 | 근거 |
|---|---|---|
| 하객 페이지 LCP | 모바일 4G 2.5초 이하 | 제안(첫 화면 회색 스켈레톤 결함의 반대 기준, `premium-wedding-invitation.md:59`) |
| 하객 페이지 JS | 첫 로드 150KB(gzip) 이하 | 제안. 원본 번들 590~936kB 문제(`nexus-micro-web-builder.md:71`, `webcraft-agency-simulator.md:74`) |
| 공개 캐시 | `s-maxage=30`, 중단·만료 반영 30초 이내 | 제안 |
| 게시 잡 | 사진 35장 기준 60초 이내, 30분 넘으면 자동 실패 처리 | `1500_microweb.sql:1266` |
| 업로드 | 사진 15MB, mp3 10MB, 사이트당 사진 35장 | 제안 |
| 레이트 리밋 | 방명록 IP 3/10분, 사이트 500/일 / RSVP IP 5/시간, 사이트 2000/일 / 문의 IP 3/10분, 조직 300/일 / AI 축하말 IP 5/시간 / 로그인 IP 10/10분 | `SECURITY_BASELINE.md` 8장 형식, 수치는 제안 |
| 보존 | 게시: 예식+90일(최대 365일) / 만료 후 하객 데이터 180일 / 보관 후 30일 / 리드 1년 / 감사 2년 | 제안(`CORE_SPEC.md` 11장 감사 2년) |
| 가용성 | 공개 페이지 99.9%(Vercel), 스튜디오 99.5% | 제안 |
| 동시성 | 예식 당일 사이트당 동시 하객 500명 | 제안 |
| 문구 제안 실행 | p95 30초 이하(`microweb.invitation_copy` 5노드, 1분 넘으면 `core.jobs` 비동기) | 제안 |
| 채팅 턴 완료 | p95 15초 이하 | 제안 |
| STT(30~60초 발화) | p95 5초 이하(오픈소스 GPU 서버 기준, 구현 시 확인) | 제안 |
| TTS 첫 오디오 / 인사말 600자 생성 | p95 2초 이하 / p95 15초 이하 | 제안 |
| AI 레이트 리밋 | 문구 제안 사용자당 5회/시간, 채팅 사용자당 20턴/분 + 하루 100턴, STT 사용자당 10회/분, 인사말 TTS 사용자당 10회/시간, 서명 토큰 발급 120회/분 | 제안: `docs/products/_platform-core/SECURITY_BASELINE.md:143-155` 형식 |
| 하객 음성 방명록 제한 | IP 해시당 10분 2건·하루 5건, 사이트당 하루 50건·30일 100건, 녹음 30초·2MB, 업로드 전 서명된 방문자 쿠키 필수 | 제안(익명이라 텍스트 방명록(IP 3/10분)보다 엄격) |
| AI 입력 상한 | 채팅 메시지 1,000자, 대화당 50턴, 문구 제안 운영자 메모 500자, 인사말 TTS 600자, 음성 질문 60초·5MB | 제안 |
| 3D 히어로 | 3D 번들+에셋 PC·태블릿 1MB, 모바일 300KB 이하, 60fps / 30fps 이상, LCP 2.5초 | `docs/products/_design-guide/HERO_3D.md:32-41` |
| AI 기록 보존 | Dify 대화 로그 30일, `core.ai_messages`는 대화 삭제 또는 탈퇴 후 30일 | `docs/products/_platform-core/AI_ARCHITECTURE.md:69`(제안 30일) |
| 음성 보존 | 하객 음성 원본: 사이트 공개 만료 + 30일(제안), 숨김·삭제 시 즉시 삭제 요청. 호스트 인사말 mp3: 사이트 보관 후 30일과 같음. 제작 상담 음성 질문: 저장하지 않음 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:90-93` |

## 6. 법, 개인정보, 금지 문구

| 항목 | 내용 |
|---|---|
| 개인정보 수집 | (a) 사이트 정보: 신랑·신부·혼주 이름, 전화번호, 계좌번호, 예식 일시·장소, 사진. 목적: 하객 안내. 보존: 게시 만료 후 30일 내 공개 파생본 삭제, 원본은 보관 후 30일 (b) 하객: 방명록 이름·본문, RSVP 이름·인원·메시지, IP 일 단위 솔트 해시. 보존: 만료 후 180일 (c) 문의자: 이름, 전화/이메일, 메시지. 보존 1년, 요청 시 즉시 삭제(`delete_lead`) |
| 공개 동의 | 계좌번호·전화번호를 공개하는 정보주체(부부, 혼주)의 동의를 게시 전 기록(`disclosure_consent_basis`: self/written/recorded_call). 대행 모드는 운영자가 서면 또는 녹취 동의를 받았음을 표시 |
| 암호화 대상 | 앱 계층 컬럼 암호화 대상 없음(공개 목적 데이터). IP 원문 저장 금지(`SECURITY_BASELINE.md` 12장). 사진 EXIF GPS 제거 |
| 삭제 절차 | 사이트: 보관(archived) → 30일 → 하객 데이터·파일 삭제 → 행 삭제. 조직: core soft delete → `purge_organization` |
| 제3자 제공 | AI 축하말: 관계와 어조만 LLM에 전송하고 하객 이름은 보내지 않으며, 화면에 "AI가 초안을 씁니다"를 고지한다. 문구 제안·채팅: 호칭 토큰, 이벤트 종류, 어조, 월/계절, 운영자 메모(전화·계좌 패턴은 마스킹)만 전송하고 실명·전화번호·계좌번호·주소·이메일은 어떤 AI 제공자에도 보내지 않는다. 사진은 외부 AI에 보내지 않는다(Phase 3 보정은 별도 동의). 상용 AI·음성 제공자(LLM: Anthropic, OpenAI, Google, OpenRouter / 음성: ElevenLabs)는 국외 이전에 동의한 조직의 요청에만 쓴다. 오픈소스 LLM·임베딩·음성 서버와 Dify는 운영사가 자체 운영한다(서버 위치·위탁 여부는 구현 시 확인) |
| 약관/고지 | 이용약관, 개인정보처리방침, 하객 페이지 하단 "이 페이지는 YYYY-MM-DD까지 공개됩니다", AI 작성 글은 방명록에 "AI 도움" 표시(`ai_assisted`). AI 생성 표시: 스튜디오의 문구 제안 결과 "AI가 생성한 초안", 채팅 답변 "AI가 생성한 답변", 인사말 음성 플레이어 "AI가 생성한 음성입니다", 문구 위키 "AI가 정리하고 운영자가 검수한 문서", 다른 모델로 대체된 답변 "다른 AI 모델로 답했습니다". 적용한 문구를 최종 청첩장에 표시할지는 호스트 결정이며 법적 의무 범위는 구현 시 확인(미확인, D-18) |
| 저작권 | 업로드 사진·음원의 권리는 고객 책임 고지. 기본 BGM은 라이선스 확보 음원만 |
| 제휴/광고 | 해당 없음. 청첩장에 제휴 링크를 넣지 않는다. 화환 링크(`wreath` 블록)는 외부 업체 링크이며 대가를 받으면 대가성 문구 필요(현재 대가 없음) |
| 플랫폼 약관 | 카카오 JS SDK·지도 사용 조건(도메인 등록, 미확인 항목은 구현 전 확인). 외부 자동화 없음 |
| 금지 문구 | AI 기능 홍보에서 "AI가 알아서 완성", "100% 맞춤" 같은 보장 표현, AI 생성 문구·음성을 직접 작성·녹음한 것처럼 표시, 고인·유명인 음성 재현 암시. 일반 금지: 가상 후기·평점, 미검증 수치(원본 `webcraft-agency-simulator/frontend/components/Hero.tsx:38-48`의 "500+ 누적 프로젝트", "98% 고객 만족도", "10년 업력"), 근거 없는 정가 대비 할인과 기간 한정 문구(`constants.ts:142` 정가/할인가 쌍, `components/PromoBanner.tsx:12` "50% 파격행사"), 가짜 포트폴리오(picsum, 실재하지 않는 고객사명 `portfolioWeb.ts`), 보장 표현("100% 만족", "평생 보관"), 타사 상표 오용(바른손 등 화환 업체명을 우리 상품처럼 표기) |
| 규제 특례 | 부고장(Phase 2): 고인 정보와 유족 연락처 공개 동의는 상주 기준. 미성년(돌잔치) 아이 사진은 보호자 동의. 하객이 만 14세 미만일 수 있는 음성 방명록은 고지문에 보호자 동의를 안내하고 법무 확인을 거친다(D-12). 부고장 AI 문구는 축하 표현을 쓰지 않는 규칙을 compliance 노드에 둔다 |
| AI 대화 기록 | `core.ai_messages`(본인만 열람, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`), Dify 대화 로그(운영사 자체 호스팅, 30일 보존, 조직 데이터 저장소로 관리, `docs/products/_platform-core/AI_ARCHITECTURE.md:69`). 대화 삭제·탈퇴 시 30일 안에 둘 다 삭제 |
| 국외 이전 | 상용 AI·음성 제공자로의 이전은 스튜디오 온보딩에서 선택 동의로 받고(`core.set_ai_cross_border_ack` + 고지문 버전, MW-F-033) 거부하면 오픈소스만 쓴다. 조직의 동의는 하객을 대신하지 못하므로 하객 음성은 동의와 무관하게 오픈소스 서버에서만 처리한다. 호스팅의 국외 이전은 개인정보처리방침에 이전 국가·항목·목적·보유 기간을 공개한다(구현 시 확인) |
| 녹음 동의(하객, 제3자) | 하객 음성은 호스트에게 제3자의 목소리다. 녹음 시작 전 고지 화면(고지문 버전 표시, 확인 버튼)에서 녹음 목적, 호스트가 청취함, 공개 재생 옵션, 문자 변환 방식(국외 전송 없음), 보관 기간, 삭제 요청 방법, 만 14세 미만 보호자 동의를 알린다. 확인하면 `voice_jobs.consent_kind='third_party_notice'`, `notice_version`, `consent_at`을 기록한다(없으면 DB가 거부, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:94-95`). 고지문은 MW-06-029가 쓰고 법무 확인 후 확정한다(D-12) |
| 녹음 동의(호스트 본인) | 호스트가 자기 목소리를 녹음해 올리면 `consent_kind='self'`와 공개 동의(`disclosure_consent`, 음성 포함)로 처리한다. 타인(유명인, 고인, 지인) 목소리 복제는 제공하지 않는다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:80`) |
| 음성 삭제 요청 | 하객은 계정이 없으므로 운영자 문의 메일로 삭제를 요청하고 호스트 또는 owner/admin이 `DELETE /api/studio/guestbook/[id]`로 음성 파일과 항목을 지운다(04장 2절). 사이트 보관·만료·삭제 시 `site.purge`가 음성 파일을 함께 지운다 |
| 코퍼스 저작권·개인정보 | RAG·위키 원본은 운영자가 직접 쓴 문구와 사용 허락을 받은 예시만 쓴다. 고객 청첩장의 실제 문구는 이름·연락처가 섞여 있어 색인하지 않는다(D-15). 위키에는 개인 식별 정보를 정리해 넣지 않는다(`docs/products/_platform-core/LLM_WIKI.md:33`) |

## 7. KPI

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| 문의 → 계약(won) 전환 | 25% | `leads.status` | 베타 3개월 |
| 계약 → 게시 리드타임 | 중앙값 3일 | `production_orders.paid_at` → `sites.first_published_at` | 월 |
| 게시 실패율 | 1% 미만 | `audit_log` `site.publish_failed` / `site.publish` | 월 |
| 하객 페이지 LCP p75 | 2.5초 이하 | Vercel Speed Insights | 월 |
| 방명록 스팸 비율 | 2% 미만 | `guestbook_entries.status='spam'` 비율 | 월 |
| AI 축하말 비용 | 사이트당 300원 이하 | `core.ai_usage` | 월 |
| 셀프 전환(Phase 2) | 초대 사용자의 40%가 30일 안에 첫 발행 | `sites.publish_charged_at` | Phase 2 |
| 문구 제안 적용률 | 실행의 40% 이상에서 1안 이상 "적용"(제안) | `ai_runs` 대비 적용 이벤트(감사 `site.ai_copy_apply`) | 월 |
| 제작 상담 채팅 사용률 | 활성 스튜디오 사용자의 30%(제안) | `core.ai_conversations` 1개 이상 사용자 / 활성 사용자 | 월 |
| 하객 음성 방명록 비율 | 음성 옵션을 켠 사이트의 방명록 중 5% 이상(제안, 참여가 낮으면 기능 재검토) | `guestbook_entries.has_voice` | 월 |
| AI 하객 기능 비용 | 사이트당 월 500원 이하(제안, 축하말 + 음성 STT) | `core.ai_usage` | 월 |

수치는 모두 제안이다(원본에 근거 없음).

## 8. 열린 결정

| ID | 항목 | 선택지 | 권고 |
|---|---|---|---|
| D-1 | 모놀리스 스키마 | public(코어 lite와 동일) / 별도 | public. 사용자 최종 확인 대기 |
| D-2 | 대행 결제 수단 | 계좌이체 수기 기록 / Toss 결제링크 / Toss 결제창(주문 kind 추가 필요) | MVP 계좌이체 수기, Phase 2 Toss. Toss 결제링크 API는 미확인 |
| D-3 | 셀프 크레딧 단가 | 4절 제안값 | 베타 고객 10명 인터뷰 후 확정 |
| D-4 | RSVP MVP 포함 | 포함 / 제외 | 포함(기본 꺼짐) |
| D-5 | 만료 기본값 | 예식+30일 / +90일 / +365일 | +90일 |
| D-6 | 지도 표시 | 카카오맵 임베드 / 정적 지도 이미지 / 딥링크만 | 임베드 + 딥링크. 정적 지도 약관 미확인 |
| D-7 | WebSite 포트폴리오 게시 | 고객 동의 확보 후 / 내부 작품으로만 | 동의 확보 전 draft 유지 |
| D-8 | studio org 지정 | 환경변수 `MICROWEB_STUDIO_ORG_ID` 1개 / 여러 대행사 | 1개(1인 운영, 확정 결정 5) |
| D-9 | 대행 모드 AI 비용 부담 | (a) 스튜디오 조직 지갑에서 선차감(운영자가 크레딧 충전) (b) 0 크레딧 호출 + `ai_usage` 기록 + 공정 사용 상한 | 대행은 (b), 셀프서비스(Phase 2)는 (a)(제안). (b)는 코어가 `credits: 0` 호출을 지원해야 한다(06장 6절 R-4) |
| D-10 | AI 크레딧 단위 가치 | (a) 코어 seed `ai_model_prices`를 그대로 적용(1cr ≈ 400원 기준이라 이 제품에는 과다) (b) 제품 상수로 환산(`src/server/ai-pricing.ts`, 4.1절 표) (c) 코어에 제품별 환산 계수 요청 | (b)(제안). 운영 중 `core.ai_usage` 원가로 재조정 |
| D-11 | 하객 음성 공개 재생 | (a) 호스트 전용만 (b) 호스트가 블록 옵션으로 공개 재생 허용 | (b)이며 기본값은 호스트 전용(제안). 공개 재생은 고지문에 명시 |
| D-12 | 하객 음성 고지문·미성년·보관 기간 | 고지문 문구, 만 14세 미만 처리(보호자 동의 안내 / 음성 기능 제한), 보관 기간(공개 만료+30일 / +90일) | 보호자 동의 안내 + 공개 만료+30일(제안). 법무 확인 후 확정 |
| D-13 | 인사말 보이스와 ElevenLabs 조건 | (a) ElevenLabs 기본 보이스 1종 + 오픈소스 보이스 1종 고정 (b) 사용자 선택. 생성 음성의 상업 이용 조건·입력 보관·제로 리텐션 여부 | (a)(제안). 보이스 id는 환경변수. 약관·보관 조건은 구현 시 ElevenLabs 계약으로 확인(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:81-83`) |
| D-14 | 호스트 녹음 mp3 변환 | (a) 워커에서 ffmpeg로 mp3 변환 (b) 원본 mime(webm/ogg/mp4)을 `site_assets`에 허용(스키마 변경 필요) | (a)(제안). 워커 이미지의 ffmpeg 라이선스·크기는 구현 시 확인 |
| D-15 | 문구 코퍼스 출처 | (a) 운영자 직접 집필 + 허락받은 예시 (b) AI 초안 + 운영자 검수 (c) 고객 청첩장 문구 재사용(이름 마스킹) | (a)+(b)(제안). (c)는 개인정보·저작권 위험으로 제외. 항목마다 작성자·검수일·라이선스 기록 |
| D-16 | 채팅 화면 레퍼런스 Astryx | 존재·라이선스 확인 후 패턴만 사용 / 확인 실패 시 Primer + shadcn/ui 패턴 | 확인 전까지 미확인(`docs/products/_design-guide/DESIGN_SYSTEM.md:11`). MW-06-036에서 확인 결과를 기록 |
| D-17 | 쇼룸 비로그인 AI 상담 시기 | (a) Phase 2 (b) MVP | (a)(제안). 방문자 쿠키 + 운영자 조직 예산 + 강한 레이트 리밋이 필요(`docs/products/_platform-core/AI_ARCHITECTURE.md:54-56`, `:130`) |
| D-18 | AI 생성물 표시 의무 범위 | 스튜디오 내부 표시만 / 최종 청첩장·음성 플레이어까지 | 음성은 플레이어 표시, 문구는 호스트 선택(제안). 법적 의무는 구현 시 확인(미확인) |
