# M3 ad-manager: 광고·업소 디렉토리·지자체 공고

작성일 2026-10-15. 표 정본 `docs/file/03-설계/05_DATA_MODEL.md`, 슬롯 배치 정본 `docs/file/03-설계/03_SCREENS_UX.md` 템플릿 절.

## 1. 목적과 범위

지역신문 매출의 중심인 광고(신문산업 매출의 64.0%가 광고, https://www.journalist.or.kr/news/article.html?no=57578)를 신문사가 직접 팔고 내보내고 집계하게 한다. 광고는 기사와 구분되어야 하고(신문법 제6조 제3항), 레이아웃을 흔들지 않아야 한다(CLS).

| 구분 | 범위 | 기능 |
|---|---|---|
| MVP(P0) | IAB 고정 크기 슬롯, 광고주·캠페인·소재(기간·우선순위), 하우스 광고, 노출·클릭 일 집계, 슬롯 공간 예약, 광고 라벨 강제 | NW-F-030, 032 |
| 확장(P1) | Google Ad Manager·AdSense 태그 슬롯, `ads.txt`, 업소 셀프 광고·디렉토리(신청·결제·검수), 지자체 공고 리스트와 게재 증빙 리포트 | NW-F-031, 033, 034, 023(공고 목록) |
| 하지 않음 | 팝업·전면 광고·카운트다운, 정부광고 직접 판매(언론진흥재단 대행 대상), 헤더 비딩(확장 후보), 네이티브 추천 위젯(Taboola 류, 포털 감점 위험) | - |

## 2. 벤치마크

| 제품 | 가져올 것 | 가져오지 않을 것 | 출처 URL |
|---|---|---|---|
| Newspack 광고 | GAM 광고 단위와 양방향 동기화, 지연 로딩·새로고침 제어, 스폰서 콘텐츠의 별도 시각 표시(스폰서 작성/편집국 작성 구분), 미디어 킷, 부동산·구인·부고 유료 리스팅 | 헤더 비딩 기본 탑재(1차 제외), AdX 할인 계약 | https://newspack.com/advertising (2026-10-15 열람 확인) |
| Newspack Ad Block | 본문 안 수동 광고 블록 + 편집기 자리표시자 | Gutenberg 블록 구조 | https://help.newspack.com/publishing-and-appearance/blocks/ad-block (2026-10-15 열람 확인) |
| Google Publisher Tag(Ad Manager) | 광고 단위 경로 `/네트워크코드/상위/단위`, `defineSlot` 크기와 div 크기 일치, Google 도메인에서만 `gpt.js` 로드 | - | https://developers.google.com/publisher-tag/guides/get-started (2026-10-15 열람 확인) |
| AdSense ads.txt | 루트 `/ads.txt`에 게시자 ID, 권장 사항(필수 아님), 반영 며칠 | - | https://support.google.com/adsense/answer/12171612 (2026-10-15 열람 확인) |
| IAB 고정 크기·Better Ads | 970x250, 728x90, 300x250, 160x600, 320x50 등 표준 크기와 초기 로드 용량 상한, 팝업·프리스티셜·모바일 광고 밀도 30% 초과 금지 | - | https://www.iab.com/wp-content/uploads/2019/04/IABNewAdPortfolio_LW_FixedSizeSpec.pdf , https://www.betterads.org/standards/ (조사 에이전트 2026-10-15 열람, 이 문서에서 재확인 안 함) |

결론: 직판(하우스 서버)이 기본, GAM은 슬롯 단위로 "외부 태그" 모드를 켜는 확장. 스폰서 표시는 Newspack처럼 기사 유형(`sponsored`)과 연결한다.

## 3. 소유·소비

| 구분 | 내용 |
|---|---|
| 소유 표 | `ad_slots`, `advertisers`, `ad_campaigns`, `ad_creatives`, `ad_daily_stats`, `local_listings`, `public_notices` |
| 소유 RPC | `news.upsert_ad_slot`, `news.upsert_advertiser`, `news.save_ad_campaign`, `news.save_ad_creative`, `news.review_ad_creative`, `news.serve_ads`(공개), `news.submit_listing`(독자)·`news.review_listing`·`news.activate_listing`(service, 결제 후), `news.save_public_notice`, `news.record_ad_stats`(service) — 이름은 05장 SQL 기준 |
| 쓰는 코어 | storage(소재 이미지 `public-assets`), rate_limit(비콘·클릭), jobs(`news.ad_stats_rollup` 일 롤업, 캠페인 경계 무효화), audit, (업소 결제) M2와 같은 신문사 Toss 가맹 경로 |
| 쓰는 모듈 | M7 광고 라벨 규칙, M1 `sponsored` 기사 연결(읽기) |
| 소비자 | 독자 화면 슬롯 컴포넌트, M8 지원사업 리포트(광고 비중), 지역 생활 블록(공고 목록) |

## 4. 데이터 (요약, 상세 `docs/file/03-설계/05_DATA_MODEL.md`)

| 표 | 핵심 컬럼(요약) |
|---|---|
| `ad_slots` | 코드(`home_top_leaderboard` 등), 위치(`home`·`section`·`article`·`mobile`·`all`), 너비·높이(IAB 고정 크기), 활성, 정렬 |
| `advertisers` | 이름, 종류(`local_business`·`agency`·`institution`·`house`·`other`), 정부·지자체 여부(`is_government`), 사업자번호, 담당자 연락처, 상태 |
| `ad_campaigns` | 광고주, 이름, 가격 방식(`flat`·`cpm`·`cpc`·`house`), 금액(원), 기간, 우선순위, 상태 |
| `ad_creatives` | 캠페인, 슬롯, 종류(`image`·`text`·`external`), 이미지 경로 또는 외부망(`gam`·`adsense`)·외부 단위 id, 헤드라인, 클릭 URL, 대체 텍스트, 라벨(허용 목록 `광고`·`AD`·`협찬`·`후원`), 검수 상태·검수자 |
| `ad_daily_stats` | 소재, 날짜(KST), 노출, 클릭((소재, 날짜) 유일. 서버가 비콘을 모아 `news.record_ad_stats(creative_id, day, impressions, clicks)`로 증분) |
| `local_listings` | 신청 독자·사용자, 업종(음식점·카페·상점 등), 지역, 주소, 전화, URL, 소개, 사진, 상태, 게재 기간, 결제 시각·주문 id, 검수 메모 |
| `public_notices` | 공고 번호, 지역, 첨부, 정부광고 참조 번호(`government_ad_ref`, 언론재단 대행 건), 게재 기간, 상태 |

## 5. 인터페이스

```ts
// src/modules/ad-manager/server/index.ts — 계약 예시(구현 파일 아님)
export interface SlotRender { slotCode: string; width: number; height: number; label: '광고' | 'AD' | '협찬' | '후원'; creative?: { id: string; kind: 'image' | 'text' | 'external'; imageUrl?: string; headline?: string; alt?: string; external?: { network: 'gam' | 'adsense'; unitId: string } } }

export interface AdManagerApi {
  // 독자 화면: 서버 렌더(ISR) 때 소재를 고르고 공간을 예약한다. 캠페인 시작·종료 잡이 해당 페이지 태그를 무효화(02장 6절 #1)
  selectForSlot(orgId: string, placement: 'home' | 'section' | 'article' | 'mobile'): Promise<SlotRender[]>   // rpc news.serve_ads(anon, 활성·기간·우선순위)
  recordImpression(input: { orgId: string; creativeId: string; slotId: string }): Promise<void>       // POST /api/r/ad-event → 서버 묶음 → rpc news.record_ad_stats(service)
  clickRedirect(creativeId: string, req: { ipHash: string; userAgent: string }): Promise<string | null>  // GET /r/ad/[creative_id] 302, 종료 캠페인 404
  submitListing(input: ListingInput & { requestId: string }): Promise<{ listingId: string; payment?: { orderId: string } }>
  reviewCreative(creativeId: string, decision: 'approve' | 'reject', reason?: string): Promise<void>
  publishNotice(input: NoticeInput): Promise<{ noticeId: string }>
  noticeProofReport(noticeId: string): Promise<{ pdfPath: string }>    // 게재 기간, URL, 노출 수, 캡처
}
```

| 이벤트 | 발생 | 구독 |
|---|---|---|
| `news.ad.campaign.started` / `.ended` | 잡이 기간 경계에서 전이 | 슬롯 캐시 무효화, 광고주 메일 |
| `news.ad.creative.reviewed` | 검수 | 광고주·업주 메일 |
| `news.listing.published` | 업소 게재 | 디렉토리 캐시 |
| `news.notice.published` | 공고 게재 | 공고 블록 캐시, M8 증빙 |

## 6. 상태·규칙

| 표 | 전이 |
|---|---|
| `ad_campaigns` | `draft` → `active` ↔ `paused` → `ended`, 어느 단계든 `canceled`. 노출 여부는 상태 `active` + 기간 안(시작·종료 시각은 잡이 캐시 무효화) |
| `ad_creatives` | `pending_review` → `approved` / `rejected`(사유 필수) → `archived` |
| `local_listings` | `pending`(결제 대기·검수 대기) → `approved` → `active`(게재 기간 안) → `expired`, 또는 `rejected`(결제 환불)·`canceled` |
| `public_notices` | `draft` → `published` → `archived` |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 라벨 강제 | 모든 직판·외부 슬롯 위에 "광고" 라벨(끌 수 없음). `sponsored` 기사는 제목 위 "광고" 또는 "기사형 광고" 라벨 + 광고주명. 문구 규칙 소유자는 M7 | 신문법 제6조 제3항(`docs/file/02-요구사항/01_PRD.md` 법 절) |
| 공간 예약 | 슬롯은 `min-height`/`aspect-ratio`로 자리를 먼저 잡고, 소재가 없으면 하우스 광고로 채운다(접지 않는다) | https://web.dev/articles/optimize-cls (조사 에이전트 2026-10-15 열람) |
| 금지 형식 | 팝업, 전면(인터스티셜), 카운트다운, 자동 재생 소리 광고 기능을 제공하지 않는다 | https://www.betterads.org/standards/ |
| 슬롯 수 상한 | 템플릿별 슬롯 수·크기는 고정(신문사가 늘릴 수 없음). 기관 배너 줄 대신 공고는 텍스트 리스트 | `docs/file/03-설계/03_SCREENS_UX.md` |
| 정부광고 | 정부·지자체 광고는 언론진흥재단이 대행하므로 직판 결제를 받지 않는다(`is_government` 광고주의 유료 캠페인 저장은 `news.save_ad_campaign`이 거부). 공고는 게재·증빙만 | 정부광고법(https://journalist.or.kr/news/article.html?no=59081) |
| 소재 검수 | 카테고리 차단(성인·사행·의료 과장 등, 목록은 제안), 낚시성 문구는 반려 | 포털 제휴 감점 위험(https://journalist.or.kr/news/article.html?no=60389) |
| 집계 | 노출은 슬롯이 화면에 들어온 뒤 브라우저가 `sendBeacon`으로 묶어 보낸다. 봇 UA 제외, IP 해시 기준 분당 상한 | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:143-157` |

## 7. 실패 동작

| 상황 | 동작 |
|---|---|
| `selectForSlot` 실패·지연(제안 300ms) | 하우스 광고 또는 빈 예약 공간 유지. 페이지 렌더를 막지 않는다 |
| GAM 스크립트 차단(광고 차단기) | 공간은 유지, 하우스 광고로 대체하지 않는다(GAM 계약상 중복 노출 위험, 제안) |
| 집계 RPC 실패 | 비콘 손실은 허용(집계는 근사치임을 리포트에 표기). 재시도 없음 |
| 클릭 URL이 안전하지 않음 | 저장 시 http(s)만 허용, 내부망 주소 거부. 리다이렉트는 저장된 URL로만 |
| 업소 결제 후 반려 | Toss 취소로 전액 환불, 상태 `rejected` + 사유 메일 |

## 8. 보안·개인정보

| 항목 | 규칙 |
|---|---|
| 권한 | 광고 표는 `ad_manager`·`editor`·`publisher`만 쓰기(RPC). 독자 화면은 `selectForSlot` 결과만 |
| 클릭 기록 | 원 IP 저장 금지, 일 솔트 해시(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md:195`) |
| 외부 태그 | GAM·AdSense 스크립트는 외부 소재(`kind=external`)가 있고 신문사 스위치(NW-F-031)가 켜진 경우에만 LCP 이후 비동기 로드. 쿠키·개인정보 처리방침에 제3자 광고 쿠키 항목(01장) |
| 업주 정보 | 업소 신청자 연락처는 편집국만, 공개 정보(업소명·주소·전화)와 분리 |

## 9. 수용 기준

| 기능 | 기준 |
|---|---|
| NW-F-030 | 기간 밖 캠페인은 노출 0, 소재 없는 슬롯은 하우스 광고, 모바일 홈 CLS ≤ 0.1(p75 목표) |
| NW-F-031 | 외부 소재가 `gam`이면 GPT `defineSlot` 크기와 예약 공간이 같음, `/ads.txt`가 신문사 도메인 루트에서 응답 |
| NW-F-032 | 라벨 없는 광고·`sponsored` 기사가 렌더되는 경로 0(컴포넌트 테스트로 확인) |
| NW-F-033 | 업주 신청 → 결제 → 검수 → 게재 → 기간 만료 자동 내림 |
| NW-F-034 | 공고별 증빙 PDF(게재 기간, URL, 노출 수, 화면 캡처 1장) 생성 |

## 10. 추출 조건

광고 슬롯이 필요한 두 번째 제품(nomad-blog 등 후보, 미확인)이 생기면 슬롯·캠페인·소재·집계를 `ads` 공용 스키마(신규 제안, 번호 미정 `README.md` MQ-4)로 꺼낸다. 지자체 공고와 기사형 광고 라벨은 뉴스 전용으로 남긴다.
