# reviews — 원본 프로젝트 코드 리뷰 25개

통합 기획의 근거 자료입니다. 각 리뷰는 원본 프로젝트의 구조, 결함("높음" 결함은 기획서 02·05장에서 차단 설계로 처리), 이식할 자산을 적었습니다. 작성 형식은 [`_tools/REVIEW_TEMPLATE.md`](../_tools/REVIEW_TEMPLATE.md), PDF 변환본은 별도 레포 [PDF_Collections](https://github.com/DevOps0906/PDF_Collections/tree/master/code-reviews)의 `code-reviews/`에 있습니다.

| 리뷰 | 원본 프로젝트 | 반영된 통합 제품 |
|---|---|---|
| [`Astro_AI.md`](Astro_AI.md) | 사주·타로 AI 리포트 | astro-ai |
| [`FortuneDocs.md`](FortuneDocs.md) | 운세 리포트 PDF | astro-ai, nomad-docs(참고) |
| [`Flora-v2.md`](Flora-v2.md) | AI 출판(v2) | flora-publishing |
| [`flora.md`](flora.md) | AI 출판(v1) | flora-publishing, nomad-docs(참고) |
| [`flora-publisher.md`](flora-publisher.md) | 출판 편집기 | flora-publishing |
| [`SellingDocs.md`](SellingDocs.md) | 판매 문서 생성 | flora-publishing, nomad-docs(참고) |
| [`NOMAD_Shorts_Maker.md`](NOMAD_Shorts_Maker.md) | 숏폼 제작 | sceneflow, nomad-blog, toon-factory(참고) |
| [`Nomad-BlogStudio.md`](Nomad-BlogStudio.md) | 블로그 자동화 | sceneflow, toon-factory(참고) |
| [`Youtube_shots_Maker.md`](Youtube_shots_Maker.md) | 유튜브 쇼츠 제작 | sceneflow, nomad-blog |
| [`Nomad-AI-Factory_V.2.md`](Nomad-AI-Factory_V.2.md) | AI 커머스 팩토리 v2 | nomad-commerce |
| [`nomad-ai-factory.md`](nomad-ai-factory.md) | AI 커머스 팩토리 | nomad-commerce, nomad-blog(참고) |
| [`nomad-ai-commerce.md`](nomad-ai-commerce.md) | AI 커머스 | nomad-commerce, nomad-blog(참고) |
| [`sellingstudio.md`](sellingstudio.md) | 셀링스튜디오(상세페이지) | nomad-commerce, toon-factory(참고) |
| [`premium-wedding-invitation.md`](premium-wedding-invitation.md) | 모바일 청첩장 | microweb-studio |
| [`nexus-micro-web-builder.md`](nexus-micro-web-builder.md) | 마이크로웹 빌더 | microweb-studio |
| [`webcraft-agency-simulator.md`](webcraft-agency-simulator.md) | 웹 제작 견적 시뮬레이터 | microweb-studio |
| [`ERP-Wesite.md`](ERP-Wesite.md) | ERP | admin-suite |
| [`Hospital.md`](Hospital.md) | 병원 관리 | admin-suite |
| [`School_Management_System.md`](School_Management_System.md) | 학교 관리 | admin-suite |
| [`basic-master-module.md`](basic-master-module.md) | 공통 마스터 모듈(인증·권한) | 공용 코어(_platform-core), admin-suite |
| [`Slido_Project.md`](Slido_Project.md) | 실시간 투표 | live-poll |
| [`Stock_Trader_nomad.md`](Stock_Trader_nomad.md) | 주식 대시보드 | stock-dashboard |
| [`Toon-Factory.md`](Toon-Factory.md) | 웹툰 제작 | toon-factory |
| [`study-note-organizer-codex-01.md`](study-note-organizer-codex-01.md) | 학습 노트 정리 | study-note |
| [`WebSite.md`](WebSite.md) | 브랜드 웹사이트 | website-floria, microweb-studio |

"참고"는 그 제품의 설계에 패턴만 참고했다는 뜻입니다(코드 이식 대상 아님). 원본 폴더 위치와 이식·폐기 목록은 각 제품 `07_SOURCE_MIGRATION.md`에 있습니다.
