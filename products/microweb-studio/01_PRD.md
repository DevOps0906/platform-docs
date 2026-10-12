# 01 PRD: Microweb Studio

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

## 3. 기능 요구사항과 수용 기준

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| MW-F-001 | 블록 엔진 | 신규 | 템플릿은 `allowed_blocks`/`required_blocks`를 가진다. 사이트 `content`는 `{theme, blocks:[{type, props}]}` JSON(256KB 이하). 블록 17종: hero, greeting, hosts, calendar, gallery, location, transport, contacts, accounts, wreath, guestbook, rsvp, bgm, notice, share, timeline(돌), memorial/funeral_info(부고) | 필수 블록이 빠진 content로 게시 요청하면 422가 반환된다. 모르는 블록 타입은 zod가 거부한다 | `00_MERGE_ANALYSIS.md:1078`, `premium-wedding-invitation.md:100` |
| MW-F-002 | 히어로 | 디벨롭 | 업로드한 실제 사진 1~5장 캐러셀, 5초 전환, 크로스페이드. 방문 시 AI 호출 0건 | 하객 페이지 네트워크 로그에 LLM/이미지 생성 요청이 없다 | `premium-wedding-invitation.md:94` |
| MW-F-003 | 오시는 길 | 디벨롭 | 주소, 좌표, 카카오/네이버 지도 딥링크, 대중교통/주차 텍스트. 지도는 카카오맵 임베드(정적 지도 API 약관은 미확인) | AI 생성 지도 이미지가 코드에 없다. 딥링크가 좌표로 열린다 | `premium-wedding-invitation.md:79` |
| MW-F-004 | 연락처·계좌 | 유지 | tel/sms 링크, 계좌 복사, 신랑측/신부측(side_a/side_b) 아코디언. 게시 전 공개 동의(`disclosure_consent_at`) 필수 | 동의 없이 게시 요청하면 MW006 | `premium-wedding-invitation.md:32` |
| MW-F-005 | 갤러리 | 디벨롭 | 최대 30장(플랜 `max_gallery_photos`), 라이트박스, lazy 로딩, 400/800/1600w webp | 30장 페이지의 LCP 이미지 외에는 `loading="lazy"` | `premium-wedding-invitation.md:105` |
| MW-F-006 | 방명록 | 디벨롭 | 이름 1~20자, 본문 1~500자, URL 금지, 같은 IP 해시 10분 3건, 사이트당 하루 500건, 같은 본문 1시간 중복 금지. 숨김/스팸 처리와 삭제는 운영자만 | 4번째 연속 작성은 `rate_limited`. 하객 화면에 삭제 버튼이 없다 | `premium-wedding-invitation.md:65`, `:98-99` |
| MW-F-007 | AI 축하말 | 디벨롭 | 이름 20자, 관계 5종, 고정 모델·고정 프롬프트, 결과 200자 이하. IP 해시당 시간 5회, 사이트당 30일 300회(제안). 실패 시 "자동 작성에 실패했습니다. 직접 입력해 주세요" | 6번째 호출은 429. 실패 시 고정 문구로 위장하지 않는다 | `premium-wedding-invitation.md:95`, `:70` |
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

모듈러 `seed.sql`의 microweb `free` 행은 2026-10-13부터 모놀리스 seed와 같은 features를 담는다. 서버는 키가 없을 때를 대비해 위 값을 코드 기본값으로 둔다.

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

## 6. 법, 개인정보, 금지 문구

| 항목 | 내용 |
|---|---|
| 개인정보 수집 | (a) 사이트 정보: 신랑·신부·혼주 이름, 전화번호, 계좌번호, 예식 일시·장소, 사진. 목적: 하객 안내. 보존: 게시 만료 후 30일 내 공개 파생본 삭제, 원본은 보관 후 30일 (b) 하객: 방명록 이름·본문, RSVP 이름·인원·메시지, IP 일 단위 솔트 해시. 보존: 만료 후 180일 (c) 문의자: 이름, 전화/이메일, 메시지. 보존 1년, 요청 시 즉시 삭제(`delete_lead`) |
| 공개 동의 | 계좌번호·전화번호를 공개하는 정보주체(부부, 혼주)의 동의를 게시 전 기록(`disclosure_consent_basis`: self/written/recorded_call). 대행 모드는 운영자가 서면 또는 녹취 동의를 받았음을 표시 |
| 암호화 대상 | 앱 계층 컬럼 암호화 대상 없음(공개 목적 데이터). IP 원문 저장 금지(`SECURITY_BASELINE.md` 12장). 사진 EXIF GPS 제거 |
| 삭제 절차 | 사이트: 보관(archived) → 30일 → 하객 데이터·파일 삭제 → 행 삭제. 조직: core soft delete → `purge_organization` |
| 제3자 제공 | AI 축하말: 하객이 입력한 이름(20자)과 관계만 LLM 제공자(core LLM 게이트웨이)에 전송, 화면에 "AI가 초안을 씁니다" 고지. 사진은 외부 AI에 보내지 않는다(Phase 3 보정은 별도 동의) |
| 약관/고지 | 이용약관, 개인정보처리방침, 하객 페이지 하단 "이 페이지는 YYYY-MM-DD까지 공개됩니다", AI 작성 글은 방명록에 "AI 도움" 표시(`ai_assisted`) |
| 저작권 | 업로드 사진·음원의 권리는 고객 책임 고지. 기본 BGM은 라이선스 확보 음원만 |
| 제휴/광고 | 해당 없음. 청첩장에 제휴 링크를 넣지 않는다. 화환 링크(`wreath` 블록)는 외부 업체 링크이며 대가를 받으면 대가성 문구 필요(현재 대가 없음) |
| 플랫폼 약관 | 카카오 JS SDK·지도 사용 조건(도메인 등록, 미확인 항목은 구현 전 확인). 외부 자동화 없음 |
| 금지 문구 | 가상 후기·평점, 미검증 수치(원본 `webcraft-agency-simulator/frontend/components/Hero.tsx:38-48`의 "500+ 누적 프로젝트", "98% 고객 만족도", "10년 업력"), 근거 없는 정가 대비 할인과 기간 한정 문구(`constants.ts:142` 정가/할인가 쌍, `components/PromoBanner.tsx:12` "50% 파격행사"), 가짜 포트폴리오(picsum, 실재하지 않는 고객사명 `portfolioWeb.ts`), 보장 표현("100% 만족", "평생 보관"), 타사 상표 오용(바른손 등 화환 업체명을 우리 상품처럼 표기) |
| 규제 특례 | 부고장(Phase 2): 고인 정보와 유족 연락처 공개 동의는 상주 기준. 미성년(돌잔치) 아이 사진은 보호자 동의 |

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

수치는 모두 제안이다(원본에 근거 없음).

## 8. 열린 결정

| 항목 | 선택지 | 권고 |
|---|---|---|
| 모놀리스 스키마 | public(코어 lite와 동일) / 별도 | public. 사용자 최종 확인 대기 |
| 대행 결제 수단 | 계좌이체 수기 기록 / Toss 결제링크 / Toss 결제창(주문 kind 추가 필요) | MVP 계좌이체 수기, Phase 2 Toss. Toss 결제링크 API는 미확인 |
| 셀프 크레딧 단가 | 4절 제안값 | 베타 고객 10명 인터뷰 후 확정 |
| RSVP MVP 포함 | 포함 / 제외 | 포함(기본 꺼짐) |
| 만료 기본값 | 예식+30일 / +90일 / +365일 | +90일 |
| 지도 표시 | 카카오맵 임베드 / 정적 지도 이미지 / 딥링크만 | 임베드 + 딥링크. 정적 지도 약관 미확인 |
| WebSite 포트폴리오 게시 | 고객 동의 확보 후 / 내부 작품으로만 | 동의 확보 전 draft 유지 |
| studio org 지정 | 환경변수 `MICROWEB_STUDIO_ORG_ID` 1개 / 여러 대행사 | 1개(1인 운영, 확정 결정 5) |
