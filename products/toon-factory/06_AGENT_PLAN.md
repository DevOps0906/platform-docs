# 06 에이전트 작업 계획: Toon Factory

작성일 2026-10-12. 작업 ID `TN-06-###`. 모델 기준은 `docs/products/_platform-core/DOC_TEMPLATE.md` 1장(Fable: 결제·권한·RLS·데이터 모델, Opus: 기능·API·테스트 설계, Sonnet: UI·문서, Haiku: 보일러플레이트·문구·반복 점검).

2026-10-13 개정: AI 계층·음성·3D 히어로·디자인 시스템(확정 결정 13~17, `docs/products/_design-guide/DESIGN_SYSTEM.md` 4장) 작업 19개(TN-06-041~059)를 뒤에 붙였다. 기존 ID는 바꾸지 않았다. 내용이 바뀐 기존 작업은 014·015·035(그래프 호출로 전환), 034(디자인 시스템 2단계), 023(스케줄 추가), 037·004(소유 경계 안내), 001·009·020·028·030·033(수용 기준 보강)이고, 화면 작업 009·013·017·021·024·026·027·032의 선행에 TN-06-043을 더했고(017은 선행에서 014를 빼고 응답 스키마 픽스처로 개발한 뒤 030 E2E에서 연동), 030의 선행에 048·055를 더했다. 작업 수 59개는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다. 이전 40개가 이미 상한이었고, AI·음성·3D·디자인 시스템이 MVP 필수가 되면서 늘었다. 검증할 수 있는 크기(`DESIGN_SYSTEM.md:24`)를 지키려고 합치지 않았다.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 작업은 표의 "소유 파일/디렉토리"만 만들거나 고친다. 다른 작업의 디렉토리가 필요하면 선행 작업의 공개 인터페이스(타입, 함수)를 import만 한다 |
| 공용 진입 파일 | `apps/toon/package.json`, `next.config.ts`, `src/app/layout.tsx`, `src/proxy.ts`는 TN-06-004 소유. 다른 작업이 의존성을 추가해야 하면 PR 설명에 적고 TN-06-004 담당이 합친다 |
| 워커 등록 | `services/toon-worker/src/main.ts`, `registry.ts`는 TN-06-033 소유. 핸들러 작업은 자기 디렉토리의 `index.ts`에서 `WorkerHandler`를 export만 한다 |
| 공유 패키지 | `packages/toon-doc`는 하위 디렉토리별로 소유를 나눈다(schema / render / layout / storyboard / presets / templates) |
| DB | `supabase/`와 모듈러 조각은 Fable만. 다른 작업은 SQL을 고치지 않고 요청을 남긴다 |
| 코어 | `_platform-core` 패키지는 소비만. 필요 기능은 6절 요청 |
| AI 서비스 경계 | `apps/api/`는 TN-06-044가 공용 ai-service를 설치하고 공용 부분과 설정을 소유한다. toon 확장은 작업별로 나눈다: 046 `app/ai/products/toon/knowledge.py`, 047 `wiki_config.py`, 049 `app/ai/graphs/toon_storyboard.py`·`app/ai/compliance/toon.py`, 050 `toon_dialogue.py`·`toon_image_prompt.py`, 051 `app/ai/tools/toon/` |
| AI·음성 Route Handler 경계 | `api/ai/`는 045(대화·채팅·정산), `api/ai/knowledge/`는 046, `api/ai/wiki/`는 047. `api/voice/`는 053(consent, sessions, stt, tts), 054(dialogue), 055(video-lines) |
| 사람 작업 | TN-06-042(디자인 시스템 3단계)는 사람이 수행하고 Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다 |
| 디자인 시스템 순서 | 화면 작업(009, 013, 017, 021, 024, 026, 027, 032, 048, 052, 056, 059)은 TN-06-043(4단계) 뒤에 시작한다(`docs/products/_design-guide/DESIGN_SYSTEM.md:39-49`) |
| 장착 요청 | 채팅 시트 열기 버튼·말풍선 보이스 슬롯은 TN-06-009 파일에, 영상 음성 토글은 TN-06-021 파일에, 3D 히어로는 TN-06-026 파일에 "1줄 장착 요청"으로 넣는다. 다른 작업의 파일을 직접 고치지 않는다 |
| 3D 경계 | three.js는 `apps/toon/src/components/hero3d/`(TN-06-056)만 import한다. 다른 화면은 3D 의존성이 없다 |

경계 요약(02장 2절과 같음): 앱 `apps/toon/`, 문서·렌더·규칙 공유 `packages/toon-doc/`, 워커 `services/toon-worker/`, AI 서비스 `apps/api/`, Dify 앱 정의 `infra/dify/`, 도구 `tools/`, DB `supabase/`, E2E `tests/e2e/`, 디자인 문서 `docs/file/03-설계/디자인/`.

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| TN-06-001 | 모듈러 조각 확정, 로컬 적용, 타입 생성, `[api].schemas`에 toon 추가 | `supabase/migrations/2000_toon.sql`, `supabase/config.toml`, `packages/toon-doc/src/db-types.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공, SQL 체커 OK, `gen types --schema core,toon` 결과 커밋, 라우팅 기본값 14행(`2000_toon.sql` 10절) 적용 확인 | 리뷰 5장 #2, 05장 |
| TN-06-002 | RLS/권한 회귀 테스트 자동화(05장 4.1절 68항목 + Storage 정책) | `supabase/tests/toon/` | TN-06-001 | P0 | M | Fable | CI에서 모듈러·모놀리스 둘 다 68항목 이상 통과, 실패 시 빌드 실패 | `SECURITY_BASELINE.md:238-263`, 리뷰 5장 #12 |
| TN-06-003 | 조각 → 모놀리스 변환 스크립트(DB_CONVENTIONS 12장 규칙) | `tools/sql-mono/` | 없음 | P0 | S | Haiku | 스크립트 결과가 `supabase/monolith/migrations/0002_toon_domain.sql`과 바이트 단위로 같다 | `DB_CONVENTIONS.md:264` |
| TN-06-004 | 앱 골격: Next 16, core-db/core-auth 연결, `proxy.ts` 라우트 보호, shadcn 설치, 로그인/가입 서버 액션 뼈대 | `apps/toon/package.json`, `next.config.ts`, `tsconfig.json`, `src/app/layout.tsx`, `src/proxy.ts`, `src/components/ui/`(shadcn 설치 산출물만, 재스타일은 TN-06-034) | 없음 | P0 | M | Sonnet | 비로그인으로 `/app` 접근 시 `/login` 리다이렉트, 프로필 없는 세션은 로그아웃, `tsc` 0 오류 | 리뷰 5장 #3, `SECURITY_BASELINE.md:178-188` |
| TN-06-005 | CutDoc zod 판별 유니온, 버전 마이그레이션, 콘티 스크립트 스키마 | `packages/toon-doc/src/schema/` | 없음 | P0 | M | Fable | 02장 2.2절, 04장 4.1절 스키마 그대로. 잘못된 kind, 61개 레이어, 256KB 초과 문서가 거부된다 | 리뷰 #3, #4, 리뷰 5장 #1 |
| TN-06-006 | 공용 렌더러 `renderCut`(브라우저 fabric / `fabric/node`), 글꼴 로딩, 워터마크·AI 표기 오버레이 | `packages/toon-doc/src/render/`, `packages/toon-doc/tests/render/` | TN-06-005 | P0 | L | Opus | 같은 문서를 두 환경에서 렌더한 골든 이미지 차이 0.5% 이하(샘플 10컷) | 02장 2절, 7절 위험 |
| TN-06-007 | editorStore: 문서 모델, 커맨드, immer patch 히스토리 100단계, 디바운스 자동 저장(`save_cut_doc`), 충돌 처리 | `apps/toon/src/stores/` | TN-06-005 | P0 | L | Opus | Undo 100회로 초기 상태 복귀, 두 탭 동시 편집 시 `TN409` 배너 | 리뷰 5장 #4, TN-F-005, TN-F-015 |
| TN-06-008 | Fabric 어댑터: 문서 → Fabric 단방향, `object:modified` → 커맨드, 선택/변형/순서, rAF 배치, SSR 비활성 | `apps/toon/src/components/canvas/` | TN-06-006, TN-06-007 | P0 | L | Opus | 레이어 30개 컷 드래그 55fps 이상, Fabric 객체를 직접 상태로 쓰는 코드 0건(린트 규칙) | 리뷰 5장 #5, 리뷰 #8 |
| TN-06-009 | 에디터 3패널 UI, 컷 스트립, 인스펙터, 키보드 단축키 | `apps/toon/src/components/editor/`, `apps/toon/src/app/editor/` | TN-06-007, TN-06-043 | P0 | L | Sonnet | 03장 3.1절 와이어프레임 구성, viewer는 편집 비활성, 인스펙터의 말풍선 보이스 슬롯(TN-06-054)과 상단 채팅 버튼 슬롯(TN-06-052) 장착 지점이 있다 | 리뷰 5장 #6 |
| TN-06-010 | 표정 앵커 계산, 말풍선 줄바꿈·크기·꼬리 기하(순수 함수) | `packages/toon-doc/src/layout/` | TN-06-005 | P0 | M | Opus | 표정 6종 교체 시 머리 위치 오차 1px 이하, 120자 말풍선 자동 확장 | 리뷰 5장 #7, TN-F-012, TN-F-013 |
| TN-06-011 | 카탈로그 서명 URL API(`org_asset_access` 검사, 15분, 레이트 리밋) | `apps/toon/src/app/api/catalog/` | TN-06-037 | P0 | M | Opus | 무료 조직이 premium id를 요청하면 `denied`에 들어가고 URL이 없다. 601번째 요청 429 | 리뷰 5장 #8, 리뷰 #2 |
| TN-06-012 | 카탈로그 일괄 등록 CLI(검수 규칙: 알파, 높이 2048 이상, 앵커, 표정 크기 일치) + 관리자 검증/공개 API | `tools/catalog-import/`, `apps/toon/src/app/api/admin/` | TN-06-001 | P0 | M | Opus | 규칙 위반 폴더는 전부 거부, 검증 없는 공개는 409, 모든 관리자 쓰기가 감사 로그에 남음 | 리뷰 5장 #8, 리뷰 #5, #6 |
| TN-06-013 | 관리자 카탈로그 화면 | `apps/toon/src/app/admin/` | TN-06-012, TN-06-043 | P0 | S | Sonnet | platform_admin 외 접근 403(서버 가드) | 03장 3.5절 |
| TN-06-014 | AI 콘티: Route Handler + `storyboard.generate` 핸들러(잡 토큰으로 그래프 `toon.storyboard` 호출, JSON 검증, 코드 보정, `blocked` 컷 처리, 환불) | `apps/toon/src/app/api/storyboard/`, `services/toon-worker/src/handlers/storyboard/` | TN-06-037, TN-06-033, TN-06-045, TN-06-049 | P0 | M | Opus | 8컷 요청이 8컷 스크립트로 저장, 그래프·LLM 실패 시 3크레딧 환불 원장 1행, 워커 환경에 LLM 키 0(기동 검사), `blocked`가 절반 초과면 잡 실패 + 환불, 호출은 잡 토큰 scope `graph:toon.storyboard`로만 | TN-F-020 |
| TN-06-015 | AI 배경: Route Handler(compliance 규칙, 용량), `image.generate` 핸들러(그래프 `toon.image_prompt` 호출, fal, 저장, 썸네일), 국외 이전 동의 확인(`TN007`), fal 웹훅 | `apps/toon/src/app/api/generations/`, `services/toon-worker/src/handlers/image/`, `apps/toon/src/app/api/webhooks/fal/` | TN-06-037, TN-06-033, TN-06-050 | P0 | L | Opus | 성공 시 `user_assets.ai_generated=true`, 안전 거부 시 재시도 없이 환불, 2장 중 1장 실패 시 4크레딧 부분 환불, 국외 이전 미동의 조직은 403 `TN007`이고 차감 0 | TN-F-022, TN-F-023 |
| TN-06-016 | 콘티 → CutDoc 변환(`scriptToDocs`), 기본 배치 규칙 | `packages/toon-doc/src/storyboard/` | TN-06-005, TN-06-010 | P0 | M | Opus | 캐릭터 position left/center/right가 컷 너비 1/4, 1/2, 3/4에 놓이고 말풍선이 머리 위에 겹치지 않게 배치 | TN-F-020 |
| TN-06-017 | 작품 목록, 작품 만들기, 회차 목록, 캐스트, 콘티 화면 | `apps/toon/src/app/app/series/`, `apps/toon/src/app/app/page.tsx` | TN-06-016, TN-06-043 | P0 | M | Sonnet | 03장 2.2절 플로우 동작, 한도 오류 문구 표시, 콘티 결과 표의 "설정 확인" 배지와 `blocked` 컷 표시, 위키 사용 토글. 콘티 화면은 04장 4.1절 응답 스키마 픽스처로 동작하고 실제 연동(TN-06-014)은 TN-06-030 E2E에서 확인한다 | 03장 3.2~3.3절 |
| TN-06-018 | 내보내기 API(플랜·월 한도·에셋 등급·길이 검사, mp4 선차감, `exports` 행, 잡), 다운로드, 잡 취소 | `apps/toon/src/app/api/exports/`, `apps/toon/src/app/api/jobs/` | TN-06-037, TN-06-033 | P0 | M | Opus | 무료가 mp4 요청 시 403 `TN002`, 요청 본문에 `watermark:false`를 넣어도 행의 값은 true | 리뷰 #1, TN-F-030~036 |
| TN-06-019 | 이미지 내보내기 핸들러: png/zip/strip, 원본 에셋 로드, 등급 재확인, 워터마크, AI 메타데이터·가시 표기, caption.txt | `services/toon-worker/src/handlers/export-image/` | TN-06-006, TN-06-018 | P0 | L | Opus | 무료 결과에 워터마크, AI 배경 사용 시 PNG iTXt `ai_generated=true`, 등급 밖 에셋이면 `TN003` 실패 | 리뷰 5장 #9, 리뷰 #1, #2 |
| TN-06-020 | MP4 핸들러: Shorts Maker FFmpeg 인자 이식, 4:5 흐림 채움, 웹툰 팬, 전환, BGM, 메타데이터 | `services/toon-worker/src/handlers/export-mp4/`, `services/toon-worker/src/media/` | TN-06-019 | P0 | L | Opus | 10컷 x 2.5초 → 25초 1080x1920 30fps, 60초 영상 p95 120초 이하, 실패 시 환불, 음성 트랙 믹스 훅(TN-06-055)을 받는 인자 자리 | 리뷰 5장 #10, TN-F-033 |
| TN-06-021 | 내보내기 패널, 진행률(Realtime), 기록·다운로드 화면, 플랫폼 체크리스트 | `apps/toon/src/components/export/`, `apps/toon/src/app/app/exports/` | TN-06-018, TN-06-043 | P0 | M | Sonnet | 대기 중 취소 시 환불 표시, 만료 행은 다시 내보내기 버튼 | 03장 3.4절, TN-F-037 |
| TN-06-022 | Toss: checkout, confirm, 빌링키 발급·첫 청구, 해지, 웹훅(서명, 멱등) | `apps/toon/src/app/api/billing/`, `apps/toon/src/app/api/webhooks/toss/` | TN-06-037 | P0 | L | Fable | 클라이언트 금액 변조 시 미승인, 같은 결제키 재호출 멱등, `PM001` 시 `fail_payment_order`, 취소 API 호출과 알림 | 리뷰 5장 #11 |
| TN-06-023 | 워커 스케줄: 빌링키 정기 청구(재시도 1/3/7일), 만료 내보내기 파일 삭제, 30분 초과 생성 실패 처리, 음성 준비 중단 `queued` 내보내기 정리, AI 정산 호출(5분), 고아 설정 컬렉션 정리(일 1회) | `services/toon-worker/src/schedules/` | TN-06-022, TN-06-045 | P0 | M | Fable | 청구 실패 3회 후 canceled, 30일 지난 파일 0개, `job_id` 없이 30분 넘은 `queued` 내보내기 0건(실패 처리 + 환불), 10분 넘은 `settled_at is null` 0, 작품 없는 컬렉션 0(24시간 안) | 리뷰 5장 #11, `CORE_SPEC.md:223-233` |
| TN-06-024 | 결제/요금 화면(플랜, 팩, 원장, 해지 예약) | `apps/toon/src/app/app/billing/`, `apps/toon/src/app/(marketing)/pricing/` | TN-06-022, TN-06-043 | P0 | M | Sonnet | 01장 4절 값과 화면 값 일치, "무제한" 문구 없음 | 리뷰 5장 #13 |
| TN-06-025 | 결제 E2E(Toss 테스트 키): 구독 시작 → 워터마크 해제 → 해지 예약 → 기간 말 free 복귀, 크레딧팩 구매 | `tests/e2e/billing/` | TN-06-022, TN-06-023, TN-06-024 | P0 | M | Opus | 시나리오 5개 통과, 원장 drift 0 | `DOC_TEMPLATE.md` 2.7절 필수 |
| TN-06-026 | 랜딩(세로 스트립 히어로, 주석 전환, 요금 표) | `apps/toon/src/app/(marketing)/(home)/`, `apps/toon/src/components/landing/` | TN-06-043 | P1 | M | Sonnet | `DESIGN_PRINCIPLES.md` 7단계 체크리스트 12항목 통과, 01장 6.5절 금지 문구 0건, 히어로 자리에 TN-06-056 컴포넌트 장착(1줄 요청), 정지 이미지로도 레이아웃 이동 0 | 리뷰 5장 #13, 03장 4절 |
| TN-06-027 | 로그인·가입(연령 확인, `signup_app`) 화면, 온보딩 템플릿 3종 | `apps/toon/src/app/(auth)/`, `apps/toon/src/app/app/onboarding/`, `packages/toon-doc/src/templates/` | TN-06-004, TN-06-016, TN-06-043 | P0 | M | Sonnet | 가입 후 템플릿 선택까지 3클릭, 템플릿은 무료 에셋만 | 리뷰 5장 #13, TN-F-006 |
| TN-06-028 | 약관, 처리방침, AI 이용 고지, 에셋 이용 허락 페이지 문구 | `apps/toon/src/app/(legal)/` | TN-06-004 | P0 | S | Haiku | 01장 6.1~6.3절 항목 전부 포함, 법무 검토 체크박스, AI 조항 3종(국외 이전·음성 처리·생성형 AI 사용 고지, 01장 6.7절) 포함 | 01장 6절 |
| TN-06-029 | 에디터 단위/통합 테스트: 커맨드·히스토리, 스키마 직렬화 왕복, 레이아웃 함수 | `apps/toon/tests/editor/`, `packages/toon-doc/tests/schema/` | TN-06-007, TN-06-010 | P0 | M | Opus | 커버리지 80% 이상(stores, schema, layout) | 리뷰 5장 #12 |
| TN-06-030 | E2E 핵심 플로우: 가입 → 템플릿 → 편집 → PNG 내보내기, 콘티 → 적용 → MP4 | `tests/e2e/flows/` | TN-06-017, TN-06-020, TN-06-021, TN-06-027, TN-06-048, TN-06-055 | P0 | M | Opus | 두 시나리오가 CI에서 통과, K1 측정 로그 출력, 시나리오에 설정 위키 만들기 → 콘티 일관성 표시 → 적용, MP4 음성 포함 내보내기(모의 제공자)를 포함 | 01장 7절 |
| TN-06-031 | 린트·타입 정리, 금지 문구 검사 스크립트(01장 6.5절 사전) | `tools/copy-lint/`, 루트 `eslint.config.mjs` | TN-06-026 | P1 | S | Haiku | 금지 문구가 포함된 문자열이 있으면 CI 실패 | 01장 6.5절 |
| TN-06-032 | 내 에셋 화면(AI 배지, 용량, 보관) | `apps/toon/src/app/app/library/` | TN-06-015, TN-06-043 | P1 | S | Sonnet | 보관 후 목록에서 사라짐(`archive_user_asset`) | TN-F-045 |
| TN-06-033 | 워커 골격(`runWorker`, 큐 2개, 동시성), 환경변수 검증(웹·워커) | `services/toon-worker/src/main.ts`, `services/toon-worker/src/registry.ts`, `services/toon-worker/src/env/`, `apps/toon/src/lib/env/` | 없음 | P0 | S | Haiku | 필수 변수 누락 시 기동 실패, FFmpeg·글꼴 확인 실패 시 기동 실패, `AI_SERVICE_URL`·`TOON_WORKER_INTERNAL_KEY` 누락 시 기동 실패, LLM·ElevenLabs 키가 워커 환경에 있으면 기동 거부 | 02장 8절 |
| TN-06-034 | 디자인 시스템 2단계: 03장 4.3절 토큰 + Tailwind CSS v4 `@theme`으로 `tokens.css` 확정, 기본 컴포넌트·배리언트(03장 3.7절) 구현, `/dev/components`, 글꼴 4종 파일과 OFL 확인 | `apps/toon/src/styles/`, `apps/toon/src/components/ui/`(TN-06-004 설치 산출물을 재스타일), `apps/toon/src/app/dev/components/`, `assets/fonts/` | TN-06-004, TN-06-041 | P0 | M | Sonnet | 토큰 6색·서체 역할이 `@theme` CSS 변수로만 쓰이고 hex 직접 사용 0(린트), `tailwind.config.js` 0, 03장 3.7절 기본 컴포넌트가 `/dev/components`에 라이트/다크로 나온다, 글꼴 라이선스 파일 동봉 | 03장 3.7·4절, `DESIGN_SYSTEM.md` 4장 2단계 |
| TN-06-035 | 대사 다듬기 API(서명 토큰으로 그래프 `toon.dialogue` 동기 호출, 정액 1크레딧, compliance 규칙) | `apps/toon/src/app/api/dialogue/` | TN-06-037, TN-06-050 | P1 | S | Opus | 3안 반환(말투 설정 유지), 그래프·LLM 실패 시 1크레딧 환불, Route Handler에 LLM 키 0 | TN-F-021 |
| TN-06-036 | 플랫폼 규격 확인(인스타 캐러셀 상한, 네이버웹툰 도전만화 이미지 규격·AI 정책, 쇼츠 길이)과 프리셋 값 기입 | `packages/toon-doc/src/presets/` | TN-06-005 | P1 | S | Sonnet | 01장 6.4절 "미확인" 항목마다 출처 URL과 확인일 기록, D3·D4 권고 갱신 | 01장 6.4절, 8절 |
| TN-06-037 | 서버 공통: `requireSession` 래퍼, 기능 게이팅(`plan_features`), 단가표 `priceOf`, 오류 매핑(SQLSTATE → HTTP), 레이트 리밋 키 | `apps/toon/src/lib/server/`(`ai/` 하위와 `voices.ts`는 TN-06-045·053 소유) | TN-06-001, TN-06-004 | P0 | M | Opus | 04장 7절 매핑 표와 단위 테스트 일치, 클라이언트 번들에 service_role 미포함(빌드 검사) | 04장 1절 |
| TN-06-038 | (Phase 2) 커스텀 캐릭터 조각 `2010_toon_character_sheet.sql`(custom_characters, sheet_cells, 승인 상태 전이) + RLS 테스트 | `supabase/migrations/2010_toon_character_sheet.sql`, `supabase/tests/toon-sheet/` | TN-06-002 | P2 | M | Fable | 셀 승인 전 에디터 사용 불가(DB), 다른 조직 0행 | 01장 2절 Phase 2 |
| TN-06-039 | (Phase 2) 캐릭터 시트 생성(참조 이미지 fal, 셀 단위 재생성 3크레딧, 배경 제거) | `services/toon-worker/src/handlers/character-sheet/`, `apps/toon/src/app/app/characters/` | TN-06-038 | P2 | L | Opus | 40셀 시트 생성 후 승인한 셀만 캐릭터 탭에 노출 | 01장 2절, 6절 코어 요청 2 |
| TN-06-040 | (Phase 3) 공개 작품 페이지 + JSON-LD(ComicStory), AI 사용 배지 | `apps/toon/src/app/(public)/works/` | TN-06-026 | P2 | S | Sonnet | 공개 설정한 회차만 anon 노출, 구조화 데이터 검증 통과 | 리뷰 5장 #14, 분석 `:1302` |
| TN-06-041 | 디자인 시스템 1단계: 레퍼런스 확정(앱 화면 Atlassian 주 + Primer 보조, 채팅 Astryx 패턴 존재·라이선스 확인, 랜딩 HERO_3D), 가져올 것과 안 가져올 것 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet | 03장 3.7절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안(Primer + shadcn/ui) 기록(01장 D15). 고문(Fable) 검토 기록 | `DESIGN_SYSTEM.md` 4장 1단계, 9절 |
| TN-06-042 | 디자인 시스템 3단계: 사람 비주얼 검토(라이트/다크, 상태 6종, 크기 배리언트) | `docs/file/03-설계/디자인/review/`(스크린샷, 수정 기록) | TN-06-034 | P0 | M | 사람(보조 Sonnet) | 03장 3.7절 기본 컴포넌트 전부의 라이트/다크·상태별·크기별 스크린샷과 사람이 고친 수치 기록, 대비 4.5:1·포커스 링 확인. 이 단계는 줄이지 않는다 | `DESIGN_SYSTEM.md` 4장 3단계 |
| TN-06-043 | 디자인 시스템 4단계: 코드(Tailwind CSS v4 + 컴포넌트)를 정답으로 확정하고 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | TN-06-042 | P0 | S | Opus | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치, 피그마 노드 id·외부 파일 링크 0, `tailwind.config.js` 0. 이전 `design-system/toon-factory/MASTER.md`를 만들지 않는다 | `DESIGN_SYSTEM.md` 4장 4단계 |
| TN-06-044 | AI 서비스 설치: `apps/api`에 공용 ai-service 적용, toon 설정(app, 컬렉션 이름 규칙), JWKS 검증, 라우터·국외 동의 필터 연동 테스트 | `apps/api/`(`app/ai/graphs/`, `app/ai/tools/toon/`, `app/ai/compliance/toon.py`, `app/ai/products/toon/` 제외), `apps/api/tests/platform/` | TN-06-001 | P0 | M | Fable | 다른 app `aud`·만료·재사용 `jti` 토큰 401, 토큰 org와 다른 org의 작품 요청 403, 미동의 조직 라우팅에 상용 0, `dify.aux` 상용 0, 필수 변수 누락 시 기동 실패 | 02장 2.3·5절, `AI_ARCHITECTURE.md` 2·4·8장 |
| TN-06-045 | AI 게이트: 대화 생성, 채팅 중계(Dify, 장애 시 FastAPI 직접), 턴 선차감·정산, 서명 토큰·잡 토큰 발급, 정산 크론 엔드포인트, AI 단가, 온보딩 국외 이전 동의 API | `apps/toon/src/app/api/ai/`(`knowledge/`, `wiki/` 제외), `src/app/api/internal/`, `src/app/api/onboarding/`, `src/lib/server/ai/` | TN-06-004, TN-06-037, TN-06-044 | P0 | L | Fable | 04장 2.1절 계약 충족. 같은 `request_id` 재전송 차감 1회, 응답 미전달 시 환불 1행, Dify 차단 시 `/tools/answer-direct`로 응답, 잡 토큰은 running 잡에만(다른 상태 409), 동의 시 `ai_org_settings` 고지문 버전 일치, 정산 크론 뒤 10분 넘은 `settled_at is null` 0, 클라이언트 번들에 서명 개인키·service_role 0(빌드 검사) | 01장 TN-F-055, 059, 060 |
| TN-06-046 | 작품 설정 RAG: 노트 API(추가·목록·삭제), 작품별 컬렉션 생성·색인(`rag.ingest`), 고아 컬렉션 정리 연동, 검색 평가셋 30문항 | `apps/toon/src/app/api/ai/knowledge/`, `apps/api/app/ai/products/toon/knowledge.py`, `apps/api/tests/toon/retrieval/` | TN-06-044, TN-06-045 | P0 | M | Opus | 재현율@6 0.8 이상(제안), 작품 A 컬렉션 검색에 작품 B 청크 0, 다른 조직 컬렉션 요청 42501, 작품 삭제 24시간 뒤 청크 0, 컬렉션당 임베딩 모델 1종(`oss-embed`) | 01장 TN-F-051 |
| TN-06-047 | 작품 설정 위키 운영: ingest(create·append_episode), 사람 소유 블록 보호, 낙관적 잠금 저장, lint, 페이지 종류·slug 규칙, `voice_key` 필드, 위키 API | `apps/api/app/ai/products/toon/wiki_config.py`, `apps/toon/src/app/api/ai/wiki/`, `apps/api/tests/toon/wiki/` | TN-06-044, TN-06-046 | P0 | M | Opus | 새 페이지 draft, 출처 없는 페이지 확정 409, 사람 소유 표시 블록을 ingest가 수정하지 않음, `expected_version` 불일치 409, 문서 1건당 갱신 페이지 5개 상한, 캐스트 캐릭터마다 entity 1개, 모든 쓰기 감사 1행, 다른 작품 slug 접근 0 | 01장 TN-F-050, `LLM_WIKI.md` 3장 |
| TN-06-048 | 설정 위키·노트 화면(목록·페이지·편집기·이력·점검 결과·노트 관리) | `apps/toon/src/app/app/series/[seriesId]/wiki/`, `apps/toon/src/app/app/series/[seriesId]/notes/`, `apps/toon/src/components/wiki/` | TN-06-043, TN-06-047 | P0 | M | Sonnet | 03장 3.6절 구성, 블록 사람 소유 표시, 저장 충돌 배너, viewer 읽기 전용, 375px, 상태 배지는 아이콘 + 텍스트, 금지 문구 0 | 01장 TN-F-050, 051 |
| TN-06-049 | LangGraph 그래프 `toon.storyboard`(plot → panel_split → consistency → image_prompts → compliance), 체크포인트, 실행 기록, 출력 스키마, 평가셋 | `apps/api/app/ai/graphs/toon_storyboard.py`, `apps/api/app/ai/compliance/toon.py`, `apps/api/tests/toon/graph/` | TN-06-005, TN-06-044, TN-06-046, TN-06-058 | P0 | L | Opus | 1건 = `ai_runs` 1행 + `ai_run_steps` 5행, compliance가 마지막 노드, 캐스트 밖 캐릭터 0, 위키 대조 위반 검출률 0.8 이상(샘플 20), 걸린 컷만 1회 재작성·2회 실패 컷 `blocked`, 컷 수 일치 100%, 평가셋 20개 시놉시스를 상용·오픈소스 경로 모두 통과 | 01장 TN-F-052, 053 |
| TN-06-050 | 보조 그래프 `toon.dialogue`(retrieve → polish → compliance), `toon.image_prompt`(translate → compliance) | `apps/api/app/ai/graphs/toon_dialogue.py`, `apps/api/app/ai/graphs/toon_image_prompt.py`, `apps/api/tests/toon/aux/` | TN-06-044, TN-06-046, TN-06-058 | P0 | M | Opus | 대사 3안이 설정 말투를 유지(샘플 10건 중 8건), 모든 영어 프롬프트에 `no people, no characters, no text`, 입력 compliance FAIL 차단, 실행 기록 1행 | 01장 TN-F-054 |
| TN-06-051 | Dify `toon-chat`(질문 분류, HTTP 노드)과 `/tools/answer` toon 확장(모드 setting·idea, `series_id` 대조, 마스킹, suggestions, compliance 후처리), 대화 평가셋 30문항 | `infra/dify/`, `apps/api/app/ai/tools/toon/`, `apps/api/tests/toon/chat/` | TN-06-045, TN-06-046, TN-06-047 | P0 | M | Opus | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403, 다른 조직·다른 작품 `series_id` 403, 답변 출처 1개 이상 또는 `no_source`, 작품 A 대화에 작품 B 고유명사 0, 금지 문구 0·위기 신호 5문장 안내, DSL에 키 0 | 01장 TN-F-055, 061, 04장 6.2절 |
| TN-06-052 | 채팅 시트와 대화 목록(스트리밍, 출처 칩, 크레딧 안내, AI 생성 표시, 제안 적용 버튼) | `apps/toon/src/components/ai-chat/`, `apps/toon/src/app/app/chat/` | TN-06-043, TN-06-045 | P0 | M | Sonnet | 03장 3.6절 구성, 375px 전체 화면 시트, `aria-live`, 402 충전 안내, 대체·근거 없음·환불 상태 표시, "말풍선에 넣기"는 editorStore 커맨드 인터페이스만 호출(Undo 가능, 에디터 파일 수정 없음) | 01장 TN-F-055, 03장 5절 |
| TN-06-053 | 음성 대화: `/api/voice/`(consent, sessions, stt, tts), 보이스 6종 매핑 `lib/server/voices.ts`, 마이크 버튼·녹음 표시·변환 텍스트 수정·고지 모달 | `apps/toon/src/app/api/voice/`(`dialogue/`, `video-lines/` 제외), `apps/toon/src/components/voice/`(`VoicePicker.tsx` 제외), `apps/toon/src/lib/server/voices.ts` | TN-06-045, TN-06-052 | P0 | M | Opus | 고지 미확인 STT 403, 60초 자동 중지·초과 413, `store_audio=false` 100%, 마이크 거부 시 텍스트 채팅 정상, STT·TTS 실패 환불 1행, TTS 입력은 DB 메시지만, 보이스 환경변수 누락 시 기동 실패 | 01장 TN-F-056 |
| TN-06-054 | 대사 음성 미리듣기: `/api/voice/dialogue`(저장된 문서 텍스트만, 24시간 캐시), `VoicePicker`, 에디터 인스펙터 슬롯 사용 | `apps/toon/src/app/api/voice/dialogue/`, `apps/toon/src/components/voice/VoicePicker.tsx` | TN-06-053, TN-06-009 | P0 | M | Opus | 클라이언트 텍스트 파라미터 없음(문서에서만 읽음), 120자 초과·sfx 422, 타 조직 컷 404, 같은 요청 재전송 차감 0, 실패 환불 1행, 대체 제공자로 들려줬을 때 안내 헤더 `X-Voice-Fallback` | 01장 TN-F-057 |
| TN-06-055 | MP4 음성 입히기: `/api/voice/video-lines`(준비 단계, 선차감·정산, 제공자 고정), 워커 음성 트랙 합성 | `apps/toon/src/app/api/voice/video-lines/`, `services/toon-worker/src/media-audio/` | TN-06-020, TN-06-045, TN-06-053 | P0 | L | Opus | 한 영상의 `ai_usage` 제공자 1종·`voice_jobs.fallback_from` null, 3번째 클립 강제 실패 시 MP4 0개 + 환불, free 403 `TN002`, 음성 포함 60초 초과 `TN004`, MP4 메타데이터 `ai_voice=true`, 클립 경로 접두사 위반 시 `fail_job` | 01장 TN-F-058 |
| TN-06-056 | 3D 히어로: 흩어진 컷 → 세로 스트립(PC·태블릿), 컷 3장 정렬(모바일), 정지 이미지 대체, 성능 예산 | `apps/toon/src/components/hero3d/`, `apps/toon/public/hero/` | TN-06-043 | P1 | L | Sonnet | `HERO_3D.md` 4절 수용 기준 전부(기기 3종 동작, 3D 번들+에셋 1MB/300KB, LCP 2.5초, 로딩 전 저사양 판정과 `deviceMemory` 없는 Safari·Firefox 분기, 런타임 강등, 3D 전 HTML 사용 가능, 스크린샷 3종 고문 검토), 토큰 밖 3D 색 0, 캐릭터·말풍선·효과 글자 0 | 01장 TN-F-062, 03장 4.5절 |
| TN-06-057 | AI·음성 보안·라우팅 회귀 테스트(서명 토큰, 대화 매핑, 국외 동의 필터, 강제 오픈소스, 선차감·정산·환불, 작품 간 격리, 영상 음성 대체 금지, 라우팅 seed 스냅샷) | `apps/api/tests/toon/security/`, `tests/e2e/ai/`, `scripts/ai-routing/` | TN-06-045, TN-06-049, TN-06-051, TN-06-053, TN-06-055 | P0 | M | Fable | `resolve_ai_route` 스냅샷(기능 14행 × 동의 유/무)이 02장 5.1절과 일치, 위조·만료·재사용 토큰 401, 타인 대화 이어 쓰기 404, 미동의 조직 상용 호출 0·AI 배경 `TN007`, 작품 A 대화로 작품 B 설정 접근 0, 영상 음성 도중 대체 0, 원장 drift 0, CI 실패 시 머지 차단 | `SECURITY_BASELINE.md` 16장 |
| TN-06-058 | 생성 규칙 사전(금지 대상 6.3절, 의료·금융 단정 문형, 대화 규칙 6.7절, 위기 신호 문장) JSON과 단위 테스트 | `packages/toon-doc/rules/`, `packages/toon-doc/tests/rules/` | 없음 | P0 | S | Sonnet | 한글 경계 처리 테스트 통과(`\b` 미사용), TS와 Python이 같은 JSON 파일을 읽는 스모크 테스트, 평가 문장 30개에서 위반 검출 100% | 01장 TN-F-061, 6.3·6.7절, 6절 요청 5 |
| TN-06-059 | AI 처리 방식 온보딩 화면과 고지문(국외 이전, 음성 처리 고지문 버전 상수) | `apps/toon/src/app/onboarding/ai/`, `apps/toon/src/lib/ai-notices.ts` | TN-06-043, TN-06-045 | P0 | S | Sonnet | 03장 3.6절 구성, 건너뛰면 미동의로 기록, 고지문 버전이 서버 상수와 같다, 설정에서 철회 가능 | 01장 TN-F-059 |
| TN-06-060 | 모듈러 2000 11절(프리셋·협찬) 적용, 모놀리스 변환 결과 일치 확인, RLS 스모크에 `sponsorships`·`decide_sponsorship`·`TN008`·`TN002` 항목 추가 | `supabase/migrations/2000_toon.sql`, `supabase/tests/toon/` | TN-06-001, TN-06-002 | P0 | S | Fable | 05장 9절 2차 검증 항목 전부 통과(두 구조), 사용자 자가 승인 42501, 협찬 미승인 최종 내보내기 `TN008` | 01장 TN-F-038, 070~073 |
| TN-06-061 | 로그라인·시놉시스 생성: 그래프 `toon.logline`(FastAPI), `POST /api/logline`, 아이디어 시트 화면 | `apps/api/app/ai/graphs/toon_logline/`, `apps/toon/src/app/api/logline/`, `apps/toon/src/components/ideation/` | TN-06-044, TN-06-045, TN-06-043 | P0 | M | Opus | 3안 중복 판정 2건 이하(평가셋 20), 금지 키워드 `TN006`, 적용 전 DB 변경 0, 실패 환불 1행, 2단계 추가 차감 0 | 01장 TN-F-024, 03장 2.10절 |
| TN-06-062 | 내보내기 프리셋: `packages/toon-doc/presets/`, 내보내기 패널 프리셋 단계, Route Handler 프리셋 검사 | `packages/toon-doc/src/presets/`, `apps/toon/src/components/export/`, `apps/toon/src/app/api/exports/` | TN-06-018, TN-06-021 | P0 | S | Sonnet | 프리셋 4종 결과 픽셀 크기가 01장 TN-F-038 표와 같다(골든 테스트), 캐러셀 11장 거부, 프리셋·종류 불일치 422 | 01장 TN-F-038 |
| TN-06-063 | 브랜디드 툰: 협찬 탭·회차 연결·승인 기록 화면, `POST /api/sponsorships/{id}/decide`, 콘티·대사 그래프에 협찬 메시지·금지어 입력 | `apps/toon/src/app/series/[id]/sponsorships/`, `apps/toon/src/app/api/sponsorships/`, `apps/api/app/ai/graphs/toon_storyboard/sponsor.py` | TN-06-060, TN-06-049, TN-06-050 | P0 | M | Opus | 무료 플랜 잠금·`TN002`, 승인 기록 감사 1행, 금지어 대사 WARN, 승인 뒤 브리프 수정 시 상태 in_review 표시 | 01장 TN-F-070, 071, 03장 2.11절 |
| TN-06-064 | 렌더 워커 대가성·가상인물 표시 삽입(이미지 상단 띠, 스트립 첫 파일, MP4 첫 3초, caption.txt, 메타데이터), 검토용 시안 띠 | `services/toon-worker/src/render/disclosure/` | TN-06-019, TN-06-020, TN-06-060 | P0 | M | Opus | 협찬 회차 결과물 100%에 문구(K12 쿼리 0건), 요청 페이로드로 문구 변경 불가, 골든 이미지 차이 0.5% 이하 | 01장 TN-F-072, 073, 6.8절 |
| TN-06-065 | (Phase 2) SNS 직접 업로드: 코어 공용 업로더 소비, 네이버 클립 위험 고지·동의 화면, 협찬 회차 제목·해시태그 문구 강제 | `apps/toon/src/app/api/uploads/`, `apps/toon/src/components/upload/` | 6절 요청 13, TN-06-064 | P1 | L | Opus | 동의 없는 `naver_clip` 업로드 잡 0, 협찬 회차 업로드 제목 첫 줄 문구 100% | 01장 TN-F-080, D18 |
| TN-06-066 | (Phase 2) 숏툰 모션·자막·효과음 | `services/toon-worker/src/media-motion/`, `packages/toon-doc/src/motion/` | TN-06-020, TN-06-055 | P1 | L | Opus | 모션 프리셋 3종 골든 영상, 자막 타이밍 오차 100ms 이하, 60초 상한 유지 | 01장 TN-F-081 |

P0 작업과 테스트 대응: DB(001, 005) → 002·029, 렌더(006, 019, 020) → 006 골든·030, 에디터(007, 008, 009, 010) → 029·030, API(011, 014, 015, 018, 037) → 002·030·037 단위 테스트, 결제(022, 023, 024) → 025, AI·음성(044, 045, 046, 047, 049, 050, 051, 053, 054, 055) → 057·030(각 작업의 평가셋·단위 테스트 포함), 디자인 시스템 2단계(034) → 042 사람 검토.

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 003, 004, 005, 033, 041, 058 | 7 | 없음 | DB 조각 적용·타입(AI 기본값 포함), 변환 스크립트, 앱·워커 골격, 문서 스키마, 디자인 레퍼런스(1단계), 생성 규칙 사전 |
| W1 | 002, 006, 007, 010, 012, 028, 037, 044 | 8 | W0 완료 | RLS 테스트, 렌더러, 스토어, 레이아웃, 카탈로그 CLI, 법적 페이지(AI 조항 포함), 서버 공통, AI 서비스 설치 |
| W1-D | 034 → 042 → 043(직렬) | 1 | 004, 041 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 008, 009, 011, 013, 016, 018, 022, 045 | 8 | W1 완료, 화면은 043 | 에디터 동작, 카탈로그·내보내기·결제 API, 콘티 변환, AI 게이트 |
| W3 | 019, 021, 023, 024, 026, 027, 036, 046, 052, 056, 059 | 11 | W2 완료, 화면은 043 | 이미지 렌더 워커, 내보내기 화면, 스케줄, 결제 화면, 랜딩, 온보딩, 플랫폼 규격, 설정 RAG, 채팅 시트, 3D 히어로, AI 온보딩 |
| W4 | 020, 025, 029, 031, 047, 049, 050, 053 | 8 | W3 완료(020은 019 완료) | MP4, 결제 E2E, 에디터 테스트, 린트, 설정 위키 운영, 콘티 그래프, 보조 그래프, 음성 대화 |
| W5 | 014, 015, 017, 035, 048, 051, 054, 055 | 8 | W4 완료 | AI 콘티·배경·대사 API(그래프 연결), 화면(콘티), 설정 위키 화면, Dify 채팅, 대사 미리듣기, MP4 음성 |
| W5-B | 060(W0에서 시작 가능), 061, 062, 063, 064 | 5 | 060은 001·002 뒤, 나머지는 W5 완료 | 2026-10-13 2차 보강: 프리셋·협찬 DB, 로그라인, 프리셋 화면, 브랜디드 툰, 표시 렌더 |
| W6 | 030, 032, 057 | 3 | W5·W5-B 완료 | 핵심 E2E(협찬 회차 내보내기 포함), 내 에셋, AI 보안·라우팅 회귀 → MVP 완료 조건 |
| W7 | 038 → 039, 040, 065, 066 | 4(039는 038 뒤) | MVP 출시 후 | Phase 2·3(직접 업로드·숏툰 모션 포함) |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 9 (001, 002, 005, 022, 023, 038, 044, 045, 057) | 15.5% | 20 / 116 = 17.2% |
| Opus | 27 (006, 007, 008, 010, 011, 012, 014, 015, 016, 018, 019, 020, 025, 029, 030, 035, 037, 039, 043, 046, 047, 049, 050, 051, 053, 054, 055) | 46.6% | 61 / 116 = 52.6% |
| Sonnet | 18 (004, 009, 013, 017, 021, 024, 026, 027, 032, 034, 036, 040, 041, 048, 052, 056, 058, 059) | 31.0% | 31 / 116 = 26.7% |
| Haiku | 4 (003, 028, 031, 033) | 6.9% | 4 / 116 = 3.4% |
| 합계 | 58 | 100% | 116 |

비율은 모델 작업 58개 기준이다. 사람 작업 1개(TN-06-042, M)는 비율에서 뺐다. 2026-10-13 이전(40개)은 Fable 15.0%, Opus 45.0%, Sonnet 30.0%, Haiku 10.0%였다. 합계 59개 = 모델 58 + 사람 1.

Fable은 이전 항목(결제, RLS, 데이터 모델)에 더해 AI 보안 경계(서명 토큰 검증 044, AI 게이트의 선차감·정산·동의 045, AI 회귀 057)를 맡는다. 그래프·RAG·위키·Dify·음성 구현은 Opus, 채팅 시트·설정 위키 화면·3D 히어로·규칙 사전·온보딩 화면은 Sonnet이다(`docs/products/_platform-core/DOC_TEMPLATE.md:253`).

## 5. 리뷰 작업 흡수표

리뷰 5장 14개(`docs/reviews/Toon-Factory.md:114-127`) 전부.

| 리뷰 작업 | 내용 | 흡수 작업 ID | 비고 |
|---|---|---|---|
| #1 | 0단계 기획 보강(스키마, 에셋 명세, 영상 규칙, 플랜 한도) | 이 폴더 01·02·05장 + TN-06-005 | 기획은 이번 단계에서 완료, 스키마 코드화는 005 |
| #2 | 마이그레이션 + RLS + Storage 정책 | TN-06-001, TN-06-002 | 조각 작성 완료, 확정·테스트 자동화 |
| #3 | 골격 이식, Claude.md 정리 | TN-06-004, 제품 `CLAUDE.md` | 골격은 BlogStudio 구조 참고 + 코어 패키지 |
| #4 | editorStore | TN-06-007 | |
| #5 | Fabric 어댑터 | TN-06-008 | 리뷰는 Fable. 상태 원천·단방향 구조를 02장에서 확정했으므로 구현은 Opus로 낮춘다 |
| #6 | 3단 에디터 UI | TN-06-009 | |
| #7 | 표정 교체, 말풍선 편집 | TN-06-010 | |
| #8 | 카탈로그 API, 서명 URL, 일괄 등록 | TN-06-011, TN-06-012 | |
| #9 | PNG/ZIP 내보내기 | TN-06-019 | 리뷰의 클라이언트 `toDataURL` 대신 서버 렌더(리뷰 #1·#2 차단), 모델 Sonnet → Opus |
| #10 | MP4 렌더 워커 | TN-06-020 | |
| #11 | Toss 정기결제 + 웹훅 | TN-06-022, TN-06-023 | |
| #12 | 에디터·RLS 테스트 | TN-06-029, TN-06-002 | |
| #13 | 랜딩/가격, 온보딩 템플릿 | TN-06-026, TN-06-024, TN-06-027 | |
| #14 | 공개 작품 페이지 + GEO | TN-06-040 | Phase 3 |

## 6. 공용 모듈 요청

`_platform-core`에 남길 요청이다. 제품이 직접 고치지 않는다.

| # | 요청 | 이유 | 급함 |
|---|---|---|---|
| 1 | `_supabase-modular/seed.sql` toon 플랜 features를 01장 4.1절 전체 키로 갱신, toon 크레딧팩 2종 추가 | 해결(2026-10-13 코어 반영 완료): 모듈러 seed가 모놀리스 seed와 일치(전체 키, 크레딧팩 2종). 이전에는 `watermark`, `export`만 있어 Pro도 무료 한도를 받았다(05장 8절) | 완료 |
| 2 | fal client `FalSubmit`에 `negativePrompt`, `seed`, (Phase 2) `referenceImageUrls` 입력 추가 | 기준 인터페이스에 없다(`SHARED_MODULES.md:240`). 배경 부정 프롬프트는 MVP에 필요 | MVP 전 |
| 3 | `core.adjust_credits` 추가 | 크레딧팩 미사용분 환불(`CORE_SPEC.md:237`) | MVP 직후 |
| 4 | `confirm_payment_order` 금액 불일치 시 주문 failed 보존 결함 수정 | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가. 제품은 PM001 시 별도 호출 | 완료 |
| 5 | compliance 규칙 사전의 제품별 확장 지점(웹툰: 작가 화풍, 타 작품 캐릭터) | `SHARED_MODULES.md:347` | MVP 전 |
| 6 | heartbeat 반환값으로 running 잡 취소 신호(`CORE_SPEC.md:307` 제안) | 긴 MP4 렌더 취소 | Phase 2 |
| 7 | `_supabase-modular/seed.sql` toon free·pro features에 AI 키 5개(`ai_chat`, `ai_chat_turns_per_day`, `voice_chat`, `dialogue_voice`, `video_voice`) 병합 | 모듈러 배포에서 `2000_toon.sql` 10.2절이 seed보다 먼저 실행되면 덮어써진다. 서버는 누락 키를 false/0으로 읽는다 | MVP 전 |
| 8 | 워커 → 그래프 호출용 잡 토큰 패턴 표준화(`/api/internal/ai-token`, 개인키는 Next.js만) | 01장 D17. 다른 제품(astro-ai R-8)과 같은 요청 | MVP 전 |
| 9 | 공용 3D 장면 키트 `packages/ui-3d`(로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 모니터) | `docs/products/_design-guide/HERO_3D.md:56-68`. 없으면 `hero3d/` 안에 같은 인터페이스로 둔다 | MVP 전(권장) |
| 10 | ai-service 공용 기능: (a) 사용자 조직 위키 페이지 저장 API(`expected_version`, 사람 소유 블록, 권한은 토큰 org + 작품 slug 접두사) (b) `/v1/chat/completions`가 `dify.aux`·`wiki.query` 기능 키를 `model`로 받기 (c) 작품(컬렉션) 삭제·고아 컬렉션 정리 엔드포인트 | `docs/products/_platform-core/LLM_WIKI.md:30-31`, `:45`. 사용자 조직 위키는 공용 설계에 편집 API가 없다 | MVP 전 |
| 11 | core-voice: 기능 단위 "작업 중 대체 금지" 플래그 일반화(`narration`, `video_voice`) | 현재는 기능 이름별 규칙이다(`VOICE_ARCHITECTURE.md:47`) | MVP 전 |
| 12 | core-voice: 서버 배치 합성 헬퍼(대사 목록 → mp3 클립, 분할 호출·진행 콜백·Storage 저장) | 영상 음성 준비 단계(TN-F-058) | MVP 직후 |
| 13 | 공용 SNS 업로더 진입점(video 외 앱이 `upload.<platform>` 잡을 요청, 채널 토큰은 `core.encrypted_credentials`, `naver_clip` 위험 동의 기록 표준화) | toon TN-F-080(2026-10-13 2차). video 스키마에 쓰지 않기 위해 | Phase 2 전 |

## 7. 완료 정의

| 조건 | 기준 |
|---|---|
| 빌드·타입·린트 | `pnpm -r build`, `tsc --noEmit`, `eslint` 0 오류, 금지 문구 검사 통과 |
| SQL | `_tools-sqlcheck` 체커 OK(모듈러·모놀리스), 모놀리스 변환 결과 일치 |
| RLS 스모크 | TN-06-002 전 항목 통과(두 구조) |
| 결제 E2E | TN-06-025 시나리오 5개 통과, 원장 drift 0 |
| 핵심 E2E | TN-06-030 통과(위키 → 콘티 일관성 → 영상 음성 포함), K1 측정 로그 |
| 렌더 일치 | 골든 이미지 차이 0.5% 이하 |
| AI·음성 | `pytest apps/api` 통과, TN-06-057 녹색, 콘티 그래프 평가셋 20개를 상용·오픈소스 경로 모두 통과, 채팅 평가셋 30문항 금지 문구 0, 영상 음성 대체 금지 테스트 통과, 정산 크론 뒤 `settled_at is null` 0 |
| 3D·디자인 시스템 | `HERO_3D.md` 4절 수용 기준, 디자인 시스템 4단계(TN-06-043) 완료, `tailwind.config.js`·hex 하드코딩 0 |
| 작업 | W0~W6 작업(001~037, 041~064) 전부 완료. W7(038~040, 065, 066)은 MVP 범위 밖 |
