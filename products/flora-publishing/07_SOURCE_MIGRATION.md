# 07 원본 이식과 폐기: FLORA Publishing

AI 관련 원본 자산(2026-10-13 점검): 원본의 AI 사용은 v1·v2의 `call_llm`/OpenRouter 폴백 호출과 Taste 14종 프롬프트(`flora/api/routers/llm.py`, `Flora-v2/api/services/llm.py`), v1 표지 제공자 7종(`cover.py`), v1 `tts.py`와 `f5-tts/`, FP의 Vertex 프록시, SD의 LLM 4사 SDK 연동이다. 이 중 프롬프트 텍스트와 Taste만 이식하고 호출 경로는 모두 ai-service 라우터(확정 결정 17)로 대체한다. RAG, 책 설정집 위키, Dify, 받아쓰기, 낭독, 3D 히어로는 원본에 없어 모두 신규다. 아래 표의 AI 행이 이 자산들의 대응이다.

작성일 2026-10-12. 원본 폴더는 수정하지 않았다. 이식은 개발 단계에서 새 저장소로 "복사 후 수정"하며, 원본은 5절 절차로 아카이브한다. 분석 근거는 `docs/products/00_MERGE_ANALYSIS.md`의 줄 번호이며, 아래에서는 "분석:줄번호"로 줄여 쓴다.

## 1. 원본별 자산 분류

### 1.1 Flora-v2 (베이스)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `frontend/src/components/ebook/*`(진행바, 판형·장르·제목·기획안·책정보·완성 화면) | 부분 | 이식 | `web/src/features/wizard/` | `docs/reviews/Flora-v2.md:25`, 분석:85 |
| `frontend/src/components/project/chapter-wizard.tsx`, `persona-card-grid.tsx`, `cover-generator.tsx`, `writing-editor.tsx`, `auto-fit-panel.tsx`, `upload-plan-review.tsx` | 부분 | 이식(계약 수정) | `web/src/features/wizard/`, `editor/` | 분석:95, :117 |
| `frontend/src/lib/personas.ts`(724줄) | 동작 | 이식(JSON 변환) | `web/src/data/personas.json` | `docs/reviews/Flora-v2.md:116` |
| `frontend/src/lib/auto-fit/auto-fit-presets.ts`(128줄) | 동작 | 이식(키와 임시값) | `web/src/data/formats.json` | 분석:86 |
| `frontend/src/lib/theme/theme-config.ts`(168줄) | 동작 | 이식 | `web/src/data/themes.json` | 분석:122 |
| `frontend/src/lib/seeds/seed-projects.ts` | 동작 | 이식 | `web/src/data/seeds/` | 분석:118 |
| `frontend/src/lib/plan/plan-limits.ts`(119줄) | 기획만(클라이언트) | 참고(features 키 설계) | `01_PRD.md` 4.4절 | 분석:231 |
| `frontend/src/proxy.ts`(50줄) | 부분 | 참고(코어 auth 골격으로 대체) | `web/src/proxy.ts` | 분석:75 |
| `frontend/src/app/page.tsx`(랜딩 101줄) | 동작 | 참고 | `web/src/app/(marketing)/` | 분석:158 |
| `api/services/llm.py`(Taste 14종), `api/routers/llm.py`(344줄) 프롬프트 | 부분 | 참고(프롬프트 텍스트만 언어 중립 파일로 이식) | `api/app/ai/products/publishing/prompts/` | 01장 D1, D13 |
| `api/routers/upload.py` 파서(txt, md, docx, pdf) | 부분 | 이식(계약·한도 수정) | `engine/app/parsers/` | 분석:116 |
| `api/routers/upload.py` HWP 파서 | 부분(깨짐) | 폐기(결정 D4 전까지) | - | `docs/reviews/Flora-v2.md:76` |
| `api/routers/books.py` merge | 동작 | 이식(엔진 HTML 조립에 흡수) | `engine/app/html/` | 분석:106 |
| `api/routers/export.py` 수제 ePub2, fpdf2 | 부분 | 폐기 | - | D-29, D-22 |
| `api/routers/cover.py`, `tts.py`, `automation.py`, `billing.py`, `waitlist.py` | 목업/부분 | 폐기(waitlist는 설계만 유지) | - | 3절 |
| `supabase/migrations/001~003` | 부분 | 참고(컬럼 이름) | `1000_publishing.sql` | 05장 |
| `PRD.md`, `DESIGN.md`, `CLAUDE.md`, `SKILL.md` | 기획 | 참고 | 01~03장 | - |

### 1.2 flora (v1)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `api/routers/export.py` `build_epub`(ePub3, `:56`) | 동작 | 이식(escape, uuid5) | `engine/app/epub/` | `docs/reviews/flora.md:93` |
| `api/routers/export.py` `_try_weasyprint`, `build_pdf_from_html`(`:195-256`) | 동작 | 참고(렌더 서비스로 재작성) | `services/render-weasyprint/` | 분석:108 |
| `api/routers/export.py` `content_disposition`(RFC 5987 한글 파일명, `:15`) | 동작 | 이식 | `web/src/app/api/exports/` | `docs/reviews/flora.md:169` |
| `frontend/src/lib/print-presets.ts`(714줄, `buildPageCss`) | 동작 | 이식(Python으로, @page 규칙) | `engine/app/presets/` | 분석:86 |
| `frontend/src/lib/html-templates.ts`(137줄) | 동작 | 이식 | `engine/app/html/templates/` | `docs/reviews/flora.md:188` |
| `frontend/src/app/api/books/build-html/route.ts`(250줄) | 동작 | 이식(서버 Python, 단락 escape 추가) | `engine/app/html/` | `docs/reviews/flora.md:78` |
| `api/routers/llm.py` `call_llm`, `_call_via_openrouter` | 동작 | 참고(ai-service 라우터 체인이 대체) | - | SM 8장(2026-10-13 변경), 확정 결정 17 |
| `api/routers/llm.py` 집필·옴니버스 프롬프트(`:298`, `:472`) | 동작 | 이식(프롬프트 텍스트) | `api/app/ai/products/publishing/prompts/` | 분석:97 |
| `api/routers/cover.py` `build_cover_prompt`(`:81`) | 동작 | 이식(프롬프트만) | `worker/src/handlers/cover.ts` | 분석:104 |
| `api/routers/cover.py` 제공자 7종 | 동작 | 폐기(fal 1개로) | - | 분석:104 |
| ToneSlider 컴포넌트 | 동작 | 이식 | `web/src/features/wizard/` | 분석:92 |
| `frontend/src/components/project/weasyprint-editor-panel.tsx`(1,067줄) | 동작 | 참고(미리보기 UX만) | `web/src/features/finish/` | 분석:113 |
| `frontend/.../new/ebook/page.tsx`(4,095줄), `manuscript/page.tsx`(1,422줄), `chapter-wizard.tsx`(1,473줄) | 동작 | 폐기 | - | D-26 |
| `f5-tts/` | 동작 | 폐기(아카이브). TTS는 확정 결정 16(ElevenLabs + 오픈소스 음성 서버)로 대체. F5-TTS 공개 가중치는 비상업 라이선스(CC-BY-NC)라 유료 서비스에 쓰지 않는다 | - | D-36, D-07, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:57` |

### 1.3 flora-publisher

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `frontend/docs/prd/02_user_flow.md`, `03_features.md` | 기획만 | 참고(집필 큐, 마이크로 프롬프트, ₩9,900) | 01장, 02장 4절 | 분석:66 |
| `frontend/services/bookApi.ts`, `components/BookCard.tsx` | 동작 | 폐기(시장 조사 폐기) | - | D-15 |
| `backend/server.js`, `vertex-ai-proxy-interceptor.js`, Vite 설정 | 동작 | 폐기 | - | D-17 |

### 1.4 SellingDocs

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `PRD.md` 크레딧 요구, 입력 6필드, 데이터 모델, GEO | 기획만 | 참고 | 01장, 05장 | `docs/reviews/SellingDocs.md:81` |
| `Claude.md`, `add.md`(0바이트) | 빈 파일 | 폐기 | - | D-38 |

### 1.5 `WeasyPrint - CSS Paged Media 명세.md`

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| @page, :left/:right, :first/:blank, 쪽 넘김 제어, string-set, 점선 목차, 인쇄/전자 분기 | 문서 | 참고(템플릿 CSS 기준) | `engine/app/presets/`, `engine/app/html/` | `WeasyPrint - CSS Paged Media 명세.md:13-147` |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| v2 위저드 컴포넌트 | localStorage 상태(`flora_ebook_draft_{id}`) 제거 → `PATCH /api/books/[id]` 2초 debounce. `projectId='new'` 제거. raw fetch → `apiFetch`. 이모지 아이콘 → Lucide. 플랜 판정은 세션 컨텍스트 + 서버 응답(403)만 |
| `personas.ts` → `personas.json` | 60종 모두 `systemPromptSnippet` 필수(빈 값이면 빌드 실패 테스트). 실존 작가 이름 검사. `free_tier: bool` 대신 순서(앞 40종)로 Free 판정 |
| `auto-fit-presets.ts` → `formats.json` | v2 값을 임시값으로 두고(01장 D3), 실물 출력 테스트 후 확정. 안쪽 ≥ 바깥 + 3mm 검증을 데이터 테스트로 |
| v1 `print-presets.ts` → `engine/app/presets` | TS → Python. 클라이언트 페이지네이션 스크립트(`buildPaginationScript`)는 버린다(WeasyPrint가 페이지 나눔). `:left/:right`, `:first`, `counter(page)`, `string-set`, `leader('.')` 목차를 명세 문서대로 |
| v1 `build-html` + `html-templates.ts` | Next Route Handler → 엔진. 모든 텍스트 `html.escape`, 본문은 nh3 허용 목록. 이미지 src는 Storage 경로를 서버가 서명 URL 또는 허용 호스트로 변환 |
| v1 `build_epub` | `abs(hash(title))` → `uuid5(NAMESPACE_URL, 'flora:book:<book_id>')`. XML escape. 표지 바이너리, nav.xhtml, 폰트(OFL)만 포함. epubcheck 통과 |
| v2 업로드 파서 | `file_id` 2단계 제거. Storage 객체를 엔진이 스트리밍으로 읽음. 20MB, 매직바이트 검사, 파싱은 워커 프로세스. `/manuscript` hex 에코 제거 |
| 프롬프트(v1, v2) | Python f-string → 언어 중립 템플릿 파일(md·json, `api/app/ai/products/publishing/prompts/`). 출력 JSON은 JSON Schema 하나에서 zod(web)·pydantic(api)을 생성. Taste는 `web/src/data/personas.json` 단일 소스를 api가 빌드 때 복사해 읽는다(해시 일치 테스트, PB-06-048). 합성 함수는 api `compose` 노드 하나 |
| v1 `content_disposition` | TS로 옮겨 다운로드 302 대신 서명 URL `download` 파라미터에 적용 |

## 3. 폐기 목록과 사유

분석 "폐기" 38건(A-2 표 16건 + A-3 목록 22건) 전부.

| ID | 항목 | 출처 | 사유 |
|---|---|---|---|
| D-01 | 키워드 추천(`/llm/keyword-suggestions`) | 분석:88 | v2 4단계 제목 추천과 역할이 같아 단계만 늘어남 |
| D-02 | 쪽번호 삽입(원고에 넣기) | 분석:101 | 쪽번호는 렌더 시 `@page` counter로 자동 처리 |
| D-03 | AI 조판(`/llm/layout`) | 분석:103 | Auto-Fit과 build-html이 대체, 사진집 폐기로 쓸 곳 없음 |
| D-04 | Typst PDF | 분석:109 | PDF 엔진 2개 유지 비용, Typst CLI 의존 |
| D-05 | DOC 내보내기(Word 호환 HTML) | 분석:110 | 진짜 docx가 아님. 필요하면 정식 생성기로 새로 기획 |
| D-06 | 차트 삽입(QuickChart) | 분석:115 | 사용자 데이터 외부 전송. 필요하면 인라인 SVG |
| D-07 | 레퍼런스 WAV(커스텀 보이스) | 분석:132 | 음성 복제 권리·동의 문제, GPU 비용, 경로 조작 취약점 |
| D-08 | AI 캔버스(React Flow) | 분석:138 | 10단계 위저드와 중복, 실행 엔진 없음 |
| D-09 | n8n 연동(전역 키 프록시) | 분석:140 | 테넌트 격리 붕괴. 아웃바운드 웹훅으로 대체 |
| D-10 | 사진집 | 분석:141 | MVP 밖(확정 결정 7), 목업 |
| D-11 | 룩북 | 분석:142 | 위와 같음 |
| D-12 | Pro 잠금해제(`'1234'`, localStorage) | 분석:150 | 유료 기능 무료 사용. dev 빌드에도 두지 않는다 |
| D-13 | 사용자 API 키(BYOK) | 분석:153 | 평문 저장 위험, 실제로 쓰이지 않는 죽은 기능 |
| D-14 | mock 폴백 응답 | 분석:155 | 장애가 정상 응답처럼 보임 |
| D-15 | 시장 조사(Google Books 검색) | 분석:156 | v1이 벤치마킹 방식 폐기를 명시. 필요 시 `bookApi.ts`, `BookCard.tsx`만 재검토 |
| D-16 | 도서 랜딩/홍보, 정산 메뉴 | 분석:157 | MVP 밖, 판매 기능은 결정 사항(01장 D5) |
| D-17 | FP Vite SPA, Express Vertex 프록시, fetch/WebSocket 몽키패치, Tailwind CDN, `latest` 의존성 | 분석:174 | 미사용, 토큰 유출 경로(`docs/reviews/flora-publisher.md:52-53`) |
| D-18 | FP PRD의 NextAuth, Vertex AI SDK | 분석:175 | Supabase Auth와 공용 LLM 게이트웨이로 대체 |
| D-19 | SD의 Next 14 전제, Route Handler에서 WeasyPrint 실행 가정 | 분석:176 | 런타임 조합 불성립(`docs/reviews/SellingDocs.md:48`) |
| D-20 | SD의 LLM 4사 SDK 직접 연동, 책 전체 단일 JSON 생성 | 분석:177 | 키·SDK 부담, 토큰·타임아웃 |
| D-21 | Typst 경로 전체(`build-typst`, `export/typst`, `typst-presets.ts`) | 분석:178 | D-04와 같음 |
| D-22 | fpdf2 폴백, html2pdf.js 클라이언트 PDF | 분석:179 | 한글 불가, 판형 미반영 |
| D-23 | v1 DOC 내보내기 | 분석:180 | D-05와 같음 |
| D-24 | v1 동기 SDK와 `requests` 호출 | 분석:181 | 이벤트 루프 블로킹 |
| D-25 | SKILL.md의 Firebase Firestore 로드맵, localStorage 라이브러리 방식 | 분석:182 | Supabase와 충돌 |
| D-26 | v1 프론트 전체(4,095줄 위저드, 1,422줄 manuscript, 1,473줄 chapter-wizard) | 분석:185 | 유지보수 불가. 데이터·엔진만 이식 |
| D-27 | v1 인증 중복(`cover.py optional_verify`와 `auth.py`) | 분석:186 | 코어 auth로 단일화 |
| D-28 | v2 업로드 3중 복제, 내보내기 3중 복제 | 분석:187 | 훅 1개, 엔진 1개로 |
| D-29 | v1·v2 waitlist, merge, build-html 이중 구현 | 분석:188 | 서버 한 곳만 |
| D-30 | v2 수제 ePub2 빌더 | 분석:189 | v1 ePub3로 대체 |
| D-31 | v2 `skill-runner.ts`, `taste-injector.ts`, `manuscript-uploader.tsx` | 분석:192 | 죽은 코드 |
| D-32 | v1 `/debug-api-keys`, `_GENRE_REFS_DEPRECATED`, mock 데이터 1,000줄 이상 | 분석:193 | 키 정보 노출, 폐기된 방식 |
| D-33 | v1 BYOK 컬럼(migration 004), in-memory waitlist와 시드 수치 147 | 분석:194 | 평문 키, 허위 수치 |
| D-34 | v2 스텁(`/api/auth/`, `add-page-numbers`, placehold.co 표지, 캔버스 `setTimeout`) | 분석:195 | 기능 없이 성공 응답 |
| D-35 | `PasswordUnlockModal`, `flora_pro_unlocked`(v1, v2) | 분석:196 | D-12와 같음 |
| D-36 | v1 `f5-tts/` 벤더링(train, eval, triton), `ckpts`, venv, 잡파일(`-w`, `server.log`, `tsbuildinfo`) | 분석:197 | 저장소 비대, 오디오북 Phase 2 |
| D-37 | 실키가 든 v1 `frontend/.env`, v2 루트 `.env`·`.env.local` | 분석:198 | 키 유출. 삭제와 재발급 |
| D-38 | SD 빈 `Claude.md`, `add.md` | 분석:199 | 내용 없음. 이 폴더 `CLAUDE.md`가 대체 |

AI 계층 도입(2026-10-13)으로 생긴 추가 폐기. 분석 A-3 목록 밖이라 따로 번호를 붙인다.

| ID | 항목 | 출처 | 사유 |
|---|---|---|---|
| D-39 | 공용 LLM 게이트웨이(TS)의 직접 제공자 호출과 모델 맵 | `docs/products/_platform-core/SHARED_MODULES.md:215` | 라우터 본체가 ai-service로 이동. TS 게이트웨이는 `/api/ai/*` 호출용 얇은 래퍼만 |
| D-40 | web·worker·engine에 LLM·임베딩 키를 두는 구성 | `docs/products/_platform-core/SECURITY_BASELINE.md:284` | 키는 `api/`에만(음성 키는 web 서버만) |
| D-41 | "Anthropic + OpenRouter 폴백" 고정 2단 체인 | 분석:154 | 기능별 대체 체인(5.1절)과 국외 이전 동의 필터로 대체 |
| D-42 | 랜딩 히어로 "판면 정지 렌더 + 판형 전환 1회" | 03장 4.3절 원칙 4(이전 판) | 2026-10-13 사용자 결정으로 3D 히어로(4.6절). 판면 렌더는 3D의 마지막 프레임으로 흡수 |
| D-43 | 임의 텍스트를 TTS로 읽는 API(클라이언트가 텍스트를 보냄) | v1 `tts.py` 설계 | 낭독·읽어 주기는 DB 본문·메시지만 입력으로 받는다(PB-F-051, 052) |

## 4. 복사 금지 결함

`SECURITY_BASELINE.md` 14장 중 해당 항목 + 원본 고유 결함.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| `user_plans FOR ALL` 정책 | `Flora-v2/supabase/migrations/002_rls.sql:13`, `flora/supabase/migrations/002_user_plans_and_persona.sql:23-25` | 자기 플랜 상향 | 코어 엔타이틀먼트(SELECT만) |
| Pro 잠금해제 `'1234'`, localStorage 플래그, 관리자 이메일 하드코딩 | `Flora-v2/frontend/src/components/ui/password-unlock-modal.tsx:14-15`, `frontend/src/lib/admin.ts:1` | 유료 기능 무료, 권한 상승 | 서버 features 해석, `platform_role` |
| 라우터 무인증(LLM/export/upload), `dev-user` 우회, 빈 JWT secret | `docs/reviews/Flora-v2.md:63`, `:70`, `docs/reviews/flora.md:80` | 비용 유출, 데이터 접근 | `requireSession`, 엔진 내부 토큰, 기동 검증. 허용되는 Mock은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2장(로컬 시드 계정으로 실제 JWT, 배포 환경 404)뿐이다(6절) |
| 웹훅 서명 미검증·시크릿 오용 | `flora/api/routers/billing.py:83-119`, `Flora-v2/api/routers/billing.py:64` | 위조 결제로 플랜 상승 | Toss confirm 정본 + 웹훅 서명 필수 |
| 비원자 크레딧 차감, 클라이언트 게이팅 | `docs/reviews/SellingDocs.md:49` | 음수 잔액, 무료 사용 | 코어 `consume_credits` |
| 사용자 입력 파일명을 경로에 사용 | `flora/api/routers/tts.py:59-71` | 경로 조작 | 서버 생성 경로 + 경로 CHECK |
| 서버가 사용자 URL을 fetch(`cover_url`), WeasyPrint 무제한 fetch | `flora/api/routers/export.py:211-228`, `:195-200` | SSRF | Storage id 참조, url_fetcher 허용 목록 |
| 범용 AI 프록시, 하드코딩 프록시 헤더 | `flora-publisher/backend/server.js:104-115`, `:194`, `vertex-ai-proxy-interceptor.js:116` | 토큰 유출 | 공용 게이트웨이(고정 호스트) |
| 전역 n8n API 키 프록시 | `Flora-v2/api/routers/automation.py:58-90` | 테넌트 격리 붕괴 | 조직별 아웃바운드 웹훅 + 암호화 비밀 |
| escape 없는 HTML/XML 삽입 | `Flora-v2/api/routers/export.py:75,88-90`, `flora/frontend/src/app/api/books/build-html/route.ts:46` | XSS, ePub 깨짐 | escape + nh3 + iframe sandbox |
| 장애를 mock으로 숨김, `except Exception` 무로깅 | `flora/api/routers/llm.py` 16곳 | 장애 은폐 | 실패 표시 + 환불 + 로깅 |
| async 핸들러 안 동기 호출 | `flora/api/routers/llm.py:117`, `Flora-v2/api/routers/projects.py:31` | 이벤트 루프 정지 | TS 게이트웨이, 워커 프로세스, `run_in_threadpool` |
| 마지막 1,000자만 다듬기 | `flora/api/routers/llm.py:245-262` | 원고 손실 위험 | 청크 잡 + Diff 수락 |
| EventSource로 POST 호출, 클라이언트 전용 상태 | `Flora-v2/frontend/src/hooks/use-write-all.ts:28`, `use-ebook-step.ts:81` | 기능 불능, 데이터 유실 | 서버 잡 + Realtime, DB 영속화 |
| 실키 `.env` 커밋, `latest` 의존성 | `docs/reviews/flora.md:79`, `docs/reviews/flora-publisher.md:57` | 키 유출, 재현 불가 빌드 | env 비커밋, lockfile, 버전 고정 |
| Windows 폰트 경로 하드코딩 | `flora/api/routers/export.py:134-139` | 컨테이너에서 한글 깨짐 | fontconfig + Noto CJK 설치 검증 |
| `.single()` 0행 500 | `Flora-v2/api/routers/projects.py:57`, `flora/api/db.py:46` | 404 대신 500 | `maybe_single`/RLS 결과 확인 |
| 허위 수치(waitlist 시드 147) | `flora/api/routers/waitlist.py:8` | 허위 표시 | 실제 행 수 |
| 브라우저에서 Dify·FastAPI·AI 제공자 직접 호출 | `docs/products/_platform-core/SECURITY_BASELINE.md:299` | 인증·과금 우회 | `/api/ai/*`, `/api/voice/*` |
| Dify 입력에 토큰·org·원고 | `docs/products/_platform-core/SECURITY_BASELINE.md:285` | Dify 로그에 평문으로 남음 | 대화 매핑(`platform_conversation_id`, `dify_user`) |
| LLM·음성 키를 브라우저·Vercel·워커에 두기 | `docs/products/_platform-core/SECURITY_BASELINE.md:284` | 키 유출, 라우팅 우회 | LLM 키는 `api/`, 음성 키는 web 서버 |
| 개인정보 포함 원고를 상용 제공자로 대체 전송 | 01장 6.1절 | 국외 이전 동의 우회 | 오픈소스 전용 책, 실패 시 환불 |
| 낭독 중 제공자 대체(목소리가 바뀜) | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:47` | 연속 낭독 품질 | 시작 제공자 고정, 실패 시 파일 없음 + 환불 |
| 참고 파일 문장을 그대로 이어 붙이는 생성 | 01장 PB-F-054 | 저작권 침해 위험 | compliance의 장문 일치 검사 |
| 사람 소유 블록을 에이전트가 덮어쓰기 | `docs/products/_platform-core/LLM_WIKI.md:30` | 이용자 수정 소실 | 제안만 남기고 `expected_version` 잠금 |
| 토큰 밖 3D 재질 색, 보라/핑크 그라디언트 | `docs/products/_design-guide/HERO_3D.md:52-53` | 피할 인상 | 03장 4.6절 토큰 표 |
| "Tailwind로"만 적은 지시로 v3 설정 생성 | `docs/products/_design-guide/DESIGN_SYSTEM.md:23` | v3 설정 혼입 | 지시와 문서에 Tailwind CSS v4 명시, `tailwind.config.js` 금지 |

## 5. 아카이브 절차

| 순서 | 작업 | 담당 |
|---|---|---|
| 1 | 2절 이식 대상 파일이 새 저장소에 들어가고 PB-06-016, 018, 021이 완료됐는지 확인(이식 전 삭제 금지, `docs/reviews/Flora-v2.md:190`) | PB-06-033 |
| 2 | `flora/` → `archive/flora-v1/`, `flora-publisher/` → `archive/flora-publisher/`. 같은 폴더의 중복 zip(`flora-publisher-factory---market-research.zip`)은 삭제(`docs/reviews/Flora-v2.md:191`) | PB-06-033 |
| 3 | `Flora-v2/` → 이식 완료 후 `archive/flora-v2/`. `구현해야 할 프로젝트/SellingDocs/`는 PRD만 `archive/sellingdocs/`로 | PB-06-033 |
| 4 | 아카이브 전에 `f5-tts/ckpts`, venv, `node_modules`, 잡파일을 제외(저장소 용량) | PB-06-033 |
| 5 | 키 재발급: v1 `frontend/.env`와 v2 루트 `.env`의 `SUPABASE_SERVICE_ROLE_KEY`, `OPENROUTER_API_KEY`(값 미확인, 키 이름만 확인)를 각 콘솔에서 재발급하고 기존 키 폐기. 재발급 기록은 `docs/flora-publishing/ops/key-rotation.md` | PB-06-033 |
| 6 | 아카이브 폴더에서 `.env*`를 지운 뒤 이동(키가 아카이브에 남지 않게) | PB-06-033 |
| 7 | 원본 폴더 이동·삭제는 사용자 승인 후에만(이번 단계는 기획만, 원본 무수정) | 사용자 |

## 6. 인증 단계 관련 복사 금지 (2026-10-14 추가, 확정 결정 22)

4절 표에 이어서 본다. 이 제품 원본에는 쿠키에 역할·플랜을 적는 Mock 로그인이 없지만, 다른 제품 원본에서 확인된 같은 결함을 이식·재발명하지 않도록 행을 둔다. 허용되는 Mock은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2장(로컬 Supabase 시드 계정으로 실제 JWT, `isMockAuthAllowed()` 가드, 배포 환경 404)뿐이다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 쿠키 역할 Mock(`mock-auth.ts`, `nomad_role`, `nomad_plan` 쿠키, localStorage 역할·플랜) | `docs/products/nomad-blog/07_SOURCE_MIGRATION.md:88`, `docs/products/nomad-commerce/07_SOURCE_MIGRATION.md:96`(다른 제품 원본, AUTH_ROADMAP 1장) | 권한 위조, 프로덕션 노출 | AUTH_ROADMAP 2장 Mock 로그인(PB-06-006), CI 금지 문자열(PB-06-005) |
| 콜백 `next` 무검증 연결(`${origin}${next}`) | `docs/reviews/Flora-v2.md:71`(`Flora-v2/frontend/src/app/auth/callback/route.ts:7,13`) | `next=@evil.com` 외부 리다이렉트 | `finishLogin`의 화이트리스트(01장 PB-F-002, AUTH_ROADMAP 3.2절 5번) |
| `SUPABASE_URL` 미설정 시 `dev-user` 반환 | `docs/reviews/flora.md:80`(`flora/api/routers/auth.py:17-18`) | 환경변수 누락이 곧 인증 우회 | 기동 시 env 검증. `AUTH_MODE=mock`인데 판정이 거짓이면 기동 실패(AUTH_ROADMAP 2.4절) |
| 기능 코드의 `if (mock)`·페르소나 이메일 분기 | AUTH_ROADMAP 0장 불변 조건, 2.5절 | 단계 전환 때 권한 경로가 달라짐 | 단계 분기는 `web/src/lib/auth/`·로그인 화면·콜백·`/api/dev/login`에만(02장 9.2절) |

## 7. 외부 제안서 반영 기준 (2026-10-14 FLORA 개편)

"FLORA Publishing — UI/UX 및 AI 에이전트 통합 디자인 제안서"(ChatGPT 작성, 대표님 전달)는 원본 코드가 아니라 기획 의견이다. 무엇을 가져오고 무엇을 가져오지 않았는지 남긴다.

| 구분 | 내용 | 반영 위치 |
|---|---|---|
| 가져옴 | 교육 범위 제외, 4개 영역, 3개 디자인 레이어와 포인트 색 사용 규칙, 랜딩 6섹션, 에디터 3단과 AI 패널, 6개 에이전트와 승인 방식, Workspace·Builder 구분(Builder는 Phase 2), 운영 콘솔 메뉴·실행 추적·원가·장애 재실행·원고 열람 최소 권한, "기존 모델·엔진을 확장하고 중복 생성하지 않는다" | 01장 3.1절, 02장 10절, 03장 8절, 04장 9절, 05장 2.5절, 06장 9절 |
| 결정으로 올림 | 포레스트 그린 팔레트, Pretendard, 헤드라인 "당신의 경험을, 한 권의 책으로." | 01장 D23~D25 |
| 가져오지 않음 | 개념 예시로 든 `agent_runs`, `task_events` 별도 표(코어 `ai_runs`·`jobs`·`audit_log`가 이미 있음), 새 실행 엔진, 에이전트 6개 카드 그리드 | 05장 머리말 |
| 복사 금지 | 제안서에 붙은 이미지 썸네일(`images.openai.com` 주소)과 그 원본 작품의 레이아웃·카피·로고. 원본 URL을 확인하기 전에는 레퍼런스로 쓰지 않는다 | 03장 8.3절 끝, `REFERENCES.md` "영감용이지 복제용이 아니다" |
