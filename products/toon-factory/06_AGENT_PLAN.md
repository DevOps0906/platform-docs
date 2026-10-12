# 06 에이전트 작업 계획: Toon Factory

작성일 2026-10-12. 작업 ID `TN-06-###`. 모델 기준은 `docs/products/_platform-core/DOC_TEMPLATE.md` 1장(Fable: 결제·권한·RLS·데이터 모델, Opus: 기능·API·테스트 설계, Sonnet: UI·문서, Haiku: 보일러플레이트·문구·반복 점검).

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 작업은 표의 "소유 파일/디렉토리"만 만들거나 고친다. 다른 작업의 디렉토리가 필요하면 선행 작업의 공개 인터페이스(타입, 함수)를 import만 한다 |
| 공용 진입 파일 | `apps/toon/package.json`, `next.config.ts`, `src/app/layout.tsx`, `src/proxy.ts`는 TN-06-004 소유. 다른 작업이 의존성을 추가해야 하면 PR 설명에 적고 TN-06-004 담당이 합친다 |
| 워커 등록 | `services/toon-worker/src/main.ts`, `registry.ts`는 TN-06-033 소유. 핸들러 작업은 자기 디렉토리의 `index.ts`에서 `WorkerHandler`를 export만 한다 |
| 공유 패키지 | `packages/toon-doc`는 하위 디렉토리별로 소유를 나눈다(schema / render / layout / storyboard / presets / templates) |
| DB | `supabase/`와 모듈러 조각은 Fable만. 다른 작업은 SQL을 고치지 않고 요청을 남긴다 |
| 코어 | `_platform-core` 패키지는 소비만. 필요 기능은 6절 요청 |

경계 요약(02장 2절과 같음): 앱 `apps/toon/`, 문서·렌더 공유 `packages/toon-doc/`, 워커 `services/toon-worker/`, 도구 `tools/`, DB `supabase/`, E2E `tests/e2e/`, 디자인 `design-system/toon-factory/`.

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| TN-06-001 | 모듈러 조각 확정, 로컬 적용, 타입 생성, `[api].schemas`에 toon 추가 | `supabase/migrations/2000_toon.sql`, `supabase/config.toml`, `packages/toon-doc/src/db-types.ts` | 없음 | P0 | M | Fable | `supabase db reset` 성공, SQL 체커 OK, `gen types --schema core,toon` 결과 커밋 | 리뷰 5장 #2, 05장 |
| TN-06-002 | RLS/권한 회귀 테스트 자동화(05장 4.1절 68항목 + Storage 정책) | `supabase/tests/toon/` | TN-06-001 | P0 | M | Fable | CI에서 모듈러·모놀리스 둘 다 68항목 이상 통과, 실패 시 빌드 실패 | `SECURITY_BASELINE.md:238-263`, 리뷰 5장 #12 |
| TN-06-003 | 조각 → 모놀리스 변환 스크립트(DB_CONVENTIONS 12장 규칙) | `tools/sql-mono/` | 없음 | P0 | S | Haiku | 스크립트 결과가 `supabase/monolith/migrations/0002_toon_domain.sql`과 바이트 단위로 같다 | `DB_CONVENTIONS.md:264` |
| TN-06-004 | 앱 골격: Next 16, core-db/core-auth 연결, `proxy.ts` 라우트 보호, shadcn 설치, 로그인/가입 서버 액션 뼈대 | `apps/toon/package.json`, `next.config.ts`, `tsconfig.json`, `src/app/layout.tsx`, `src/proxy.ts`, `src/components/ui/` | 없음 | P0 | M | Sonnet | 비로그인으로 `/app` 접근 시 `/login` 리다이렉트, 프로필 없는 세션은 로그아웃, `tsc` 0 오류 | 리뷰 5장 #3, `SECURITY_BASELINE.md:178-188` |
| TN-06-005 | CutDoc zod 판별 유니온, 버전 마이그레이션, 콘티 스크립트 스키마 | `packages/toon-doc/src/schema/` | 없음 | P0 | M | Fable | 02장 2.2절, 04장 4.1절 스키마 그대로. 잘못된 kind, 61개 레이어, 256KB 초과 문서가 거부된다 | 리뷰 #3, #4, 리뷰 5장 #1 |
| TN-06-006 | 공용 렌더러 `renderCut`(브라우저 fabric / `fabric/node`), 글꼴 로딩, 워터마크·AI 표기 오버레이 | `packages/toon-doc/src/render/`, `packages/toon-doc/tests/render/` | TN-06-005 | P0 | L | Opus | 같은 문서를 두 환경에서 렌더한 골든 이미지 차이 0.5% 이하(샘플 10컷) | 02장 2절, 7절 위험 |
| TN-06-007 | editorStore: 문서 모델, 커맨드, immer patch 히스토리 100단계, 디바운스 자동 저장(`save_cut_doc`), 충돌 처리 | `apps/toon/src/stores/` | TN-06-005 | P0 | L | Opus | Undo 100회로 초기 상태 복귀, 두 탭 동시 편집 시 `TN409` 배너 | 리뷰 5장 #4, TN-F-005, TN-F-015 |
| TN-06-008 | Fabric 어댑터: 문서 → Fabric 단방향, `object:modified` → 커맨드, 선택/변형/순서, rAF 배치, SSR 비활성 | `apps/toon/src/components/canvas/` | TN-06-006, TN-06-007 | P0 | L | Opus | 레이어 30개 컷 드래그 55fps 이상, Fabric 객체를 직접 상태로 쓰는 코드 0건(린트 규칙) | 리뷰 5장 #5, 리뷰 #8 |
| TN-06-009 | 에디터 3패널 UI, 컷 스트립, 인스펙터, 키보드 단축키 | `apps/toon/src/components/editor/`, `apps/toon/src/app/editor/` | TN-06-007, TN-06-034 | P0 | L | Sonnet | 03장 3.1절 와이어프레임 구성, viewer는 편집 비활성 | 리뷰 5장 #6 |
| TN-06-010 | 표정 앵커 계산, 말풍선 줄바꿈·크기·꼬리 기하(순수 함수) | `packages/toon-doc/src/layout/` | TN-06-005 | P0 | M | Opus | 표정 6종 교체 시 머리 위치 오차 1px 이하, 120자 말풍선 자동 확장 | 리뷰 5장 #7, TN-F-012, TN-F-013 |
| TN-06-011 | 카탈로그 서명 URL API(`org_asset_access` 검사, 15분, 레이트 리밋) | `apps/toon/src/app/api/catalog/` | TN-06-037 | P0 | M | Opus | 무료 조직이 premium id를 요청하면 `denied`에 들어가고 URL이 없다. 601번째 요청 429 | 리뷰 5장 #8, 리뷰 #2 |
| TN-06-012 | 카탈로그 일괄 등록 CLI(검수 규칙: 알파, 높이 2048 이상, 앵커, 표정 크기 일치) + 관리자 검증/공개 API | `tools/catalog-import/`, `apps/toon/src/app/api/admin/` | TN-06-001 | P0 | M | Opus | 규칙 위반 폴더는 전부 거부, 검증 없는 공개는 409, 모든 관리자 쓰기가 감사 로그에 남음 | 리뷰 5장 #8, 리뷰 #5, #6 |
| TN-06-013 | 관리자 카탈로그 화면 | `apps/toon/src/app/admin/` | TN-06-012 | P0 | S | Sonnet | platform_admin 외 접근 403(서버 가드) | 03장 3.5절 |
| TN-06-014 | AI 콘티: Route Handler + `storyboard.generate` 핸들러(JSON 검증, 코드 보정, 환불) | `apps/toon/src/app/api/storyboard/`, `services/toon-worker/src/handlers/storyboard/` | TN-06-037, TN-06-033 | P0 | M | Opus | 8컷 요청이 8컷 스크립트로 저장, LLM 실패 시 3크레딧 환불 원장 1행 | TN-F-020 |
| TN-06-015 | AI 배경: Route Handler(compliance 규칙, 용량), `image.generate` 핸들러(fal, 저장, 썸네일), fal 웹훅 | `apps/toon/src/app/api/generations/`, `services/toon-worker/src/handlers/image/`, `apps/toon/src/app/api/webhooks/fal/` | TN-06-037, TN-06-033 | P0 | L | Opus | 성공 시 `user_assets.ai_generated=true`, 안전 거부 시 재시도 없이 환불, 2장 중 1장 실패 시 4크레딧 부분 환불 | TN-F-022, TN-F-023 |
| TN-06-016 | 콘티 → CutDoc 변환(`scriptToDocs`), 기본 배치 규칙 | `packages/toon-doc/src/storyboard/` | TN-06-005, TN-06-010 | P0 | M | Opus | 캐릭터 position left/center/right가 컷 너비 1/4, 1/2, 3/4에 놓이고 말풍선이 머리 위에 겹치지 않게 배치 | TN-F-020 |
| TN-06-017 | 작품 목록, 작품 만들기, 회차 목록, 캐스트, 콘티 화면 | `apps/toon/src/app/app/series/`, `apps/toon/src/app/app/page.tsx` | TN-06-014, TN-06-016 | P0 | M | Sonnet | 03장 2.2절 플로우 동작, 한도 오류 문구 표시 | 03장 3.2~3.3절 |
| TN-06-018 | 내보내기 API(플랜·월 한도·에셋 등급·길이 검사, mp4 선차감, `exports` 행, 잡), 다운로드, 잡 취소 | `apps/toon/src/app/api/exports/`, `apps/toon/src/app/api/jobs/` | TN-06-037, TN-06-033 | P0 | M | Opus | 무료가 mp4 요청 시 403 `TN002`, 요청 본문에 `watermark:false`를 넣어도 행의 값은 true | 리뷰 #1, TN-F-030~036 |
| TN-06-019 | 이미지 내보내기 핸들러: png/zip/strip, 원본 에셋 로드, 등급 재확인, 워터마크, AI 메타데이터·가시 표기, caption.txt | `services/toon-worker/src/handlers/export-image/` | TN-06-006, TN-06-018 | P0 | L | Opus | 무료 결과에 워터마크, AI 배경 사용 시 PNG iTXt `ai_generated=true`, 등급 밖 에셋이면 `TN003` 실패 | 리뷰 5장 #9, 리뷰 #1, #2 |
| TN-06-020 | MP4 핸들러: Shorts Maker FFmpeg 인자 이식, 4:5 흐림 채움, 웹툰 팬, 전환, BGM, 메타데이터 | `services/toon-worker/src/handlers/export-mp4/`, `services/toon-worker/src/media/` | TN-06-019 | P0 | L | Opus | 10컷 x 2.5초 → 25초 1080x1920 30fps, 60초 영상 p95 120초 이하, 실패 시 환불 | 리뷰 5장 #10, TN-F-033 |
| TN-06-021 | 내보내기 패널, 진행률(Realtime), 기록·다운로드 화면, 플랫폼 체크리스트 | `apps/toon/src/components/export/`, `apps/toon/src/app/app/exports/` | TN-06-018 | P0 | M | Sonnet | 대기 중 취소 시 환불 표시, 만료 행은 다시 내보내기 버튼 | 03장 3.4절, TN-F-037 |
| TN-06-022 | Toss: checkout, confirm, 빌링키 발급·첫 청구, 해지, 웹훅(서명, 멱등) | `apps/toon/src/app/api/billing/`, `apps/toon/src/app/api/webhooks/toss/` | TN-06-037 | P0 | L | Fable | 클라이언트 금액 변조 시 미승인, 같은 결제키 재호출 멱등, `PM001` 시 `fail_payment_order`, 취소 API 호출과 알림 | 리뷰 5장 #11 |
| TN-06-023 | 워커 스케줄: 빌링키 정기 청구(재시도 1/3/7일), 만료 내보내기 파일 삭제, 30분 초과 생성 실패 처리 | `services/toon-worker/src/schedules/` | TN-06-022 | P0 | M | Fable | 청구 실패 3회 후 canceled, 30일 지난 파일 0개 | 리뷰 5장 #11, `CORE_SPEC.md:223-233` |
| TN-06-024 | 결제/요금 화면(플랜, 팩, 원장, 해지 예약) | `apps/toon/src/app/app/billing/`, `apps/toon/src/app/(marketing)/pricing/` | TN-06-022 | P0 | M | Sonnet | 01장 4절 값과 화면 값 일치, "무제한" 문구 없음 | 리뷰 5장 #13 |
| TN-06-025 | 결제 E2E(Toss 테스트 키): 구독 시작 → 워터마크 해제 → 해지 예약 → 기간 말 free 복귀, 크레딧팩 구매 | `tests/e2e/billing/` | TN-06-022, TN-06-023, TN-06-024 | P0 | M | Opus | 시나리오 5개 통과, 원장 drift 0 | `DOC_TEMPLATE.md` 2.7절 필수 |
| TN-06-026 | 랜딩(세로 스트립 히어로, 주석 전환, 요금 표) | `apps/toon/src/app/(marketing)/(home)/`, `apps/toon/src/components/landing/` | TN-06-034 | P1 | M | Sonnet | `DESIGN_PRINCIPLES.md` 7단계 체크리스트 12항목 통과, 01장 6.5절 금지 문구 0건 | 리뷰 5장 #13, 03장 4절 |
| TN-06-027 | 로그인·가입(연령 확인, `signup_app`) 화면, 온보딩 템플릿 3종 | `apps/toon/src/app/(auth)/`, `apps/toon/src/app/app/onboarding/`, `packages/toon-doc/src/templates/` | TN-06-004, TN-06-016 | P0 | M | Sonnet | 가입 후 템플릿 선택까지 3클릭, 템플릿은 무료 에셋만 | 리뷰 5장 #13, TN-F-006 |
| TN-06-028 | 약관, 처리방침, AI 이용 고지, 에셋 이용 허락 페이지 문구 | `apps/toon/src/app/(legal)/` | TN-06-004 | P0 | S | Haiku | 01장 6.1~6.3절 항목 전부 포함, 법무 검토 체크박스 | 01장 6절 |
| TN-06-029 | 에디터 단위/통합 테스트: 커맨드·히스토리, 스키마 직렬화 왕복, 레이아웃 함수 | `apps/toon/tests/editor/`, `packages/toon-doc/tests/schema/` | TN-06-007, TN-06-010 | P0 | M | Opus | 커버리지 80% 이상(stores, schema, layout) | 리뷰 5장 #12 |
| TN-06-030 | E2E 핵심 플로우: 가입 → 템플릿 → 편집 → PNG 내보내기, 콘티 → 적용 → MP4 | `tests/e2e/flows/` | TN-06-017, TN-06-020, TN-06-021, TN-06-027 | P0 | M | Opus | 두 시나리오가 CI에서 통과, K1 측정 로그 출력 | 01장 7절 |
| TN-06-031 | 린트·타입 정리, 금지 문구 검사 스크립트(01장 6.5절 사전) | `tools/copy-lint/`, 루트 `eslint.config.mjs` | TN-06-026 | P1 | S | Haiku | 금지 문구가 포함된 문자열이 있으면 CI 실패 | 01장 6.5절 |
| TN-06-032 | 내 에셋 화면(AI 배지, 용량, 보관) | `apps/toon/src/app/app/library/` | TN-06-015 | P1 | S | Sonnet | 보관 후 목록에서 사라짐(`archive_user_asset`) | TN-F-045 |
| TN-06-033 | 워커 골격(`runWorker`, 큐 2개, 동시성), 환경변수 검증(웹·워커) | `services/toon-worker/src/main.ts`, `services/toon-worker/src/registry.ts`, `services/toon-worker/src/env/`, `apps/toon/src/lib/env/` | 없음 | P0 | S | Haiku | 필수 변수 누락 시 기동 실패, FFmpeg·글꼴 확인 실패 시 기동 실패 | 02장 8절 |
| TN-06-034 | 디자인 시스템: UUPM 초안 → MASTER.md(03장 4.3절 토큰), Tailwind 테마, 글꼴 4종 파일과 OFL 확인 | `design-system/toon-factory/`, `apps/toon/src/styles/`, `assets/fonts/` | 없음 | P0 | M | Sonnet | 토큰 6색·서체 역할이 CSS 변수로만 쓰임, 글꼴 라이선스 파일 동봉 | 03장 4절 |
| TN-06-035 | 대사 다듬기 API(`withCredits`, compliance 규칙) | `apps/toon/src/app/api/dialogue/` | TN-06-037 | P1 | S | Opus | 3안 반환, LLM 실패 시 1크레딧 환불 | TN-F-021 |
| TN-06-036 | 플랫폼 규격 확인(인스타 캐러셀 상한, 네이버웹툰 도전만화 이미지 규격·AI 정책, 쇼츠 길이)과 프리셋 값 기입 | `packages/toon-doc/src/presets/` | TN-06-005 | P1 | S | Sonnet | 01장 6.4절 "미확인" 항목마다 출처 URL과 확인일 기록, D3·D4 권고 갱신 | 01장 6.4절, 8절 |
| TN-06-037 | 서버 공통: `requireSession` 래퍼, 기능 게이팅(`plan_features`), 단가표 `priceOf`, 오류 매핑(SQLSTATE → HTTP), 레이트 리밋 키 | `apps/toon/src/lib/server/` | TN-06-001, TN-06-004 | P0 | M | Opus | 04장 7절 매핑 표와 단위 테스트 일치, 클라이언트 번들에 service_role 미포함(빌드 검사) | 04장 1절 |
| TN-06-038 | (Phase 2) 커스텀 캐릭터 조각 `2010_toon_character_sheet.sql`(custom_characters, sheet_cells, 승인 상태 전이) + RLS 테스트 | `supabase/migrations/2010_toon_character_sheet.sql`, `supabase/tests/toon-sheet/` | TN-06-002 | P2 | M | Fable | 셀 승인 전 에디터 사용 불가(DB), 다른 조직 0행 | 01장 2절 Phase 2 |
| TN-06-039 | (Phase 2) 캐릭터 시트 생성(참조 이미지 fal, 셀 단위 재생성 3크레딧, 배경 제거) | `services/toon-worker/src/handlers/character-sheet/`, `apps/toon/src/app/app/characters/` | TN-06-038 | P2 | L | Opus | 40셀 시트 생성 후 승인한 셀만 캐릭터 탭에 노출 | 01장 2절, 6절 코어 요청 2 |
| TN-06-040 | (Phase 3) 공개 작품 페이지 + JSON-LD(ComicStory), AI 사용 배지 | `apps/toon/src/app/(public)/works/` | TN-06-026 | P2 | S | Sonnet | 공개 설정한 회차만 anon 노출, 구조화 데이터 검증 통과 | 리뷰 5장 #14, 분석 `:1302` |

P0 작업과 테스트 대응: DB(001, 005) → 002·029, 렌더(006, 019, 020) → 006 골든·030, 에디터(007, 008, 009, 010) → 029·030, API(011, 014, 015, 018, 037) → 002·030·037 단위 테스트, 결제(022, 023, 024) → 025.

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 003, 004, 005, 033, 034 | 6 | 없음 | DB 조각 적용·타입, 변환 스크립트, 앱·워커 골격, 문서 스키마, 디자인 토큰 |
| W1 | 002, 006, 007, 010, 012, 028, 037 | 7 | W0 완료 | RLS 테스트, 렌더러, 스토어, 레이아웃, 카탈로그 CLI, 법적 페이지, 서버 공통 |
| W2 | 008, 009, 011, 013, 014, 015, 016, 018, 022, 035 | 10 | W1 완료 | 에디터 동작, 카탈로그·AI·내보내기·결제 API |
| W3 | 017, 019, 021, 023, 024, 026, 027, 032, 036 | 9 | W2 완료 | 화면 전부, 이미지 렌더 워커, 스케줄 |
| W4 | 020, 025, 029, 030, 031 | 5 | W3 완료(020은 019 완료) | MP4, 결제 E2E, 테스트, 린트 → MVP 완료 |
| W5 | 038, 039, 040 | 3 | MVP 출시 후 | Phase 2·3 |

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 6 (001, 002, 005, 022, 023, 038) | 15.0% | 13 / 80 = 16.3% |
| Opus | 18 (006, 007, 008, 010, 011, 012, 014, 015, 016, 018, 019, 020, 025, 029, 030, 035, 037, 039) | 45.0% | 42 / 80 = 52.5% |
| Sonnet | 12 (004, 009, 013, 017, 021, 024, 026, 027, 032, 034, 036, 040) | 30.0% | 21 / 80 = 26.3% |
| Haiku | 4 (003, 028, 031, 033) | 10.0% | 4 / 80 = 5.0% |
| 합계 | 40 | 100% | 80 |

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

## 7. 완료 정의

| 조건 | 기준 |
|---|---|
| 빌드·타입·린트 | `pnpm -r build`, `tsc --noEmit`, `eslint` 0 오류, 금지 문구 검사 통과 |
| SQL | `_tools-sqlcheck` 체커 OK(모듈러·모놀리스), 모놀리스 변환 결과 일치 |
| RLS 스모크 | TN-06-002 전 항목 통과(두 구조) |
| 결제 E2E | TN-06-025 시나리오 5개 통과, 원장 drift 0 |
| 핵심 E2E | TN-06-030 통과, K1 측정 로그 |
| 렌더 일치 | 골든 이미지 차이 0.5% 이하 |
| 작업 | W0~W4 작업(001~037) 전부 완료. W5는 MVP 범위 밖 |
