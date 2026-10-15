# 06 에이전트 작업 계획: NOMAD Book Trailer (book-trailer)

작성일 2026-10-15. 작업 60개(`TR-06-001`~`TR-06-060`, 인증 단계 B·C 3개 포함). 모델 기준은 `docs/products/_platform-core/DOC_TEMPLATE.md` 1장(Fable 결제·권한·RLS·데이터 모델, Opus 기능·API·테스트 설계, Sonnet UI·컴포넌트·문서, Haiku 반복·정리). 경로 약어: `web/` = `apps/web/`, `api/` = `apps/api/`, `orch/` = `workers/trailer-orchestrator/`, `rend/` = `services/trailer-renderer/`, `comp/` = `packages/trailer-compositions/`.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 소유 | 작업마다 소유 경로를 디렉토리 단위로 나눈다. 같은 파일을 두 작업이 만지지 않는다. 남의 경로에 필요한 변경은 그 작업에 1줄 요청으로 남긴다(`log.md`) |
| 스키마 | `supabase/**`와 모듈러 조각 변경은 TR-06-001만. 모놀리스는 변환 스크립트로만 만든다 |
| 계약 우선 | 잡 payload·장면·스냅샷 스키마(04장 4절)는 TR-06-012(TS)와 TR-06-015(Python)가 먼저 만들고, 다른 작업은 import만 한다. 동치 테스트는 TR-06-024 |
| 디자인 순서 | 화면 작업(W4)은 디자인 시스템 4단계(TR-06-011)가 끝난 뒤 시작한다(`DESIGN_SYSTEM.md` 4장) |
| 코어 | `_platform-core`, `_supabase-modular`의 다른 파일, `packages/core-*`를 고치지 않는다. 필요하면 6절에 요청 |
| 테스트 짝 | 모든 P0 작업은 수용 기준을 확인하는 테스트(단위·통합·E2E·스모크)를 같은 작업 안에 두거나 5장 테스트 작업이 덮는다 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| TR-06-001 | DB 조각 적용, 모놀리스 변환 스크립트, 타입 생성 | `supabase/**`(tests 제외), `scripts/db/**`, `web/src/types/supabase.ts` | 없음 | P0 | M | Fable | `supabase db reset` 오류 0. `check.mjs --vector` 모듈러·모놀리스 OK. 변환 스크립트를 다시 돌리면 diff 0. `ai_routing_settings` app `trailer` 16행 | 05장 9절, 리뷰 SM 5장 #1, #6 |
| TR-06-002 | RLS·권한 스모크 연결 | `supabase/tests/**`, `scripts/test-rls/**` | 001 | P0 | S | Fable | `rls_smoke.sql` 124/124(모듈러·모놀리스), CI 잡으로 실행 | 05장 9절, 리뷰 SM #1, #15, Toon #2 |
| TR-06-003 | web 골격: proxy, env 검증, 로거, 서버 클라이언트 2종, 공통 lib | `web/src/{proxy.ts,lib/**}`(`lib/auth` 제외), `web/next.config.ts`, `web/src/app/layout.tsx` | 없음 | P0 | M | Opus | 보호 경로 미로그인 302. env 누락 시 기동 실패. 쿠키 클라이언트와 service 클라이언트가 다른 모듈이고 service는 `src/server/**`에서만 import(린트) | 리뷰 SM #3, #4, #8, #10, #14 |
| TR-06-004 | Stage A Mock 로그인(로컬 시드 계정, `/api/dev/login`) | `web/src/lib/auth/`, `web/src/app/(auth)/`, `web/src/components/auth/`, `web/src/app/api/dev/login/`, `scripts/dev/` | 001, 003 | P0 | M | Opus | 페르소나 9종 중 7종 로그인 후 `/home`(`suspended` 거부, `no_app` 온보딩). 쿠키·localStorage 역할 Mock 0건(CI 검색). 원격 Supabase에서 라우트 404 | 확정 결정 22, `AUTH_ROADMAP.md` 2장 |
| TR-06-005 | 오케스트레이터 골격: 클레임 루프, 잡 토큰 클라이언트, 실패 순서(`fail_job` → `fail_run`), 타임아웃 | `orch/src/{index.ts,core/**}`, `orch/package.json` | 001 | P0 | M | Opus | `trailer.ai` 큐 잡을 클레임해 빈 단계 성공·실패 처리. 실패 시 환불 원장 행 생성 확인 | 02장 4절, 리뷰 SM #3, #7, #10 |
| TR-06-006 | 렌더러 골격: Docker(Node 20, Chrome Headless Shell, OFL 서체 8종), 클레임 루프, 빈 컴포지션 렌더 | `rend/{Dockerfile,package.json,src/index.ts,src/core/**}` | 001 | P0 | M | Opus | 컨테이너에서 1초 테스트 컴포지션 렌더 성공. 서체 8종이 네트워크 없이 로드 | 02장 1·4절, 리뷰 SM #7, Toon #10 |
| TR-06-007 | 디자인 레퍼런스 확정(1단계) | `docs/file/03-설계/디자인/DESIGN.md` 1절 | 없음 | P0 | S | Sonnet | 08장 1절과 03장 4.1절 표 반영, 고문(Fable) 검토 기록 | `DESIGN_SYSTEM.md` 4장 |
| TR-06-008 | 앱 토큰 `tokens.css`(2단계) | `web/src/styles/tokens.css` | 007 | P0 | S | Sonnet | 08장 3.7절 값 그대로. 라이트·다크 대비 AA(axe). `tailwind.config.js` 없음 | 08장 3장 |
| TR-06-009 | 기본 컴포넌트 + `/dev/components` | `web/src/components/ui/**`, `web/src/app/dev/components/**` | 008 | P0 | L | Sonnet | 08장 11.1·11.3절 배리언트 전부, 라이트/다크 x 컴팩트/기본 스크린샷 | 08장 11장 |
| TR-06-010 | 비주얼 검토(3단계, 사람) | (산출물) 스크린샷 수정 기록 | 009 | P0 | M | 사람 | 컴포넌트마다 상태·크기 배리언트를 보고 수치 수정 기록 | `DESIGN_SYSTEM.md` 4장 3단계 |
| TR-06-011 | 정답 확정(4단계) | `docs/file/03-설계/디자인/{DESIGN,COMPONENTS}.md` | 010 | P0 | S | Opus | 문서가 코드 토큰·컴포넌트와 일치 | `DESIGN_SYSTEM.md` 4장 4단계 |
| TR-06-012 | 영상 토큰과 계약 스키마(TS) | `comp/src/{tokens,schema}/**`, `comp/package.json` | 007 | P0 | M | Opus | 캔버스·타입·모션·안전 영역·`minReadMs` 상수, 04장 4.2~4.4절 zod 스키마. 단위 테스트(포맷별 `u` 계산, 노출 시간) | 08장 5·7장, 04장 4절 |
| TR-06-013 | 결제·플랜 게이팅·크레딧 단가 상수 | `web/src/server/billing/**`, `web/src/server/pricing.ts`, `web/src/app/api/billing/**`, `web/src/app/api/webhooks/toss/**` | 003 | P0 | M | Fable | 01장 4장 단가표 단위 테스트. PM001이면 `fail_payment_order` + 취소. 웹훅 서명 없으면 401 | 리뷰 SM #2, #6, Toon #11 |
| TR-06-014 | 결제 E2E(Toss 테스트 키) | `e2e/billing/**` | 013, 048 | P0 | M | Opus | 구독 creator 결제 → 엔타이틀먼트·월 크레딧. 팩 구매 → 잔액. 금액 위조 → failed | `DOC_TEMPLATE.md` 2.7절 필수 작업 |
| TR-06-015 | AI 서비스 설치 + trailer 확장 골격, Python 계약 스키마 | `api/**`(공용 설치), `api/app/ai/products/trailer/{__init__,schema}.py` | 001 | P0 | M | Opus | 서명 토큰 검증, 조직 격리 테스트, pydantic 스키마가 04장 4절과 같다 | 확정 결정 13 |
| TR-06-016 | AI 게이트: 대화, 서명·잡 토큰, 턴 선차감·정산·환불, 국외 이전 온보딩 | `web/src/app/api/{ai,internal,onboarding}/**`, `web/src/server/ai/**`, `web/src/server/ai-pricing.ts`, `web/src/app/onboarding/**` | 003, 015 | P0 | L | Fable | 잡 토큰은 running 잡의 org·user로만 발급. 채팅 실패 시 전액 환불. 정산 상한 5 | `AI_ARCHITECTURE.md` 2·7장 |
| TR-06-017 | 라우팅 seed 검증 + AI 보안 테스트 | `scripts/ai-routing/**`, `api/tests/trailer/security/**` | 015, 016 | P0 | M | Fable | 02장 5.1절 16행 = DB. 미동의 조직은 상용 제공자 0. 다른 조직·다른 책 컬렉션 검색 0 | 확정 결정 17 |
| TR-06-018 | 업로드·원고 파서 | `api/app/ai/products/trailer/parsers/**`, `web/src/server/uploads/**`, `web/src/app/api/uploads/**` | 003, 015 | P0 | M | Opus | 5형식 파싱, 매직바이트, 20MB, 스캔 PDF 오류, 20만 자 p95 60초 | TR-F-010 |
| TR-06-019 | 책 도메인: 서지·권리·붙여넣기·구매 링크·통계 API | `web/src/server/{books,links}/**`, `web/src/app/api/books/route.ts`, `web/src/app/api/books/[id]/{route.ts,rights,paste,links,stats}/**`, `web/src/app/api/links/**` | 001, 003 | P0 | M | Opus | 권리 확인 후 감사 로그. 11번째 링크 `TR005`. 통계 7/30일 | TR-F-011~014, 리뷰 SM #8 |
| TR-06-020 | 공개 리다이렉트 `/b/[code]` | `web/src/app/b/**`, `web/src/server/public/**` | 019 | P0 | S | Opus | 302, 없는 코드 404, IP당 분당 60 초과 429, IP는 일 단위 솔트 sha256만 | TR-F-111, 리뷰 SM #4, #5(빌드), #12 |
| TR-06-021 | 표지 팔레트 추출 + 브랜드 키트 | `rend/src/handlers/kit/**`, `web/src/server/brand-kits/**`, `web/src/app/api/brand-kits/**` | 006, 012 | P0 | M | Opus | 고정 표지 10장 팔레트 기대값 일치(결정성), 대비 보정 | 08장 4장, TR-F-013 |
| TR-06-022 | 그래프 `trailer.digest` + RAG 색인 + 위키 초안 | `api/app/ai/graphs/trailer_digest.py`, `api/app/ai/products/trailer/{knowledge,wiki_config}.py` | 015, 018 | P0 | L | Opus | 20만 자 p95 5분. 장 나누기 평가셋(제목 패턴 5종). 재시도 시 같은 실행 재개 | TR-F-020, TR-F-101 |
| TR-06-023 | 그래프 `trailer.brief` + 인용 원고 대조 + compliance 규칙 | `api/app/ai/graphs/trailer_brief.py`, `api/app/ai/products/trailer/quotes.py`, `api/app/ai/compliance/trailer.py`, `packages/trailer-rules/**` | 022 | P0 | L | Opus | 3안, 인용 글자 일치 검증 100%, 스포일러 구간 제외, 금지 문구 평가셋(실적·보장·할인 15% 초과) FAIL | TR-F-021~023, TR-F-080 |
| TR-06-024 | 실행 서버·오케스트레이터 그래프 단계·스키마 동치 테스트 | `web/src/server/runs/**`, `web/src/app/api/books/[id]/digest/**`, `web/src/app/api/trailers/[id]/{brief,storyboard}/**`, `orch/src/steps/{graph,parse}/**`, `tests/contract/**` | 005, 016, 018 | P0 | M | Opus | 분석·브리프·스토리보드 실행 → `finish_run`. zod·pydantic 동치 테스트 통과 | 02장 4절, 리뷰 SM #7, #9 |
| TR-06-025 | 그래프 `trailer.storyboard` | `api/app/ai/graphs/trailer_storyboard.py` | 023, 012 | P0 | L | Opus | 목표 길이 ±10%, 39장면 이하, 글자 노출 시간 공식, 엔드카드 미포함, 문법 6종 샘플 | TR-F-031 |
| TR-06-026 | 트레일러·장면 도메인 API(설정, 장면 편집, 순서, 수동 브리프) | `web/src/server/{trailers,scenes}/**`, `web/src/app/api/trailers/route.ts`, `web/src/app/api/trailers/[id]/{route.ts,briefs,scenes,scene-order}/**`, `web/src/app/api/scenes/[id]/route.ts` | 001, 003 | P0 | M | Opus | `TR409` 충돌 처리, 엔드카드 보호 `TR007`, viewer 쓰기 0행 | TR-F-022, 032, 034 |
| TR-06-027 | 이미지 단계(fal, 스타일 고정) | `orch/src/steps/image/**`, `web/src/app/api/scenes/[id]/image/**` | 024, 012 | P0 | M | Opus | 같은 seed 재현, 금지 접미어, 안전 차단 시 환불 + 안내 | 02장 5.4절, 리뷰 Toon #5 |
| TR-06-028 | 내레이션 단계(같은 목소리) + 전체 다시 녹음 + 샘플 | `orch/src/steps/tts/**`, `web/src/app/api/scenes/[id]/narration/**`, `web/src/app/api/trailers/[id]/narration/**` | 024 | P0 | M | Opus | 다른 목소리 결과 거부, 같은 제공자 재시도 3회, 전체 다시 녹음 비용 표시 | 02장 5.3절 |
| TR-06-029 | 음악 카탈로그 조회·사용자 음악 업로드·권리 확인 | `web/src/server/music/**`, `web/src/app/api/music/**` | 019 | P0 | M | Opus | 원본 경로 비노출, 미리듣기만 공개, 업로드 권리 없으면 렌더 `TR011` | 리뷰 Toon #2, #6, #8 |
| TR-06-030 | Remotion 컴포지션 6종 + 장면 컴포넌트 8종 + 자막 | `comp/src/{compositions,scenes,motion,captions}/**` | 012 | P0 | L | Opus | 08장 6·7·9장 규격, 포맷 5종, 안전 영역 안 글자, 스크림 대비 4.5:1 | 08장, 리뷰 Toon #3, #4, #7 |
| TR-06-031 | 렌더 파이프라인: 스냅샷 → props, 워터마크·AI 표시, 포스터·SRT·ZIP, `start_render`/`finish_render` 서버 | `rend/src/handlers/render/**`, `web/src/server/renders/**`, `web/src/app/api/trailers/[id]/renders/**`, `web/src/app/api/renders/[id]/{download,rerender}/**` | 006, 026, 030 | P0 | L | Fable | 워터마크·AI 표시는 스냅샷·렌더 행 값만 사용(요청 입력 무시). 출력 경로 검사. 60초 1080p p95 6분 | 02장 4절, 05장 7절, 리뷰 Toon #1, #9, #10 |
| TR-06-032 | 브라우저 미리보기(Remotion Player) | `web/src/components/preview/**` | 030, 009 | P0 | M | Sonnet | 첫 프레임 2초, 프록시 에셋, 워터마크 오버레이, 다운로드 경로 없음, 안전 영역 토글 | TR-F-051, 리뷰 Toon #1 |
| TR-06-033 | 홈·책 목록·책 상세 화면 | `web/src/app/(app)/home/**`, `web/src/app/(app)/books/page.tsx`, `web/src/app/(app)/books/[id]/page.tsx`, `web/src/app/(app)/books/[id]/_tabs/**`, `web/src/components/books/detail/**` | 011, 019 | P0 | M | Sonnet | 03장 3.1·3.3절, 빈 상태·로딩·오류·권한 없음 5종, 실데이터만 | 03장, 리뷰 SM #9 |
| TR-06-034 | 책 등록 마법사(원고·서지·권리·표지 키트) | `web/src/app/(app)/books/new/**`, `web/src/components/books/{wizard,rights,palette}/**` | 011, 018, 019, 021 | P0 | M | Sonnet | 중간 저장·뒤로 가기, `RightsGate`, `PaletteEditor` 대비 표시 | 03장 3.2절 |
| TR-06-035 | 트레일러 만들기 + 브리프 비교 화면 | `web/src/app/(app)/trailers/new/**`, `web/src/app/(app)/trailers/[id]/brief/**`, `web/src/components/brief/**` | 011, 024, 026 | P0 | M | Sonnet | `BriefCompare` 3열/탭, `QuoteHighlight` 검증 배지, 버전 목록 | 03장 3.4절 |
| TR-06-036 | 작업실(장면 스트립·속성·미리보기 배치·단축키·실행 취소 1단계) | `web/src/app/(app)/trailers/[id]/studio/**`, `web/src/components/studio/**` | 011, 026, 027, 028, 032 | P0 | L | Sonnet | 03장 3.5절, 키보드 조작, 디바운스 저장 + 충돌 안내, 768px 이하 시트 | 03장 3.5절, 리뷰 Toon #4, #6 |
| TR-06-037 | 렌더 기록·게시 화면 | `web/src/app/(app)/trailers/[id]/{renders,publish}/**`, `web/src/components/{render,publish}/**` | 011, 031, 039 | P0 | M | Sonnet | `RenderMonitorRow` 상태 5종, 실패 원인 한 줄 + 로그, 대가성 문구 잠금 표시 | 03장 3.6·3.7절 |
| TR-06-038 | 설정 화면(프로필·조직·결제·키트·AI) | `web/src/app/(app)/settings/{profile,org,billing,brand-kits,ai}/**`, `web/src/app/(app)/settings/layout.tsx` | 011, 013, 016 | P0 | M | Sonnet | 결제 시트, 국외 이전 동의 토글, 키트 편집 | 03장 1절 |
| TR-06-039 | 메타데이터 그래프 + 메타 API | `api/app/ai/graphs/trailer_meta.py`, `web/src/server/meta/**`, `web/src/app/api/meta/**`, `web/src/app/api/trailers/[id]/meta/**` | 023, 019 | P0 | M | Opus | 플랫폼 4개, 단축 링크 태그, 해시태그 검사, 대가성 문구는 DB 트리거만 | TR-F-060, 061 |
| TR-06-040 | Dify 앱 `trailer-chat` + `/tools/answer` 코치 | `infra/dify/**`, `api/app/ai/tools/trailer/**` | 016, 022 | P0 | M | Opus | 출처(장·문단) 필수, 이 책 컬렉션만, 평가셋 30문항(제안) 재현율 0.8 | TR-F-100 |
| TR-06-041 | 채팅 위젯 + `/coach` | `web/src/components/ai-chat/**`, `web/src/app/(app)/coach/**` | 040, 009 | P0 | M | Sonnet | 스트리밍, 출처 칩, "인용 장면으로", 턴 비용 표시 | 03장 3.8절 |
| TR-06-042 | 음성 API + UI(대화·받아쓰기·읽어 주기·샘플) | `web/src/app/api/voice/**`, `web/src/components/voice/**` | 016 | P0 | M | Opus | 60초 상한, 녹음 고지, 권한 거부 시 텍스트, 샘플 대체 없음 | TR-F-102, 103 |
| TR-06-043 | 책 설정 위키 화면 + API | `web/src/components/wiki/**`, `web/src/app/(app)/books/[id]/wiki/**`, `web/src/app/api/wiki/**` | 022, 009 | P0 | M | Sonnet | 목록·편집·이력·점검, 삭제는 보관 | TR-F-101 |
| TR-06-044 | 랜딩 + 3D 히어로 + 3D 영상 단계 + 샘플·요금 페이지(JSON-LD VideoObject) | `web/src/app/(marketing)/**`, `web/src/components/hero3d/**`, `web/public/hero/**` | 009 | P0 | L | Sonnet | `HERO_3D.md` 4·6절, 03장 4절, 카피 금지 문구 0건, 샘플은 실제 결과만 | 확정 결정 15, 리뷰 Toon #13, #14 |
| TR-06-045 | 운영자 카탈로그 콘솔(문법·템플릿·음악·라이선스 검증) | `web/src/app/(ops)/**`, `web/src/server/ops/**` | 001, 009 | P0 | M | Opus | 라이선스 근거 입력 없이는 공개 불가(DB), 플랫폼 관리자만 | TR-F-120, 리뷰 Toon #6, #8 |
| TR-06-046 | 통합 흐름 테스트(업로드 → 분석 → 브리프 → 스토리보드 → 에셋 → 렌더 → 내려받기) | `tests/integration/**` | 031, 039 | P0 | M | Opus | 가짜 제공자(LLM·fal·TTS 목) + 실제 DB·렌더러로 끝까지 통과, 실패 주입 시 환불 | 리뷰 SM #15 |
| TR-06-047 | 렌더 품질 회귀: 결정성, 안전 영역, 한글 서체, 벤치마크 | `rend/tests/**`, `comp/tests/**` | 031 | P0 | M | Opus | 같은 스냅샷 프레임 해시 일치, 장면 8 x 포맷 4 스냅샷, 글자 상자 안전 영역 침범 0, 렌더 시간 측정 기록 | 08장 14장 |
| TR-06-048 | E2E 인증 페르소나 globalSetup + 주요 화면 E2E | `e2e/setup/**`, `e2e/app/**` | 004, 036 | P0 | M | Opus | 페르소나별 `storageState`, viewer 읽기 전용, 무료 체험 흐름 E2E | `AUTH_ROADMAP.md` 2장, 리뷰 Toon #12 |
| TR-06-049 | CI 게이트(tsc, lint, build, pytest, sqlcheck, 모드 분기 금지 검색, hex 린트) | `.github/workflows/**`, `scripts/ci/**` | 001 | P0 | S | Haiku | 하나라도 실패하면 머지 불가 | 리뷰 SM #5, #11, #14, #15 |
| TR-06-050 | 탈퇴·책 삭제 purge | `web/src/server/account/**`, `web/src/app/api/account/**`, `orch/src/steps/purge/**` | 019 | P0 | M | Opus | 30일 뒤 Storage·청크·위키·렌더 0건 | TR-F-121 |
| TR-06-051 | 법적 고지 페이지·문구(약관, 개인정보, AI 표시 안내) | `web/src/app/legal/**`, `web/src/content/legal/**` | 009 | P0 | S | Haiku | 01장 6장 항목 전부 반영, 금지 문구 검사 통과 | 01장 6장 |
| TR-06-052 | 크론: 정산, 보존 만료, reconcile, 승인 만료 | `orch/src/cron/**` | 005, 031 | P0 | S | Opus | 02장 4절 스케줄 표 동작, 만료 7일 전 알림 | 02장 4절 |
| TR-06-053 | Stage B: Google + 이메일, 콜백, 첫 로그인 약관 | `web/src/app/auth/callback/**`, `web/src/app/onboarding/terms/**`(004의 `(auth)`·`components/auth` 이어받기) | G1, 004 | P0 | M | Fable | `AUTH_ROADMAP.md` 5.3절 B-1~B-6 | 확정 결정 22 |
| TR-06-054 | C1 카카오 | `web/src/lib/auth/providers/kakao.ts`, `web/src/app/(app)/settings/login-methods/**` | G2, 053 | P1 | S | Opus | C1-1~C1-5 | `AUTH_ROADMAP.md` 7.1절 |
| TR-06-055 | C2 네이버(OIDC 또는 브리지) | `web/src/lib/auth/providers/naver.ts`, `web/src/app/auth/naver/**`, `scripts/auth/**` | G2, 053 | P1 | M | Fable | C2-1~C2-6, 경로 결정 `[DECISION]` | `AUTH_ROADMAP.md` 7.2절 |
| TR-06-056 | FLORA 가져오기 | `web/src/server/import/**`, `web/src/app/api/import/**`, `web/src/components/books/flora/**` | 019, 034 | P1 | M | Fable | 두 엔타이틀먼트·creator 이상만, 원고 md 내보내기 → 파싱, 모놀리스 `TR010` | TR-F-015 |
| TR-06-057 | 외부 승인 링크 | `web/src/server/reviews/**`, `web/src/app/api/reviews/**`, `web/src/app/review/**` | 031 | P1 | M | Fable | 토큰 원문 1회 표시·sha256만 저장, 만료 `TR009`, 로그인 버튼 없음 | TR-F-071 |
| TR-06-058 | YouTube 업로드(sns-uploader 소비), 채널 연결, 변주 부족 경고 | `web/src/server/channels/**`, `web/src/app/(app)/settings/channels/**`, `web/src/app/api/channels/**`, `web/src/app/api/renders/[id]/upload/**`, `orch/src/steps/upload/**` | 031, 039 | P1 | M | Opus | OAuth state 서버 발급, 1크레딧, 쿼터 재예약, 같은 템플릿 7일 3편 경고 | TR-F-063, 리뷰 SM #4, #12 |
| TR-06-059 | 음악 BPM 맞춤 컷 길이 | `comp/src/music/**`, `rend/src/beat/**` | 030, 031 | P1 | M | Opus | drop 큐가 마디 경계 ±1프레임 | 08장 7.5절 |
| TR-06-060 | 팀 멤버 초대(publisher 5인) | `web/src/app/(app)/settings/members/**`, `web/src/server/team/**` | 038 | P1 | S | Opus | `members_max` 초과 거부, viewer 역할 | TR-F-072 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 003, 007 → 002, 004, 005, 006, 015 | 3 → 5 | 없음 | 로컬 DB, 웹·워커·렌더러·AI 서비스 골격, Mock 로그인 |
| W1 | 012, 013, 016, 018, 019, 026, 049 | 7 | W0 | 계약 스키마, 결제, AI 게이트, 업로드, 책·장면 API, CI |
| W1-D | 008 → 009 → 010(사람) → 011 | 1씩 | 007 | 디자인 시스템 1~4단계 |
| W2 | 017, 020, 021, 022, 024, 029, 030, 050 | 8 | W1 | AI 보안 테스트, 리다이렉트, 키트, 분석 그래프, 실행 서버, 음악, 컴포지션, purge |
| W3 | 023, 027, 028, 031, 032, 045 | 6 | W2 | 브리프 그래프, 이미지·내레이션, 렌더, 미리보기, 운영 콘솔 |
| W4 | 025, 033, 034, 035, 036, 038, 039, 040, 042, 043, 044, 051, 052 → 037, 041 | 13 → 2(화면은 011 이후) | W3 + 011 | 스토리보드·메타 그래프, 전체 화면, 코치·음성·위키, 랜딩, 법적 고지, 크론 |
| W5 | 046, 047, 048 → 014 | 3 → 1 | W4 | 결제 E2E, 통합·렌더 회귀·E2E → 공개 베타 후보 |
| W6 | 053 | 1 | G1(사람 판정) | Google + 이메일 로그인 → 공개 베타 |
| W7 | 054, 055, 056, 057, 058, 059, 060 | 7 | G2(카카오·네이버) / 베타 피드백 | P1 기능 |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 10 | 16.7% | 17.6% (21/119) |
| Opus | 34 | 56.7% | 56.3% (67/119) |
| Sonnet | 13 | 21.7% | 22.7% (27/119) |
| Haiku | 2 | 3.3% | 1.7% (2/119) |
| 사람 | 1 | 1.7% | 1.7% (2/119) |
| 합계 | 60 | 100% | 119 |

## 5. 리뷰 작업 흡수표

이식 원천 리뷰의 5장 작업 목록(NOMAD Shorts Maker 15, Toon-Factory 14)을 흡수한 위치. 원천 코드를 옮기지 않으므로 "해당 없음"은 이 제품에 그 기능이 없는 경우다.

| 리뷰 작업 | 내용 요약 | 흡수 작업 ID |
|---|---|---|
| `docs/reviews/NOMAD_Shorts_Maker.md` 5장 #1 | 크레딧 RPC 봉쇄 + 회귀 테스트 | TR-06-001, 002 |
| SM #2 | 결제 경로 단일화, 웹훅 서명 필수 | TR-06-013, 014 |
| SM #3 | 서비스 클라이언트 도입, `x-internal-call` 제거 | TR-06-003, 005, 006 |
| SM #4 | 인증 가드, Mock 조건, OAuth state | TR-06-003, 004, 058 |
| SM #5 | 빌드 복구(tsc, params Promise) | TR-06-049, 020 |
| SM #6 | 제품 경계·org 기준 스키마·플랜 단일 소스 | TR-06-001, 013 |
| SM #7 | 파이프라인 재설계(독립 워커, 큐 분리, 계약) | TR-06-005, 006, 024, 031 |
| SM #8 | 전 API zod 검증, 조직 헬퍼 통합 | TR-06-003, 019, 026 |
| SM #9 | 대시보드 실데이터, 난수 지표 제거 | TR-06-033, 037, 044(샘플은 실제 결과만) |
| SM #10 | AI 클라이언트 단일화, env zod 검증 | TR-06-003, 015, 016 |
| SM #11 | reactflow executor 직접 호출 교체 | 해당 없음(자동화 캔버스 기능이 없다) |
| SM #12 | YouTube 업로드 스트리밍 | TR-06-058 |
| SM #13 | 루트 문서 정리 | 해당 없음(신규 저장소. 정본은 이 기획 폴더와 `docs/file/`, TR-06-011) |
| SM #14 | 로깅 정리, sanitize | TR-06-003(공용 logger), 049(린트) |
| SM #15 | 크레딧·웹훅·OAuth·RLS 통합 테스트, CI | TR-06-002, 017, 046, 049 |
| `docs/reviews/Toon-Factory.md` 5장 #1 | 0단계 기획 보강(스키마, 영상 변환 규칙, 플랜 한도) | 이 기획서(05장, 08장) + TR-06-001 |
| Toon #2 | 마이그레이션 + RLS + Storage 버킷 | TR-06-001, 002 |
| Toon #3 | 골격 이식(Next 16, supabase lib, 토큰) | TR-06-003, 008 |
| Toon #4 | 편집 상태 모델, 실행 취소, 디바운스 저장 | TR-06-036(장면 단위 상태 + `save_scene` 낙관적 동시성) |
| Toon #5 | Fabric.js 캔버스 어댑터 | 해당 없음(자유 캔버스 편집 대신 템플릿 컴포지션, TR-06-030) |
| Toon #6 | 3단 에디터 UI | TR-06-036 |
| Toon #7 | 표정 교체·말풍선 편집 | 해당 없음(말풍선 없음). 텍스트 장면은 TR-06-030 |
| Toon #8 | 에셋 카탈로그 API + 서명 URL 플랜 검사 | TR-06-029, 045 |
| Toon #9 | PNG/ZIP 내보내기 + 워터마크 | TR-06-031(포스터 PNG, ZIP, 워터마크) |
| Toon #10 | MP4 렌더 워커, 진행률 Realtime | TR-06-006, 031 |
| Toon #11 | Toss 정기결제 + 웹훅 서명 | TR-06-013 |
| Toon #12 | 편집기 단위·통합 테스트, RLS 테스트 | TR-06-002, 047, 048 |
| Toon #13 | 랜딩·가격 페이지, 첫 진입 5분 경험 | TR-06-044, 034(마법사), 01장 KPI "첫 트레일러 20분" |
| Toon #14 | 공개 작품 페이지 + JSON-LD | TR-06-044(샘플 페이지 VideoObject JSON-LD) |

## 6. 공용 모듈 요청

| # | 요청 | 대상 | 이유 | 시점 |
|---|---|---|---|---|
| R-T1 | 모듈러 `seed.sql`에 trailer 플랜 3·팩 3 반영 | `_supabase-modular/seed.sql` | 지금은 조각 12절이 do nothing으로 넣는다(nomad-docs C-3과 같은 처리) | W0 |
| R-T2 | `DB_CONVENTIONS.md` 2장 번호 표에 `2600~2699 trailer`, 1장 SQLSTATE 접두사에 `TR` 등록 | `_platform-core/DB_CONVENTIONS.md` | 표에 2400·2500도 아직 없다 | W0 |
| R-T3 | affiliate `source_app`에 `trailer` 추가와 서점 제휴 제공자(알라딘 TTB 등) 범용화 검토 | `0006_core_affiliate.sql` | 범용화되면 `purchase_links`의 제휴 링크를 코어로 옮길 수 있다(지금은 제품 테이블, 05장 6절) | Phase 2 |
| R-T4 | 오케스트레이터 잡 토큰 표준화 | `AI_ARCHITECTURE.md` 2.1절 | nomad-video R-V5와 같은 요청 | W1 |
| R-T5 | `AUTH_ROADMAP.md` 8장 매트릭스에 trailer 행: open, 작가·출판사, 추가 페르소나 creator·publisher 팀, B Google + 이메일, C1 P1, C2 P1 | `_platform-core/AUTH_ROADMAP.md` | 확정 결정 22 적용 | W0 |
| R-T6 | `SHARED_MODULES.md` 11장 sns-uploader 소비자 목록에 trailer 추가 | `_platform-core/SHARED_MODULES.md` | YouTube 업로드(P1) | W7 전 |
| R-T7 | `REFERENCES.md`에 book-trailer 절 추가(북트레일러·출판 마케팅 사이트 URL 확인 후) | `_design-guide/REFERENCES.md` | 지금은 다른 제품 후보를 다른 방식으로만 인용한다(03장 4.1절) | W1-D |
| R-T8 | Remotion 렌더러를 공용 렌더 서비스로 승격 검토 | `_platform-core` | toon-factory MP4, nomad-video Track C/D가 같은 렌더러를 쓸 수 있다. 라이선스는 조직 단위(D-2) | Phase 2 |

## 7. 완료 정의

| 항목 | 기준 |
|---|---|
| 빌드 | `pnpm -F web lint && pnpm -F web typecheck && pnpm -F web build`, 오케스트레이터·렌더러·컴포지션 패키지 typecheck·test, `pytest apps/api` 오류 0 |
| DB | `check.mjs --vector` 모듈러·모놀리스 OK, `rls_smoke.sql` 124/124(모듈러·모놀리스) |
| 결제 | TR-06-014 결제 E2E 통과 |
| AI | TR-06-017 보안 테스트, 그래프 평가셋(분석 장 나누기, 인용 대조, 금지 문구, 코치 재현율) 통과 |
| 렌더 | TR-06-047 결정성·안전 영역·서체 통과, 60초 1080p p95 6분 이하(측정 기록) |
| 흐름 | TR-06-046 통합, TR-06-048 E2E(무료 체험 흐름) 통과 |
| 디자인 | `DESIGN_PRINCIPLES.md` 7단계 체크리스트 12항목, 03장 4.4절 기본값 검토 |
| 법·문구 | 01장 6장 항목이 화면·약관에 반영, 랜딩·영상 카피 금지 문구 0건 |
| 인증 | G1·G2 사람 판정과 단계별 수용 기준(`AUTH_ROADMAP.md` 4·6장) |
| 작업 | 2절 P0 작업 전부 완료, 각 수용 기준 확인 기록 |

## 8. 인증 단계 작업 (확정 결정 22)

### 8.1 작업 목록 (2절과 같은 열, 요약)

| ID | 단계 | 우선순위 | 모델 | 게이트 |
|---|---|---|---|---|
| TR-06-004 | A Mock | P0 | Opus | 없음(W0) |
| TR-06-053 | B Google + 이메일 | P0 | Fable | G1 |
| TR-06-054 | C1 카카오 | P1 | Opus | G2 |
| TR-06-055 | C2 네이버 | P1 | Fable | G2 |

### 8.2 게이트와 웨이브

G1: MVP 기능(W0~W5)이 Mock 로그인으로 모두 동작하고 공개 베타 준비가 되면 사람이 판정(`AUTH_ROADMAP.md` 4장) → W6. G2: Google 로그인 안정(장애 0, 2주) 후 사람이 판정(6장) → W7. 판정은 task `log.md`에 `[DECISION] G1 통과`, `[DECISION] G2 통과`로 남긴다.

### 8.3 코어 요청

R-T5(매트릭스 행). 네이버 브리지를 채택하면 코어 `staged/0010_core_auth_identity_links.sql` 1회 적용 요청을 추가한다.
