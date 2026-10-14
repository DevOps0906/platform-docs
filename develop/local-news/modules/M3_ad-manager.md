# M3 ad-manager 개발 지시서

작성일 2026-10-15. 기획 정본 `D:/WorkSpace/platform/docs/products/local-news/modules/M3_ad-manager.md`, 슬롯 배치 `D:/WorkSpace/platform/docs/products/local-news/03_SCREENS_UX.md` 템플릿 절, 표 `D:/WorkSpace/platform/docs/products/local-news/05_DATA_MODEL.md`.

## 1. 만들 것

| 부분 | 내용 | 우선 |
|---|---|---|
| 슬롯 | 템플릿별 고정 슬롯 정의(코드·크기·위치), `AdSlot` 컴포넌트(공간 예약 + "광고" 라벨) | P0 |
| 직판 | 광고주·캠페인(기간·우선순위·가격 방식)·소재(검수), 하우스 광고 | P0 |
| 서빙·집계 | 서버 렌더 때 슬롯별 소재 선택, 노출 비콘 `/api/r/ad-event`, 클릭 리다이렉트 `/r/ad/[creative_id]`, 일 롤업 | P0 |
| 외부 광고망 | 소재 종류 `external`(GAM·AdSense), GPT 로더, 신문사 도메인 `/ads.txt` | P1 |
| 업소 디렉토리 | 업주 신청 → 결제 → 검수 → 게재 → 만료, 디렉토리 페이지 | P1 |
| 지자체 공고 | 공고 등록·게재, 공고 목록 블록, 게재 증빙 PDF | P1 |

## 2. 디렉토리·파일

모듈 모양은 이 폴더 `README.md` 3.1절, 경로·잡 이름 정본은 `D:/WorkSpace/platform/docs/products/local-news/02_ARCHITECTURE.md` 2·4절과 `D:/WorkSpace/platform/docs/products/local-news/04_API.md` 2절.

| 경로 | 책임 |
|---|---|
| `apps/web/src/modules/ad-manager/server/index.ts` | `selectForSlot`, `recordImpression`, `clickRedirect`, 업소·공고 함수 |
| `.../components/AdSlot.tsx` | 서버 렌더 때 `min-height`/`aspect-ratio` 예약 + 라벨, 화면 진입 시 노출 비콘(IntersectionObserver), 외부 소재면 LCP 이후 GPT 로드 |
| `.../server/select.ts` | `news.serve_ads(org, placement)`(anon, 상태·기간·우선순위 판정은 DB) 결과에서 슬롯별 1개 선택, 없으면 하우스 |
| `.../server/stats.ts` | 비콘 검증 → (소재, 날짜) 묶음 → `news.record_ad_stats(creative_id, day, impressions, clicks)`(service) |
| `.../server/listings.ts`, `.../server/notices.ts` | `news.submit_listing`(service), 공고 RPC, 증빙 PDF 잡 enqueue |
| `.../cache.ts` | 슬롯이 있는 페이지 태그(홈·섹션·기사) 무효화 목록 |
| `worker/src/handlers/news.stats/news.ad_stats_rollup.ts` | 02장 4절의 일 롤업 잡. 05장 RPC가 일 행에 직접 증분하므로 샤드를 쓰지 않으면 생략 가능(06장에서 결정) |
| 캠페인 경계 무효화 | 시작·종료 시각에 태그 무효화(주기 잡 위치는 06장 작업에서 정함, 제안: `news.stats` 큐 10분 주기) |
| `apps/web/src/app/api/r/ad-event/route.ts`, `apps/web/src/app/r/ad/[creative_id]/route.ts` | 노출 비콘, 클릭 302(04장 2.1절) |
| `apps/web/src/app/api/r/listings/*`, `apps/web/src/app/api/newsroom/ads/*` | 업소 신청, 편집국 광고 관리 |
| `apps/web/src/app/(reader)/_t/[host]/ads.txt/route.ts`(제안) | 신문사별 ads.txt(설정 없으면 404). 04장 경로 표에 없으므로 추가 요청 |

## 3. 구현 순서

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | 템플릿별 슬롯 목록을 시드로(코드·크기·위치). 신문사는 슬롯을 켜고 끄기만 | 슬롯 수 상한을 신문사가 못 늘림 |
| 2 | `AdSlot`: 소재 전에 공간 예약, 라벨 고정 | Lighthouse·web-vitals로 모바일 홈 CLS ≤ 0.1 |
| 3 | 광고주·캠페인·소재 CRUD(RPC), 소재 검수 화면, 클릭 URL 검증(https만, 내부망 거부) | 미검수 소재 노출 0 |
| 4 | `selectForSlot`: 서버 렌더(ISR) 때 선택, 실패·지연 300ms 초과 시 하우스. 캠페인 시작·종료 때 슬롯이 있는 페이지 태그 무효화 | 장애 주입 시 페이지 정상 |
| 5 | 노출 비콘: 50% 이상 1초 노출 시 1회(제안), 페이지 이탈 때 `sendBeacon` 묶음 | 봇 UA 0 증가 |
| 6 | 클릭: 레이트 리밋(IP 해시) → 집계 → 302 | 같은 IP 분당 상한 초과 시 집계 제외 |
| 7 | 캠페인 경계 무효화(`news.ad.campaign.started`·`.ended`), 일 롤업 `news.ad_stats_rollup` | 종료 뒤 다음 무효화 주기 안에 노출 중단 |
| 8 | (P1) GAM: 소재 `external` + `external_unit_id`(광고 단위 경로), 동의·설정 있는 신문사만 GPT 로드 | GPT 슬롯 크기 = 예약 공간 |
| 9 | (P1) ads.txt 설정 화면과 라우트 | 신문사 도메인 루트에서 응답 |
| 10 | (P1) 업소 신청·결제(M2와 같은 신문사 Toss 경로)·검수·만료, 공고·증빙 PDF | 반려 시 자동 환불 |

## 4. 외부 서비스 설정

| 서비스 | 할 일 | 링크 |
|---|---|---|
| Google Ad Manager | 신문사가 자기 GAM 네트워크에서 광고 단위를 만들고 경로(`/네트워크코드/상위/단위`)를 우리 설정에 입력. GPT는 `https://securepubads.g.doubleclick.net/tag/js/gpt.js`에서만 로드, `defineSlot` 크기와 div 크기를 맞춤, 라인 아이템이 Ready여야 노출 | https://developers.google.com/publisher-tag/guides/get-started (2026-10-15 열람 확인) |
| AdSense ads.txt | 루트 `/ads.txt`에 게시자 ID 줄. 필수는 아니지만 권장, 반영에 며칠 | https://support.google.com/adsense/answer/12171612 (2026-10-15 열람 확인) |
| AdSense 광고 크기 | 300x600·320x100 등 실적 좋은 크기 참고 | https://support.google.com/adsense/answer/6002621 (조사 에이전트 열람) |
| IAB 고정 크기 | 표준 크기와 초기 로드 용량 상한(Billboard 250kB, MREC 150kB) → 직판 소재 업로드 상한으로 사용 | https://www.iab.com/wp-content/uploads/2019/04/IABNewAdPortfolio_LW_FixedSizeSpec.pdf (조사 에이전트 열람) |
| Better Ads | 금지 형식(팝업, 프리스티셜, 카운트다운, 모바일 광고 밀도 30% 초과) 점검 | https://www.betterads.org/standards/ |

GAM·AdSense 계정은 신문사 소유입니다. 플랫폼은 계정을 대신 만들지 않고 설정값만 받습니다. 제3자 광고 쿠키는 신문사 개인정보처리방침에 반영합니다(01장).

## 5. 테스트

| 종류 | 항목 |
|---|---|
| 단위 | 소재 선택(기간·우선순위·하우스), 클릭 URL 검증, 비콘 묶음 검증 |
| 컴포넌트 | 라벨 없는 `AdSlot` 렌더 경로 0, `sponsored` 기사 라벨(M7 문구 사전) |
| 성능 | 템플릿 3종 모바일·데스크톱 CLS 측정(소재 있음·없음·지연) |
| RLS | `ad_manager` 쓰기 가능, `reporter` 광고 표 쓰기 불가, 독자 직접 SELECT 불가(서빙 API만) |
| E2E | 캠페인 등록 → 검수 → 기간 시작 → 노출·클릭 집계 → 종료 |

## 6. 운영 점검표

- [ ] 일 집계 잡 성공, 노출·클릭이 0인 활성 캠페인 경고
- [ ] 검수 대기 소재 24시간 초과 알림
- [ ] 신문사별 CLS(p75) 주간 확인(광고 원인 여부)
- [ ] ads.txt 설정 신문사의 응답 확인
- [ ] 업소 게재 만료 잡, 공고 증빙 PDF 생성 실패 0

## 7. 자주 나는 문제

| 증상 | 원인 | 조치 |
|---|---|---|
| 레이아웃이 밀림 | 소재 크기가 슬롯 예약과 다름, 또는 GAM 반응형 크기 | 소재 업로드 때 크기 검사, GAM 크기 목록을 슬롯 크기로 제한 |
| GAM 광고가 안 뜸 | 라인 아이템 미준비, 단위 경로 오타, 광고 차단기 | GPT 콘솔(`googletag.openConsole()`)로 확인, 공간은 유지 |
| 노출이 과다 집계 | 비콘 중복 전송 | 소재·페이지뷰 단위 1회 플래그 |
| 클릭 리다이렉트가 이상한 곳으로 | 저장된 URL 변경 권한 오남용 | 클릭 URL 변경은 재검수 상태로 전이(제안) |
