# 01 PRD: FLORA Publishing

작성일 2026-10-12. 근거 표기: 리뷰는 `docs/reviews/<이름>.md:줄`, 분석은 `docs/products/00_MERGE_ANALYSIS.md:줄`(아래 "분석:줄"로 줄임), 원본은 저장소 루트 기준 경로. 원본·리뷰에 근거가 없는 수치는 "제안"으로 표시하고 이유를 적었다.

## 1. 페르소나와 핵심 과제

| 이름 | 상황 | 목표 | 좌절 | 근거 |
|---|---|---|---|---|
| 김서연(41, 에세이스트) | 블로그와 노트에 쓴 산문 원고가 100편 넘게 있다. 편집·조판 경험은 없다 | 원고를 B6 수필집 판형의 인쇄용 PDF로 묶어 소량 인쇄하고 ePub도 만든다 | 워드로 만든 PDF는 제본 여백이 없고, 무료 변환기는 한글이 깨지거나 쪽번호가 안 맞는다 | `Flora-v2/PRD.md:21`, `docs/reviews/Flora-v2.md:68`, `docs/reviews/SellingDocs.md:58` |
| 박준호(34, IT 실무자) | 사내 강의 자료를 실용서로 정리해 전자책 플랫폼에 등록하려 한다 | 키워드와 예상 독자만으로 목차를 받고, 챕터별 초안을 자동 생성한 뒤 다듬어 ePub으로 등록한다 | 생성형 AI 대화창으로는 책 한 권 분량이 중간에 끊기고, 챕터 사이 문체가 흔들린다 | `flora-publisher/frontend/docs/prd/02_user_flow.md:21-31`, `:56-60`, `docs/reviews/SellingDocs.md:51` |
| 이하은(27, 웹소설 지망생) | 단편 여러 편을 묶은 단편집을 만들고 싶다. 월 구독료는 1만 원 이하만 감당할 수 있다 | 페르소나 문체를 고르고, 막히는 문단만 AI에게 이어쓰기를 시킨 뒤 직접 고친다 | 고가 구독(월 ₩60,000~₩100,000)은 부담스럽고, 쓴 만큼만 내고 싶다 | `flora/PRD.md:48`, `Flora-v2/PRD.md:305-307`, 분석:228-231 |

| # | 핵심 과제 | 이 제품이 해결하는 방식 |
|---|---|---|
| J1 | 원고(또는 아이디어)를 책의 구조(챕터, 소제목, 단락)로 만든다 | 10단계 위저드(판형 → 장르 → 페르소나 → 제목 → 기획안 → 목차 → 집필 → 표지 → 책 정보 → 완성), 업로드 경로는 파싱 결과를 목차로 자동 매핑 |
| J2 | 판형에 맞는 인쇄용 PDF와 표준 ePub을 한 번에 얻는다 | WeasyPrint(CSS Paged Media) + Noto CJK 렌더 서비스, ePub3 빌더. 미리보기와 PDF가 같은 HTML 템플릿을 쓴다 |
| J3 | 문체가 일관된 원고를 끊기지 않고 끝까지 생성한다 | 페르소나 Taste를 서버에서 모든 호출에 주입, 전체 순차 생성은 서버 잡(섹션 단위 저장, 재시도 3회, 실패 섹션만 표시) |

## 2. 범위: MVP와 Phase

확정 결정 7 "출판: 전자책만"(분석:15)을 넘는 범위는 MVP에 넣지 않는다.

| 기능 | 범위 | 근거 |
|---|---|---|
| 인증, 조직, 세션, 라우트 보호 | MVP | 확정 결정 5, `docs/reviews/Flora-v2.md:61-62` |
| 10단계 전자책 위저드(판형, 장르, 페르소나, 제목, 기획안, 목차, 집필, 표지, 책 정보, 완성) | MVP | 확정 결정 7, `Flora-v2/PRD.md:41-56` |
| 원고 업로드 경로(txt, md, docx, pdf) | MVP | 분석:116-117. HWP는 열린 결정(8장) |
| 전체 순차 생성(서버 잡) | MVP | 분석:98 |
| 원고 에디터와 마이크로 프롬프트(이어쓰기, 살붙이기, 다듬기) | MVP | 분석:99 |
| PDF(WeasyPrint), ePub3 내보내기, 워터마크 서버 강제 | MVP | 분석:108, :111, :112 |
| AI 표지(fal, 3후보) | MVP | 분석:104 |
| 크레딧팩 + 저가 구독(Toss) | MVP | 확정 결정 4, 8 |
| 시드 3종 복제, 테마 7종, 진행바·Confetti | MVP | 분석:118, :121, :122 |
| 나만의 페르소나 합성(텍스트 샘플) | MVP(P1) | 분석:90 "프로 이상 기능" |
| 옴니버스(단편집) 모드 | MVP(P1) | 분석:97 "우선순위 낮음" |
| 아웃바운드 웹훅(`book.completed`, `export.*`) | MVP(P1) | 분석:139, :243 "자동화는 아웃바운드 웹훅 하나만" |
| 공개 책 페이지 + Book JSON-LD + GEO 랜딩 메타 | Phase 2 | 분석:114, :159, :269-273 |
| 번역 | Phase 2 | 분석:102 |
| 페르소나 합성의 음성 샘플 STT | Phase 2 | 분석:90. 음성 처리 비용과 동의 절차를 MVP에서 뺀다(제안) |
| 오디오북(보이스, 등장인물 추출, 멀티보이스) | Phase 2(엔진 결정 필요) | 분석:129-131, :245-249 |
| 판매·정산 | Phase 3 이후(결정 필요) | 분석:157, :269-273 |
| 사진집, 룩북, AI 캔버스, n8n, Typst, DOC | 폐기 | 분석:138-142, :109-110. `07_SOURCE_MIGRATION.md` 3절 |

## 3. 기능 요구사항과 수용 기준

ID 접두사 `PB`(`docs/products/_platform-core/DB_CONVENTIONS.md` 1장 SQLSTATE 접두사와 같다). "크레딧"은 4장 단가표를 따른다.

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| PB-F-001 | 가입/로그인 | 통합 | `@supabase/ssr` 브라우저 클라이언트의 `signInWithPassword`, `signUp({options:{data:{signup_app:'publishing'}}})`, Google OAuth. 이메일 인증 필수. 카카오는 열린 결정 | 가입 직후 `core.session_context('publishing')`이 `entitled=true`, `plan_code='free'`, `credit_balance=20`을 돌려준다. 로그인 후 `/dashboard`가 열리고 새로고침해도 유지된다 | 분석:74, `docs/reviews/Flora-v2.md:61`, `CORE_SPEC.md:70-80` |
| PB-F-002 | 콜백 리다이렉트 검증 | 디벨롭 | `/auth/callback`의 `next`는 `/`로 시작하고 `//`, `@`, `\`가 없는 경로만 허용 | `next=@evil.com`, `next=//evil.com` 요청은 `/dashboard`로 보낸다 | `docs/reviews/Flora-v2.md:71`, `:141` |
| PB-F-003 | API 인증 경계 | 디벨롭 | 모든 Route Handler는 `requireSession('publishing')`로 시작한다. 공개 예외는 `/api/waitlist`, `/api/webhooks/*`, `/health`뿐. FastAPI 엔진과 렌더 서비스는 공개 인터넷에서 호출되지 않고 내부 토큰을 요구한다 | 토큰 없이 LLM, 업로드, 내보내기 API를 호출하면 401. 엔진 내부 엔드포인트를 토큰 없이 호출하면 401 | `docs/reviews/Flora-v2.md:63`, `docs/reviews/flora.md:68`, `SHARED_MODULES.md:259` |
| PB-F-004 | 대기자 명단 | 유지(v2) | 출시 전 랜딩에서 이메일 수집. 실제 수만 표시하고 시드 수치를 넣지 않는다. IP당 5회/시간(제안: 스팸 방지 최소치) | 같은 이메일 2회 등록은 200 + "이미 등록됨". 카운트 API는 `publishing.waitlist` 행 수와 같다 | 분석:79, `docs/reviews/flora.md:82` |
| PB-F-005 | 운영자 화면 | 디벨롭 | `/admin`은 `profiles.platform_role='platform_admin'`만. 이메일 하드코딩 금지. 지표: 가입 수, 활성 책 수, 내보내기 수, 렌더 실패율, 크레딧 drift. 수동 크레딧 조정과 플랜 변경은 service_role 서버 경로 + 감사 로그 | 일반 사용자가 `/admin` 접근 시 404. 수동 조정 1건마다 `core.audit_log` 1행 | 분석:78, `docs/reviews/Flora-v2.md:89`, `SECURITY_BASELINE.md` 9장 |
| PB-F-006 | 위저드 10단계 | 통합 | v2 10단계 순서. 완료한 단계만 클릭 이동. 단계 진입 시 `books.current_step`, `step_state`를 2초 debounce로 저장 | 7단계에서 브라우저를 닫고 다시 열면 같은 책의 7단계가 열린다. `projectId='new'` 같은 공유 키가 없다 | `Flora-v2/PRD.md:41-56`, `docs/reviews/Flora-v2.md:79`, `Flora-v2/CLAUDE.md` "use-auto-save 2초" |
| PB-F-007 | 판형 선택 + Auto-Fit | 통합 | 6종 키(A6, B6, A5, shinkuk, B5, A4_variant), 판형별 본문 pt·행간·여백 프리셋, Auto-Fit 미세조정(본문 ±1pt, 여백 ±5mm, 제안). 안쪽 여백 > 바깥 여백 3~5mm 규칙은 미세조정 후에도 강제 | 미세조정으로 안쪽 여백이 바깥+3mm 미만이 되면 슬라이더가 멈추고 안내 문구가 뜬다. 같은 설정이 미리보기와 PDF에 같게 반영된다 | 분석:86, `Flora-v2/PRD.md:476-485`, `flora/PRD.md:179-189` |
| PB-F-008 | 장르 선택 | 유지 | 장르 8종(소설, 에세이, 시, 자기계발, 논픽션·비즈니스, IT·기술서, 동화, 판타지) | 선택한 장르가 `books.genre`에 저장되고 페르소나 탭 기본값이 된다 | `Flora-v2/PRD.md:65-68` |
| PB-F-009 | 페르소나 60종 | 디벨롭 | 60종을 JSON 단일 소스로 두고 프론트와 서버가 같은 파일을 읽는다. 실존 작가 이름 금지. Free는 40종, Basic은 60종(`features.personas`) | 60종 전부 서버 프롬프트에 문체 지시가 있다(빈 문자열 0건). Free 사용자가 41번째 이후 페르소나로 집필을 요청하면 403 | `docs/reviews/Flora-v2.md:77`, `Flora-v2/CLAUDE.md` "실존 작가 이름 절대 금지", `Flora-v2/PRD.md:312` |
| PB-F-010 | 페르소나 보관함/즐겨찾기 | 디벨롭 | 즐겨찾기(최대 60)와 최근 사용을 `publishing.member_settings`에 저장 | 다른 브라우저에서 로그인해도 즐겨찾기가 같다 | 분석:91 |
| PB-F-011 | 나만의 페르소나 합성 | 디벨롭(P1) | Basic 이상. 기준 페르소나 최대 3개 + 텍스트 샘플(최대 5,000자, 제안: 프롬프트 길이 상한)로 Taste 합성. 결과는 `custom_personas`에 서버가 저장 | Free에서 호출하면 403 `plan_required`. 합성 1회 3크레딧 차감, 실패 시 환불 행 1개 | 분석:90, `docs/reviews/Flora-v2.md:66` |
| PB-F-012 | 어조 슬라이더 | 유지(v1 이식) | 문장 길이, 어조, 리듬 3축 5단계. Basic 이상. 값은 `books.tone` | Free 화면에서 잠금 표시, API는 Free 요청의 tone 값을 무시하고 기본값을 쓴다 | 분석:92, `flora/PRD.md:48` |
| PB-F-013 | AI 제목 추천 | 유지 | 장르+페르소나+기획 방향으로 후보 3~5개(제목, 부제, 추천 이유). 직접 입력 가능 | 1회 1크레딧. 응답이 JSON 스키마를 어기면 1회 재시도 후 실패 + 환불 | `Flora-v2/PRD.md:76-80` |
| PB-F-014 | 기획안 3종 | 통합 | synopsis, logline, theme, characters + 입력 "타겟 독자", "강조 톤"(SD 6필드 중 2개). 탭 비교 후 1종 선택, 인라인 편집 | 선택본이 `books.plan_brief`에 저장된다. 1회 2크레딧 | 분석:94, `구현해야 할 프로젝트/SellingDocs/PRD.md:52` |
| PB-F-015 | 목차 3종 + 편집 | 통합 | 챕터 수(1~20), 소제목 수(챕터당 1~10), 단락 수(소제목당 1~5) 설정 → 목차 3종 → 선택 후 드래그 정렬·인라인 편집. 플랜 한도: Free 챕터 3·소제목 합계 6·단락 3 | Free 사용자가 4번째 챕터를 추가하면 DB가 `PB002`를 내고 화면에 "Free는 챕터 3개까지" 안내. 1회 2크레딧 | `Flora-v2/PRD.md:88-93`, 분석:95, `flora-publisher/frontend/docs/prd/02_user_flow.md:31` |
| PB-F-016 | 섹션 단건 집필 | 유지 | 소제목 1개를 스트리밍 생성(fetch POST + ReadableStream). 완료 시 서버가 sanitize 후 `sections.body_html` 저장 | 생성 중 연결이 끊겨도 서버가 끝까지 받아 저장하고, 다시 열면 본문이 보인다. fast 1크레딧, quality 2크레딧 | 분석:96, `docs/reviews/Flora-v2.md:105` |
| PB-F-017 | 전체 순차 생성 | 디벨롭 | Basic 이상. 서버 잡이 섹션 단위로 생성·저장. 책당 동시 3섹션, 섹션 재시도 3회(지수 백오프), 실패 섹션만 표시, 진행률은 Realtime. 이미 본문이 있는 섹션은 건너뛴다(덮어쓰기 옵션 별도). 취소 시 대기 섹션은 환불 | 15섹션 책에서 2개가 3회 실패하면 실행 상태 `partial`, 13개 저장, 2개 `failed`, 차감 = 성공 섹션분만(실패분 자동 환불). 취소 요청 후 60초 안에 새 섹션 생성이 멈춘다 | 분석:98, `flora-publisher/frontend/docs/prd/03_features.md:83-97`, `docs/reviews/Flora-v2.md:67`, `:122` |
| PB-F-018 | 원고 에디터 + 마이크로 프롬프트 | 디벨롭 | Tiptap. 선택영역 플로팅 툴바(이어쓰기, 살붙이기, 다듬기, 직접 명령), `/` 명령, 결과 Diff 카드(삽입/대체/재생성/취소). 저장 HTML은 서버 sanitize(허용 태그 목록) | `<script>`, `on*` 속성, `javascript:` 링크가 저장 후 사라진다. 선택영역 2,000자 초과는 청크로 나뉜다. 1회 1크레딧 | 분석:99, `flora-publisher/frontend/docs/prd/03_features.md:110-131`, `docs/reviews/SellingDocs.md:55` |
| PB-F-019 | 전체 다듬기 | 통합 | v1 "AI 고도화"를 대체. 원고 전체를 2,000자 청크로 나눠 순서대로 다듬고, 섹션별 Diff로 수락/거절. Basic 이상 | 3만 자 원고 → 15청크 처리, 마지막 1,000자만 처리되는 결함이 재현되지 않는다(청크 수 = 결과 수). 청크당 1크레딧 | 분석:100, `docs/reviews/flora.md:77` |
| PB-F-020 | 옴니버스 모드 | 유지(v1 이식, P1) | 집필 옵션 하나. 챕터를 독립 단편으로 보고 앞 챕터 요약을 프롬프트에 넣지 않는다 | 옵션을 켠 책의 섹션 생성 요청에 이전 챕터 요약이 포함되지 않는다(서버 로그 확인) | 분석:97, `flora/api/routers/llm.py:298`, `:472` |
| PB-F-021 | AI 표지 | 통합 | 스타일 5종, 3후보 동시 생성(fal 비동기 + 웹훅), 결과를 Storage `org-files`로 복사, 제목·저자 오버레이는 HTML/CSS로 렌더(이미지에 글자를 굽지 않음). 안전 필터 켬 | 3후보 6크레딧. 1장이라도 실패하면 실패분만 환불. 후보 선택 시 `books.cover_image_id` 저장, 다른 책의 표지 id는 `PB006` | 분석:104, `SHARED_MODULES.md:228-249` |
| PB-F-022 | 책 정보 생성 | 디벨롭 | 서버가 DB에서 제목, 기획안, 원고 앞 3,000자(제안: 토큰 비용 상한)를 읽어 부제, 키워드 5개, 소개글 200자, 출판사, ISBN 형식(참조용)을 생성 | ISBN 칸 옆에 "형식 참조용이며 실제 등록 번호가 아닙니다" 고지. 원고가 없는 책은 409 `manuscript_empty`. 1회 1크레딧 | 분석:105, `docs/reviews/Flora-v2.md:78`, `Flora-v2/PRD.md:115` |
| PB-F-023 | HTML 조립과 미리보기 | 통합 | 서버(FastAPI 엔진)가 DB 원고를 읽어 v1 템플릿으로 HTML 조립(병합 포함). 모든 텍스트 escape, 본문 HTML 재-sanitize. 미리보기 iframe은 sandbox + 같은 HTML | 미리보기 첫 3쪽과 PDF 첫 3쪽의 줄바꿈 위치가 같다(판형 6종 골든 테스트) | 분석:106-107, :113, `docs/reviews/flora.md:78` |
| PB-F-024 | PDF 내보내기 | 통합 | 렌더 잡(`render.pdf`) → WeasyPrint 서비스 → Storage `exports`. `@page` 판형, `:left/:right` 제책 여백, `:first` 표지 무쪽번호, `counter(page)` 쪽번호, `string-set` 러닝 헤더, 점선 목차, `orphans/widows 2`. 같은 원고·설정(content_hash)의 7일 내 재요청은 재과금 없이 기존 파일 | 한글 본문 200쪽 PDF가 120초 안에 생성되고 두부 문자 0개. 2크레딧. 실패 시 환불 행 1개 | 분석:108, `WeasyPrint - CSS Paged Media 명세.md:13-125`, `SHARED_MODULES.md:251-275` |
| PB-F-025 | ePub3 내보내기 | 통합 | v1 ePub3 빌더 이식. XML escape, 식별자 uuid5(책 id 기반), 표지 바이너리 포함, nav 문서, 한글 폰트 임베딩(라이선스 허용 폰트만) | epubcheck 오류 0건. 같은 책 2회 내보내기의 `dc:identifier`가 같다. 1크레딧 | 분석:111, `docs/reviews/flora.md:93` |
| PB-F-026 | 워터마크 강제 | 디벨롭 | 서버가 `features.watermark`를 읽어 렌더 옵션을 결정. 클라이언트 파라미터 무시. Free는 월 내보내기 2회(`exports_per_month`) | Free 계정이 `watermark=false`로 요청해도 PDF 모든 쪽에 워터마크. 3번째 내보내기는 403 `plan_limit` | 분석:112, `docs/products/_supabase-modular/seed.sql:33` |
| PB-F-027 | 원고 업로드 | 디벨롭 | 서명 업로드 URL로 Storage `org-files`에 직접 업로드 → 완료 통지 → 서버가 크기(20MB)·MIME·매직바이트 재검사 → 파싱 잡. 경로는 서버 생성 `<org>/publishing/manuscripts/<uuid>.<ext>`, 원래 파일명은 표시용만 | 25MB 파일은 413, 확장자를 바꾼 실행 파일은 415. 파싱 결과 챕터·소제목 목록이 60초 안에 보인다. 원본 파일은 파싱 24시간 뒤 삭제 | 분석:116, `docs/reviews/Flora-v2.md:66`, `:75`, `SECURITY_BASELINE.md` 10장 |
| PB-F-028 | 업로드 후 기획 검토 | 유지(v2) | 파싱 구조를 목차로 매핑하고 제목·기획안을 간소화 제안(4·5단계 축약) | 업로드 책의 6단계 목차가 파싱 구조와 같다. 7단계에 원문이 보인다 | 분석:117, `Flora-v2/PRD.md:139-150` |
| PB-F-029 | 시드 3종 복제 | 유지(v2) | 시드 원고 3종을 서버가 새 책으로 복제(`source='seed'`). 크레딧 없음 | 복제한 책이 내 책 목록에 생기고 Free 한도(3권)에 포함된다 | 분석:118, `Flora-v2/PRD.md:252-258` |
| PB-F-030 | 책 목록과 자동 저장 | 통합 | 목록(최근 수정순, 상태 필터), 소프트 삭제(휴지통 30일), 자동 저장은 DB 2초 debounce 하나 | 휴지통의 책은 30일 뒤 영구 삭제. localStorage 초안은 오프라인 임시본으로만 쓰고 서버 값이 우선 | 분석:119-120, `docs/reviews/flora.md:97` |
| PB-F-031 | 진행바와 완성 연출 | 유지(v2) | 원형 10단계 진행바, 완성 시 Confetti 1회(`prefers-reduced-motion`이면 생략) | 감소 모션 설정에서 Confetti가 실행되지 않는다 | 분석:121, `Flora-v2/DESIGN.md` 3.1절 |
| PB-F-032 | 화면 테마 7종 | 유지(v2) | 3종 basic, 4종 pro. 잠금은 DB 트리거가 강제 | Free가 Pro 테마를 저장하면 `PB008` | 분석:122, `Flora-v2/PRD.md:227-237` |
| PB-F-033 | Taste-Skill 서버 합성 | 디벨롭 | 프롬프트 합성(Taste + Skill + 어조)을 서버 한 곳에서. Taste는 집필 시작 후 잠금 | `status <> 'draft'`인 책의 페르소나 변경은 `PB011` | 분석:123, `Flora-v2/PRD.md:223-225` |
| PB-F-034 | 플랜·크레딧 서버 강제 | 신규 | 모든 유료 동작은 코어 선차감-환불 시퀀스. 기능 게이팅은 `features`를 서버가 해석. 클라이언트 잠금은 UX 보조 | 브라우저 콘솔에서 `rpc('grant_credits')`, `update app_entitlements`가 42501. 잔액 부족은 402와 필요량 표시 | 분석:149, `CORE_SPEC.md:172-183` |
| PB-F-035 | 결제 | 통합 | Toss 일반결제(크레딧팩, 첫 구독)와 빌링키 정기결제. 주문 선저장, 서버 confirm, 금액 대조, 웹훅은 보조 | 테스트 키로 팩 결제 → 원장 grant 1행. 같은 confirm 2회 → 지급 1회. 위조 웹훅 → 401 | 분석:151, `CORE_SPEC.md:210-233` |
| PB-F-036 | 아웃바운드 웹훅 | 디벨롭(P1) | 사용자 등록 HTTPS URL(조직당 5개, 제안)로 `book.completed`, `export.succeeded`, `export.failed`를 HMAC 서명 POST. 비밀은 `core.encrypted_credentials`. 5회 실패 후 `failing`, 20회 연속 실패 시 `disabled`(제안) | 수신 측이 `X-Signature`로 검증 가능. 사설 IP·localhost URL 등록은 422 | 분석:139, `SHARED_MODULES.md:160-172` |
| PB-F-037 | 랜딩 | 통합 | v2 랜딩 구조 + v1 히어로 연출 1회. 03장 4절 방향. 금지 문구 통과 | 랜딩에 검증되지 않은 사용자 수·후기 0건 | 분석:158, `docs/reviews/flora.md:82` |
| PB-F-038 | 탈퇴와 데이터 삭제 | 신규 | 설정 → 계정 삭제: 확인 문구 입력 → 조직 soft delete → 30일 유예 → `purge_organization`. 유예 중 로그인하면 복구 버튼. 내보내기 파일과 업로드는 즉시 삭제 예약 | 삭제 요청 후 30일 뒤 조직의 모든 publishing 행 0개, Storage 객체 0개 | 분석:217, `SECURITY_BASELINE.md` 12장 |
| PB-F-039 | 법무 페이지 | 신규 | 이용약관, 개인정보처리방침, 환불 규정, AI 생성물 안내, 사업자 정보(통신판매업 신고) | 랜딩·결제 화면 하단에서 5개 페이지 모두 1클릭 | 분석:214 |
| PB-F-040 | 공개 책 페이지 | 디벨롭(Phase 2) | 완성된 책만, owner/admin이 `set_book_visibility`로 켬. `/b/[slug]`에 표지·소개·목차·Book JSON-LD. 본문은 미리보기 1장까지만(제안: 판매 기능 결정 전 전문 공개 방지) | 미완성 책 공개 시 `PB009`. anon은 공개 컬럼만 조회 | 분석:114, :159, `docs/reviews/SellingDocs.md:52` |
| PB-F-041 | 번역 | 유지(Phase 2) | 완성 원고를 영어·일본어로 번역해 별도 책으로 복제 | Phase 2 기획에서 단가 확정 | 분석:102 |
| PB-F-042 | 오디오북 | 디벨롭(Phase 2) | TTS 엔진 결정 후 기획. 산출물은 Storage + 서명 URL | 해당 없음(Phase 2) | 분석:129-131, :245-249 |
| PB-F-043 | 운영 기반 | 디벨롭 | 필수 환경변수 누락 시 기동 실패, Dockerfile(pango, cairo, Noto CJK), CI(tsc, lint, build, pytest, SQL 체커, RLS 스모크) | 빈 `SUPABASE_JWT_SECRET`이나 `RENDER_SERVICE_TOKEN`으로 엔진이 기동하지 않는다. main 브랜치 CI 녹색 | 분석:160, :216, `docs/reviews/Flora-v2.md:132-133` |

## 4. 요금과 크레딧

### 4.1 플랜 (정본 출처: 확정 결정 8 "크레딧팩 + 저가 구독")

금액·크레딧은 모듈러 seed 샘플(`docs/products/_supabase-modular/seed.sql:33`, `:95`, `:100-101`)과 같게 두었다. 저가 구독 ₩9,900은 FP 기획의 NOMAD PRO 가격(`flora-publisher/frontend/docs/prd/02_user_flow.md:65`)이 근거다. 월 크레딧 수치는 제안이며 이유는 4.3절에 적었다.

| 코드 | 이름 | 월 가격 | 월 크레딧(plan 버킷) | 가입 크레딧 | 이월 | 주요 features |
|---|---|---|---|---|---|---|
| `free` | Free(기본) | ₩0 | 20 | 0(첫 달 20이 가입 시 지급) | 없음 | 워터마크, 월 내보내기 2회, 책 3권, 챕터 3, 소제목 6, 단락 3, 페르소나 40, fast 모드만 |
| `basic` | Basic | ₩9,900 | 200 | 0 | 없음(남은 plan 크레딧은 갱신 시 만료) | 워터마크 없음, 내보내기 무제한, 책 무제한, 챕터 20, 소제목 200, 단락 5, 페르소나 60, 전체 순차 생성, 업로드, 어조, 보조 집필, quality 모드, 페르소나 합성, 웹훅, 공개 페이지(Phase 2) |

### 4.2 크레딧팩 (pack 버킷, 소멸 없음)

| 코드 | 크레딧 | 가격 | 크레딧당 | 근거 |
|---|---|---|---|---|
| `pack_100` | 100 | ₩9,900 | ₩99 | 모듈러 seed 샘플(`seed.sql:100`) |
| `pack_500` | 500 | ₩39,900 | ₩79.8 | 모듈러 seed 샘플(`seed.sql:101`) |

차감 순서는 plan 버킷 → pack 버킷(`CORE_SPEC.md:168`). 팩 크레딧은 Free 사용자도 살 수 있다(쓴 만큼만 내는 페르소나 이하은의 요구).

### 4.3 크레딧 단가 (전부 제안)

| 작업 | 크레딧 | 단위 | 이유 |
|---|---|---|---|
| 제목 추천 | 1 | 1회(3~5후보) | 짧은 출력 |
| 기획안 3종 | 2 | 1회 | 3안 동시 생성 |
| 목차 3종 | 2 | 1회 | 3안 동시 생성 |
| 섹션 집필 fast | 1 | 소제목 1개 | 원고 생성의 기본 단위. SD 리뷰가 "단계별 단가 분리"를 요구(`docs/reviews/SellingDocs.md:72`) |
| 섹션 집필 quality | 2 | 소제목 1개 | 상위 모델 비용 |
| 이어쓰기/살붙이기/다듬기 | 1 | 선택영역 2,000자 청크 | 청크 단위로 비용 비례 |
| 전체 다듬기 | 1 | 2,000자 청크 | 위와 같음 |
| 책 정보 생성 | 1 | 1회 | 짧은 출력 |
| 페르소나 합성 | 3 | 1회 | 샘플 분석 + 합성 2단계 |
| 표지 3후보 | 6 | 1회(장당 2) | 이미지 생성 원가가 텍스트보다 높음 |
| PDF 내보내기 | 2 | 1회 | 렌더 컨테이너 CPU 시간 |
| ePub 내보내기 | 1 | 1회 | 렌더보다 가벼움 |
| 같은 content_hash 재내보내기(7일 내) | 0 | - | 같은 파일 재사용 |
| 원고 업로드 파싱, 시드 복제, 미리보기 | 0 | - | LLM 비용 없음. 미리보기는 레이트 리밋으로 보호 |

검산: Free 한도(챕터 3, 소제목 6)로 책 1권 = 제목 1 + 기획 2 + 목차 2 + 섹션 6 + 표지 6 + 정보 1 + PDF 2 = 20크레딧. Free 월 20크레딧으로 작은 책 1권을 끝까지 만들 수 있다(체험 목적). 5챕터 x 3소제목 책은 약 30크레딧이므로 Basic 200크레딧으로 월 6권 안팎을 만든다. 단가와 월 크레딧은 출시 전 실제 토큰 원가로 재검증한다(06장 PB-06-008).

### 4.4 `core.plans.features` 키 해석 (서버만 읽는다, `DB_CONVENTIONS.md` 11장)

키가 없으면 "기본값" 열(= Free 값)로 해석한다. 모듈러 seed에는 `watermark`, `exports_per_month`, `themes`, `persona_blend`만 있으므로 나머지는 기본값이 적용된다(06장 6절 코어 요청).

| 키 | 타입 | 기본값 | 의미 | 강제 위치 |
|---|---|---|---|---|
| `watermark` | boolean | true | PDF/ePub 워터마크 | 렌더 잡 옵션(서버) |
| `exports_per_month` | integer | 2 | 월 내보내기 횟수(-1 무제한). KST 달력 월 기준 succeeded+진행 중 건수 | 내보내기 Route Handler |
| `themes` | text[] | `["basic"]` | 화면 테마 그룹 | `member_settings` 트리거(`PB008`) |
| `max_books` | integer | 3 | 삭제되지 않은 책 수 | `books` INSERT 트리거(`PB001`) |
| `max_chapters` | integer | 3 | 책당 챕터 수 | `chapters` INSERT 트리거(`PB002`) |
| `max_sections` | integer | 6 | 책당 소제목 합계 | `sections` INSERT 트리거(`PB003`) |
| `max_paragraphs` | integer | 3 | 소제목당 단락 목표 | `sections` 트리거(`PB004`) |
| `personas` | integer | 40 | 사용 가능 페르소나 수(카탈로그 앞에서부터) | LLM Route Handler |
| `write_all` | boolean | false | 전체 순차 생성 | Route Handler |
| `upload` | boolean | false | 원고 업로드 | Route Handler |
| `tone_slider` | boolean | false | 어조 슬라이더 반영 | 프롬프트 합성 |
| `writing_assist` | boolean | false | 이어쓰기/살붙이기/다듬기, 전체 다듬기 | Route Handler |
| `quality_mode` | boolean | false | quality 모드 선택 | LLM 게이트웨이 호출 전 |
| `persona_blend` | boolean | false | 나만의 페르소나 합성 | Route Handler |
| `webhooks` | boolean | false | 아웃바운드 웹훅 등록 | Route Handler |
| `public_page` | boolean | false | 공개 책 페이지(Phase 2) | `set_book_visibility`(`PB009`) |

### 4.5 환불 규정 (제안, 법무 검토 필요)

| 대상 | 규칙 | 근거 |
|---|---|---|
| 크레딧팩 | 결제 후 7일 이내이고 해당 팩 크레딧을 쓰지 않았으면 전액 환불. 일부라도 쓰면 환불 불가(디지털 콘텐츠 제공 개시) | 전자상거래법 청약철회 7일(미확인: 디지털 콘텐츠 예외 적용 요건은 법무 확인) |
| Basic 구독 | 결제 후 7일 이내이고 그 달 plan 크레딧 사용 0이면 전액 환불. 그 외에는 해지 예약(기간 말까지 이용) | 제안 |
| 서비스 장애 | 생성·렌더 실패는 자동 환불(코어 `fail_job`). 장애로 인한 손실은 운영자가 원장 adjust로 복원 | `CORE_SPEC.md:180`, `:237` |
| 처리 | Toss 취소 API → `payments` 갱신 → 미사용 크레딧 회수(원장 adjust) → 감사 로그 | `CORE_SPEC.md` 5.4 |

## 5. 비기능 요구사항

| 항목 | 목표 | 근거 |
|---|---|---|
| 동기 LLM(제목, 기획안, 목차, 책 정보) | p95 30초 이내 완료, 타임아웃 60초, 폴백 1회 | `SHARED_MODULES.md:207` |
| 섹션 단건 스트리밍 | 첫 토큰 p95 5초, 완료 p95 90초 | 제안: Vercel 함수 최대 실행 시간 안에 끝나야 함 |
| 전체 순차 생성 | 책당 동시 3섹션, 섹션 재시도 3회, 하트비트 30초, 무응답 10분이면 회수 | 분석:98, `CORE_SPEC.md:304` |
| PDF 렌더 | 200쪽 p95 60초, 타임아웃 120초, 렌더 서비스 동시 4건(제안: 컨테이너 2vCPU 기준) | `SHARED_MODULES.md:261` |
| ePub 생성 | p95 30초 | 제안 |
| 업로드 | 파일 20MB 상한, 형식 txt/md/docx/pdf, 파싱 p95 60초 | 분석:116 |
| 원고 크기 | 섹션 본문 200KB, 책당 소제목 200(Basic), 챕터 20, 소제목/챕터 10, 단락/소제목 5 | `Flora-v2/PRD.md:90`, 제안(DB CHECK) |
| 자동 저장 | 2초 debounce, 저장 실패 시 3회 재시도 후 배너 | `Flora-v2/CLAUDE.md` use-auto-save |
| 레이트 리밋 | 생성 API 조직당 60회/분, 로그인 IP당 10회/10분, 웹훅 수신 600회/분, 대기자 IP당 5회/시간, 미리보기 조직당 30회/분 | `SECURITY_BASELINE.md` 8장, 제안(대기자·미리보기) |
| 파일 보존 | 내보내기 파일 30일(서명 URL 7일, 만료 후 같은 해시면 재생성 무료), 업로드 원본은 파싱 24시간 뒤 삭제(파싱 결과는 책과 함께), 표지는 책과 함께 | `CORE_SPEC.md:317`, 제안 |
| 삭제 | 책 휴지통 30일, 조직 탈퇴 유예 30일 → purge | `SECURITY_BASELINE.md` 12장 |
| 감사 로그 보존 | 2년 | `CORE_SPEC.md:330` |
| 가용성 | 월 99.5%(Vercel + Railway + Supabase 합산) | 제안 |
| 한글 폰트 | PDF는 Noto Serif CJK KR / Noto Sans CJK KR 임베딩, ePub은 OFL 폰트만 포함 | 분석:215 |

## 6. 법, 개인정보, 금지 문구

| 항목 | 내용 |
|---|---|
| 개인정보 수집 항목 | 이메일, 표시 이름, 비밀번호 해시(Supabase Auth), Google 계정 식별자, 결제 정보(Toss가 보관, 우리는 주문 id·금액·카드사·마스킹 번호만), 원고와 생성물, 접속 IP 해시(레이트 리밋, 원문 저장 안 함), 대기자 이메일 |
| 목적 | 계정 운영, 책 제작 기능 제공, 결제와 환불, 부정 사용 방지, 출시 알림(대기자, 마케팅 동의 시에만) |
| 보존 | 회원 정보는 탈퇴 후 30일 유예 뒤 삭제. 결제 기록은 전자상거래법상 5년(미확인: 적용 조항은 법무 확인). 업로드 원본 24시간, 내보내기 파일 30일, 감사 로그 2년, 대기자 이메일은 출시 후 90일 또는 수신 거부 시 삭제(제안) |
| 암호화 대상 | 아웃바운드 웹훅 서명 비밀은 `core.encrypted_credentials`(AES-256-GCM). 빌링키는 `core.billing_keys`. 원고는 Supabase 저장 암호화에 맡기고 컬럼 암호화는 하지 않는다(제안: 원고는 검색·렌더 대상이라 앱 계층 암호화 시 기능 손실) |
| 삭제 절차 | 책: soft delete(`deleted_at`) → 30일 뒤 purge 잡. 조직: soft delete → 30일 → `purge_organization` + Storage 폴더 삭제 |
| 제3자 제공(국외 이전 포함) | LLM 제공자(Anthropic, OpenRouter 경유 모델): 프롬프트에 원고 일부, 기획안, 페르소나 지시를 보낸다. 이미지 제공자(fal): 표지 프롬프트(제목·장르·스타일)만 보내고 원고 본문은 보내지 않는다. Toss: 결제 정보. 처리방침에 제공자, 항목, 국가, 보유 기간을 표로 고지. 각 제공자의 학습 사용 여부 정책은 미확인이며 계약 전 확인 |
| 약관/고지 | 이용약관, 개인정보처리방침, 환불 규정(4.5절), 사업자 정보(상호, 대표, 사업자등록번호, 통신판매업 신고번호, 주소)를 하단에 표시 |
| AI 생성물 안내 | 생성물의 권리와 책임은 이용자에게 있고, AI 생성물은 저작권 보호가 제한될 수 있으며 타인의 저작물과 유사할 수 있음을 생성 화면과 약관에 고지. 실존 작가 이름을 페르소나로 쓰지 않는다(`Flora-v2/CLAUDE.md` 페르소나 규칙). 업로드 원고는 이용자가 권리를 가진 것만 올리도록 업로드 화면에서 확인 체크 |
| AI 생성 표시 | 내보낸 PDF/ePub 판권면(마지막 쪽)에 "이 책의 일부는 AI 도구(FLORA Publishing)로 작성·편집되었습니다" 문구를 기본으로 넣고 이용자가 끌 수 있다(제안: 표시 의무 법제화 여부 미확인, 자율 표시로 시작) |
| ISBN | 9단계 ISBN은 형식 참조용이며 실제 등록 번호가 아님을 고지. 실제 ISBN은 국립중앙도서관 서지정보유통지원시스템에서 발급받아야 함을 안내(미확인: 절차 링크는 구현 시 확인) |
| 제휴/광고 | 해당 없음. 이 제품은 affiliate 모듈을 쓰지 않는다(`SHARED_MODULES.md:44`) |
| 플랫폼 약관 | 외부 플랫폼 자동 업로드가 없다. 아웃바운드 웹훅은 이용자가 등록한 URL로만 보낸다. 전자책 플랫폼 등록 규격(ePub 검증)은 이용자 책임이며 epubcheck 결과를 보여 준다 |
| 금지 문구(마케팅) | 가상 후기(존재하지 않는 작가 후기·평점), 허위 수치(검증되지 않은 사용자 수·출간 수·대기자 수, 원본의 시드 카운트 147 같은 값, `docs/reviews/flora.md:82`), 보장 표현("베스트셀러 보장", "100% 출간", "수익 보장"), 타사 상표 오용(교보문고, 리디, 크레마 등의 로고·이름을 제휴처럼 쓰는 것), "인쇄소 수준 보장" 같은 품질 단정 |
| 금지 문구(생성 콘텐츠) | 실존 인물 사칭 문체 지시, 의료·금융 단정 표현은 이용자 원고의 책임이지만 기본 시스템 프롬프트가 생성하지 않도록 지시한다. 표지 이미지 안전 필터를 끄지 않는다 |
| 규제 특례 | 해당 없음(의료·금융·미성년자 특화 없음). 만 14세 미만 가입 제한(제안: 법정대리인 동의 절차를 만들지 않기 위해) |

## 7. KPI

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| 10단계 완성률 | 60% 이상 | `books`에서 `writing_started_at`이 있는 책 중 `completed_at`이 있는 비율 | 출시 후 90일 | 
| PDF/ePub 내보내기 완료율 | 70% 이상 | `book_exports.status='succeeded'` / 요청 수 | 월간 |
| 원고 업로드 경로 사용률 | 30% 이상 | `books.source='upload'` 비율 | 월간 |
| 전체 순차 생성 사용률(Basic) | 70% 이상 | Basic 조직 중 `generation_runs.kind='write_all'` 1회 이상 비율 | 월간 |
| Free → Basic 또는 팩 구매 전환율 | 8% | 가입 후 60일 안에 첫 결제한 조직 비율 | 코호트 60일 |
| 렌더 실패율 | 2% 미만 | `book_exports.status='failed'` / 전체 | 주간 |
| 크레딧 원장 drift | 0 | `core.credit_ledger_reconciliation` | 매일 |
| 대기자 명단 | 출시 전 1,000명 | `publishing.waitlist` 행 수 | 출시 전 |

근거: 첫 4개와 대기자 목표는 `Flora-v2/PRD.md:536-547`, 전환율은 v2 "프리 → 기본 8%"(`:539`)를 2단 플랜에 맞춰 옮김. 렌더 실패율·drift는 제안.

## 8. 열린 결정

| # | 항목 | 선택지 | 권고 | 근거 |
|---|---|---|---|---|
| D1 | 확정 결정 3의 FastAPI 범위 | (a) LLM 라우터까지 FastAPI(v2 방식) (b) LLM·크레딧·결제는 Next(공용 TS 모듈), FastAPI는 파싱·HTML 조립·ePub·렌더 호출 엔진 | (b). LLM 게이트웨이·크레딧·Toss·잡 공용 모듈이 TS 패키지라 Python에서 다시 만들면 재정의 금지 위반(`SHARED_MODULES.md:11-16`, `:469-474`). Python 자산(pdfplumber, docx 파서, ePub3, WeasyPrint)은 엔진에 남긴다 | 확정 결정 3, 분석:221-225 |
| D2 | TTS 엔진(Phase 2) | (a) F5-TTS GPU 자체 배포 (b) 외부 TTS API (c) 오디오북 제외 | (b) | 분석:245-249 |
| D3 | 판형 프리셋 값 충돌(A5 v1 10.5pt/20mm vs v2 9.5pt/18mm) | (a) v2 값 (b) v1 값 (c) v2 키 + 실물 출력 테스트로 확정 | (c). 확정 전 임시값은 v2 값 | 분석:257-261 |
| D4 | 업로드 형식 | (a) txt, md, docx, pdf, hwp (b) hwp 제외 (c) txt, md, docx만 | (b). DB CHECK도 hwp를 뺐다 | 분석:263-267, `docs/reviews/Flora-v2.md:76` |
| D5 | 판매·유통 | (a) 없음 (b) 공개 책 페이지만(Phase 2) (c) 판매·정산 | (b) | 분석:269-273 |
| D6 | 카카오 로그인 | (a) 이메일 + Google (b) 카카오 추가 | (a)로 시작 | 분석:275-279 |
| D7 | LLM 전략 | 공용 LLM 게이트웨이가 "Anthropic + OpenRouter 폴백, 2모드 노출"로 이미 정해져 있다(`SHARED_MODULES.md:204`) | 분석 권고 (c)를 그대로 따른다. 사용자 확인만 필요 | 분석:251-255 |
| D8 | 크레딧 단가·월 크레딧 | 4.3절 제안값 | 출시 전 실제 토큰 원가로 재산정 | 제안 |
| D9 | Free의 업로드·전체 생성 허용 | (a) v2처럼 막음 (b) 크레딧이 비용을 막으므로 허용 | (a)로 시작(유료 전환 동기). 업로드 사용률 KPI가 목표 미달이면 (b) | `Flora-v2/PRD.md:313-314` |
| D10 | 모놀리스 스키마 | `public`(코어 lite와 같음) | 사용자 최종 확인 대기 | 작업 지시, `MONOLITH_CORE_LITE.sql:5` |
| D11 | 표지 이미지 모델 | fal 안의 모델 1~2개 | 출시 전 한글 제목 없는 표지 품질 비교 후 1개 | 분석:104 "제공자는 1~2개로 축소" |
