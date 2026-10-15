# ads 개발 지시서 (`@nomad/ads`)

기획 정본: `products/_platform-core/common-modules/ads.md`. 공통 규칙·적용 절차: [`README.md`](README.md).

## 1. 만들 것 (v1.0)

슬롯(크기·기기·높이 예약), 광고주, 캠페인(정액·CPM), 소재(media 자산, 라벨 필수)와 검수, 소재 선택 함수, 하우스 광고, 외부 광고망 태그(AdSense·Ad Manager·카카오 애드핏), 노출·가시 노출·클릭 집계(서버 묶음, 서명 클릭 URL), 광고주 리포트 CSV, `AdSlot` 서버 컴포넌트.

## 2. 파일

| 경로 | 책임 |
|---|---|
| `sql/0650_ads.sql` | 표 8개, 전이 RPC, `pick_creative`, `record_events`, 리포트 뷰 |
| `src/server/serve.ts`, `events.ts`, `click.ts`(HMAC 서명), `report.ts` | 공개 API |
| `src/ui/AdSlot.tsx`(서버), `AdBeacon.tsx`(클라이언트, IntersectionObserver), `NetworkTag.tsx`(지연 로드) | 화면 |
| `src/ui/admin/` | 슬롯·광고주·캠페인·소재 검수(체크리스트)·리포트 |
| `worker/handlers/ads/flush-events.ts`, `budget.ts` | 묶음 저장, 예산 소진 판정 |

## 3. 구현 순서

| 순서 | 작업 | 확인 |
|---|---|---|
| 1 | SQL, 라벨 없는 소재 승인 거부(`AD001`), 미승인 소재 연결 거부(`AD002`) | 스모크 |
| 2 | `pick_creative`: 기간·검수·타기팅·예산·우선순위·가중치, 없으면 하우스 → 외부망 | 시나리오 표 20개 |
| 3 | `AdSlot`: 반응형 구간별 높이 예약(`reserve`), 라벨 표시, 광고 없어도 공간 유지 | 페이지 CLS 0.1 이하(Lighthouse CI) |
| 4 | 비콘: 화면 50% 이상 1초 → 가시 노출, 묶음 전송, 서버 봇 필터 | 같은 페이지뷰 중복 0 |
| 5 | 클릭: `/api/ads/c/<토큰>` 서명·만료 검사 → 기록 → 302 | 위조 토큰 거부 |
| 6 | 외부망 태그: 동의(쿠키) 상태 확인 후 지연 로드, 실패해도 렌더 영향 없음 | 스크립트 차단 시 페이지 정상 |
| 7 | 리포트 CSV, 예산 소진 이벤트 | 광고주 리포트 수치 = 일 집계 합 |

## 4. 외부 서비스·공식 문서

| 주제 | 링크 |
|---|---|
| Google Publisher Tag(Ad Manager) | https://developers.google.com/publisher-tag/guides/get-started |
| AdSense 프로그램 정책 | https://support.google.com/adsense/answer/48182 |
| 카카오 애드핏 | https://adfit.kakao.com |
| Better Ads 기준 | https://www.betterads.org/standards/ |
| CLS 최적화 | https://web.dev/articles/optimize-cls |

## 5. 제품 주입 값

`slots` seed(제품 화면별 코드·크기), 타기팅 컨텍스트 생성 함수(페이지 종류·섹션·지역), `publicBodyDirectSale`(local-news `false`), 차단 카테고리, 하우스 광고 소재.

## 6. 테스트

기간 경계, 예산 소진 후 미노출, 우선순위·가중치 분포(1만 회 시뮬레이션), 라벨 필수, 공공기관 직판 거부(`AD003`), CLS 회귀, 봇 UA 제외.

## 7. 자주 나는 문제

| 증상 | 원인·해결 |
|---|---|
| ISR 페이지에 같은 광고만 나옴 | 소재 선택을 페이지 캐시 밖에서(슬롯은 서버 스트리밍 또는 작은 클라이언트 요청) |
| 외부망 광고가 레이아웃을 밀어냄 | 외부망 단위 크기를 슬롯 `sizes` 안으로 제한, 높이 예약 유지 |
