# 공용 인프라 원가 기준

확인일 2026-10-14. 외부 서비스 가격은 바뀌므로 분기마다 다시 확인하고 확인일을 고친다. 아래 값은 출처 문서에서 확인한 공개 가격이며, 실제 청구는 사용량에 따라 달라진다.

## 1. 호스팅·DB

| 서비스 | 플랜 | 가격 | 핵심 조건 | 출처 |
|---|---|---|---|---|
| Vercel | Hobby | 무료 | 개인·비상업 용도만. 고객 사이트·유료 상품은 쓸 수 없음 | https://modelence.com/compare/vercel-pricing |
| Vercel | Pro | 사용자(좌석)당 월 $20 + 사용량 | 상업 이용 허용, 전송 1TB 포함, 지출 한도 설정 가능 | https://docs.it.apps.vogels.com/docs/vercel/reference/pricing |
| Netlify | Pro | 월 $19 | Vercel 대안 | https://toolradar.com/tools/vercel/pricing |
| Cloudflare Pages | Free | 무료부터 | 무료 티어에 개인용 제한 없음(정적 랜딩 원가 절감용) | https://thesearchsherpa.com/?p=2188 |
| Supabase | Free | 무료 | 프로젝트 2개, 7일 활동 없으면 자동 일시정지(수동 재개) | https://supabase.com/pricing.md |
| Supabase | Pro | 조직당 월 $25 + 프로젝트 컴퓨트 | 컴퓨트 크레딧 $10 포함(Micro 1개분). 예: 프로젝트 2개 = 월 $35 | https://supabase.com/pricing.md |
| 아임웹 | Starter | 1개월 결제 월 2만원, 12개월 결제 월 16,000원 | 노코드 빌더, 고객 직접 수정 | https://www.i-boss.co.kr/ab-6141-64470 |

## 2. 에이전시 공용 인프라 원가 (제안)

| 항목 | 월 원가 | 설명 |
|---|---|---|
| Vercel Pro 팀 1개(배포 좌석 1) | $20 | 고객 정적·모션 사이트를 한 팀에 모아 운영 |
| Supabase Pro 조직 1개(리드 DB 프로젝트 1개) | $25 | 멀티테넌트 `leads` 테이블 1개로 모든 고객 리드 저장 |
| 합계 | 약 $45~55 | 트래픽 큰 고객이 생기면 사용량 과금 추가. 지출 한도를 반드시 설정 |

고객 수가 늘어도 고정 원가가 거의 그대로이므로, 호스팅·리드 저장을 유지보수 구독에 포함해 받으면 마진이 커진다(`Web-App-Agency/03_HOSTING_DATA.md`).

## 3. AI 원가

AI 호출 원가는 코어 seed 단가를 원가 지표로 쓴다(`products/_supabase-modular/seed.sql:243-262`, 값은 제안, 원화 환산 미확인). 제품별 작업 원가 계산 예시는 `products/website-floria/01_PRD.md` 4.1절을 참고한다.

원화 환산 환율은 미확인이다. 2026-10-14 초안 작성 때 플랫폼 문서마다 1달러 1,400원(nomad-docs·blog·commerce, admin-suite, stock-dashboard, microweb-studio, astro-ai, study-note, live-poll) 또는 1,500원(nomad-video, toon-factory, flora-publishing)을 가정했다. 다음 분기 재확인 때 하나로 통일하고 각 문서 3장을 다시 계산한다.

에이전시 제작에 쓰는 코딩 에이전트(Claude Code 등) 구독비는 플랫폼 원가가 아니라 사업 고정비로 본다. 금액은 미확인이며 대표님 실제 결제액으로 채운다.

## 4. 결제 수수료

공개 페이지에서 확인한 값이다. 정기결제(빌링) 전용 요율, 숨고 견적 단가, 숨고페이·위시켓 수수료는 미확인으로 남긴다. 상세 계산은 `../Web-App-Agency/01_MARKET_BENCHMARK.md` 6장.

| 채널 | 수수료 | 출처 | 확인일 |
|---|---|---|---|
| Toss Payments(자체 결제) | 가입비 220,000원, 연관리비 110,000원. 카드·간편결제 3.4%, 계좌이체 2.0%(최저 200원), 가상계좌 건당 400원(모두 VAT 별도). 영세·중소 우대 요율 별도. 정기결제 전용 요율 미확인 | https://www.tosspayments.com/about/fee | 2026-10-14 |
| 크몽(판매자) | 서비스 이용료 70만원까지 16.4%, 200만원까지 9.4%, 초과분 4.4%(구간 경계는 공식 예시에서 역산) + 결제망 이용료 3.3% + 두 수수료의 VAT 10%. 실효 약 21.7%(70만원 이하), 약 13.2%(350만원) | https://kmong.com/support/expert-center/posts/751 , https://kmong.com/support/expert-center/posts/588 | 2026-10-14 |
| 크몽(구매자) | 2023년 공지는 주문 금액의 3.5%(VAT 포함, 최소 300원·최대 105,000원)인데 현재 상품 페이지에는 4.5%(VAT 포함)로 표시된다. 현행은 4.5%로 보고 공지 갱신 여부는 미확인 | https://kmong.com/support/customer-center/posts/57 , https://kmong.com/gig/792046 | 2026-10-14 |
| 숨고 | 거래 수수료 없음. 고객이 견적을 열람할 때 캐시 차감(48시간 내 미열람 시 환급). 견적 1건 단가 미확인(제3자 추정 약 3,000~4,000원) | https://soomgo.com/pro | 2026-10-14 |
