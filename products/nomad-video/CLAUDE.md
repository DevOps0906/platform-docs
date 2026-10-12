# CLAUDE.md: NOMAD AI Factory (nomad-video)

## 1. 먼저 읽을 문서

| 순서 | 문서 |
|---|---|
| 1 | `docs/products/_platform-core/CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql` |
| 2 | 이 폴더 `01_PRD.md`(Track A~F, 단가, 금지 문구) → `02_ARCHITECTURE.md` → `05_DATA_MODEL.md` → `04_API.md` → `03_SCREENS_UX.md` → `06_AGENT_PLAN.md`(자기 작업 행) → `07_SOURCE_MIGRATION.md` |
| 3 | UI 작업이면 `docs/products/_design-guide/DESIGN_PRINCIPLES.md`, `REFERENCES.md` nomad-video 절 |

## 2. 절대 규칙

| 규칙 | 내용 |
|---|---|
| service_role | `SUPABASE_SERVICE_ROLE_KEY`와 `createAdminClient`는 `src/server/**`, 워커에서만. `NEXT_PUBLIC_` 금지 |
| 크레딧 | 생성·업로드·검사는 선차감 → enqueue(ledger 연결) → 실패 시 자동 환불. 사용자 RPC 안에서 차감하지 않는다 |
| 코어 | 공용 모듈 16개를 재정의하지 않는다. `_platform-core`, `_supabase-modular`의 다른 파일, `packages/core-*` 수정 금지. 필요하면 06장 6절에 요청 |
| 스키마 | `video` 스키마 변경은 VID-06-001만. 모놀리스 파일은 변환 스크립트로만 생성 |
| 대가성 문구 | 제휴 링크가 있으면 설명란 첫 줄과 고정 댓글 첫 줄에 `effective_disclosure` 문구. 끄는 옵션을 만들지 않는다 |
| 유료 프로모션 | 자동 설정 금지(제안 단계). 체크박스 + 안내만 |
| Track E/F | 메뉴, 테이블, 단가, 채널 역할(lofi/playlist), 색을 섞지 않는다. 공유는 Suno 엔진과 인코딩 워커뿐 |
| 금지 문구 | 01장 6절. 미검증 수치, 가상 후기, 보장 표현 금지 |
| git | 정리(삭제·이동) 커밋과 기능 커밋을 분리한다(YSM #1). 원본 폴더 삭제는 사용자 승인 후 |

## 3. 디렉토리와 소유 경계

| 영역 | 경로 | 소유 작업 |
|---|---|---|
| 공통 lib, proxy | `apps/nomad-video/src/{proxy.ts,lib/**}` | VID-06-003 |
| 과금·게이팅 | `src/server/billing/**` | VID-06-005 |
| 도메인 서버 | `src/server/<domain>/**` | 06장 2절 |
| API | `src/app/api/<domain>/**` | 06장 2절 |
| 화면 | `src/app/(dashboard)/dashboard/<area>/**` | 028~034 |
| 공개 | `src/app/{landing,lb,r,(marketing),legal}/**` | 022, 023, 035 |
| 오케스트레이터 | `workers/video-orchestrator/**` | 015, 016, 024, 026, 027 |
| 미디어 워커 | `services/media-worker/**` | 011~014 |
| 업로더 | `packages/sns-uploader/**` | 009, 010 |
| DB | `supabase/**` | 001, 002 |

## 4. 코어 사용 규칙

| 상황 | 쓸 것 |
|---|---|
| Route Handler 진입 | `requireSession('video', { roles })`. 조직은 세션에서만 |
| 기능 판정 | `entitled_plan_code` + `plans.features`(01장 4절 키 표). DB 정책은 `video.org_has_feature` |
| 차감 | `consume_credits(..., p_idempotency_key='consume:video:<request_id>')` → `enqueue_job(p_credit_ledger_id, p_idempotency_key='job:video:<request_id>')` |
| 부분 환불 | `refund_credits(ledger_id, reason, amount, 'refund:<production_id>:<lang>')` |
| Python 단계 | `core.enqueue_job(queue='video.media.cpu'|'video.media.gpu', parent_job_id=root)` → 결과 대기. Python은 `claim_jobs`만 |
| 채널 토큰 | `beginOAuth/completeOAuth`, `CredentialVault`. 페이로드에는 `credential_id`만 |
| 제휴 | `createShortLink`, `disclosure`, `injectDisclosure`, `/r/[code]`는 `record_affiliate_click` |
| 감사 | 제품 RPC가 이미 기록. 서버 쓰기 중 관리 동작은 `auditAsService` |
| 결제 | 코어 toss. `confirm_payment_order` PM001이면 별도 호출로 `fail_payment_order(order_id,'amount_mismatch',{...})` 후 운영 알림 + Toss 취소 |

## 5. 코드 규칙

| 항목 | 규칙 |
|---|---|
| 스택 | Next.js 16 App Router, React 19, TS strict, Tailwind v4 + shadcn, zod, TanStack Query, BullMQ, Python 3.11 |
| 검증 | 모든 입력 zod, env는 `src/lib/env.ts`, Python은 pydantic settings |
| 타입 생성 | `supabase gen types typescript --local --schema core,video > apps/nomad-video/src/types/supabase.ts` |
| 언어 키 | `'KO' | 'JA' | 'EN'` 상수 하나 |
| 하위 프로세스 | 인자 배열, `--`, 타임아웃(01장 5절), 실패 시 kill |
| 로깅 | 공용 logger, 토큰·카드·본문 전체 금지 |
| 디자인 토큰 | `src/styles/tokens.css`. 컴포넌트에 hex 하드코딩 금지 |
| 서버 컴포넌트 | 기본. 상호작용만 클라이언트 |

## 6. 테스트와 완료 조건

| 명령 | 기준 |
|---|---|
| `pnpm -F nomad-video lint && pnpm -F nomad-video typecheck && pnpm -F nomad-video build` | 오류 0 |
| `pytest services/media-worker` | 통과 |
| `node docs/products/_tools-sqlcheck/check.mjs mod <0000~0007> <seed> <1200_video.sql>` | OK |
| `node docs/products/_tools-sqlcheck/check.mjs mono <0001_core_lite> <0002_video_domain> <seed>` | OK |
| `pnpm test:rls`(VID-06-002) | 전 항목 통과 |
| `pnpm test:e2e`(007, 038), `pnpm test:integration`(037) | 통과 |

06장 7절 완료 정의를 모두 만족해야 PR을 머지한다.

## 7. 금지 패턴

07장 4절 요약: 크레딧 RPC 권한 미회수, 비원자 차감, 웹훅 서명 선택 검증·orderId 파싱, `Date.now()` customerKey, OAuth state 신뢰, 토큰 평문·0키 폴백, 세션 없는 anon 클라이언트, `FOR ALL` 정책, `x-internal-call`·자기 HTTP 호출, Mock 로그인, `/landing` 보호, 이메일 자동 계정 병합, task 소유권 미검증, 자유 모델명, 예외 원문 노출, 타임아웃 없는 하위 프로세스, yt-dlp 인자 주입, sanitize 없는 HTML, 난수 지표, 미검증 마케팅 수치, 운영자 이메일 하드코딩, 실키 `.env` 커밋, mock 응답으로 장애 숨기기.
