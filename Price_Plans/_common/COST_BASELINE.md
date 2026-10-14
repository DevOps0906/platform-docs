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

AI 호출 원가는 코어 seed 단가를 원가 지표로 쓴다(`products/_supabase-modular/seed.sql:228-246`, 값은 제안, 원화 환산 미확인). 제품별 작업 원가 계산 예시는 `products/website-floria/01_PRD.md` 4.1절을 참고한다.

에이전시 제작에 쓰는 코딩 에이전트(Claude Code 등) 구독비는 플랫폼 원가가 아니라 사업 고정비로 본다. 금액은 미확인이며 대표님 실제 결제액으로 채운다.

## 4. 결제 수수료

PG 수수료와 플랫폼 중개 수수료(크몽·숨고 등)는 미확인. 각 플랫폼 판매 페이지에서 확인 후 이 표에 추가한다.

| 채널 | 수수료 | 확인일 |
|---|---|---|
| 크몽 | 미확인 | - |
| 숨고 | 미확인 | - |
| Toss Payments(자체 결제) | 미확인 | - |
