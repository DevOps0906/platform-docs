# 06 에이전트 작업 계획: Microweb Studio

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 아래 표의 "소유 파일/디렉토리"는 작업끼리 겹치지 않는다. 다른 작업의 디렉토리는 읽기만 한다 |
| 공유 파일 | `apps/microweb-studio/package.json`, `tsconfig.json`, `next.config.ts`는 MW-06-001 소유. 다른 작업은 의존성 추가를 PR 설명에 적고 001 담당(또는 웨이브 종료 후 통합 에이전트)이 반영 |
| DB | `_supabase-modular/migrations/1500_microweb.sql`과 모놀리스 변환본은 MW-06-002(Fable)만 수정. 다른 작업은 스키마 변경을 요청으로 남긴다 |
| 코어 | `_platform-core`, 코어 마이그레이션은 수정하지 않는다. 필요하면 6절 요청 |
| 앱 루트 | `apps/microweb-studio/` (아래 경로는 이 루트 기준) |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| MW-06-001 | 앱 스캐폴드: Next.js 16, TS strict, Tailwind 빌드, lockfile, `.gitignore`, CI(tsc, lint, build) | `package.json`, `tsconfig.json`, `next.config.ts`, `.gitignore`, `.github/workflows/microweb-ci.yml` | 없음 | P0 | M | Haiku | `tsc --noEmit` 0오류, `latest` 의존성 0개, CI 녹색. 근거: 보일러플레이트 | premium 5장 #4, nexus #3, #6, webcraft #6, #10 |
| MW-06-002 | DB 조각 적용, 모놀리스 변환 스크립트, 타입 생성(`--schema core,microweb`) | `supabase/`(링크), `scripts/db/`, `src/types/supabase.ts` | 없음 | P0 | S | Fable | 체커 mod/mono OK, 변환 결과가 저장된 `0002_microweb_domain.sql`과 diff 0. 근거: 데이터 모델 | 05장 9절, premium #5, #10 |
| MW-06-003 | 인증 연결: core-db 클라이언트, `requireSession('microweb')`, `proxy.ts`, `studio_access` 가드, `/pending` | `src/server/auth/`, `src/proxy.ts`, `src/app/pending/`, `src/app/login/` | 001, 002 | P0 | M | Fable | 허용 목록 없는 사용자는 `/studio`에서 `/pending`, 프로필 없으면 로그아웃. 근거: 권한 | MW-F-024, `SECURITY_BASELINE.md` 11장 |
| MW-06-004 | 블록 zod 스키마 17종, content 검증, 템플릿 레지스트리(필수 블록) | `src/engine/schema/` | 001 | P0 | M | Opus | 필수 블록 누락 content는 검증 실패, 모르는 블록 거부, 256KB 초과 거부. 근거: 데이터 계약 설계 | MW-F-001, premium #7 |
| MW-06-005 | 블록 렌더러 이식(원본 섹션 7개 → 블록 17종), 갤러리 라이트박스·lazy, 미사용 코드 제거 | `src/engine/blocks/` | 004 | P0 | L | Sonnet | 원본 constants 없이 content JSON만으로 렌더, `scrollRef`·`mapUrl` 잔재 0, picsum 0. 근거: UI | MW-F-002~010, premium #8, #12 |
| MW-06-006 | 템플릿 테마 토큰과 `wedding_classic` 테마, 모션(Ken Burns, 크로스페이드, reduced-motion) | `src/engine/themes/` | 004 | P0 | M | Sonnet | 테마 대비 4.5:1, reduced-motion에서 자동 모션 0. 근거: UI | 03장 6절 |
| MW-06-007 | 하객 페이지 `/i/[slug]`: anon 스냅샷 조회, slug별 OG, noindex, 404/410, 공개 기한 표시, BGM 라우트 | `src/app/i/`, `src/app/api/public/[slug]/bgm/` | 005, 006 | P0 | M | Opus | 초안 slug 404, 중단 30초 안에 410, 카카오 디버거 slug별 OG, 하객 경로에 생성형 AI 호출 0. 근거: 기능 구현 | MW-F-009, MW-F-011, premium #1, #10 |
| MW-06-008 | 공유 바: 카카오 SDK(환경변수 키, 공식 SRI), Web Share, 링크 복사 | `src/engine/share/` | 004 | P0 | S | Sonnet | 키 없으면 Web Share 폴백, 가짜 integrity 0. 근거: 설정 | premium #3 |
| MW-06-009 | 하객 쓰기 라우트(방명록, RSVP), IP 해시, 허니팟, Origin 검사 | `src/app/api/public/[slug]/guestbook/`, `src/app/api/public/[slug]/rsvp/`, `src/server/guest/` | 002, 003 | P0 | M | Opus | 4번째 연속 작성 429, 링크 422, 예식 후 RSVP 410, 원문 IP 로그 0. 근거: API 연동 | MW-F-006, MW-F-008, premium #5, #6 |
| MW-06-010 | 업로드 파이프라인: 서명 업로드 URL, 완료 검증, 삭제(Storage+행) | `src/app/api/studio/sites/[id]/assets/`, `src/app/api/studio/assets/`, `src/server/storage/` | 002, 003 | P0 | M | Opus | 사용자 파일명이 경로에 0, 15MB 초과 413, 다른 조직 경로 400. 근거: API 연동 | MW-F-013, premium #1, #11 |
| MW-06-011 | 워커 `asset.process`: 매직바이트, EXIF 제거, 400/800/1600w webp, og 1200x630 | `worker/handlers/asset/`, `worker/main.ts` | 002 | P0 | M | Opus | GPS EXIF가 든 샘플 처리 후 메타 0, ready 전환. 근거: 기능 구현 | MW-F-013 |
| MW-06-012 | 워커 `site.publish`/`unpublish_assets`/`purge` + 스케줄(expire 10분, purge 매일) | `worker/handlers/site/`, `worker/schedule/` | 011 | P0 | M | Opus | 게시 잡 성공 시 `finalize_publish`, 실패 시 `fail_job` 환불 + `fail_publish`, 만료 후 공개 파일 0. 근거: 기능 구현 | MW-F-014, MW-F-015 |
| MW-06-013 | 게시 라우트: (셀프) consume → `request_publish` → enqueue, 실패 시 환불·복구 | `src/app/api/studio/sites/[id]/publish/`, `src/server/publish/` | 009, 010 | P0 | M | Fable | 미결제 MW008, 같은 request_id 재시도 시 차감 1회, enqueue 실패 시 환불 행 1. 근거: 크레딧/결제 | MW-F-014, 02장 4절 |
| MW-06-014 | 스튜디오 편집기: 블록 폼, 375px 미리보기, 자동 저장, 업로드 진행률(Realtime), 동의·시안·게시 버튼 | `src/studio/editor/`, `src/app/studio/sites/` | 005, 010, 015 | P0 | L | Sonnet | 3초 자동 저장, 게시 중 편집 잠금 표시, 키보드로 전 기능 사용. 근거: UI | MW-F-012, premium #11 |
| MW-06-015 | 스튜디오 사이트 라우트: 생성, PATCH, 전이, 동의, 시안 토큰 | `src/app/api/studio/sites/route.ts`, `src/app/api/studio/sites/[id]/route.ts`, `src/app/api/studio/sites/[id]/transition/`, `.../consent/`, `.../preview-token/` | 003, 004 | P0 | M | Opus | slug 중복 409, 게시 후 slug 변경 409, 토큰 원문은 응답 1회만. 근거: API 연동 | MW-F-012, MW-F-016 |
| MW-06-016 | AI 축하말 엔드포인트(고정 purpose/프롬프트, 입력 제한, 리밋, ai_usage) | `src/app/api/public/[slug]/greeting/`, `src/server/ai/` | 007, 009 | P0 | M | Fable | 6번째 호출 429, 미게시 사이트 404, 모델/헤더 지정 불가, 실패 시 고정 문구 위장 0. 근거: 비용·남용 경계 | MW-F-007, premium #2, 리뷰 높음 premium #3 |
| MW-06-017 | 시안 확인 `/p/[token]`과 승인 라우트 | `src/app/p/`, `src/app/api/public/preview/` | 007, 015 | P0 | S | Opus | 만료 토큰 410, 승인 후 `customer_approved_at` 기록, 페이지 noindex. 근거: 기능 구현 | MW-F-016 |
| MW-06-018 | 하객 관리: 방명록 숨김/스팸/삭제, RSVP 합계·CSV(감사 기록) | `src/studio/guests/`, `src/app/studio/sites/[id]/guests/`, `src/app/api/studio/guestbook/`, `src/app/api/studio/sites/[id]/rsvp.csv/` | 009, 014 | P0 | M | Sonnet | member는 삭제 버튼 없음, CSV 엑셀에서 한글 정상. 근거: UI | premium #5 |
| MW-06-019 | 리드·주문 관리: 라우트와 화면, 상태 전이, 개인정보 삭제 | `src/app/studio/leads/`, `src/app/studio/orders/`, `src/app/api/studio/leads/`, `src/app/api/studio/orders/`, `src/studio/crm/` | 003, 015 | P0 | M | Opus | 허용 안 된 전이 409, 카드번호형 참조 거부, 삭제 후 리드 0. 근거: 기능 구현 | MW-F-018, MW-F-019, webcraft #8(대체) |
| MW-06-020 | 쇼룸 디자인 시스템: UUPM 초안 → MASTER.md, 토큰 CSS, 서체 로딩 | `design-system/microweb-studio/`, `src/styles/` | 001 | P0 | M | Sonnet | 03장 4.3 토큰과 일치, 생성형 기본값 점검표 기록. 근거: UI | 03장 4절, nexus #6, webcraft #10 |
| MW-06-021 | 쇼룸 랜딩 `/`: 실제 샘플 렌더 히어로, 템플릿, 진행 순서, 가격 요약 | `src/app/(showroom)/page.tsx`, `src/app/(showroom)/layout.tsx`, `src/showroom/components/landing/` | 020, 024 | P0 | M | Sonnet | 금지 문구 0(미검증 수치, 할인 배너), 자동 모션 1개, 375~1440 체크리스트 통과. 근거: 메인페이지 | 03장 4절, nexus #9, #13 |
| MW-06-022 | 쇼룸 데이터 단일화: geoMeta → industries/tiers/pricing, 중복 constants 제거, 아이콘 명시 맵 | `src/showroom/data/` | 001 | P0 | S | Haiku | 업종·등급 출처 1곳, `import * as Icons` 0. 근거: 반복 정리 | webcraft #5, #7 |
| MW-06-023 | 시뮬레이터 이식: 업종 9 x 등급 4 x 디바이스 3, 등급 시안 공통 레이아웃, 문의 프리필 | `src/showroom/components/simulator/`, `src/app/(showroom)/simulator/` | 022 | P1 | M | Opus | 선택값이 `/contact` 쿼리와 리드 simulator로 이어짐, 등급 컴포넌트 공통 프레임 1개. 근거: 다중 파일 리팩토링 | MW-F-023, webcraft #9 |
| MW-06-024 | 가격표, 템플릿 카탈로그(선언형 목업 렌더), 포트폴리오 페이지 | `src/app/(showroom)/pricing/`, `src/app/(showroom)/templates/`, `src/app/(showroom)/portfolio/`, `src/showroom/components/catalog/` | 004, 022 | P0 | M | Sonnet | 카탈로그가 DB `templates`에서 렌더, picsum 0, published 포트폴리오만 노출. 근거: UI | MW-F-020~022, nexus #5, #7 |
| MW-06-025 | 견적 문의 `/contact`, 공개 라우트, 운영자 메일 알림 | `src/app/(showroom)/contact/`, `src/app/api/public/leads/`, `src/server/notify/` | 002, 022 | P0 | M | Opus | 동의 없으면 422, 4번째 연속 제출 429, 메일 실패해도 리드 저장. 근거: 외부 연동 | MW-F-017, webcraft #12 |
| MW-06-026 | 초대·허용 목록 관리(관리자 라우트, Auth 초대 메일, studio_access 부여/회수 감사) | `src/app/api/admin/`, `src/server/admin/` | 003 | P0 | S | Fable | platform_admin 외 403, 부여/회수 감사 행 1. 근거: 권한 | MW-F-024 |
| MW-06-027 | (Phase 2) Toss 크레딧팩 결제, confirm 실패 처리, 웹훅 | `src/app/api/billing/`, `src/app/api/webhooks/toss/`, `src/app/studio/billing/` | 013 | P2 | M | Fable | 금액 위조 시 confirm 미호출, PM001 시 `fail_payment_order`+Toss 취소+감사, 웹훅 서명 실패 401. 근거: 결제 | 04장 2절, MW-F-025 |
| MW-06-028 | (Phase 2) 돌잔치·부고장 블록(timeline, memorial, funeral_info)과 템플릿 출시 | `src/engine/blocks/phase2/` | 005 | P2 | M | Sonnet | `dol_basic`, `obituary_basic` beta 전환 후 생성 가능. 근거: UI | `00_MERGE_ANALYSIS.md:1091` |
| MW-06-029 | 법적 고지와 문구: 약관, 개인정보처리방침, 하객 고지, 금지 문구 점검 목록 | `src/app/(legal)/`, `src/content/copy/` | 001 | P0 | S | Haiku | 01장 6절 항목 전부 반영, 금지 문구 grep 0. 근거: 문구 | 01장 6절 |
| MW-06-030 | RLS/권한 회귀 테스트: 스모크 87항목 이식 + CI(PGlite) | `supabase/tests/` | 002 | P0 | M | Fable | mod/mono 모두 87/87, CI 필수 체크. 근거: RLS | `SECURITY_BASELINE.md` 15장, 05장 9절 |
| MW-06-031 | 결제 E2E(Toss 테스트 키): 팩 구매 → 셀프 게시 → 잡 실패 환불 | `e2e/billing/` | 027 | P2 | M | Opus | 성공 1건, 금액 위조 1건, 환불 1건 시나리오 녹색. 근거: 테스트 설계 | DOC_TEMPLATE 2.7 필수 |
| MW-06-032 | E2E 대행 플로우(F1~F3) + 출시 체크리스트(뷰포트 4종, 포커스, reduced-motion, LCP, 번들 150KB) | `e2e/flows/` | 013, 014, 021 | P0 | M | Opus | F1~F3 녹색, 하객 페이지 JS 150KB 이하. 근거: 테스트 설계 | 03장 2절, webcraft #11, nexus #10 |
| MW-06-033 | 노출 시크릿 사고 대응: webcraft `backend/.env.local` 값 폐기·재발급, 공개 여부 확인, 히스토리 정리 판단 | `archive/webcraft-agency-simulator/`(운영 작업, 앱 코드 아님) | 없음 | P0 | M | Opus | PROXY_HEADER 폐기, GCP 프로젝트 키·ADC 점검 기록, filter-repo 여부 결정 기록. 근거: 되돌리기 어려운 작업 | 리뷰 높음 webcraft #2, webcraft 5장 #4 |
| MW-06-034 | 원본 아카이브와 위생 검사: 원본 3개 이동, CI에 node_modules 추적·중첩 `.git`·시크릿 스캔(gitleaks) | `archive/`(premium, nexus), `.github/workflows/microweb-hygiene.yml` | 033 | P0 | S | Sonnet | 추적 node_modules 0, 앱 아래 `.git` 0, gitleaks 0건. 근거: 설정 | webcraft #1~#3, #5, nexus #1, #2, premium #4 |
| MW-06-035 | 문서: 앱 README, 운영 런북(초대, 게시 실패, 개인정보 삭제 요청), CLAUDE.md 동기화 | `README.md`, `docs/runbook/` | 032 | P1 | S | Sonnet | 환경변수 표와 배포 절차가 02장과 일치. 근거: 문서 | premium #9, nexus #4, webcraft #13 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 002 | 2 | 없음 | 앱 골격, DB 조각 적용, 타입 |
| W1 | 003, 004, 022, 033, 034 | 5 | W0 완료 | 인증 가드, 블록 스키마, 쇼룸 데이터, 사고 대응, 아카이브 |
| W2 | 005, 006, 008, 009, 010, 011, 015, 020, 025, 026, 029 | 11 | W1 완료 | 렌더러, 테마, 공유, 하객 쓰기, 업로드, 이미지 워커, 사이트 라우트, 디자인 시스템, 문의, 초대, 문구 |
| W3 | 007, 012, 013, 014, 016, 017, 018, 019, 021, 023, 024, 030 | 12 | W2 완료 | 하객 페이지, 게시 파이프라인, 편집기, 축하말, 시안 확인, 관리 화면, 쇼룸 페이지, RLS 테스트 |
| W4 | 032, 035 | 2 | W3 완료 | E2E와 체크리스트, 문서. MVP 출시 판정 |
| W5(Phase 2) | 027, 028, 031 | 3 | MVP 출시 + 셀프 단가 확정 | 크레딧팩 결제, 돌잔치·부고장, 결제 E2E |

W3 안의 021은 024와 같은 웨이브지만 024의 카탈로그 컴포넌트를 쓰므로 024 머지 뒤 시작한다(같은 웨이브 내 순서).

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 7 (002, 003, 013, 016, 026, 027, 030) | 20.0% | 12/64 = 18.8% |
| Opus | 14 | 40.0% | 27/64 = 42.2% |
| Sonnet | 11 | 31.4% | 21/64 = 32.8% |
| Haiku | 3 (001, 022, 029) | 8.6% | 4/64 = 6.3% |

## 5. 리뷰 작업 흡수표

| 리뷰 5장 작업 | 내용 요약 | 흡수 작업 ID |
|---|---|---|
| premium #1 | 런타임 Imagen 제거, 사진 URL/지도 임베드 | MW-06-005, MW-06-007, MW-06-010 |
| premium #2 | 범용 프록시 제거, 축하말 전용 엔드포인트 | MW-06-016 |
| premium #3 | 카카오 SRI, 키 환경변수 | MW-06-008 |
| premium #4 | tsconfig, 타입, 버전 고정 | MW-06-001 |
| premium #5 | Supabase 연동, 테이블·RLS, 삭제는 관리자만 | MW-06-002, MW-06-009, MW-06-018 |
| premium #6 | 방명록 입력 검증, 쿨다운 | MW-06-009 |
| premium #7 | invitation JSON 스키마 분리 | MW-06-004 |
| premium #8 | 폰트 오타, Tailwind 빌드, 미사용 정리 | MW-06-005, MW-06-020 |
| premium #9 | 문서 갱신 | MW-06-035 |
| premium #10 | `/i/:slug` 다중 커플 구조 | MW-06-002, MW-06-007, MW-06-015 |
| premium #11 | 관리자 편집 화면, 사진 업로드 | MW-06-010, MW-06-011, MW-06-014 |
| premium #12 | 라이트박스, lazy, 음악 자체 호스팅 | MW-06-005, MW-06-007 |
| nexus #1 | 백엔드/인터셉터 제거 | MW-06-034(아카이브), MW-06-001(새 앱에 없음) |
| nexus #2 | 고아 파일 삭제 | MW-06-034 |
| nexus #3 | tsconfig, 타입, 버전 고정 | MW-06-001 |
| nexus #4 | CLAUDE.md 재작성 | MW-06-035 |
| nexus #5 | 목업 선언형 리팩토링 | MW-06-024(`templates.preview_mockup` 렌더) |
| nexus #6 | Tailwind 빌드, Pretendard 수정 | MW-06-001, MW-06-020 |
| nexus #7 | picsum 교체 | MW-06-024 |
| nexus #8 | 기획서 다운로드 | 폐기(07장 3절). 작업 없음 |
| nexus #9 | 헤더 네비게이션, 반응형 | MW-06-021 |
| nexus #10 | recharts lazy, 번들 분석 | MW-06-032(번들 예산). recharts는 산점도 폐기로 미사용 |
| webcraft #1 | .gitignore, node_modules/.env 추적 해제 | MW-06-034 |
| webcraft #2 | 중첩 repo 삭제 | MW-06-034 |
| webcraft #3 | 백엔드 제거, 단일 프로젝트화 | MW-06-034, MW-06-001 |
| webcraft #4 | 히스토리 정리 판단, 공개 여부 확인 | MW-06-033 |
| webcraft #5 | 고아 파일, constants 단일화 | MW-06-022, MW-06-034 |
| webcraft #6 | 버전 고정, strict | MW-06-001 |
| webcraft #7 | 아이콘 명시 맵 | MW-06-022 |
| webcraft #8 | AdminDashboard 분리 | 대시보드 폐기(07장 3절), 실제 운영 화면은 MW-06-019 |
| webcraft #9 | Pricing 공통 레이아웃 | MW-06-023 |
| webcraft #10 | Tailwind 빌드, Pretendard | MW-06-001, MW-06-020 |
| webcraft #11 | 코드 스플리팅 | MW-06-032 |
| webcraft #12 | 견적 문의 폼 | MW-06-025 |
| webcraft #13 | 데모 표시, 문서 | 로그인/관리자 데모는 폐기(07장 3절), 문서는 MW-06-035 |

리뷰 5장 작업 35개(12 + 10 + 13) 모두 행이 있다.

## 6. 공용 모듈 요청

| 요청 | 이유 | 대상 |
|---|---|---|
| `on_signup_app_bootstrap`/`bootstrap_app_for_org`가 `signup_policy='invite'`를 강제(초대 기록 없으면 엔타이틀먼트 미부여) | 해결(2026-10-13 코어 반영 완료): invite 앱은 가입 트리거가 구독·엔타이틀먼트를 만들지 않고 `bootstrap_app_for_org`는 비 service 호출자에 42501. 제품의 `studio_access`는 2차 게이트로 유지 | core 0003 |
| `confirm_payment_order` PM001 시 주문 failed 영속(예외 대신 결과 반환 또는 별도 기록) | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가. 제품은 PM001 시 별도 호출(04장 2절) | core 0003 |
| `payment_orders.kind`에 일회성 상품(`one_time`) | 대행비를 Toss로 받으려면 필요(Phase 2 이후 검토) | core 0002 |
| LLM 게이트웨이 `credits: 0` 호출 허용(차감 생략, ai_usage만) | 하객 기능은 과금 주체가 없다 | core-ai |
| 모듈러 `seed.sql` microweb `free` 플랜 features를 01장 4절 값으로, 크레딧팩 2행(비활성) 추가 | 해결(2026-10-13 코어 반영 완료): 모듈러 seed가 모놀리스 seed와 일치. 제품 조각은 core seed를 고치지 않는다 | `_supabase-modular/seed.sql` |
| 크레딧 `adjust_credits`(음수 조정) | 팩 미사용분 환불(`CORE_SPEC.md` 5.4) | core 0003 |
| `public-assets` 버킷 MIME에 `audio/mpeg` 허용 또는 오디오 공개 버킷 | 현재 BGM은 서명 URL 302로 우회 | core 0005 |

## 7. 완료 정의

| 조건 | 명령/기준 |
|---|---|
| 빌드·타입·린트 | `pnpm --filter microweb-studio build`, `tsc --noEmit`, `eslint .` 0오류 |
| SQL | `node check.mjs mod ...1500_microweb.sql`, `node check.mjs mono ...` OK |
| RLS 스모크 | `supabase/tests` mod/mono 87/87 |
| E2E | MW-06-032 F1~F3 녹색, 출시 체크리스트 12항목(`DESIGN_PRINCIPLES.md` 7단계) |
| 결제 E2E | MW-06-031(Phase 2 출시 조건) |
| 위생 | gitleaks 0, 추적 node_modules 0 |
| 작업 | 이 표의 P0/P1 작업 전부 완료, P2는 Phase 2 출시 조건 |
