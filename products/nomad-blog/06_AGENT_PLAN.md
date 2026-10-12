# 06 에이전트 작업 계획: NOMAD Blog

작성일 2026-10-12. 작업 ID 접두사 `BL`은 `DB_CONVENTIONS.md` 1장 SQLSTATE 접두사와 같다. 경로는 `apps/nomad-blog/` 기준(제안), `workers/`와 `packages/blog-render/`는 모노레포 루트 기준이다.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 디렉토리는 한 작업만 만든다. 다른 작업은 그 디렉토리의 공개 인터페이스(`index.ts`)만 import |
| 공용 인터페이스 선행 | `src/server/*`의 타입 시그니처는 W0의 BL-06-003이 빈 모듈(`index.ts` + 타입)로 먼저 만든다. 이후 작업은 자기 디렉토리 안만 채운다 |
| 코어 불변 | `packages/core-*`, `_platform-core`, `_supabase-modular`의 다른 파일은 수정하지 않는다. 필요하면 6절 요청 |
| DB 변경 | `supabase/`는 BL-06-001만 쓴다. 다른 작업이 스키마 변경이 필요하면 BL-06-001 담당(Fable)에게 요청 |
| 테스트 | 각 테스트 작업은 `tests/<영역>/` 하위 고유 디렉토리를 소유 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| BL-06-001 | DB 조각 적용, 모놀리스 사본 동기화, 타입 생성 | `supabase/`, `src/types/supabase.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공, `gen types --schema core,blog` 결과 커밋, 체커 OK. 이유: RLS·데이터 모델 | 05장, SM 리뷰 5장 #6 |
| BL-06-002 | 모듈러 → 모놀리스 변환 스크립트와 SQL 체커 CI 등록 | `scripts/sql/` | BL-06-001 | P1 | S | Haiku | 스크립트 결과가 `0002_blog_domain.sql`과 diff 0, CI에서 mod/mono 체커 OK. 이유: 반복 작업 | `DB_CONVENTIONS.md` 12장 |
| BL-06-003 | 앱 골격, `lib/env.ts`(zod, 누락 시 기동 실패), Supabase 3계층 클라이언트, 응답 봉투, `src/server/*` 인터페이스 뼈대 | `src/lib/`, `src/server/*/index.ts`(타입만) | 없음 | P0 | M | Opus | 필수 env 1개를 지우면 `next build`와 워커 기동이 실패. 0행 UPDATE를 오류로 던지는 쓰기 래퍼 존재. 이유: 다파일 구성 | SM #3, #8, #10, #12; YSM #10 |
| BL-06-004 | `src/proxy.ts` 가드, `requireSession('blog')`, 가입 `signup_app`, 부트스트랩, 프로필 없음 → 로그아웃 | `src/proxy.ts`, `src/app/(auth)/`, `src/server/session/` | BL-06-003 | P0 | M | Fable | 비로그인 `/dashboard` → `/login`, 웹훅·`/r` 통과. 가입 직후 entitled=true, 크레딧 20. Mock 로그인 코드 없음. 이유: 인증·권한 | SM #4, #6; YSM #5, #8 |
| BL-06-005 | features 해석, 월 발행 한도(`monthly_post_usage`), 채널 한도, 예약·자동 삽입·품질 모드 게이팅 | `src/server/entitlements/` | BL-06-001, BL-06-003 | P0 | M | Fable | Free 11번째 발행 402 BL004, Free 3번째 채널 403, seed 구버전 키(`channels`) 호환. 이유: 플랜 권한 | YSM #9, 01장 4.3절 |
| BL-06-006 | AI 크레딧 단가표, purpose 맵, 동기 AI 라우트(keywords, outline, rewrite, tags, bc message) | `src/server/ai/credits.ts`, `src/server/ai/purposes.ts`, `src/app/api/ai/`, `src/app/api/posts/[id]/rewrite/`, `src/app/api/posts/[id]/tags/` | BL-06-003 | P0 | M | Opus | LLM 실패 시 환불 행 1개 + 502 AI_FAILED. 요청 바디로 모델 지정 불가. 폴백 데이터 반환 없음 | SM #10; YSM #7 |
| BL-06-007 | TipTap 확장: AffiliateCard 노드, DisclosureBlock 잠금 노드, 자동 저장 훅(2초, version 충돌) | `src/features/editor/` | BL-06-003 | P0 | L | Opus | 잠금 블록 삭제 키 입력이 무시됨. 두 탭 동시 편집 시 충돌 안내. 붙여 넣은 `<script>`가 JSON에 남지 않음 | 01장 BL-F-017, SM #14 |
| BL-06-008 | `packages/blog-render`: body_json → 채널별 HTML, sanitize, 대가성 문구 삽입(제공자 집합, 도메인 스캔), `rendered_hash`, AI 활용 표기 | `packages/blog-render/` | BL-06-003 | P0 | M | Opus | 제휴 카드 1개 원고의 출력 첫 블록이 문구. 매핑 없는 `link.coupang.com` 링크만 있어도 문구 삽입. 같은 입력 같은 해시 | 확정 결정 12, BL-F-024 |
| BL-06-009 | 채널 연결 API: 자격증명 vault 저장, 워드프레스 SSRF 차단 fetch, 동의 RPC 연결, 해제 | `src/server/channels/`, `src/app/api/channels/` | BL-06-004, BL-06-005 | P0 | M | Fable | `https://10.0.0.1` 거부, 응답에 비밀 없음, DB에 평문 비밀 없음, 동의 전 naver 연결 409 BL005. 이유: 자격증명 | SM #5, #7; YSM #2, #4, #13 |
| BL-06-010 | 워커 런타임: `runWorker`, 브라우저 풀(4), 채널 잠금, 타임아웃, 간격·일일 상한 재배치, 하트비트 취소 | `workers/blog-worker/src/runtime/` | BL-06-001, BL-06-003 | P0 | M | Opus | 같은 계정 잡 2개가 동시에 브라우저를 열지 않음. 180초 초과 잡은 컨텍스트 종료 후 실패. Next import 없음 | SM #3, #7, #8, #10; YSM #11, #13 |
| BL-06-011 | 네이버 블로그 게시 어댑터(CA + YSM 스마트에디터 절차 이식, 셀렉터 상수 분리, CAPTCHA 정지, unconfirmed 판정) | `workers/blog-worker/src/channels/naver/` | BL-06-010, BL-06-008 | P0 | L | Opus | 녹화 픽스처에서 제목·본문·태그 10개 입력과 URL 파싱 통과. 로그인 페이지 감지 시 needs_reauth, 재시도 없음. 봇 우회 코드 없음 | YSM #12, 07장 2절 |
| BL-06-012 | 티스토리 게시 어댑터 | `workers/blog-worker/src/channels/tistory/` | BL-06-010, BL-06-008 | P0 | M | Opus | 픽스처 통과, 실패 분기는 네이버와 같음 | 07장 2절 |
| BL-06-013 | 워드프레스 REST 어댑터(태그, 대표 이미지, Yoast 메타 선택) | `workers/blog-worker/src/channels/wordpress/` | BL-06-010, BL-06-008 | P0 | S | Opus | 로컬 WordPress 컨테이너에 발행 성공, 401은 채널 error | 07장 2절 |
| BL-06-014 | 발행 오케스트레이션: publish/cancel/retry/resolve 라우트, 멱등, 채널 정책 경고, 잡 연결, 워커 발행 핸들러의 상태 반영 | `src/server/publish/`, `src/app/api/posts/[id]/publish/`, `src/app/api/publications/`, `workers/blog-worker/src/handlers/publish/` | BL-06-005, BL-06-008, BL-06-010 | P0 | M | Fable | 같은 request_id 2회 → 행·잡 1개. 네이버+쿠팡 경고 미확인 409 BL006. 예약 취소 시 core 잡 canceled. 이유: 상태 머신·권한 | SM #4, #9; YSM #6 |
| BL-06-015 | 생성 잡 핸들러와 프롬프트(템플릿 5종, 금지 지시, JSON 스키마, 자동 제휴 삽입 호출) | `src/server/ai/prompts/`, `src/app/api/posts/[id]/generate/`, `workers/blog-worker/src/handlers/generate/` | BL-06-006, BL-06-016 | P0 | M | Opus | 체험 메모 없는 원고에 1인칭 사용 경험 문장이 없음(평가 세트 20건). 스키마 불일치 1회 재시도 후 실패·환불 | 01장 6.5절, YSM #7 |
| BL-06-016 | 제휴 API: 계정 연결, 쿠팡 검색, 링크+매핑 생성·삭제, 수동 URL(텐핑·네이버쇼핑 커넥트), 자동 추천, 클릭 통계 | `src/server/affiliate/`, `src/app/api/affiliate/`, `src/app/api/posts/[id]/affiliate-links/` | BL-06-009 | P0 | M | Opus | 카드 삽입 시 매핑 1행·단축 코드 1개. 키가 응답에 없음. 수익 열은 데이터 없으면 숨김 | 확정 결정 12, BL-F-020~027 |
| BL-06-017 | 브랜드커넥트 API: 계정(자격증명 공유), 동의(버전 감사), 철회(잡 취소), 지원 요청(5/시간, 20/일), 스캔 요청(4/일) | `src/server/brandconnect/`, `src/app/api/brandconnect/` | BL-06-009, BL-06-016 | P0 | M | Fable | member 동의 403, 동의 없는 지원 42501, 6번째 지원 429, 철회 후 대기 잡 canceled. 이유: 권한·위험 동의 | 확정 결정 12, 01장 6.4절 |
| BL-06-018 | 브랜드커넥트 워커: scan/apply/sync(Playwright, 셀렉터 상수, 제출 확인, CAPTCHA 정지) | `workers/blog-worker/src/handlers/brandconnect/` | BL-06-010, BL-06-017 | P0 | L | Opus | 픽스처에서 제출 성공 시 submitted + submitted_at, 확인 실패는 failed. 상태 전이 위반 없음 | `NOMAD Shorts Maker/src/skill/playwright-engine/brand-connect.ts` |
| BL-06-019 | 컴플라이언스 연결: blog 규칙 사전(가상 후기·수익 보장 등), core check 호출, 결과 저장, WARN 확인 라우트 | `src/server/compliance/`, `src/app/api/posts/[id]/compliance/` | BL-06-006 | P0 | S | Opus | "내돈내산" 포함 정보형 원고 → WARN 이상. LLM 오류 → WARN. 한글 경계 매칭 테스트 통과 | `SHARED_MODULES.md` 13장 |
| BL-06-020 | `/r/[code]` 리다이렉트(레이트 리밋, IP 해시, 봇 UA 표시) | `src/app/r/` | BL-06-003 | P0 | S | Opus | 302 + 클릭 1행, 61번째/분 429, 원문 IP 미저장 | `CORE_SPEC.md` 13.3절 |
| BL-06-021 | 대시보드, 원고 목록, 캘린더 UI(서버 컴포넌트 + 실데이터) | `src/app/(app)/dashboard/`, `src/app/(app)/posts/page.tsx`, `src/app/(app)/calendar/`, `src/components/dashboard/` | BL-06-014 | P0 | L | Sonnet | 더미 배열 없음, 빈 상태 문구, 375px 레이아웃. 파일 400줄 이하 | SM #9, YSM #14 |
| BL-06-022 | 에디터 화면, 보조 패널 5탭, 발행 시트 UI | `src/app/(app)/posts/[id]/`, `src/app/(app)/posts/new/`, `src/components/editor-shell/` | BL-06-007, BL-06-014 | P0 | L | Sonnet | AI 버튼마다 예상 크레딧, 잡 진행률 Realtime, 402/409 화면 03장 5절 문구 | 03장 3.2~3.3절, SM #14 |
| BL-06-023 | 채널 화면과 위험 동의 모달(스크롤 완독, 체크 3개, 입력 확인) | `src/app/(app)/channels/`, `src/components/consent/` | BL-06-009 | P0 | M | Sonnet | 고지문 끝까지 스크롤 전 체크 비활성, member는 요청 안내만 | 01장 6.4절 |
| BL-06-024 | 제휴 통계 화면, 브랜드커넥트 화면 | `src/app/(app)/affiliate/`, `src/app/(app)/brandconnect/` | BL-06-016, BL-06-017 | P0 | M | Sonnet | 수익 데이터 없으면 열 숨김, 지원 상태 칩 6종 | 03장 3.6~3.7절 |
| BL-06-025 | 결제: 주문 생성, confirm, 빌링키, billing 화면, PM001 처리(운영 알림 + Toss 취소) | `src/app/api/billing/`, `src/app/(app)/billing/`, `src/server/billing/` | BL-06-004 | P0 | M | Fable | 금액을 클라이언트에서 받지 않음, confirm 2회 → 지급 1회, PM001 시 `fail_payment_order` 호출 후 취소 호출 | SM #1, #2; 01장 4장 |
| BL-06-026 | 랜딩, 가격, 약관, 개인정보처리방침 | `src/app/(marketing)/`, `src/styles/tokens.css` | BL-06-003 | P0 | M | Sonnet | 03장 4절 토큰·와이어프레임 반영, 금지 문구 0건, 체크리스트 12항목 통과 | 03장 4절 |
| BL-06-027 | 설정: 대가성 문구 편집(끄기 없음), 멤버, 활동 기록 | `src/app/(app)/settings/` | BL-06-016 | P1 | S | Sonnet | 이해관계 단어 없는 문구 저장 422, owner/admin 외 접근 403 | BL-F-006, BL-F-024 |
| BL-06-028 | RLS/권한 회귀 테스트(05장 9절 69항목 + 추가) | `supabase/tests/` | BL-06-001 | P0 | M | Fable | 모듈러·모놀리스 모두 0 실패, CI 필수 단계 | `SECURITY_BASELINE.md` 15장, SM #15, YSM #15 |
| BL-06-029 | 결제 E2E(Toss 테스트 키): Pro 구독, 크레딧팩, 중복 confirm, 금액 위조 | `tests/e2e/billing/` | BL-06-025 | P0 | M | Opus | 4개 시나리오 통과, 위조 금액 PM001 | SM #2, #3 |
| BL-06-030 | 발행·어댑터 통합 테스트(WordPress 컨테이너, 네이버·티스토리 녹화 픽스처, 중복·취소·unconfirmed) | `tests/integration/publish/`, `workers/blog-worker/test/` | BL-06-011~014 | P0 | M | Opus | 중복 발행 0, unconfirmed 자동 재시도 0, 문구 포함 100% | BL-F-043~047 |
| BL-06-031 | 렌더러·sanitize·대가성 문구 단위 테스트 | `tests/unit/render/` | BL-06-008 | P0 | S | Opus | XSS 벡터 30종 제거, 제공자 조합 문구 중복 없음 | SM #14 |
| BL-06-032 | CI: tsc, lint, build, 금지 문자열 검사(`x-internal-call`, `dangerouslySetInnerHTML`, `Math.random()` 지표, Mock 로그인) | `.github/workflows/`, `eslint.config.mjs` | BL-06-003 | P0 | S | Haiku | 금지 문자열 PR이 실패, 타입 오류 0 | SM #5, #11, #15; YSM #2(정리) |
| BL-06-033 | 원본 아카이브와 이식 기록(태그, 이식 파일 목록, 잔해 정리 체크리스트) | `docs/migration/` | 없음 | P1 | S | Sonnet | 07장 5절 체크리스트 완료 기록, 태그 생성은 사용자 승인 후 | YSM #1, #2; SM #13 |
| BL-06-034 | 관측: 구조화 로거(비밀 마스킹), 실패 스크린샷 7일, 셀렉터 미발견 운영 알림 | `src/lib/logger/`, `workers/blog-worker/src/observability/` | BL-06-010 | P1 | S | Opus | 로그에 쿠키·비밀번호 0건(테스트), 스크린샷 만료 삭제 | SM #14; YSM #13 |
| BL-06-035 | 키 점검: 원본 `.env` 키 목록 대조, 공유 키 교체, `CREDENTIALS_KEY` 버전 교체 절차 | `ops/secrets/`(문서·스크립트 없음) | 없음 | P0 | S | Opus | 교체 대상 목록과 완료 기록, 원본 키 재사용 0 | YSM #3 |
| BL-06-036 | 문구·금지 표현 체크리스트 반복 점검(UI, 이메일, 프롬프트) | `src/content/copy/` | BL-06-026 | P1 | S | Haiku | 01장 6.5절 목록 대비 위반 0 | 01장 6.5절 |
| BL-06-037 | 생성 흐름 E2E: 키워드 → 생성 → 검사 → 워드프레스 발행, 크레딧·환불 검증 | `tests/e2e/generate/` | BL-06-015, BL-06-019, BL-06-030 | P0 | M | Opus | 성공 시 크레딧 4 차감, LLM 실패 주입 시 원장 환불 1행 | BL-F-003, BL-F-011 |
| BL-06-038 | 데이터 내보내기 잡(Markdown/HTML ZIP, exports 버킷) | `workers/blog-worker/src/handlers/export/`, `src/app/api/exports/` | BL-06-010 | P1 | S | Opus | 100편 60초 이내, 서명 URL 7일 | BL-F-007 |
| BL-06-039 | Phase 2: n8n/Make 브릿지와 발신 웹훅 노드 등록(automation-core) | `src/server/automation/` | BL-06-014 | P2 | M | Opus | 서명 없는 콜백 401, `post.published` 이벤트 HMAC | SM #11 |
| BL-06-040 | Phase 2: 인스타그램 카드 포스팅(sns-uploader 소비, OAuth state) | `workers/blog-worker/src/channels/instagram/` | BL-06-010 | P2 | M | Opus | 캡션 첫 줄 대가성 문구, 토큰은 vault | BL-F-049 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | BL-06-001, 003, 033, 035 | 4 | 없음 | DB 조각 적용, 타입, 앱 골격, 아카이브·키 점검 |
| W1 | BL-06-002, 004, 006, 007, 008, 010, 020, 026, 032 | 9 | W0 | 인증, AI 라우트, 에디터 확장, 렌더러, 워커 런타임, `/r`, 랜딩, CI |
| W2 | BL-06-005, 009, 011, 012, 013, 019, 025, 028, 031 | 9 | W1 | 게이팅, 채널 연결, 어댑터 3종, 컴플라이언스, 결제, RLS·렌더 테스트 |
| W3 | BL-06-014, 016, 023, 029, 034, 036 | 6 | W2 | 발행 오케스트레이션, 제휴, 채널 화면, 결제 E2E |
| W4 | BL-06-015, 017, 021, 022, 027, 030, 038 | 7 | W3 | 생성 잡, 브랜드커넥트 API, 앱 화면, 발행 통합 테스트 |
| W5 | BL-06-018, 024, 037 | 3 | W4 | 브랜드커넥트 워커와 화면, 생성 E2E. MVP 완료 |
| W6 | BL-06-039, 040 | 2 | MVP 출시 | Phase 2 |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 8 | 20.0% | 16 / 73 = 21.9% |
| Opus | 22 | 55.0% | 40 / 73 = 54.8% |
| Sonnet | 7 | 17.5% | 14 / 73 = 19.2% |
| Haiku | 3 | 7.5% | 3 / 73 = 4.1% |
| 합계 | 40 | 100% | 73 |

## 5. 리뷰 작업 흡수표

| 리뷰 5장 작업 | 흡수한 작업 ID | 비고 |
|---|---|---|
| SM #1 크레딧 RPC 봉쇄 | 코어(0003) + BL-06-028, BL-06-025 | blog는 크레딧 함수를 만들지 않음 |
| SM #2 결제 경로 단일화 | BL-06-025, BL-06-029 | |
| SM #3 백그라운드 서비스 클라이언트, `x-internal-call` 제거 | BL-06-003, BL-06-010, BL-06-014 | |
| SM #4 인증 가드, Mock 로그인, OAuth state, 키 폴백 | BL-06-004, BL-06-009 | |
| SM #5 빌드 복구 | BL-06-032 | 새 저장소, tsc 게이트 |
| SM #6 제품 경계·스키마 통합 | BL-06-001 | 확정 결정 1로 경계 확정 |
| SM #7 파이프라인 재설계 | BL-06-010 | blog 잡은 core.jobs 단일 단계. video 파이프라인은 nomad-video 소관 |
| SM #8 zod 입력 검증, `getCurrentOrg` | BL-06-003, BL-06-004 | 세션 컨텍스트로 대체 |
| SM #9 대시보드 실데이터 | BL-06-021 | |
| SM #10 AI 클라이언트 단일화, env 검증 | BL-06-006, BL-06-003 | |
| SM #11 AIContentGen 내부 호출, 콜백 서명 | BL-06-039 | DistroKid는 video 소관 |
| SM #12 YouTube 스트리밍, Redis lazy | 해당 없음 | video 소관. blog는 Redis를 쓰지 않음 |
| SM #13 루트 문서 정리 | BL-06-033 | 원본은 아카이브만 |
| SM #14 로깅 정리, sanitize | BL-06-034, BL-06-007, BL-06-031 | |
| SM #15 통합 테스트·CI | BL-06-028, BL-06-032 | |
| YSM #1 아카이브 태그와 방향 결정 | BL-06-033 | 방향은 "모듈 이식"으로 결정됨(README 3장) |
| YSM #2 gitignore, 잔해 삭제 | BL-06-033 | 원본 폴더 수정은 사용자 승인 후 |
| YSM #3 키 점검·교체 | BL-06-035 | |
| YSM #4 OAuth state 재구현 | BL-06-009(코어 oauth 사용) | |
| YSM #5 네이버 로그인 `naver_id` 매핑 | BL-06-004 | MVP 미도입, 정책만 |
| YSM #6 태스크 소유권 검증 | BL-06-014, BL-06-028 | core.jobs RLS |
| YSM #7 모델 허용 목록, LLM 단일 모듈 | BL-06-006, BL-06-015 | |
| YSM #8 인증 의존성 블로킹 | BL-06-004 | FastAPI 폐기, `requireSession` |
| YSM #9 role/plan 통합 | BL-06-005 | 코어 org 역할 + 엔타이틀먼트 |
| YSM #10 CORS, 예외 원문 노출 | BL-06-003 | 응답 봉투. CORS는 동일 출처라 해당 없음 |
| YSM #11 하위 프로세스 타임아웃 | BL-06-010 | Playwright 타임아웃 |
| YSM #12 이식 설계 | BL-06-011 | TS로 이식 |
| YSM #13 account_manager 분할, `except: pass` | BL-06-009, BL-06-034 | |
| YSM #14 거대 페이지 분할 | BL-06-021, BL-06-022, BL-06-023 | 파일 400줄 상한 |
| YSM #15 pytest 기본 세트 | BL-06-028, BL-06-030, BL-06-031 | TS 테스트로 대응 |

## 6. 공용 모듈 요청

| 요청 | 대상 | 이유 |
|---|---|---|
| `_supabase-modular/seed.sql`의 blog 플랜을 01장 4.1절로 갱신(free 월 20, `max_channel_accounts` 등 키, pro/business 행, 팩 3종) | seed 소유자 | 해결(2026-10-13 코어 반영 완료): 모듈러 seed가 모놀리스 seed와 일치 |
| `adjust_credits` 함수 | `_platform-core` | 크레딧팩 환불 시 음수 조정(`CORE_SPEC.md` 5.4절) |
| `confirm_payment_order` 금액 불일치 시 주문 failed 기록 | `_platform-core` | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가. PM001 시 별도 호출로 운영 대사 가능 |
| 브랜드커넥트 위험 동의 고지문 버전 컬럼(`affiliate_accounts.risk_notice_version`) | `_platform-core` | 지금은 감사 로그 메타데이터로 대체 |
| 브랜드커넥트 동의 철회 함수 | `_platform-core` | 지금은 서버가 service_role로 처리 |
| compliance 규칙 사전에 blog 추가분(가상 후기, 수익 보장) 등록 경로 | `_platform-core` | 제품별 확장 지점 |

## 7. 완료 정의

| 조건 | 명령/기준 |
|---|---|
| 빌드·타입·린트 | `pnpm -w build`, `pnpm -w tsc --noEmit`, `pnpm -w lint` 0 오류 |
| SQL | `node docs/products/_tools-sqlcheck/check.mjs mod ...`, `... mono ...` OK |
| RLS 스모크 | BL-06-028 모듈러·모놀리스 0 실패 |
| 결제 E2E | BL-06-029 통과(Toss 테스트 키) |
| 발행 | BL-06-030, BL-06-037 통과, 대가성 문구 포함률 100% |
| 디자인 | `DESIGN_PRINCIPLES.md` 7단계 체크리스트 12항목 |
| 작업 | 2절 P0 작업 전부 완료, P1은 출시 전 완료 |
