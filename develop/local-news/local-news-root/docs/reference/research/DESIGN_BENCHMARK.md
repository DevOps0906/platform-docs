# 리서치 1: 언론사 홈페이지 디자인 벤치마크 (2026-10-15, 조사 에이전트 보고 요약 원문)

조사 한계: chosun.com, joongang.co.kr, hani.co.kr, yna.co.kr, nytimes.com, theguardian.com, bbc.com, bbc.co.uk/gel, law.go.kr 은 도구 접근 차단(미확인). WebFetch는 HTML 텍스트만 읽어 sticky·컬럼 수·광고 실제 크기·모바일 차이는 대부분 미확인.

## 0. 사이트별 실측 요약
| 사이트 | 마스트헤드 | 내비/지역 | 리드·블록 순서 | 랭킹·오피니언 | 지역 모듈 | CTA·광고 | 푸터 법정표기 |
|---|---|---|---|---|---|---|---|
| 경향신문 khan.co.kr | 로고, 요일 포함 날짜, 날씨 없음 | 7개 대섹션 메가메뉴, '지역' 단일 메뉴 | 톱+랭크 8개 → 대형 블록 3 → 오피니언 → 뉴스레터 → 사진 → 스포츠 → 인터랙티브 → 문화 | '많이 본 뉴스' 5개 중단, 오피니언 리드 직후 | 없음 | 뉴스레터 2종, 구독신청, 중단 광고 3줄 | 미확인 |
| 매일신문 imaeil.com | 날짜, 지면보기·기사제보 | 10개 섹션 + '고향사랑' | 사진 톱 → 썸네일 약 20개 리스트 → 사설·칼럼 → 기획 | 랭킹 없음 | 인사·화촉·모임·부음은 메뉴에만 | 배너 1개 | 미확인 |
| 경인일보 kyeongin.com | 날짜, 지면·구독·제보 | 인천/경기 분리, EDITOR'S PICK | 리드 → 후속 그리드 → 심층 슬라이더 → 기관·지자체 배너 여러 줄 → 오피니언 → 탐사 → 디지털스페셜 → 컬처 → 지역 목록 → 정정·반론 → 뉴스레터 4종 → 회원 CTA → AI 검색 | 오피니언 중단 | 인사·부음은 '피플' 메뉴 | 지자체 배너 비중 높음 | 등록번호 경기 아51587, 등록일, 발행·편집인. 청소년보호책임자는 이름 없이 정책 링크만 |
| 강원일보 kwnews.co.kr | '최종편집' 일시 | 지역 메뉴에 18개 시군 전부 | 속보 → 알립니다 → 리드·리스트 → 인사·동정·부고·결혼 → 오피니언 → 사설 → 기획 → 포토 → 문화 → 인물 | 미확인 | 홈 본문 블록 | 복지몰·광고안내 | 미확인 |
| 한라일보 ihalla.com | 날짜·시각, 제휴 사이트 바 | '지역소식', '궨당소식'(화촉·부고·인사), 독자마당(제보·투고) | 리드 캐러셀 → 실시간뉴스 → 영상 → 주목 이사람 → 섹션 → 기획 → 많이 본 뉴스 1~10 → 포토 → 공지·화촉·부고·인사 탭 → 사설·정정보도 → 섹션 탭 → 오피니언 | 랭킹 하단 | 탭 모듈 | 세미나 팝업, 제휴기관 로고 | 발행인, 편집인, 등록번호, 등록일, 청소년보호책임자 모두 표기 |
| 용인시민신문 yongin21.co.kr (엔디소프트) | 최종편집 일시, 검색, 전체메뉴 | 뉴스·생활·사람들·기획·오피니언·포토 | 헤드 5 → 그리드 → 영상 → 인기기사 5 → 커버스토리 → 15개 섹션 | 인기기사 상단 | 없음 | 영상 옆 배너 | 전 항목 + 엔디소프트 로고 |
| 옥천신문 okinews.com (엔디소프트) | 로고 | 면 소식은 사회 하위, 여론광장·구독·제보·옥천장터 | 홍보·공지·축하·부음 모듈이 리드보다 위 → 리드 → 섹션 → 지면보기 → 기부·상가탐방 → 기고 | 없음 | 상단 | 이미지 팝업 1 | 전 항목 + 최초발행일 |
| Texas Tribune (Newspack) | 로고, 슬로건, Donate | Investigations·Guides·Events·Data·Newsletters | 리드 → 선거 패키지 → 데이터 탐색기 → 뉴스레터 → 후보 가이드 → 후원 CTA → 토픽 → 뉴스레터2 → Load more | 랭킹 없음 | 데이터 DB | CTA 블록 사이 반복 | Who Funds Us, 윤리강령, 정정 |
| Baltimore Banner | Breaking 태그 | 지역 경험 전환 탭 3개, Obituaries 메뉴 | 리드 → Top Stories(LIVE) → 선거 가이드 → Must Reads → 스포츠 → Sponsored "Presents" → 기획 → 주정치 | 없음 | 부고·이벤트·Job Board 메뉴 | "Subscribe for $1", Advertise | - |
| Axios Denver | 로고+도시명 | News·Things to Do·Politics·Food·Sports | 구독 CTA 최상단 → 리드("Why it matters") → 카드 → 기자 추천 → 섹션 → 5 big things | 없음 | Things to Do | 뉴스레터 중심 | - |
조선일보: 2020년 Washington Post Arc CMS 도입. 중앙: 2021년 로그인 유도. 한겨레: 상단 '후원하기'(이상 2차 출처).
엔디소프트 홈페이지(ndsoft.co.kr): 거래 매체 3,644개 표기.

## 1. 한국형 vs 글로벌형
| 항목 | 한국 | 글로벌 |
|---|---|---|
| 상단 | 날짜·'최종편집' 시각, 지면보기·제보·구독 유틸 바. 날씨 대부분 없음 | 브랜드 바 + Donate/Subscribe. 날짜 생략 다수 |
| 내비 | 7~12개 대섹션 + 메가메뉴 | 짧은 필라 + 토픽 |
| 리드 | 톱 1 + 헤드라인 리스트 5~20. 텍스트 밀도 높음 | 패키지형, 카드 그리드, 이미지 비중 큼 |
| 블록 순서 | 섹션 나열식, 오피니언 중단 | 주제·이벤트형(선거, 데이터, LIVE) |
| 랭킹 | '많이 본 뉴스' 5~10 거의 필수 | Must Reads/에디터 픽 |
| 수익 CTA | 구독신청, 후원(한겨레), 회원가입 유도 | 뉴스레터·후원 CTA 블록 사이 2~3회 |
| 광고 | 기관·지자체 배너 줄, 날개 광고, 팝업 | GAM 표준 슬롯, 스폰서 라벨 |
| 지역 | 시군 메뉴, 부음·인사 모듈 | 지역 '경험' 전환, 도시별 뉴스레터 |
| 푸터 | 법정 매체정보 + CMS 벤더 로고 | 윤리강령, 재원 공개, 정정 정책 |

## 2. 지역신문 필수 모듈
시·군/읍면 칩 탭(쿠키 저장, '우리 동네' 블록 필터), 지역 소식, 부고·인사·동정·화촉 4탭(리드 바로 아래 권장, 옥천 사례), 행사·축제 캘린더, 날씨·생활정보(기상청 API, 미세먼지, 당번 약국 — 조사한 한국 사이트 전부 없음 = 차별화), 지역 업소 광고(300x250 카드 그리드, 디렉터리형 네이티브), 지자체 공고(배너 대신 텍스트 리스트), 독자 제보(고정 CTA + 카카오톡 채널), 정정·반론보도 하단 블록, 구독·후원·뉴스레터 블록 사이 2회.

## 3. 추천 템플릿 3종
그리드: Guardian Source 브레이크포인트 320/375/480/660/740/980/1140/1300, WPDS 768/900/1024/1280/1440.
| 이름 | 범위 | 컬럼, 거터, 마진 |
|---|---|---|
| xs | 0–599 | 4col, 16px, 16px |
| sm | 600–1023 | 8col, 20px, 24px |
| md | 1024–1279 | 12col, 24px, max 1200 |
| lg | ≥1280 | 12col, 24px, max 1200 |
| xl | ≥1440 | 1200 + 좌우 160px 날개(선택) |

| # | A. 전통 신문형(지역 일간·주간) | B. 모던 매거진형(기획·인물) | C. 모바일 피드형(인터넷 지역신문) |
|---|---|---|---|
| 1 | 유틸 바: 날짜, 날씨, 지면, 제보, 구독 | 유틸 바 최소 + 후원 버튼 | 앱 바: 로고, 시군 선택, 검색 |
| 2 | 마스트헤드: 로고 중앙, 좌우 468x60 배너 2 | 로고 좌측, 필라 내비 | 시군 칩 탭 |
| 3 | GNB(sticky) + 시군 탭 | sticky 내비 | 속보 티커 |
| 4 | 속보 티커 | 리드 패키지 8col 대형 이미지 + 4col 관련 | 리드 카드 16:9 |
| 5 | 리드: 헤드 6col, 서브 3col, 많이 본 뉴스 3col | 970x250 Billboard(lg 이상) | 부음·인사 미니 탭 |
| 6 | 728x90(md+) / 320x100(xs) | 섹션 4x3col 카드(섹션 컬러 상단 룰) | 피드 카드 5개마다 320x100 또는 300x250 |
| 7 | 부고·인사·동정·화촉 탭 4col + 행사 캘린더 8col | 오피니언 레일(칼럼니스트 사진) | 뉴스레터·카톡 구독 CTA |
| 8 | 섹션 블록 xN: 9col 기사 + 3col 300x250 | 포토 스토리 풀블리드 | 행사, 날씨 카드 |
| 9 | 오피니언(사설·칼럼) | 뉴스레터, 후원 CTA | 업소 광고 카드 |
| 10 | 포토·영상 | 지역 생활(날씨, 행사) | 많이 본 뉴스 |
| 11 | 지자체 공고 리스트 + 업소 광고 300x250 x4 | 300x250 x2 | 하단 탭 바: 홈, 지역, 제보, 구독 |
| 12 | 정정·반론, 푸터 | 푸터 | 푸터(접힘형 매체정보) |
| 날개 | xl 이상 160x600 또는 300x600 | 없음 | 없음 |
IAB: 970x250 Billboard, 728x90 Leaderboard, 970x90 Pushdown, 300x250 MREC, 160x600, 300x1050, 320x50. 300x600·320x100은 AdSense top-performing. IAB 초기 로드 상한 Billboard 250kB, MREC 150kB.

서체: A = Noto Serif KR 700/900 + Pretendard(둘 다 OFL), B = 본명조(Source Han Serif, OFL) + Pretendard, B' = 나눔명조(OFL), C = Pretendard Variable(동적 서브셋). KoPub World는 사전승인 없는 수정·변형 금지 조건 → SaaS 기본값 비권장. 신문사 전용서체(조선일보명조 등) 웹 임베드 조건 미확인.

테넌트 커스터마이즈: 로고·파비콘·제호, 브랜드 컬러(primary/accent), 섹션 컬러(B만 자유), 블록 순서 드래그, 블록 ON/OFF(부음, 행사, 날씨, 공고, 업소, 날개광고), 시군·읍면 탭 목록, 서체 프리셋(목록 안), 그리드 비율·광고 슬롯 크기는 고정(CLS 보호), 푸터 법정정보 필수 입력·비노출 불가.

## 4. 안티패턴
팝업·전면광고(Better Ads: 데스크톱 팝업·카운트다운, 모바일 팝업·프리스티셜·광고 밀도 30% 초과 기준 미달; Google 인터스티셜 불이익) → 팝업 기능 제공 안 함. 낚시성·선정 배너 → 크리에이티브 카테고리 차단·스폰서 라벨 강제. 기관 배너 줄 과다 → 공고 리스트·배너 수 상한. 레이아웃 이동(web.dev: 광고가 CLS 최대 원인, 슬롯을 접지 말 것) → min-height/aspect-ratio 예약, 하우스 광고. 웹폰트 → Pretendard 동적 서브셋, font-display swap.
CWV 목표: LCP ≤2.5s, INP ≤200ms, CLS ≤0.1 (75퍼센타일, 모바일·데스크톱).

## 5. 출처(직접 확인)
https://www.khan.co.kr, https://www.imaeil.com, https://www.kyeongin.com, https://www.kwnews.co.kr, https://www.ihalla.com, https://www.yongin21.co.kr, http://www.okinews.com/, https://www.ndsoft.co.kr, https://www.texastribune.org, https://www.thebanner.com/, https://www.axios.com/local/denver, https://newspack.com/, https://build.washingtonpost.com/foundations/breakpoints, https://build.washingtonpost.com/foundations/typography, https://raw.githubusercontent.com/guardian/csnx/main/libs/%40guardian/source/src/foundations/__generated__/breakpoints.ts, https://www.iab.com/wp-content/uploads/2019/04/IABNewAdPortfolio_LW_FixedSizeSpec.pdf, https://support.google.com/adsense/answer/6002621, https://web.dev/articles/optimize-cls, https://web.dev/articles/vitals, https://developers.google.com/search/docs/appearance/avoid-intrusive-interstitials, https://www.betterads.org/standards/, https://github.com/orioncactus/pretendard, https://raw.githubusercontent.com/adobe-fonts/source-han-serif/release/LICENSE.txt, https://raw.githubusercontent.com/google/fonts/main/ofl/notoserifkr/OFL.txt, https://www.sandollcloud.com/free-font/205/NanumMyeongjoOTF, https://www.sandollcloud.com/free-font/15810/KoPubWorldDotum, https://www.journalist.or.kr/m/m_article.html?no=47102
