# 공용모듈 기획서 색인 (local-news에서 꺼낸 7종 + 기존 4종 보강)

작성일 2026-10-15. 상태: **제안**(대표님 승인 범위: 신규 7개 전부 + 각 제품 문서는 고치지 않고 적용표·적용 절차만, 2026-10-15). local-news 기획(`docs/products/local-news/modules/`)에서 다른 제품에도 쓰이는 부분을 꺼내 공용모듈로 정의한다. 개발 방법은 `docs/develop/_shared/modules/README.md`, 전체 공용모듈 로드맵은 `docs/products/_platform-core/COMMON_MODULES_ROADMAP.md`가 정본이다.

## 0. 요약

| 순서 | 모듈(패키지) | 스키마·번호 | 한 줄 | local-news 출처 | 첫 적용 제품(기준 구현) |
|---|---|---|---|---|---|
| 1 | [compliance](compliance.md) `@nomad/compliance` | `compliance` 0150 | 약관·개인정보처리방침 버전, 동의 기록, 사업자·법정 표기, 광고·AI 표시 라벨, 개인정보 열람·삭제 요청 | M7 일부 | website-floria·study-note(1단계) |
| 2 | [media](media.md) `@nomad/media` | `media` 0250 | 업로드·크기별 사본·대체 텍스트·저작권·사용처 추적 | M1 일부 | flora-publishing(2단계, 원고·표지 업로드) |
| 3 | [editorial](editorial.md) `@nomad/editorial` | `editorial` 0750 | 작성 → 검토 → 승인 → 예약 → 게시 → 수정 이력, 미리보기, 조회 집계 | M1 일부, M8 일부 | nomad-blog(3단계) |
| 4 | [community](community.md) `@nomad/community` | `community` 0350 | 댓글·방명록·Q&A, 신고, 임시조치, 금칙어, 비회원 글 | M5 일부 | microweb-studio(4단계, 방명록) |
| 5 | [search](search.md) `@nomad/search` | `search` 0450 | 한국어 검색 색인, 필터·정렬, 동의어, 검색 기록 | M8 일부 | local-news(6단계, 기사 검색) |
| 6 | [membership](membership.md) `@nomad/membership` | `membership` 0550 | 고객사의 최종 이용자(독자·수강생), 등급, 정기 구독·후원, 콘텐츠 접근 규칙(페이월) | M2 | local-news(6단계), 앞 제품이 채택하면 그 제품 |
| 7 | [ads](ads.md) `@nomad/ads` | `ads` 0650 | 광고 슬롯·광고주·캠페인·소재 검수·노출 집계, 외부 광고망 태그 | M3 일부 | local-news(6단계) |

기존 로드맵 모듈 4개는 local-news 설계로 보강한다(`COMMON_MODULES_ROADMAP.md` 4.11절): **notify**(뉴스레터 목록·이중 동의·발송 회차·웹 푸시), **analytics**(콘텐츠 조회 이벤트 규격), **cms**(블록 에디터 규격, RSS·사이트맵·구조화 데이터·OG), **tenancy**(최종 이용자와 조직 멤버 분리, 테넌트 도메인별 로그인 주소 등록).

공용으로 꺼내지 **않는** 것(local-news 전용으로 남김): 신문법 필요적 게재사항 10개 판정 규칙(compliance의 `kr_newspaper` 프로필 정의로만 들어감), 자체기사 비율, 정정·반론보도 청구와 기한, 선거 모드, 지면 PDF, 홈 편집, 통신사 전재 계약, 뉴스 사이트맵, 지자체 공고, 경조사.

## 1. 적용표 (16개 제품)

● 1차 적용(그 제품 기획에 이미 해당 기능이 있음) / ○ 후보(제품 개발 착수 때 채택 여부 결정) / - 해당 없음. 각 제품 문서는 이번에 고치지 않았다. 제품 개발을 시작할 때 이 표를 보고 그 제품 `06_AGENT_PLAN.md` 공용 모듈 요청 표에 소비 행을 추가한다(5장).

| 제품(개발 단계) | compliance | media | editorial | community | search | membership | ads | notify | analytics | cms | tenancy |
|---|---|---|---|---|---|---|---|---|---|---|---|
| study-note(1) | ● | ○ | - | ○ 질문 | ○ | ○ 유료 강좌 | - | ● | ● | ○ | - |
| website-floria(1) | ● | ○ 정적 이미지 | ○ 사례·소식 | - | - | - | - | ● | ● | ● | - |
| flora-publishing(2) | ● | ● | ○ 원고 버전 | ○ 독자 리뷰 | ○ | ○ 작가 멤버십 | - | ● | ● | ● | ○ |
| astro-ai(2) | ● | ○ | - | - | - | - | - | ● | ● | ● | - |
| shortsflow(3) | ● | ○ | ○ 업로드 예약 | - | - | - | - | ● | ● | ● | - |
| nomad-blog(3) | ● | ● | ● | ○ | ○ | ○ | ○ | ● | ● | ● | - |
| nomad-commerce(3) | ● | ● | - | - | ○ 상품 DB | - | - | ● | ● | ● | - |
| microweb-studio(4) | ● | ● | ○ 사이트 게시 | ● 방명록 | - | - | ○ | ● | ● | ● | ● |
| live-poll(4) | ● | ○ | - | ○ Q&A 검수 | - | - | ○ 스폰서 | ● | ● | ● | ○ |
| toon-factory(4) | ● | ● | ○ 회차 게시 | ○ 회차 댓글 | - | ○ 유료 회차 | ○ | ● | ● | ● | - |
| admin-suite(5) | ● | ○ | - | - | ○ | - | - | ● | - | - | ○ |
| stock-dashboard(5) | ● | - | - | - | - | - | - | ● | ● | ● | - |
| nomad-docs | ● | ○ 첨부 | ○ 문서 승인 | - | ○ 문서·거래처 | - | - | ● | ● | ● | ○ |
| book-trailer(4) | ● | ○ 표지·이미지 | ○ 승인 링크 | - | ○ 책 목록 | - | - | ● | ● | ● | ○ 화이트라벨 |
| arch-studio(설치형) | ● | ○ | - | - | ○ | - | - | ○ | ○ | - | - |
| local-news(6) | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● |

2026-10-15 수정: 제품 표(SQL)를 다시 확인해 첫 적용 제품을 바로잡았다. media는 website-floria(업로드 기능 없음) → flora-publishing, search는 nomad-docs(현재는 RAG만) → local-news, ads는 live-poll(광고 기능 없음) → local-news. 제품별 적용 방법은 `docs/develop_V2/`. 판단 근거는 각 제품 README·01장의 기능 설명과 SQL 표이며, 제품 개발 착수 때 다시 확인한다(●도 착수 때 범위를 확정). arch-studio는 설치형이라 서버 모듈을 쓰려면 라이선스 서버 쪽에서만 쓴다.

## 2. DB 번호 배정 (제안, `COMMON_MODULES_ROADMAP.md` 3장 갱신)

공용 모듈은 제품(1000~)보다 먼저 적용돼야 하므로 공용 구간 `0100~0999` 안에 둔다. 기존 9개 범위를 100개씩 쓰지 않고 앞 50개로 줄이고(아직 조각 파일이 하나도 없어 바꿔도 깨지는 곳이 없다), 뒤 50개에 새 모듈을 둔다. 의존 순서(media → editorial·community·ads)가 번호 순서와 맞는다.

| 범위 | 스키마 | 모듈 | 상태 |
|---|---|---|---|
| 0100~0149 | `notify` | 알림 | 기존 |
| 0150~0199 | `compliance` | 법정 표기·동의·라벨 | **신규** |
| 0200~0249 | `funnel` | 리드·폼·퍼널 | 기존 |
| 0250~0299 | `media` | 미디어 | **신규** |
| 0300~0349 | `crm` | CRM | 기존 |
| 0350~0399 | `community` | 댓글·신고 | **신규** |
| 0400~0449 | `sync` | 외부 시트 연동 | 기존 |
| 0450~0499 | `search` | 검색 | **신규** |
| 0500~0549 | `lms` | 강좌 | 기존 |
| 0550~0599 | `membership` | 최종 이용자·구독 | **신규** |
| 0600~0649 | `booking` | 예약 | 기존 |
| 0650~0699 | `ads` | 광고 | **신규** |
| 0700~0749 | `support` | 문의함(제보·투고 접수 포함) | 기존 |
| 0750~0799 | `editorial` | 콘텐츠 워크플로 | **신규** |
| 0800~0849 | `cms` | 콘텐츠 블록·SEO | 기존 |
| 0850~0899 | (예비) | - | - |
| 0900~0949 | `growth` | 실험·쿠폰·추천 | 기존 |
| 0950~0999 | (예비) | - | - |

## 3. 공통 설계 규칙 (7개 모두)

| 규칙 | 내용 | 근거 |
|---|---|---|
| 키 | 모든 표에 `org_id`(고객사)와 `app_id`(제품, `core.apps`). 플랫폼 공통 행은 `org_id is null` | `docs/products/_platform-core/DB_CONVENTIONS.md:73` |
| 쓰기 | 브라우저 직접 쓰기 금지. 쓰기는 `SECURITY DEFINER` RPC(`search_path` 고정) 또는 service 경유 서버 | `docs/products/_platform-core/SECURITY_BASELINE.md` |
| RLS | 연산별 정책, `FOR ALL` 금지. 조직 직원 판정은 `core.is_org_member`, 최종 이용자 판정은 `membership.is_end_user` | `docs/products/_platform-core/DB_CONVENTIONS.md` |
| 상태 | 상태 컬럼은 전이 RPC로만. 허용 밖 전이는 `22023` | `docs/products/_platform-core/DB_CONVENTIONS.md` |
| 오류 코드 | 모듈 머리글자 2자 + 숫자 3자리: compliance `CP`, media `MD`, editorial `ED`, community `CO`, search `SR`, membership `MB`, ads `AD`(기존 코어·제품 머리글자와 겹치지 않음) | `docs/products/_platform-core/DB_CONVENTIONS.md:22` |
| 이벤트 | 이름 `<모듈>.<대상>.<동작>`. 전달은 잡(`core.jobs`) 또는 같은 요청 안 후처리. 멱등 키 `<event>:<id>:<version>` | `docs/products/local-news/modules/README.md` 3장 |
| 제품 확장 | 제품 전용 필드는 공용 표에 넣지 않고 제품 스키마의 1:1 확장 표(예: `news.articles.entry_id → editorial.entries.id`)나 `meta jsonb`(허용 키 검사)로 | 제안 |
| 설정 | 제품마다 다른 값은 코드 분기가 아니라 `<모듈>.settings`(org·app별 행) 또는 패키지 초기화 옵션으로 | 제안 |
| 모놀리스 | 단독 Supabase 제품은 `public`으로 변환해 넣는다(local-news `to_monolith.py`와 같은 방식, 모듈별 변환 스크립트를 패키지에 둔다) | `docs/products/local-news/supabase/tools/to_monolith.py` |
| 개인정보 | 최종 이용자 개인정보는 고객사 = 처리자, 플랫폼 = 수탁자. IP·UA는 해시만 저장 | `docs/products/local-news/01_PRD.md` 6절 |

## 4. 의존 관계

```text
코어(auth, org, entitlements, toss, encrypted_credentials, jobs, storage, audit, rate_limit, ai-gateway, Theming)
   ^
   |  모든 모듈이 사용
compliance(0150)  <---- 라벨·게시 가드 ---- editorial(0750), ads(0650), community(0350), notify(0100)
media(0250)       <---- 자산 참조 -------- editorial, ads, community(첨부, 확장)
membership(0550)  <---- 최종 이용자 ------ community(작성자), notify(구독자), editorial(접근 규칙 판정)
search(0450)      <---- 색인 요청(잡) ---- editorial, 제품 표(어댑터)
```

순환 금지: 위 화살표 방향으로만 import 한다. compliance·media는 다른 공용 모듈을 import 하지 않는다.

## 5. 다른 제품에 적용하는 방법 (요약)

자세한 절차는 `docs/develop/_shared/modules/README.md` 5장.

| 단계 | 할 일 |
|---|---|
| 1 | 1장 적용표에서 ●·○ 확인 → 제품 개발 착수 회의에서 채택 확정 |
| 2 | 그 제품 `06_AGENT_PLAN.md` 공용 모듈 요청 표에 소비 행 추가(모듈, 버전, 쓰는 기능 ID) |
| 3 | 모놀리스 제품은 모듈 SQL 변환본을 `supabase/migrations/`에 추가, 모듈러 통합은 조각(`0150_compliance.sql` 등) 적용 |
| 4 | `pnpm add @nomad/<모듈>@<버전>`, 제품 설정(`settings` 행, 초기화 옵션) 작성 |
| 5 | 제품 확장 표·어댑터(검색 색인 변환 등)만 제품 코드로 작성 |
| 6 | 모듈 계약 테스트 + 제품 E2E 녹색 확인 |

## 6. 결정 필요

| ID | 결정 | 선택지 | 권고 |
|---|---|---|---|
| CMX-1 | 공용화 시점 원칙 변경 | (a) 기존 원칙 유지: 첫 제품 안에서 만들고 두 번째 제품 때 꺼냄 (b) 이번 7개는 계약(이 문서들)을 먼저 정하고 첫 적용 제품이 처음부터 패키지로 만듦 | (b). 대표님 요청(모든 제품에 적용 가능한 모듈화)에 맞고, 계약이 정해져 있어 나중에 꺼내는 비용이 없다. 단 MVP 범위는 첫 제품이 실제로 쓰는 만큼만 |
| CMX-2 | 번호 재배정(2장) | 채택 / 기존 100 단위 유지 + 새 모듈은 별도 구간 | 채택. 조각 파일이 아직 없어 비용 0 |
| CMX-3 | 검색 엔진 | Postgres(PGroonga 또는 pg_trgm) / Meilisearch 등 외부 | Postgres 먼저([search](search.md) SR-D1) |
| CMX-4 | 최종 이용자 결제 수취 | 고객사 자기 Toss 가맹 / 플랫폼 일괄 수취 후 정산 | 고객사 자기 가맹(정산·전자금융업 부담 없음, [membership](membership.md) MB-D1) |
