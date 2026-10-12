# 06 에이전트 작업 계획: FLORA Publishing

작성일 2026-10-12. 작업 ID는 `PB-06-###`. 모델 기준은 `docs/products/_platform-core/DOC_TEMPLATE.md` 1장(Fable: 결제·권한·RLS·데이터 모델, Opus: 기능·API·테스트, Sonnet: UI·문서·설정, Haiku: 보일러플레이트·문구·체크). 경로는 앱 저장소 기준 `apps/flora-publishing/`를 생략해 `web/`, `worker/`, `engine/`로 적는다.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 디렉토리는 한 작업만 쓴다. 공용 파일(`web/package.json`, 레이아웃)은 PB-06-002만 수정하고, 다른 작업은 의존성 추가를 PB-06-002 담당에 요청하거나 같은 웨이브 종료 후 순차 반영 |
| Route Handler 분할 | `web/src/app/api/` 아래는 리소스 디렉토리별로 소유자가 다르다(2절 표). 한 작업이 다른 작업의 route 디렉토리에 파일을 만들지 않는다 |
| 서버 공용 코드 | `web/src/server/<영역>/`도 영역별 단일 소유. 다른 작업은 import만 한다 |
| 코어 불변 | `packages/core-*`, `_platform-core`, `_supabase-modular`의 다른 파일은 수정하지 않는다. 필요하면 6절 코어 요청 |
| SQL | DB 변경은 PB-06-001(Fable)만. 다른 작업이 컬럼이 필요하면 001에 요청 |
| 테스트 | 테스트 디렉토리는 테스트 작업이 소유(`supabase/tests/`, `web/tests/integration/`, `web/e2e/`, `engine/tests/`). 기능 작업은 자기 디렉토리 안 단위 테스트(`*.test.ts`, `test_*.py`)만 쓴다 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| PB-06-001 | DB 조각 적용, 모놀리스 변환 스크립트, 타입 생성 | `supabase/migrations/`, `supabase/scripts/to_monolith.sh`, `supabase/seed.sql`, `web/src/types/supabase.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공, 변환 스크립트 결과가 `0002_publishing_domain.sql`과 diff 0, SQL 체커 OK 2종 | SellingDocs 5장 #1, #4, 05장 9절 |
| PB-06-002 | web 골격(basic-master-module 기반 Next 16, core-db 연결, `proxy.ts`, env zod 검증, 저장소 CLAUDE.md) | `web/` 루트 설정(package.json, next.config.ts, tsconfig.json, eslint, tailwind), `web/src/proxy.ts`, `web/src/lib/supabase/`, `web/src/lib/env.ts`, `web/src/app/layout.tsx`, `web/CLAUDE.md` | 없음 | P0 | M | Opus | 필수 env 하나 빠지면 `next dev`가 시작하지 않음. 미로그인 `/dashboard` → `/login`. TS strict, `latest` 의존성 0 | SellingDocs 5장 #2, #3, flora-publisher 5장 #8, #10 |
| PB-06-003 | 엔진 골격(FastAPI, pydantic Settings, Python 잡 워커 루프, Dockerfile, 내부 토큰) | `engine/pyproject.toml`, `engine/Dockerfile`, `engine/app/main.py`, `engine/app/settings.py`, `engine/app/worker.py`, `engine/app/db.py`, `engine/app/auth.py` | 없음 | P0 | M | Opus | 토큰 없이 `/internal/*` 401, 빈 토큰·빈 JWT secret이면 기동 실패. 워커가 `claim_jobs('publishing.doc')` 루프로 빈 핸들러 잡을 complete | Flora-v2 5장 #1, #10, #11, #12, flora 5장 #1, #4, #6 |
| PB-06-004 | WeasyPrint 렌더 서비스(공용, 이 제품 소유) | `services/render-weasyprint/`(tests 제외) | 없음 | P0 | M | Opus | 한글 200쪽 HTML → 120초 안 PDF, 두부 0. `file://`·사설 IP 이미지 요청 시 렌더 실패. 폰트 없으면 헬스체크 실패 | SellingDocs 5장 #6, flora 5장 #3, #5, 분석:108 |
| PB-06-005 | CI(tsc, lint, build, pytest, SQL 체커, RLS 스모크, actionlint, 금지 문자열 검사) | `.github/workflows/flora-publishing.yml` | PB-06-002, PB-06-003 | P0 | S | Sonnet | PR마다 실행, 하나라도 실패하면 병합 불가. `flora_pro_unlocked`, `PasswordUnlock`, `/auth/v1/token` 문자열이 있으면 실패 | Flora-v2 5장 #3, #13, flora 5장 #5, flora-publisher 5장 #4 |
| PB-06-006 | 인증 화면과 콜백(`signup_app`, Google, `next` 화이트리스트, 재설정) | `web/src/app/(auth)/`, `web/src/app/auth/callback/` | PB-06-002 | P0 | M | Fable | 가입 → 메일 인증 → `/dashboard`, 새로고침 유지. `next=//evil.com` → `/dashboard`. 가입 직후 잔액 20 | Flora-v2 5장 #1, SellingDocs 5장 #3, PB-F-001, PB-F-002 |
| PB-06-007 | API 공통(apiFetch, `requireSession` 래퍼, 응답 봉투, request_id, SQLSTATE → HTTP 매핑, 레이트 리밋) | `web/src/lib/api/`, `web/src/server/http/` | PB-06-002 | P0 | M | Opus | 모든 route가 래퍼를 거치는지 린트 규칙으로 검사. 401/402/403/409 매핑 표대로 응답 | Flora-v2 5장 #1, #11, flora 5장 #1, #10, PB-F-003 |
| PB-06-008 | 크레딧 단가표, features 해석기, 원가 재산정 | `web/src/server/pricing/`, `web/src/server/features/` | PB-06-001 | P0 | M | Fable | `priceOf('publishing', action)`이 01장 4.3절과 같고, 키 없는 features는 Free 기본값. 토큰 원가 표로 단가 재검증 보고 1건 | Flora-v2 5장 #2, flora 5장 #8, SellingDocs 5장 #4, PB-F-034 |
| PB-06-009 | Toss 결제(팩 주문, confirm, 빌링키, 구독 해지, Toss 웹훅, 결제 화면) | `web/src/app/api/billing/`, `web/src/app/api/webhooks/toss/`, `web/src/app/(app)/dashboard/billing/`, `web/src/features/billing/` | PB-06-007, PB-06-008 | P0 | L | Fable | 테스트 키로 팩 결제 → grant 1행, 같은 confirm 재호출 → 지급 1회, 금액 조작 → `PM001` + 취소 요청, 위조 웹훅 401 | Flora-v2 5장 #2, flora 5장 #2, SellingDocs 5장 #13, PB-F-035 |
| PB-06-010 | 책 CRUD, 위저드 영속화(debounce 2초), 휴지통·복구, 시드 복제 | `web/src/app/api/books/route.ts`, `web/src/app/api/books/[id]/route.ts`, `web/src/app/api/books/[id]/restore/`, `web/src/app/api/seeds/`, `web/src/server/books/`, `web/src/data/seeds/` | PB-06-007 | P0 | M | Opus | 새 책마다 고유 id, 7단계에서 닫고 다시 열면 같은 상태. Free 4번째 책 409 `PB001` | Flora-v2 5장 #7, flora 5장 #13, PB-F-006, PB-F-029, PB-F-030 |
| PB-06-011 | 기획 LLM API(제목, 기획안, 목차, 구조 저장)와 프롬프트 이식(v1·v2) | `web/src/app/api/books/[id]/titles/`, `.../plans/`, `.../toc/`, `.../structure/`, `web/src/server/prompts/` | PB-06-007, PB-06-008, PB-06-012 | P0 | M | Opus | 각 호출 선차감, JSON 스키마 위반 1회 재시도 후 환불. 구조 저장이 플랜 한도 초과 시 409 + 초과 목록 | SellingDocs 5장 #5, flora 5장 #1, PB-F-013~015 |
| PB-06-012 | 페르소나 60종 JSON 단일 소스, Taste 합성, 페르소나 합성 API | `web/src/data/personas.json`, `web/src/server/personas/`, `web/src/app/api/personas/` | PB-06-007 | P0 | M | Opus | 60종 모두 문체 지시 비어 있지 않음(테스트). Free 41번째 페르소나 사용 시 403. 합성은 Basic만, 3크레딧 | Flora-v2 5장 #8, PB-F-009, PB-F-011, PB-F-033 |
| PB-06-013 | 섹션 단건 스트리밍 생성, 보조 집필(이어/살/다듬기), 섹션 PATCH, 서버 sanitize | `web/src/app/api/books/[id]/sections/`, `web/src/app/api/books/[id]/assist/`, `web/src/server/sanitize/` | PB-06-011 | P0 | L | Opus | 연결이 끊겨도 본문 저장. `<script>`·`on*` 제거 단위 테스트. 생성 중 PATCH 409 `PB005`. revision 충돌 409 | Flora-v2 5장 #5, SellingDocs 5장 #5, #9, flora 5장 #7, PB-F-016, PB-F-018 |
| PB-06-014 | TS 워커: write_all(창 3), write_section(재시도 3), refine_all/chunk, 취소 처리, 실행 API | `worker/src/handlers/write-*.ts`, `worker/src/handlers/refine-*.ts`, `worker/src/main.ts`, `web/src/app/api/books/[id]/write-all/`, `.../refine-all/`, `web/src/app/api/generation-runs/` | PB-06-013 | P0 | L | Opus | 15섹션 중 2개 강제 실패 → `partial`, 차감 = 성공분. 취소 후 60초 안 신규 섹션 0. 3만 자 다듬기 → 청크 15개 결과 15개 | Flora-v2 5장 #5, #10, flora 5장 #4, #7, SellingDocs 5장 #5, PB-F-017, PB-F-019 |
| PB-06-015 | 원고 업로드(서명 URL, 완료 검증, 파싱 잡, 파서 4종, 책 생성) | `engine/app/parsers/`, `engine/app/jobs/parse_manuscript.py`, `web/src/app/api/uploads/` | PB-06-003, PB-06-007 | P0 | M | Opus | 25MB 413, 위장 확장자 415, md·docx·txt·pdf 샘플 4종의 챕터 수가 기대값과 같음. 원본은 24시간 뒤 삭제 | Flora-v2 5장 #4, flora 5장 #3, SellingDocs 5장 #9, PB-F-027, PB-F-028 |
| PB-06-016 | HTML 조립(v1 템플릿 이식, escape, nh3 재-sanitize), 판형 프리셋 → @page CSS, 미리보기 | `engine/app/html/`, `engine/app/presets/`, `engine/app/routes/preview.py`, `web/src/data/formats.json`, `web/src/app/api/books/[id]/preview/` | PB-06-003 | P0 | L | Opus | 6판형 골든: 미리보기와 PDF 첫 3쪽 줄바꿈 일치. 안쪽 여백 ≥ 바깥 + 3mm. 제목 `<script>` escape | flora 5장 #7, SellingDocs 5장 #8, Flora-v2 5장 #6, PB-F-007, PB-F-023 |
| PB-06-017 | PDF 내보내기(`render.pdf` 잡, 워터마크 강제, 월 한도, content_hash 재사용, 다운로드) | `engine/app/jobs/render_pdf.py`, `web/src/app/api/books/[id]/exports/`, `web/src/app/api/exports/` | PB-06-004, PB-06-016, PB-06-008 | P0 | M | Opus | Free가 워터마크 끄기 요청해도 워터마크. Free 3번째 403. 같은 해시 재요청 0크레딧. 렌더 실패 시 환불 1행 | Flora-v2 5장 #6, SellingDocs 5장 #6, PB-F-024, PB-F-026 |
| PB-06-018 | ePub3 빌더 이식(escape, uuid5, 표지, nav, 폰트) | `engine/app/epub/`, `engine/app/jobs/export_epub.py` | PB-06-016 | P0 | M | Opus | epubcheck 오류 0, 같은 책 2회 `dc:identifier` 동일, `&`·`<` 포함 제목 정상 | Flora-v2 5장 #6, flora 5장 #13, SellingDocs 5장 #7, PB-F-025 |
| PB-06-019 | 표지 3후보(fal 비동기, 웹훅, Storage 복사, 부분 환불) | `worker/src/handlers/cover.ts`, `web/src/app/api/books/[id]/covers/`, `web/src/app/api/webhooks/fal/` | PB-06-007, PB-06-008 | P0 | M | Opus | 1장 실패 시 2크레딧 환불, 다른 책 표지 선택 `PB006`. 이미지 URL은 Storage 경로만 | Flora-v2 5장 #9, PB-F-021 |
| PB-06-020 | 책 정보 생성(DB 원고 기반, ISBN 참조용) | `web/src/app/api/books/[id]/metadata/` | PB-06-011 | P1 | S | Opus | 원고 없는 책 409. 생성 프롬프트에 DB 제목·기획안·원고 앞 3,000자가 들어감(로그) | Flora-v2 5장 #8, PB-F-022 |
| PB-06-021 | 위저드 UI 10단계(진행바, 단계 컴포넌트 v2 이식, 판형·장르·페르소나·제목·기획·목차·표지·정보) | `web/src/features/wizard/`, `web/src/app/(app)/books/[id]/wizard/` | PB-06-010, PB-06-011 | P0 | L | Sonnet | 375/1440px 깨짐 없음, 완료 단계만 이동, 비용 라벨 표시, 402 모달 | Flora-v2 5장 #7, flora 5장 #9, PB-F-006~015 |
| PB-06-022 | 원고 에디터(Tiptap, 플로팅 툴바, `/` 명령, Diff 카드, 섹션 상태 Realtime) | `web/src/features/editor/`, `web/src/app/(app)/books/[id]/editor/` | PB-06-013, PB-06-014 | P0 | L | Opus | 선택 → 다듬기 → Diff 대체 → 저장 후 revision+1. 생성 중 섹션 읽기 전용. 자동 저장 2초 | flora 5장 #9, SellingDocs 5장 #9, PB-F-018 |
| PB-06-023 | 대시보드, 책 목록·휴지통, 완성/내보내기 화면, 페르소나 보관함, 설정(테마) | `web/src/app/(app)/dashboard/`(billing/, settings/webhooks/ 제외), `web/src/app/(app)/books/[id]/finish/`, `web/src/features/{books,finish,personas,settings}/`, `web/src/app/api/settings/` | PB-06-010, PB-06-017 | P0 | M | Sonnet | 빈 상태 문구, Pro 테마 잠금 표시, 사이드바 모바일 드로어, 내보내기 기록 만료 표시 | flora-publisher 5장 #9, #11, SellingDocs 5장 #10, PB-F-010, PB-F-030~032 |
| PB-06-024 | 메인페이지(랜딩), 요금 페이지, 디자인 시스템 MASTER.md | `web/src/app/(marketing)/`(legal/ 제외), `web/src/features/landing/`, `design-system/flora-publishing/` | PB-06-016 | P0 | M | Sonnet | 03장 4절 토큰·와이어프레임 A안, DP 7단계 체크리스트 12항목 통과, 허위 수치·가상 후기 0 | SellingDocs 5장 #10, 분석:158, PB-F-037 |
| PB-06-025 | 법무 페이지 5종 문구(약관, 처리방침, 환불, AI 고지, 사업자 정보) | `web/src/app/(marketing)/legal/` | PB-06-002 | P0 | S | Haiku | 01장 6절 항목 전부 반영, 법무 검토 표시 문구 포함 | PB-F-039, 분석:214 |
| PB-06-026 | 아웃바운드 웹훅(등록, 비밀 vault, HMAC 발송, 재시도, 비활성) | `web/src/app/api/webhook-endpoints/`, `worker/src/handlers/webhook-deliver.ts`, `web/src/app/(app)/dashboard/settings/webhooks/` | PB-06-014, PB-06-017 | P1 | M | Opus | 사설 IP URL 422, 수신 측 서명 검증 성공, 5회 실패 후 failing | 분석:139, PB-F-036 |
| PB-06-027 | 운영자 화면(지표, 수동 크레딧 조정 + 감사, 렌더 실패 목록) | `web/src/app/admin/`, `web/src/app/api/admin/` | PB-06-008 | P1 | M | Fable | 일반 사용자 404, 조정 1건 = audit 1행, 사유 10자 미만 422 | Flora-v2 5장 #2(관리자 하드코딩 제거), PB-F-005 |
| PB-06-028 | 대기자 명단 API(레이트 리밋, 실제 카운트) | `web/src/app/api/waitlist/` | PB-06-007 | P1 | S | Haiku | 같은 이메일 2회 200, IP 6회째 429, 카운트 = 행 수 | flora 5장 #12, PB-F-004 |
| PB-06-029 | RLS/권한 회귀 테스트(05장 9절 57항목 + `SECURITY_BASELINE.md` 15장) | `supabase/tests/` | PB-06-001 | P0 | M | Fable | 모듈러·모놀리스 모두 통과, CI에서 실행 | SellingDocs 5장 #4, Flora-v2 5장 #2, flora 5장 #2, #8 |
| PB-06-030 | 결제 E2E(Toss 테스트 키: 팩, 구독, 정기결제 실패 → past_due, 해지, 환불) | `web/e2e/billing/` | PB-06-009 | P0 | M | Opus | 시나리오 5개 통과, 원장 drift 0 | SellingDocs 5장 #13, flora 5장 #2 |
| PB-06-031 | web 통합 테스트(무토큰 401, 402, 크레딧 동시성 50회, 쿼터, 생성 실패 환불, 내보내기 한도) | `web/tests/integration/` | PB-06-013, PB-06-017 | P0 | M | Opus | 동시 50회 consume 음수 0, drift 0, 실패 경로마다 환불 행 확인 | SellingDocs 5장 #14, Flora-v2 5장 #14 |
| PB-06-032 | 엔진·렌더 테스트(파서, escape, url_fetcher SSRF, 한글 골든 PDF, epubcheck) | `engine/tests/`, `services/render-weasyprint/tests/` | PB-06-004, PB-06-015, PB-06-016, PB-06-018 | P0 | M | Opus | 테스트 30개 이상(제안) 녹색, SSRF 케이스 6종(file, 169.254, 10.x, localhost, 리다이렉트, http) 모두 실패 처리 | Flora-v2 5장 #14, flora 5장 #3 |
| PB-06-033 | 원본 아카이브, 키 재발급 체크리스트, FP·v1 잔재 정리 | `archive/`(이동 대상 4개 폴더), `docs/flora-publishing/ops/key-rotation.md` | PB-06-021 | P1 | S | Haiku | 07장 5절 절차 완료, 재발급 대상 키 목록 4종 처리 기록 | flora 5장 #14, #15, flora-publisher 5장 #1~#7, #12, Flora-v2 5장 #12 |
| PB-06-034 | 배포 설정(Vercel, Railway 4서비스, private network, env 문서) | `infra/flora-publishing/`, `docs/flora-publishing/ops/env.md` | PB-06-003, PB-06-004 | P0 | S | Sonnet | 스테이징에서 가입 → PDF 1회 성공, env 문서 = 02장 8절 | Flora-v2 5장 #13, flora 5장 #5 |
| PB-06-035 | 공개 책 페이지와 Book JSON-LD(Phase 2) | `web/src/app/(public)/b/`, `web/src/app/api/books/[id]/visibility/` | PB-06-023 | P2 | S | Sonnet | 미완성 공개 `PB009`, anon은 공개 컬럼만, JSON-LD 검증 통과 | SellingDocs 5장 #12, PB-F-040 |
| PB-06-036 | 탈퇴·데이터 삭제와 purge 잡(휴지통, 업로드 원본, 만료 내보내기, 조직 30일) | `web/src/app/api/account/`, `worker/src/handlers/purge.ts` | PB-06-014, PB-06-017 | P1 | M | Fable | 삭제 요청 30일 뒤 조직 행 0, Storage 객체 0, 감사 기록 남음 | 분석:217, PB-F-038 |
| PB-06-037 | E2E 핵심 플로우(가입 → 10단계 → PDF/ePub, 업로드 경로, 전체 생성 취소) | `web/e2e/flows/` | PB-06-021, PB-06-022, PB-06-023 | P0 | M | Opus | 플로우 3개가 스테이징에서 통과, 로그인 새로고침 유지 확인 | Flora-v2 5장 #1, 03장 2절 |
| PB-06-038 | 문구 사전, 금지 문구·접근성 체크리스트 점검 | `web/src/copy/`, `docs/flora-publishing/checklists/` | PB-06-024 | P1 | S | Haiku | 01장 6절 금지 문구 검색 0건, 이모지 아이콘 0, 대비 4.5:1 | flora-publisher 5장 #11, 03장 6절 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 002, 003, 004 | 4 | 없음 | DB 조각 적용, 타입, web·엔진·렌더 골격 |
| W1 | 005, 006, 007, 008, 016, 025, 029 | 7 | W0 완료 | CI, 인증, API 공통, 단가·features, HTML/프리셋, 법무 문구, RLS 테스트 |
| W2 | 009, 010, 012, 015, 017, 018, 019, 028, 034 | 9 | W1 완료 | 결제, 책 CRUD, 페르소나, 업로드, PDF, ePub, 표지, 대기자, 배포 |
| W3 | 011, 013, 020, 024, 027 | 5 | 010, 012 완료 | 기획 LLM, 섹션 생성, 책 정보, 랜딩, 운영자 |
| W4 | 014, 021, 023, 030, 031, 032 | 6 | 013, 017 완료 | 전체 생성 워커, 위저드 UI, 대시보드, 결제 E2E, 통합·엔진 테스트 |
| W5 | 022, 026, 033, 036, 037, 038 | 6 | W4 완료 | 에디터, 웹훅, 아카이브, 탈퇴, E2E, 문구 점검 |
| W6 | 035 | 1 | MVP 출시 후 | 공개 책 페이지(Phase 2) |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 7 (001, 006, 008, 009, 027, 029, 036) | 18.4% | 15 / 74 = 20.3% |
| Opus | 21 | 55.3% | 45 / 74 = 60.8% |
| Sonnet | 6 (005, 021, 023, 024, 034, 035) | 15.8% | 10 / 74 = 13.5% |
| Haiku | 4 (025, 028, 033, 038) | 10.5% | 4 / 74 = 5.4% |
| 합계 | 38 | 100% | 74 |

## 5. 리뷰 작업 흡수표

리뷰 5장 작업 55건(Flora-v2 14, flora 15, flora-publisher 12, SellingDocs 14).

| 리뷰 작업 | 내용 요약 | 흡수 작업 ID |
|---|---|---|
| `docs/reviews/Flora-v2.md` 5장 #1 | 인증 체계 복구(브라우저 클라이언트, next 검증, apiFetch, 라우터 인증, JWT secret 기동 검증) | PB-06-006, PB-06-007, PB-06-003 |
| Flora-v2 5장 #2 | 플랜/결제 서버 강제, user_plans SELECT 전용, 잠금해제 제거 | PB-06-001, PB-06-008, PB-06-009, PB-06-029 |
| Flora-v2 5장 #3 | 빌드 복구, 죽은 코드 정리 | PB-06-002, PB-06-005(죽은 코드는 이식하지 않음, 07장) |
| Flora-v2 5장 #4 | 업로드 계약 통일, 20MB, 스레드풀, HWP | PB-06-015 |
| Flora-v2 5장 #5 | 전체 집필 수정(SSE → 서버 잡), TOC 상한 | PB-06-014, PB-06-013 |
| Flora-v2 5장 #6 | 내보내기 복구(WeasyPrint, ePub3, escape, DB 조회) | PB-06-016, PB-06-017, PB-06-018 |
| Flora-v2 5장 #7 | 프로젝트 영속화(POST /projects, debounce PATCH) | PB-06-010, PB-06-021 |
| Flora-v2 5장 #8 | 페르소나 JSON, 메타데이터 DB 기반 | PB-06-012, PB-06-020 |
| Flora-v2 5장 #9 | v1 엔진 이식(표지·TTS) | PB-06-019(표지). TTS는 Phase 2(PB-F-042, 01장 D2) |
| Flora-v2 5장 #10 | 블로킹 제거 | PB-06-003, PB-06-014 |
| Flora-v2 5장 #11 | 백엔드 오류 처리 | PB-06-007, PB-06-003 |
| Flora-v2 5장 #12 | 의존성·환경 정리, 루트 .env 삭제 | PB-06-003, PB-06-033 |
| Flora-v2 5장 #13 | 배포 설정, CI | PB-06-034, PB-06-004, PB-06-005 |
| Flora-v2 5장 #14 | 백엔드 테스트 | PB-06-031, PB-06-032 |
| `docs/reviews/flora.md` 5장 #1 | 백엔드 인증 통합, `/debug-api-keys` 삭제 | PB-06-007, PB-06-003 |
| flora 5장 #2 | Stripe 서명 검증, user_plans RLS | PB-06-009(Toss로 대체), PB-06-001, PB-06-029 |
| flora 5장 #3 | 파일/URL 하드닝(WAV, cover_url, url_fetcher) | PB-06-015, PB-06-004, PB-06-032(WAV 기능은 폐기) |
| flora 5장 #4 | 동기 호출 비동기화 | PB-06-003, PB-06-014 |
| flora 5장 #5 | 배포 설정 복구(Dockerfile, deploy.yml, Python 3.11) | PB-06-004, PB-06-034, PB-06-005 |
| flora 5장 #6 | requirements 재생성, 로깅, mock은 dev만 | PB-06-003(mock 폴백은 폐기, 07장) |
| flora 5장 #7 | AI 고도화 수정, build-html escape | PB-06-014, PB-06-016 |
| flora 5장 #8 | 플랜 제한 서버 강제 | PB-06-008, PB-06-001 |
| flora 5장 #9 | 4,095줄 페이지 분해 | PB-06-021, PB-06-022 |
| flora 5장 #10 | lib/api.ts 확장 | PB-06-007 |
| flora 5장 #11 | TTS Storage 저장 | Phase 2(PB-F-042). MVP 작업 없음 |
| flora 5장 #12 | waitlist 경로·테이블·시드 수치 제거 | PB-06-028 |
| flora 5장 #13 | db.py 오류 처리, ePub uuid5 | PB-06-010, PB-06-018 |
| flora 5장 #14 | f5-tts 벤더링 제거 | PB-06-033 |
| flora 5장 #15 | 문서·잡파일 정리, 프론트 .env 키 제거 | PB-06-033, PB-06-002 |
| `docs/reviews/flora-publisher.md` 5장 #1 | Vertex 프록시 리전 검증 | PB-06-033(프록시 이식 안 함, 아카이브) |
| flora-publisher 5장 #2 | 미사용 프록시·shim 삭제 | PB-06-033 |
| flora-publisher 5장 #3 | PROXY_HEADER 제거, 세션 인증 | PB-06-033, PB-06-002(번들 비밀 금지) |
| flora-publisher 5장 #4 | `latest` 의존성 고정 | PB-06-005(lockfile·latest 금지 검사) |
| flora-publisher 5장 #5 | index.html, vite define 잔재 | PB-06-033 |
| flora-publisher 5장 #6 | WS 파싱 return, 로그 | PB-06-033 |
| flora-publisher 5장 #7 | 검색 훅, AbortController | PB-06-033(Google Books 검색 폐기) |
| flora-publisher 5장 #8 | Tailwind CDN → 빌드 타임 | PB-06-002 |
| flora-publisher 5장 #9 | 사이드바 반응형 | PB-06-023 |
| flora-publisher 5장 #10 | tsconfig strict, ESLint | PB-06-002 |
| flora-publisher 5장 #11 | 더미 버튼 숨김 | PB-06-023, PB-06-038 |
| flora-publisher 5장 #12 | 아카이브 결정과 이식 판단 | PB-06-033 |
| `docs/reviews/SellingDocs.md` 5장 #1 | PDF 엔진 결정과 데이터 모델 v2 | PB-06-001, PB-06-004 |
| SellingDocs 5장 #2 | Claude.md 작성 | `CLAUDE.md`(이 폴더), PB-06-002 |
| SellingDocs 5장 #3 | 골격 복제와 Supabase 이식 | PB-06-002, PB-06-006 |
| SellingDocs 5장 #4 | 마이그레이션(profiles, books, chapters, credit_logs, exports, RPC) | PB-06-001, PB-06-029(코어 원장 사용) |
| SellingDocs 5장 #5 | 목차 → 챕터별 생성 라우트 | PB-06-011, PB-06-013, PB-06-014 |
| SellingDocs 5장 #6 | WeasyPrint Docker + export/pdf | PB-06-004, PB-06-017 |
| SellingDocs 5장 #7 | ePub 라우트 | PB-06-018 |
| SellingDocs 5장 #8 | 판형 프리셋 + Paged Media CSS | PB-06-016 |
| SellingDocs 5장 #9 | Tiptap, 자동 저장, sanitize | PB-06-022, PB-06-013 |
| SellingDocs 5장 #10 | 대시보드, 크레딧 모달, 랜딩 | PB-06-023, PB-06-024 |
| SellingDocs 5장 #11 | QuickChart 차트 | 폐기(07장 3절 D-06). 작업 없음 |
| SellingDocs 5장 #12 | 공개 서가 + JSON-LD | PB-06-035 |
| SellingDocs 5장 #13 | 결제 + 웹훅 서명 | PB-06-009 |
| SellingDocs 5장 #14 | 크레딧 동시성 테스트, env zod | PB-06-031, PB-06-002 |

## 6. 공용 모듈 요청

| # | 요청 | 이유 | 대상 |
|---|---|---|---|
| R1 | 모듈러 `seed.sql`의 publishing 플랜 features를 01장 4.4절 16키로 갱신 | 현재 4키라 나머지는 서버 기본값(Free)으로 해석된다. Basic 사용자가 의도치 않게 제한될 수 있다 | `_supabase-modular/seed.sql:33`, `:95` |
| R2 | `core.adjust_credits` RPC(음수 허용, service_role 전용) | 팩 환불 시 미사용분 회수와 운영자 조정(PB-06-027)에 필요(`CORE_SPEC.md:237` 제안) | `_platform-core` |
| R3 | `confirm_payment_order` 금액 불일치 시 주문 `failed` 영속화 | 알려진 결함(raise가 UPDATE를 롤백). 제품은 의존하지 않고 운영 알림·취소 요청으로 우회한다. 수정은 코어 담당 | `_platform-core`, `DB_CONVENTIONS.md` 13.2 |
| R4 | `heartbeat_job` 반환값으로 취소 신호 제공 | 실행 중 잡 취소를 제품 테이블(`generation_runs.cancel_requested_at`) 없이도 하려면 필요(`CORE_SPEC.md:307` 제안). 그전까지는 제품 테이블로 처리 | `_platform-core` |
| R5 | fal 웹훅 서명 검증 방식 확인과 verifier 제공 | 미확인 상태(SM 9장). 확인 전에는 request_id 대조만 | `packages/core-ai` |
| R6 | 렌더 서비스를 `services/render-weasyprint`로 이 제품이 소유·운영함을 astro-ai와 계약 확정(요청 본문 상한, 동시성, 장애 연락) | 공용 서비스 운영 책임 명확화 | astro-ai, `_platform-core` |

## 7. 완료 정의

| 조건 | 확인 |
|---|---|
| 빌드·타입·린트 | `npm run build`, `npx tsc --noEmit`, `npm run lint`(web, worker) 녹색 |
| Python | `pytest`(engine, render) 녹색, `ruff` 통과 |
| SQL | `node check.mjs mod ... 1000_publishing.sql`, `node check.mjs mono 0001 0002 seed` OK |
| RLS 스모크 | PB-06-029 전 항목 통과(모듈러, 모놀리스) |
| 결제 E2E | PB-06-030 시나리오 5개 통과(Toss 테스트 키) |
| 핵심 플로우 E2E | PB-06-037 통과 |
| 작업 | 2절 P0·P1 작업 전부 완료(P2 제외) |

P0 작업과 대응 테스트:

| P0 작업 | 대응 테스트 작업 |
|---|---|
| 001, 008 | 029, 031 |
| 002, 006, 007 | 031, 037 |
| 003, 004, 015, 016, 017, 018 | 032, 031 |
| 009 | 030 |
| 010, 011, 012, 013, 014, 019 | 031, 037 |
| 021, 023, 024, 025 | 037, 038 |
| 005, 034 | CI 자체 실행 결과, 스테이징 배포 확인(037) |
