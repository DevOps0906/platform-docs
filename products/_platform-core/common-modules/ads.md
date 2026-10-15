# ads: 광고 슬롯·캠페인·소재·집계 (공용모듈 기획서)

작성일 2026-10-15. 상태: 제안. 패키지 `@nomad/ads`, 스키마 `ads`(0650~0699), 오류 코드 `AD###`. 출처: local-news M3(`docs/products/local-news/modules/M3_ad-manager.md`)의 직판 광고 부분과 코어 요청 R-9(번호 범위, 이 문서로 해결). 개발서 `docs/develop/_shared/modules/ads.md`.

## 1. 문제

지역신문(local-news)의 매출 절반 이상이 광고이고, 행사 스폰서 배너(live-poll), 웹툰 회차 광고(toon-factory), 블로그 사이트 광고(nomad-blog), 부고장·청첩장 협찬(microweb-studio)도 같은 구조다. "슬롯에 기간·우선순위에 맞는 소재를 고르고, 노출·클릭을 세고, 광고주에게 리포트를 준다." 제품마다 만들면 광고 표시 누락(법 위반), 광고 때문에 화면이 밀리는 문제(CLS), 클릭 수 조작 위험이 반복된다.

## 2. 범위

| 구분 | 내용 |
|---|---|
| MVP | 슬롯(위치·크기·기기·높이 예약), 광고주, 캠페인(기간·단가 방식·예산·우선순위·타기팅), 소재(이미지·텍스트·HTML 제한형, media 자산), 소재 검수, 광고 라벨 필수, 소재 선택 함수, 노출·클릭 집계(서버 묶음), 하우스 광고(빈 슬롯 채움), 외부 광고망 태그(AdSense·Google Ad Manager·카카오 애드핏), 광고주 리포트(CSV) |
| 확장 | 광고주 셀프서비스 포털·결제, 실시간 입찰, 빈도 제한(사용자별), 노출 가시성 측정 고도화, 정산서 |
| 제품에 남김 | 지자체 공고(local-news), 기사형 광고 작성 흐름(editorial 항목 + `sponsored` 라벨), 정부광고 직판 금지 규칙(local-news 가드) |

## 3. 데이터 모델

| 표 | 주요 컬럼 | RLS·쓰기 |
|---|---|---|
| `ads.slots` | `id`, `org_id`, `app_id`, `code`(예 `home_top`, `article_mid`, `event_screen_footer`), `sizes`(jsonb, 예 `[[728,90],[320,100]]`), `device`(`all`, `desktop`, `mobile`), `reserve`(jsonb, 반응형 구간별 높이), `fallback`(`house`, `network`, `collapse_never`), `status` | 공개 읽기(슬롯 정의), org admin 쓰기 |
| `ads.advertisers` | `id`, `org_id`, `name`, `biz_no`, `contact_name`, `contact_email`, `category`, `is_public_body`(정부·지자체·공공기관 여부) | org 멤버(광고 역할) |
| `ads.campaigns` | `id`, `org_id`, `app_id`, `advertiser_id`, `name`, `starts_at`, `ends_at`, `pricing`(`flat`, `cpm`, `cpc`, `cpd`), `unit_price`, `budget`, `priority`(1~10), `targeting`(jsonb: 페이지 종류, 섹션, 지역, 기기, 키워드), `status`(`draft`, `pending_review`, `active`, `paused`, `ended`) | org 멤버(광고 역할). 전이 RPC |
| `ads.creatives` | `id`, `campaign_id`, `kind`(`image`, `text`, `html_safe`), `media_asset_id`, `headline`, `body`, `click_url`, `alt_text`, `label_code`(compliance, 기본 `ad`), `review_status`(`pending`, `approved`, `rejected`), `review_note` | org 멤버. 승인 전 노출 불가 |
| `ads.placements` | `campaign_id`, `slot_id`, `weight` | org 멤버 |
| `ads.daily_stats` | `creative_id`, `slot_id`, `day`, `impressions`, `viewable`, `clicks` | 쓰기 service(묶음 증분 `ads.record_events`), 읽기 org 멤버 |
| `ads.network_tags` | `slot_id`, `provider`(`adsense`, `gam`, `adfit`), `config`(jsonb: 게시자 id, 광고 단위 id) | org admin |
| `ads.settings` | `org_id`, `app_id`, `block_categories`(text[]), `house_creative_ids`, `public_body_direct_sale`(bool, 기본 true, local-news는 false) | org admin |

함수 `ads.pick_creative(org, app, slot_code, context jsonb)`(service): 활성 기간·검수 승인·타기팅·예산 소진·우선순위·가중치로 1개를 고르고, 없으면 하우스 → 외부망 순.

오류 코드: `AD001` 라벨 없는 소재 승인 시도, `AD002` 검수 미승인 소재 노출 연결, `AD003` 공공기관 광고주 직판 금지 설정 위반, `AD004` 기간 역전, `AD005` 차단 카테고리.

## 4. 노출·클릭

| 항목 | 규칙 |
|---|---|
| 노출 | 슬롯이 화면에 50% 이상 1초 보이면 `viewable`(IAB 기준과 같은 정의, 제안). 비콘은 묶어서 `/api/ads/e`로, 서버가 봇 필터 후 `record_events` |
| 클릭 | `/api/ads/c/<서명 토큰>` → 기록 → 302. 토큰에 소재·슬롯·만료 포함(위조 클릭 방지) |
| 레이아웃 | 슬롯 높이를 항상 예약. 광고가 없어도 접지 않고 하우스 광고로 채움(CLS 0.1 이하, web.dev 가이드) |
| 금지 | 팝업·전면광고·자동 재생 소리 광고 컴포넌트 제공 안 함(Better Ads 기준) |

## 5. 공개 API (TS 계약 예시)

```ts
// @nomad/ads/server
pickCreative(ctx: TenantCtx, slotCode: string, context: AdContext): Promise<ServedAd | null>
recordEvents(batch: AdEvent[]): Promise<void>
signClick(ad: ServedAd): string
report(ctx: TenantCtx, campaignId: string, range: DateRange): Promise<CampaignReport>
// @nomad/ads/ui
<AdSlot code="article_mid" />   // 서버 컴포넌트, 크기 예약 + 라벨 + 외부망 태그 지연 로드
```

## 6. 이벤트

`ads.campaign.submitted`, `.activated`, `.ended`, `ads.creative.reviewed`, `ads.budget.exhausted`. notify(광고주·담당자), analytics(매출 리포트).

## 7. 법규·정책

| 항목 | 규칙 | 상태 |
|---|---|---|
| 광고 표시 | 모든 소재에 "광고" 라벨(compliance `ad`), 기사형은 `sponsored` | local-news 01장 6절 |
| 표시광고법 | 허위·과장 소재 검수 체크리스트(검수 화면) | 체크 항목 법무 확인 |
| 정부광고 | 정부광고법상 정부기관 광고는 대행 기관 경유 규정이 있어 local-news는 직판 금지(`public_body_direct_sale=false`). 다른 제품 적용 여부는 확인 필요 | 미확인 |
| 외부망 정책 | AdSense·Ad Manager·애드핏 정책(클릭 유도 금지 등)은 각 제공자 정책 페이지 기준 | 제공자 확인 |

## 8. 실패 동작

소재 선택 오류 → 하우스 광고(없으면 빈 예약 공간). 집계 실패 → 비콘을 잡 큐에 다시 넣음(유실 1% 미만 목표, 제안). 외부망 스크립트 실패는 페이지 렌더를 막지 않음(비동기).

## 9. local-news에서 옮기는 것

| local-news | 공용 | 남는 것 |
|---|---|---|
| `news.ad_slots`, `advertisers`, `ad_campaigns`, `ad_creatives`, `ad_daily_stats` | `ads.*` | - |
| 외부 광고망 태그 | `ads.network_tags` | - |
| `news.local_listings`(업소 디렉토리), `news.public_notices`(지자체 공고) | - | local-news 전용 |
| 정부광고 직판 금지(NW013) | `settings.public_body_direct_sale` + `AD003` | NW013은 호환 기간 동안 유지 |

## 10. 결정 필요

| ID | 결정 | 권고 |
|---|---|---|
| AD-D1 | 단가 방식 1차 범위 | `flat`(기간 정액)과 `cpm`만. 지역 광고주는 정액이 대부분 |
| AD-D2 | 광고주 셀프 포털 | 확장(1차는 담당자 입력 + 리포트 CSV 발송) |
| AD-D3 | 비콘 저장 | 일 집계만 저장, 원시 이벤트는 저장하지 않음 |
