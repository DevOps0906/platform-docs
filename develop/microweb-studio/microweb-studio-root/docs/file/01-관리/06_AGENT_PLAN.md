# 06 에이전트 작업 계획: Microweb Studio

2026-10-13 개정: AI 계층·음성·3D 히어로·디자인 시스템(확정 결정 13~17, `docs/file/03-설계/디자인/DESIGN_SYSTEM.md` 4장) 작업 18개(MW-06-036~053)를 뒤에 붙였다. 기존 ID는 바꾸지 않았다. 내용이 바뀐 기존 작업은 002, 004, 011, 014, 016, 018~021, 023~026, 029, 030, 032다. 작업 수 53개는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다. AI·음성·3D·디자인 시스템이 MVP 필수가 되면서 늘었고 검증할 수 있는 크기(`DESIGN_SYSTEM.md:24` 취지)를 지키려고 합치지 않았다.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 아래 표의 "소유 파일/디렉토리"는 작업끼리 겹치지 않는다. 다른 작업의 디렉토리는 읽기만 한다 |
| 공유 파일 | `apps/microweb-studio/package.json`, `tsconfig.json`, `next.config.ts`는 MW-06-001 소유. 다른 작업은 의존성 추가를 PR 설명에 적고 001 담당(또는 웨이브 종료 후 통합 에이전트)이 반영 |
| DB | `_supabase-modular/migrations/1500_microweb.sql`과 모놀리스 변환본은 MW-06-002(Fable)만 수정. 다른 작업은 스키마 변경을 요청으로 남긴다 |
| 코어 | `_platform-core`, 코어 마이그레이션은 수정하지 않는다. 필요하면 6절 요청 |
| 앱 루트 | `apps/microweb-studio/` (아래 경로는 이 루트 기준) |
| AI 서비스 경계 | `apps/api/`는 MW-06-039가 공용 ai-service를 설치하고 공용 부분과 설정을 소유한다. microweb 확장은 작업별로 나눈다: 042 `app/ai/products/microweb/knowledge.py`, 043 `.../wiki_config.py`, 044 `app/ai/graphs/microweb_invitation_copy.py`·`app/ai/compliance/microweb.py`, 016 `app/ai/graphs/microweb_guest_greeting.py`, 045 `app/ai/tools/microweb/`, 053 `tests/microweb/security/` |
| 공용 AI 패키지 | `packages/ai-gateway`, `packages/core-voice`, `services/ai-service` 원본, 공용 Dify·GPU 서버는 수정하지 않는다. 필요하면 6절 요청 |
| 서버 AI 폴더 | `src/server/ai/`와 `ai-pricing.ts`는 040, `src/server/ai-public/`은 016, `src/server/voice/`는 049, `src/server/guest-voice/`는 051 소유 |
| 언어 중립 파일 | `content/rules/banned.json`은 044 소유(Next.js 검사와 FastAPI compliance가 같은 파일을 읽는다). 블록 JSON Schema 내보내기는 004 소유 |
| 사람 작업 | MW-06-037(디자인 시스템 3단계)은 사람이 수행하고 Sonnet은 사람이 정한 수치를 코드에 옮기는 일만 돕는다 |
| 디자인 시스템 순서 | 스튜디오·쇼룸 화면 작업(014, 018, 019, 021, 023, 024, 025, 043, 047, 048, 052)은 MW-06-038(4단계) 뒤에 시작한다(`docs/file/03-설계/디자인/DESIGN_SYSTEM.md:48`). 공개 청첩장 엔진(005, 006)은 템플릿 테마 토큰을 쓰므로 해당 없음 |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| MW-06-001 | 앱 스캐폴드: Next.js 16, TS strict, Tailwind CSS v4 빌드, lockfile, `.gitignore`, CI(tsc, lint, build) | `package.json`, `tsconfig.json`, `next.config.ts`, `.gitignore`, `.github/workflows/microweb-ci.yml` | 없음 | P0 | M | Haiku | `tsc --noEmit` 0오류, `latest` 의존성 0개, CI 녹색. 근거: 보일러플레이트 | premium 5장 #4, nexus #3, #6, webcraft #6, #10 |
| MW-06-002 | DB 조각 적용, 모놀리스 변환 스크립트, 타입 생성(`--schema core,microweb`) | `supabase/`(링크), `scripts/db/`, `src/types/supabase.ts` | 없음 | P0 | S | Fable | 체커 mod/mono OK, 변환 결과가 저장된 `0002_microweb_domain.sql`과 diff 0. 근거: 데이터 모델. 2026-10-13: 20절(AI·음성 기본값, 방명록 음성 컬럼, `site_assets.kind` voice)이 변환 결과에 포함되고 `--vector` 체커가 mod/mono 모두 OK | 05장 9절, premium #5, #10 |
| MW-06-003 | 인증 연결: core-db 클라이언트, `requireSession('microweb')`, `proxy.ts`, `studio_access` 가드, `/pending` | `src/server/auth/`, `src/proxy.ts`, `src/app/pending/`, `src/app/login/` | 001, 002 | P0 | M | Fable | 허용 목록 없는 사용자는 `/studio`에서 `/pending`, 프로필 없으면 로그아웃. 근거: 권한 | MW-F-024, `SECURITY_BASELINE.md` 11장 |
| MW-06-004 | 블록 zod 스키마 17종, content 검증, 템플릿 레지스트리(필수 블록) | `src/engine/schema/` | 001 | P0 | M | Opus | 필수 블록 누락 content는 검증 실패, 모르는 블록 거부, 256KB 초과 거부. 근거: 데이터 계약 설계. 블록 JSON Schema 내보내기 파일(`greeting.voice_asset_id`, `guestbook.voice_enabled/voice_public` 포함)을 FastAPI 그래프가 읽을 수 있게 빌드 산출(MW-06-044 입력) | MW-F-001, premium #7 |
| MW-06-005 | 블록 렌더러 이식(원본 섹션 7개 → 블록 17종), 갤러리 라이트박스·lazy, 미사용 코드 제거 | `src/engine/blocks/` | 004 | P0 | L | Sonnet | 원본 constants 없이 content JSON만으로 렌더, `scrollRef`·`mapUrl` 잔재 0, picsum 0. 근거: UI | MW-F-002~010, premium #8, #12 |
| MW-06-006 | 템플릿 테마 토큰과 `wedding_classic` 테마, 모션(Ken Burns, 크로스페이드, reduced-motion) | `src/engine/themes/` | 004 | P0 | M | Sonnet | 테마 대비 4.5:1, reduced-motion에서 자동 모션 0. 근거: UI | 03장 6절 |
| MW-06-007 | 하객 페이지 `/i/[slug]`: anon 스냅샷 조회, slug별 OG, noindex, 404/410, 공개 기한 표시, BGM 라우트 | `src/app/i/`, `src/app/api/public/[slug]/bgm/` | 005, 006 | P0 | M | Opus | 초안 slug 404, 중단 30초 안에 410, 카카오 디버거 slug별 OG, 하객 경로에 생성형 AI 호출 0. 근거: 기능 구현 | MW-F-009, MW-F-011, premium #1, #10 |
| MW-06-008 | 공유 바: 카카오 SDK(환경변수 키, 공식 SRI), Web Share, 링크 복사 | `src/engine/share/` | 004 | P0 | S | Sonnet | 키 없으면 Web Share 폴백, 가짜 integrity 0. 근거: 설정 | premium #3 |
| MW-06-009 | 하객 쓰기 라우트(방명록, RSVP), IP 해시, 허니팟, Origin 검사 | `src/app/api/public/[slug]/guestbook/`, `src/app/api/public/[slug]/rsvp/`, `src/server/guest/` | 002, 003 | P0 | M | Opus | 4번째 연속 작성 429, 링크 422, 예식 후 RSVP 410, 원문 IP 로그 0. 근거: API 연동 | MW-F-006, MW-F-008, premium #5, #6 |
| MW-06-010 | 업로드 파이프라인: 서명 업로드 URL, 완료 검증, 삭제(Storage+행) | `src/app/api/studio/sites/[id]/assets/`, `src/app/api/studio/assets/`, `src/server/storage/` | 002, 003 | P0 | M | Opus | 사용자 파일명이 경로에 0, 15MB 초과 413, 다른 조직 경로 400. 근거: API 연동 | MW-F-013, premium #1, #11 |
| MW-06-011 | 워커 `asset.process`: 매직바이트, EXIF 제거, 400/800/1600w webp, og 1200x630 | `worker/handlers/asset/`, `worker/main.ts` | 002 | P0 | M | Opus | GPS EXIF가 든 샘플 처리 후 메타 0, ready 전환. 근거: 기능 구현. kind `voice`(mp3)도 매직바이트 검사 후 ready, `voice.transcode` 핸들러(MW-06-050이 요청) 등록 지점 제공 | MW-F-013 |
| MW-06-012 | 워커 `site.publish`/`unpublish_assets`/`purge` + 스케줄(expire 10분, purge 매일) | `worker/handlers/site/`, `worker/schedule/` | 011 | P0 | M | Opus | 게시 잡 성공 시 `finalize_publish`, 실패 시 `fail_job` 환불 + `fail_publish`, 만료 후 공개 파일 0. 근거: 기능 구현 | MW-F-014, MW-F-015 |
| MW-06-013 | 게시 라우트: (셀프) consume → `request_publish` → enqueue, 실패 시 환불·복구 | `src/app/api/studio/sites/[id]/publish/`, `src/server/publish/` | 009, 010 | P0 | M | Fable | 미결제 MW008, 같은 request_id 재시도 시 차감 1회, enqueue 실패 시 환불 행 1. 근거: 크레딧/결제 | MW-F-014, 02장 4절 |
| MW-06-014 | 스튜디오 편집기: 블록 폼, 375px 미리보기, 자동 저장, 업로드 진행률(Realtime), 동의·시안·게시 버튼 | `src/studio/editor/`, `src/app/studio/sites/` | 005, 010, 015, 038 | P0 | L | Sonnet | 3초 자동 저장, 게시 중 편집 잠금 표시, 키보드로 전 기능 사용. 근거: UI. AI 문구 제안 패널(047)과 인사말 음성 블록(050) 장착 지점 제공 | MW-F-012, premium #11 |
| MW-06-015 | 스튜디오 사이트 라우트: 생성, PATCH, 전이, 동의, 시안 토큰 | `src/app/api/studio/sites/route.ts`, `src/app/api/studio/sites/[id]/route.ts`, `src/app/api/studio/sites/[id]/transition/`, `.../consent/`, `.../preview-token/` | 003, 004 | P0 | M | Opus | slug 중복 409, 게시 후 slug 변경 409, 토큰 원문은 응답 1회만. 근거: API 연동 | MW-F-012, MW-F-016 |
| MW-06-016 | AI 축하말 엔드포인트와 그래프 `microweb.guest_greeting`(고정 라우팅 기능 `microweb_greeting`, 입력 enum, 리밋, ai_usage) | `src/app/api/public/[slug]/greeting/`, `src/server/ai-public/`, `apps/api/app/ai/graphs/microweb_guest_greeting.py`, `apps/api/tests/microweb/greeting/` | 007, 009, 039, 040 | P0 | M | Fable | 6번째 호출 429, 미게시 사이트 404, 모델/헤더 지정 불가, 실패 시 고정 문구 위장 0. 근거: 비용·남용 경계. 2026-10-13: FastAPI 그래프 경유(서명 토큰 `sub=visitor`), 모델 요청 본문에 하객 이름 0, 미동의 조직은 oss-llm만 | MW-F-007, premium #2, 리뷰 높음 premium #3 |
| MW-06-017 | 시안 확인 `/p/[token]`과 승인 라우트 | `src/app/p/`, `src/app/api/public/preview/` | 007, 015 | P0 | S | Opus | 만료 토큰 410, 승인 후 `customer_approved_at` 기록, 페이지 noindex. 근거: 기능 구현 | MW-F-016 |
| MW-06-018 | 하객 관리: 방명록 숨김/스팸/삭제, RSVP 합계·CSV(감사 기록) | `src/studio/guests/`, `src/app/studio/sites/[id]/guests/`, `src/app/api/studio/guestbook/`, `src/app/api/studio/sites/[id]/rsvp.csv/` | 009, 014, 038 | P0 | M | Sonnet | member는 삭제 버튼 없음, CSV 엑셀에서 한글 정상. 근거: UI. 음성 재생·삭제(음성 파일 동시 삭제)는 MW-06-051이 제공하는 라우트를 사용 | premium #5 |
| MW-06-019 | 리드·주문 관리: 라우트와 화면, 상태 전이, 개인정보 삭제 | `src/app/studio/leads/`, `src/app/studio/orders/`, `src/app/api/studio/leads/`, `src/app/api/studio/orders/`, `src/studio/crm/` | 003, 015, 038 | P0 | M | Opus | 허용 안 된 전이 409, 카드번호형 참조 거부, 삭제 후 리드 0. 근거: 기능 구현 | MW-F-018, MW-F-019, webcraft #8(대체) |
| MW-06-020 | 디자인 시스템 2단계: UUPM 초안 → MASTER.md, 토큰 CSS(Tailwind CSS v4 `@theme`), 서체 로딩, 기본 컴포넌트와 `/dev/components` | `design-system/microweb-studio/`, `src/styles/`, `src/components/ui/`, `src/app/dev/components/` | 001, 036 | P0 | M | Sonnet | 03장 4.3 토큰과 일치, 생성형 기본값 점검표 기록. 근거: UI. 03장 3.2절 기본 컴포넌트·배리언트가 라이트/다크로 렌더되고 `tailwind.config.js` 0, hex 하드코딩 0 | 03장 4절, nexus #6, webcraft #10 |
| MW-06-021 | 쇼룸 랜딩 `/`: 실제 샘플 렌더 히어로, 템플릿, 진행 순서, 가격 요약 | `src/app/(showroom)/page.tsx`, `src/app/(showroom)/layout.tsx`, `src/showroom/components/landing/` | 020, 024, 038, 052 | P0 | M | Sonnet | 금지 문구 0(미검증 수치, 할인 배너), 자동 모션 1개, 375~1440 체크리스트 통과. 근거: 메인페이지. 히어로는 MW-06-052의 컴포넌트를 동적 import로 장착만 한다(three.js 직접 import 0) 랜딩 레퍼런스는 `03_SCREENS_UX.md` 4.1절의 Awwwards 행만 쓰고, 각 행의 "참고 포인트" 대비 PC·모바일 스크린샷을 남긴다. 로고·카피·이미지 복제 0(`docs/file/03-설계/디자인/REFERENCES.md:16-23`). | 03장 4절, nexus #9, #13 |
| MW-06-022 | 쇼룸 데이터 단일화: geoMeta → industries/tiers/pricing, 중복 constants 제거, 아이콘 명시 맵 | `src/showroom/data/` | 001 | P0 | S | Haiku | 업종·등급 출처 1곳, `import * as Icons` 0. 근거: 반복 정리 | webcraft #5, #7 |
| MW-06-023 | 시뮬레이터 이식: 업종 9 x 등급 4 x 디바이스 3, 등급 시안 공통 레이아웃, 문의 프리필 | `src/showroom/components/simulator/`, `src/app/(showroom)/simulator/` | 022, 038 | P1 | M | Opus | 선택값이 `/contact` 쿼리와 리드 simulator로 이어짐, 등급 컴포넌트 공통 프레임 1개. 근거: 다중 파일 리팩토링 | MW-F-023, webcraft #9 |
| MW-06-024 | 가격표, 템플릿 카탈로그(선언형 목업 렌더), 포트폴리오 페이지 | `src/app/(showroom)/pricing/`, `src/app/(showroom)/templates/`, `src/app/(showroom)/portfolio/`, `src/showroom/components/catalog/` | 004, 022, 038 | P0 | M | Sonnet | 카탈로그가 DB `templates`에서 렌더, picsum 0, published 포트폴리오만 노출. 근거: UI | MW-F-020~022, nexus #5, #7 |
| MW-06-025 | 견적 문의 `/contact`, 공개 라우트, 운영자 메일 알림 | `src/app/(showroom)/contact/`, `src/app/api/public/leads/`, `src/server/notify/` | 002, 022, 038 | P0 | M | Opus | 동의 없으면 422, 4번째 연속 제출 429, 메일 실패해도 리드 저장. 근거: 외부 연동 | MW-F-017, webcraft #12 |
| MW-06-026 | 초대·허용 목록 관리(관리자 라우트, Auth 초대 메일, studio_access 부여/회수 감사) | `src/app/api/admin/invites/`, `src/app/api/admin/access/`, `src/server/admin/` | 003 | P0 | S | Fable | platform_admin 외 403, 부여/회수 감사 행 1. 근거: 권한 | MW-F-024 |
| MW-06-027 | (Phase 2) Toss 크레딧팩 결제, confirm 실패 처리, 웹훅 | `src/app/api/billing/`, `src/app/api/webhooks/toss/`, `src/app/studio/billing/` | 013 | P2 | M | Fable | 금액 위조 시 confirm 미호출, PM001 시 `fail_payment_order`+Toss 취소+감사, 웹훅 서명 실패 401. 근거: 결제 | 04장 2절, MW-F-025 |
| MW-06-028 | (Phase 2) 돌잔치·부고장 블록(timeline, memorial, funeral_info)과 템플릿 출시 | `src/engine/blocks/phase2/` | 005 | P2 | M | Sonnet | `dol_basic`, `obituary_basic` beta 전환 후 생성 가능. 근거: UI | `00_MERGE_ANALYSIS.md:1091` |
| MW-06-029 | 법적 고지와 문구: 약관, 개인정보처리방침, 하객 고지, 금지 문구 점검 목록 | `src/app/(legal)/`, `src/content/copy/` | 001 | P0 | S | Haiku | 01장 6절 항목 전부 반영, 금지 문구 grep 0. 근거: 문구. AI·음성 고지문(국외 이전, 스튜디오 음성 처리, 하객 녹음 `third_party_notice`) 버전 상수와 문안, AI 생성 표시 문구 | 01장 6절 |
| MW-06-030 | RLS/권한 회귀 테스트: 스모크 87항목 이식 + CI(PGlite) | `supabase/tests/` | 002 | P0 | M | Fable | mod/mono 모두 87/87, CI 필수 체크. 근거: RLS. 2026-10-13: `attach_guestbook_voice` 결과 5종, `voice_job_id` 열 권한 거부, `site_assets` voice 제약, 하객 음성 익명 접근 거부 항목을 더해 mod/mono 모두 통과 | `SECURITY_BASELINE.md` 15장, 05장 9절 |
| MW-06-031 | 결제 E2E(Toss 테스트 키): 팩 구매 → 셀프 게시 → 잡 실패 환불 | `e2e/billing/` | 027 | P2 | M | Opus | 성공 1건, 금액 위조 1건, 환불 1건 시나리오 녹색. 근거: 테스트 설계 | DOC_TEMPLATE 2.7 필수 |
| MW-06-032 | E2E 대행 플로우(F1~F3) + 출시 체크리스트(뷰포트 4종, 포커스, reduced-motion, LCP, 번들 150KB) | `e2e/flows/` | 013, 014, 021, 047, 051, 052, 053 | P0 | M | Opus | F1~F3 녹색, 하객 페이지 JS 150KB 이하. 근거: 테스트 설계. F5(문구 제안 → 적용)와 F8(하객 음성 방명록)을 더한 F1~F3, F5, F8 녹색 | 03장 2절, webcraft #11, nexus #10 |
| MW-06-033 | 노출 시크릿 사고 대응: webcraft `backend/.env.local` 값 폐기·재발급, 공개 여부 확인, 히스토리 정리 판단 | `archive/webcraft-agency-simulator/`(운영 작업, 앱 코드 아님) | 없음 | P0 | M | Opus | PROXY_HEADER 폐기, GCP 프로젝트 키·ADC 점검 기록, filter-repo 여부 결정 기록. 근거: 되돌리기 어려운 작업 | 리뷰 높음 webcraft #2, webcraft 5장 #4 |
| MW-06-034 | 원본 아카이브와 위생 검사: 원본 3개 이동, CI에 node_modules 추적·중첩 `.git`·시크릿 스캔(gitleaks) | `archive/`(premium, nexus), `.github/workflows/microweb-hygiene.yml` | 033 | P0 | S | Sonnet | 추적 node_modules 0, 앱 아래 `.git` 0, gitleaks 0건. 근거: 설정 | webcraft #1~#3, #5, nexus #1, #2, premium #4 |
| MW-06-035 | 문서: 앱 README, 운영 런북(초대, 게시 실패, 개인정보 삭제 요청), CLAUDE.md 동기화 | `README.md`, `docs/runbook/` | 032 | P1 | S | Sonnet | 환경변수 표와 배포 절차가 02장과 일치. 근거: 문서 | premium #9, nexus #4, webcraft #13 |
| MW-06-036 | 디자인 시스템 1단계: 레퍼런스 확정(스튜디오 Atlassian 주·Primer 보조, 채팅 Astryx 패턴 확인, 공개 청첩장·쇼룸은 DESIGN_PRINCIPLES + HERO_3D), 가져올 것과 안 가져올 것 | `docs/file/03-설계/디자인/DESIGN.md`(1절 "레퍼런스와 방향") | 없음 | P0 | S | Sonnet | 03장 3.2절의 주 레퍼런스·가져올 것·안 가져올 것이 1절 표로 있다. Astryx 존재·라이선스 확인 결과와 미확인 시 대체안 기록(01장 D-16). 고문(Fable) 검토 기록 시각 레퍼런스: `03_SCREENS_UX.md` 4.1절 표(랜딩은 Awwwards, 앱 화면은 Dribbble. 후보는 `docs/file/03-설계/디자인/REFERENCES.md:142` microweb-studio 절)를 DESIGN.md 1절에 옮기고, 각 링크를 브라우저로 열어 본 결과(열림/교체)를 적는다(`docs/file/03-설계/디자인/DESIGN_PRINCIPLES.md:29-38`). | DESIGN_SYSTEM 4장 1단계, 9절 |
| MW-06-037 | 디자인 시스템 3단계: 사람 비주얼 검토(라이트/다크, 상태 6종, 크기 배리언트) | `docs/file/03-설계/디자인/review/`(스크린샷, 수정 기록) | 020 | P0 | M | 사람(보조 Sonnet) | 03장 3.2절 기본 컴포넌트 전부의 라이트/다크·상태별 스크린샷과 사람이 고친 수치 기록, 대비 4.5:1·포커스 링 확인. 이 단계는 줄이지 않는다 | DESIGN_SYSTEM 4장 3단계 |
| MW-06-038 | 디자인 시스템 4단계: 코드(Tailwind CSS v4 CSS + 컴포넌트)를 정답으로 확정하고 문서를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | 037 | P0 | S | Opus | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치, 피그마 노드 id·외부 파일 링크 0, `tailwind.config.js` 0 | DESIGN_SYSTEM 4장 4단계 |
| MW-06-039 | AI 서비스 설치: `apps/api`에 공용 ai-service 적용, microweb 설정(app, `MICROWEB_KNOWLEDGE_ORG_ID`, 컬렉션 이름), JWKS 검증, 라우터·국외 동의 필터 연동 테스트 | `apps/api/`(`app/ai/graphs/`, `app/ai/tools/microweb/`, `app/ai/compliance/microweb.py`, `app/ai/products/microweb/` 제외), `apps/api/tests/platform/` | 001 | P0 | M | Fable | 다른 app `aud`·만료·재사용 `jti` 토큰 401, 토큰 org와 다른 org 사이트 요청 403, 미동의 조직 라우팅에 상용 0, `dify.aux`·`microweb_guestbook_voice` 상용 0, 필수 변수 누락 시 기동 실패 | 02장 2·5절, AI_ARCHITECTURE 2·4·8장 |
| MW-06-040 | AI 게이트: 대화 생성, 채팅 중계(Dify, 장애 시 FastAPI 직접), 턴 선차감·정산(대행 모드 0 크레딧 분기), 서명 토큰 발급, 정산 크론, AI 단가, 온보딩 국외 이전 동의, 설정 화면 | `src/app/api/ai/`, `src/app/api/internal/`, `src/app/api/onboarding/`, `src/app/studio/onboarding/`, `src/app/studio/settings/ai/`, `src/server/ai/`, `src/server/ai-pricing.ts` | 003, 039 | P0 | L | Fable | 04장 2.1절 계약 충족. 같은 `request_id` 재전송 차감 1회, 응답 미전달 시 환불 1행, Dify 차단 시 `/tools/answer-direct`로 응답, 동의 시 `ai_org_settings` 버전 기록, 정산 크론 뒤 10분 넘은 `settled_at is null` 0, 대행 모드는 선차감 없이 `ai_usage`만 기록하고 한도 적용(01장 D-9) | 01장 MW-F-029, 033, 034 |
| MW-06-041 | 문구 코퍼스 원고: 이벤트 종류별 인사말·안내·계좌·방명록 문구 예시와 표현 가이드, 템플릿 설명 | `content/copy/` | 004 | P0 | L | Sonnet | 청첩장 항목 60개 이상(제안) + 돌잔치·부고장 초안, 항목마다 작성자·검수일·라이선스 메타데이터, 전화·계좌·실명 패턴 0, 금지 문구 검사 0, 운영자 검수 기록(01장 D-15) | 01장 MW-F-027 |
| MW-06-042 | RAG 색인과 Dify 외부 지식 API: 지식 조직 컬렉션(`microweb-copy`, `microweb-templates`, `microweb-wiki`, oss-embed), 색인 스크립트(PII 검사), `/dify/retrieval`, 검색 평가셋 40문항 | `apps/api/app/ai/products/microweb/knowledge.py`, `scripts/knowledge/`, `apps/api/tests/microweb/retrieval/` | 039, 041 | P0 | M | Opus | 재현율@8 0.8 이상(제안), 다른 조직 컬렉션 요청 42501, 외부 지식 응답에 사용자 조직 데이터 0, 컬렉션당 임베딩 모델 1종, PII 패턴 포함 문서 색인 거부 | 01장 MW-F-027 |
| MW-06-043 | 문구 위키 운영: 코퍼스 → 위키 ingest(draft), 게시·편집·이력·lint 관리자 화면과 API, 스튜디오 읽기 화면, 주 1회 lint 잡 | `apps/api/app/ai/products/microweb/wiki_config.py`, `src/app/studio/wiki/`, `src/app/studio/admin/`, `src/app/api/admin/wiki/`, `src/app/api/admin/knowledge/` | 038, 042 | P0 | M | Opus | 새 페이지 draft, 출처 없는 페이지 게시 409, 사람 소유 표시 블록을 ingest가 수정하지 않음, `expected_version` 불일치 409, 문서 1건당 갱신 5개 상한, 스튜디오 화면에 draft 0, `dol/*`·`obituary/*`는 템플릿 beta 전환 전 published 0, 모든 쓰기 감사 1행 | 01장 MW-F-028, LLM_WIKI 3장 |
| MW-06-044 | LangGraph `microweb.invitation_copy`(intake → retrieve → draft_copy → propose_composition → compliance), 체크포인트, 실행 기록, 금지 문구 규칙 파일 | `apps/api/app/ai/graphs/microweb_invitation_copy.py`, `apps/api/app/ai/compliance/microweb.py`, `content/rules/`, `apps/api/tests/microweb/graph/` | 004, 039, 041 | P0 | L | Opus | 1회 실행 = `ai_runs` 1행 + 노드별 `ai_run_steps`, 모르는 블록 타입 0·필수 블록 포함, 모델 요청에 실명·전화·계좌 패턴 0, 걸린 안만 1회 재작성·2회 실패 시 해당 안 제외, 평가셋 30건(금지 문구 위반 0)을 상용·오픈소스 경로 모두 통과, 부고장 입력에서 축하 표현 0 | 01장 MW-F-026, 035 |
| MW-06-045 | Dify `microweb-chat`(질문 분류, HTTP 노드, 외부 지식)과 `/tools/answer` microweb 확장(모드 consult, 사이트 컨텍스트 로더, 마스킹, compliance 후처리), 대화 평가셋 30문항 | `infra/dify/`, `apps/api/app/ai/tools/microweb/`, `apps/api/tests/microweb/chat/` | 040, 042 | P0 | M | Opus | 대화 매핑 불일치(`sys.user` 다름, closed, 다른 app) 403, 다른 조직 `site_id` 403, 컨텍스트에 이름·연락처·계좌 본문 0, 답변 출처 1개 이상 또는 `no_source`, 가격 답변이 `templates` 범위와 일치, 위기 신호 5문장 안내, DSL에 키 0 | 01장 MW-F-029, 035, 04장 6.2절 |
| MW-06-046 | 문구 제안 라우트: 실행·조회·적용(블록 재검증, 병합, 감사), 한도와 선차감·정산 | `src/app/api/studio/sites/[id]/ai-copy/` | 015, 040, 044 | P0 | M | Opus | 한도 초과 429, 같은 `request_id` 차감 1회, 실패 환불 1행, 적용 시 템플릿 `allowed_blocks` 밖 블록 422, 편집 충돌 409, 적용 전 `sites.content` 변경 0, 감사 본문 0 | 01장 MW-F-026 |
| MW-06-047 | AI 문구 제안 패널(3안 비교, 출처 칩, 구성 diff, 적용, 크레딧·한도 표시) | `src/studio/ai-copy/` | 014, 038, 046 | P0 | M | Sonnet | 03장 3.1절 구성, 375px 미리보기에 저장 전 임시 반영, "AI가 생성한 초안" 표시, 키보드 전 기능, 402·429·실패 환불 상태 표시. 편집기 장착은 MW-06-014 파일에 1줄 요청 | 01장 MW-F-026, 03장 5절 |
| MW-06-048 | 제작 상담 채팅 시트와 대화 목록(스트리밍, 출처 칩, 크레딧 안내, AI 표시, 사이트 칩) | `src/components/ai-chat/`, `src/app/studio/chat/` | 038, 040 | P0 | M | Sonnet | 03장 3.1절 구성, 375px 전체 화면, `aria-live`, 402 충전 모달, 대체·근거 없음·환불 상태 표시. 스튜디오 레이아웃 장착은 MW-06-014 파일에 1줄 요청 | 01장 MW-F-029, 03장 5절 |
| MW-06-049 | 스튜디오 음성 대화: `/api/voice/*`(consent, sessions, stt, tts), 마이크 버튼·녹음 표시·변환 텍스트 수정, 읽어 주기 | `src/app/api/voice/`, `src/components/voice/`, `src/server/voice/` | 040, 048 | P0 | M | Opus | 고지 미확인 STT 403, 60초 자동 중지·초과 413, `store_audio=false` 100%, 마이크 거부 시 텍스트 채팅 정상, STT·TTS 실패 환불 1행, TTS 입력은 DB 메시지만 | 01장 MW-F-030 |
| MW-06-050 | 청첩장 인사말 음성: TTS 생성 라우트, 호스트 녹음 업로드·`voice.transcode` 핸들러, 공개 재생 라우트, 블록 UI | `src/app/api/studio/sites/[id]/voice-greeting/`, `src/app/api/public/[slug]/voice-greeting/`, `worker/handlers/voice/`, `src/studio/voice-greeting/` | 011, 015, 040 | P0 | M | Opus | 인사말 본문은 DB에서만 읽음(600자 초과 422), 제공자 1개 고정·실패 시 파일 0 + 환불 1행, 호스트 녹음은 본인 확인 없이 업로드 URL 발급 422, 변환 결과 mp3 매직바이트 통과, 하객 페이지 네트워크 로그에 TTS/STT 요청 0, 자동 재생 0, 공개 동의 없는 게시 MW006 | 01장 MW-F-031 |
| MW-06-051 | 하객 음성 방명록: 고지·동의, 방문자 쿠키, 업로드·STT(오픈소스 강제), `voice_token`, 제출 연결(`attach_guestbook_voice`), 재생·삭제 라우트, 녹음 UI | `src/app/api/public/[slug]/guestbook/voice/`, `src/app/api/public/[slug]/guestbook/[entry_id]/`, `src/app/api/studio/guestbook/[id]/`, `src/server/guest-voice/`, `src/engine/voice/` | 009, 029, 040, 050 | P0 | M | Fable | 고지 없이 업로드 403, 10분 안 3번째 녹음 429, 사이트 하루 50건 초과 429, 상용 제공자 호출 0(`ai_usage`), STT 장애 시 대체 없이 503, 타인 방문자의 `voice_token` 거부, 숨김 항목 재생 404, 삭제 시 파일 삭제, 원문 IP·오디오 로그 0, 음성 없이 텍스트 방명록 정상 | 01장 MW-F-032 |
| MW-06-052 | 쇼룸 3D 히어로: 봉투 → 카드 → 미니 사이트(PC·태블릿), 봉투 열림만(모바일), 정지 이미지 대체, 성능 예산 | `src/components/hero3d/`, `public/hero/` | 020, 038 | P1 | L | Sonnet | `HERO_3D.md` 4절 수용 기준 전부(기기 3종 동작, 3D 번들+에셋 1MB/300KB, LCP 2.5초, 로딩 전 저사양 판정과 `deviceMemory` 없는 Safari·Firefox 분기, 런타임 강등, 3D 전 HTML 사용 가능, 스크린샷 3종 고문 검토), 토큰 밖 3D 색 0, 파티클·글로우 0, 하객·스튜디오 번들에 three.js 0 | 01장 MW-F-036, 03장 4.6절 |
| MW-06-053 | AI·음성 보안·라우팅 회귀 테스트(서명 토큰, 대화 매핑, 국외 동의 필터, 강제 오픈소스, 하객 음성 남용, 선차감·정산·환불, 라우팅 seed 스냅샷) | `apps/api/tests/microweb/security/`, `e2e/ai/`, `scripts/ai-routing/` | 040, 044, 045, 049, 051 | P0 | M | Fable | `resolve_ai_route` 스냅샷(기능 12행 × 동의 유/무)이 02장 5.1절과 일치, 위조·만료·재사용 토큰 401, 타인 대화 이어 쓰기 404, 미동의 조직 상용 호출 0, 하객 음성 상용 0, 원장 drift 0, 하객 경로 번들에 LLM·이미지 SDK import 0, CI 실패 시 머지 차단 | SECURITY_BASELINE 16장 |

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 002, 036 | 3 | 없음 | 앱 골격, DB 조각 적용(AI·음성 20절 포함), 타입, 디자인 레퍼런스(디자인 시스템 1단계) |
| W1 | 003, 004, 022, 033, 034, 039 | 6 | W0 완료 | 인증 가드, 블록 스키마, 쇼룸 데이터, 사고 대응, 아카이브, AI 서비스 설치 |
| W1-D | 020 → 037 → 038(직렬) | 1 | 001, 036 | 디자인 시스템 2~4단계(토큰·기본 컴포넌트, 사람 검토, 정답 확정). 화면 작업의 진입 조건 |
| W2 | 005, 006, 008, 009, 010, 011, 015, 025, 026, 029, 040, 041, 052 | 13 | W1 완료, 025·052는 038 | 렌더러, 테마, 공유, 하객 쓰기, 업로드, 이미지 워커, 사이트 라우트, 문의, 초대, 문구·고지문, AI 게이트, 문구 코퍼스, 3D 히어로 |
| W3 | 007, 012, 013, 014, 016, 017, 018, 019, 021, 023, 024, 030, 042, 044, 048 | 15 | W2 완료, 화면은 038 | 하객 페이지, 게시 파이프라인, 편집기, 축하말 그래프, 시안 확인, 관리 화면, 쇼룸 페이지, RLS 테스트, RAG 색인, 문구 제안 그래프, 채팅 시트 |
| W4 | 043, 045, 046, 049, 050, 051 | 6 | W3 완료 | 위키 운영, Dify 채팅, 문구 제안 라우트, 음성 대화, 인사말 음성, 하객 음성 방명록 |
| W5 | 047, 053 | 2 | W4 완료 | 문구 제안 패널, AI·음성 보안 회귀 |
| W6 | 032, 035 | 2 | W5 완료 | E2E와 체크리스트, 문서. MVP 출시 판정 |
| W7(Phase 2) | 027, 028, 031 | 3 | MVP 출시 + 셀프 단가 확정 | 크레딧팩 결제, 돌잔치·부고장, 결제 E2E |

같은 웨이브 안 순서: W3의 021은 024의 카탈로그 컴포넌트와 052(W2)의 히어로를 쓰므로 024 머지 뒤 시작하고, 016은 007 뒤, 044는 041·039 뒤, 042는 041 뒤에 시작한다. 이전 W4(032, 035)는 W6, 이전 W5(027, 028, 031)는 W7이 됐다.

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 11 (002, 003, 013, 016, 026, 027, 030, 039, 040, 051, 053) | 21.2% | 21/100 = 21.0% |
| Opus | 22 | 42.3% | 43/100 = 43.0% |
| Sonnet | 16 | 30.8% | 32/100 = 32.0% |
| Haiku | 3 (001, 022, 029) | 5.8% | 4/100 = 4.0% |

비율은 모델 작업 52개 기준이다. 사람 작업 1개(MW-06-037, M)는 비율에서 뺐다. 2026-10-13 이전(35개)은 Fable 20.0%, Opus 40.0%, Sonnet 31.4%, Haiku 8.6%였다. Fable은 AI 보안 경계(서명 토큰 검증 039, AI 게이트의 선차감·정산·동의 040, 익명 하객 음성 051, AI 회귀 053)를 맡고, 그래프·RAG·Dify·음성 구현은 Opus, 채팅 시트·문구 제안 패널·3D 히어로·코퍼스 원고는 Sonnet이다(`docs/file/03-설계/공용코어/DOC_TEMPLATE.md:253`).

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
| premium #8 | 폰트 오타, Tailwind CSS v4 빌드, 미사용 정리 | MW-06-005, MW-06-020 |
| premium #9 | 문서 갱신 | MW-06-035 |
| premium #10 | `/i/:slug` 다중 커플 구조 | MW-06-002, MW-06-007, MW-06-015 |
| premium #11 | 관리자 편집 화면, 사진 업로드 | MW-06-010, MW-06-011, MW-06-014 |
| premium #12 | 라이트박스, lazy, 음악 자체 호스팅 | MW-06-005, MW-06-007 |
| nexus #1 | 백엔드/인터셉터 제거 | MW-06-034(아카이브), MW-06-001(새 앱에 없음) |
| nexus #2 | 고아 파일 삭제 | MW-06-034 |
| nexus #3 | tsconfig, 타입, 버전 고정 | MW-06-001 |
| nexus #4 | CLAUDE.md 재작성 | MW-06-035 |
| nexus #5 | 목업 선언형 리팩토링 | MW-06-024(`templates.preview_mockup` 렌더) |
| nexus #6 | Tailwind CSS v4 빌드, Pretendard 수정 | MW-06-001, MW-06-020 |
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
| webcraft #10 | Tailwind CSS v4 빌드, Pretendard | MW-06-001, MW-06-020 |
| webcraft #11 | 코드 스플리팅 | MW-06-032 |
| webcraft #12 | 견적 문의 폼 | MW-06-025 |
| webcraft #13 | 데모 표시, 문서 | 로그인/관리자 데모는 폐기(07장 3절), 문서는 MW-06-035 |

리뷰 5장 작업 35개(12 + 10 + 13) 모두 행이 있다.

## 6. 공용 모듈 요청

| ID | 요청 | 이유 | 대상 |
|---|---|---|---|
| R-1 | `on_signup_app_bootstrap`/`bootstrap_app_for_org`가 `signup_policy='invite'`를 강제(초대 기록 없으면 엔타이틀먼트 미부여) | 해결(2026-10-13 코어 반영 완료): invite 앱은 가입 트리거가 구독·엔타이틀먼트를 만들지 않고 `bootstrap_app_for_org`는 비 service 호출자에 42501. 제품의 `studio_access`는 2차 게이트로 유지 | core 0003 |
| R-2 | `confirm_payment_order` PM001 시 주문 failed 영속(예외 대신 결과 반환 또는 별도 기록) | 해결(2026-10-13 코어 반영 완료): `fail_payment_order` 추가. 제품은 PM001 시 별도 호출(04장 2절) | core 0003 |
| R-3 | `payment_orders.kind`에 일회성 상품(`one_time`) | 대행비를 Toss로 받으려면 필요(Phase 2 이후 검토) | core 0002 |
| R-4 | ai-gateway·core-voice가 `credits: 0` 호출을 허용(차감 생략, `ai_usage`와 `voice_jobs`만 기록) | 하객 기능(축하말, 음성 방명록)과 대행 모드 AI(01장 D-9)는 과금 주체가 없다. 기존 "LLM 게이트웨이 credits: 0" 요청을 AI 계층 구조에 맞게 바꾼 것 | core-ai, core-voice |
| R-5 | 모듈러 `seed.sql` microweb `free` 플랜 features를 01장 4절 값으로, 크레딧팩 2행(비활성) 추가 | 해결(2026-10-13 코어 반영 완료): 모듈러 seed가 모놀리스 seed와 일치. 제품 조각은 core seed를 고치지 않는다 | `_supabase-modular/seed.sql` |
| R-6 | 크레딧 `adjust_credits`(음수 조정) | 팩 미사용분 환불(`CORE_SPEC.md` 5.4) | core 0003 |
| R-7 | `public-assets` 버킷 MIME에 `audio/mpeg` 허용 또는 오디오 공개 버킷 | 현재 BGM·인사말 음성은 서명 URL 302로 우회 | core 0005 |
| R-8 | 모듈러 `seed.sql` microweb `free` features에 AI 키 8개(01장 4절) 추가 | seed가 1500 조각보다 나중에 실행되면 20.2절 병합 UPDATE를 덮어쓴다 | `_supabase-modular/seed.sql` |
| R-9 | core-voice/`voice-audio`: 익명 방문자 세션(`user_id null`, `visitor_key`) 음성 작업 지원과 조직 멤버의 하객 녹음 읽기 경로. 현재 Storage 읽기 정책은 작업 주인(`user_id = auth.uid()`)만이라 하객 녹음을 호스트가 직접 읽을 수 없다 | 하객 음성 방명록 재생 | core 0009 |
| R-10 | ai-service: (a) OpenAI 호환 `/v1/chat/completions`의 `model` 값을 기능 키로 해석 (b) 위키 페이지 사람 편집 저장 엔드포인트 | Dify 보조 노드 라우팅(`dify.aux`)과 관리자 위키 편집 | ai-service |
| R-11 | 공용 Dify: `microweb-chat` 앱 생성, 내부 키 환경 변수, 외부 지식 `microweb-copy` 등록, 로그 보존 30일 | 공용 인프라는 코어 소유 | 공용 Dify |
| R-12 | 공용 3D 장면 키트 `packages/ui-3d`(로더, 저사양 판정, 토큰 재질, 대체 이미지, 성능 모니터) 제공(`docs/file/03-설계/디자인/HERO_3D.md:56-68`, 제안) | 12개 제품이 같은 판정·강등 로직을 따로 만들지 않게 | `_design-guide` |
| R-13 | AI 단가 환산 계수(제품별 크레딧 가치) 또는 `ai_model_prices` 제품별 오버라이드 | 코어 seed 단가는 크레딧 1개 ≈ 400원 기준이라 이 제품(1,000원)과 맞지 않는다(01장 D-10). 그때까지 제품 상수 `ai-pricing.ts` | core-ai |

## 7. 완료 정의

| 조건 | 명령/기준 |
|---|---|
| 빌드·타입·린트 | `pnpm --filter microweb-studio build`, `tsc --noEmit`, `eslint .` 0오류 |
| SQL | `node check.mjs --vector mod ...0000~0009 seed 1500_microweb.sql`, `node check.mjs --vector mono ...` OK |
| RLS 스모크 | `supabase/tests` mod/mono 87/87 |
| E2E | MW-06-032 F1~F3 녹색, 출시 체크리스트 12항목(`DESIGN_PRINCIPLES.md` 7단계) |
| 결제 E2E | MW-06-031(Phase 2 출시 조건) |
| 위생 | gitleaks 0, 추적 node_modules 0 |
| AI·음성 | `pytest apps/api` 통과, MW-06-053 녹색, 문구 제안 평가셋 30건·채팅 평가셋 30문항 금지 문구 0, 검색 평가셋 재현율 0.8, 하객 음성 남용·상용 호출 0 테스트 통과 |
| 3D·디자인 시스템 | `HERO_3D.md` 4절 수용 기준, 디자인 시스템 4단계(MW-06-038) 완료, `tailwind.config.js`·hex 하드코딩 0 |
| 작업 | 이 표의 P0/P1 작업 전부 완료(W0~W6), P2는 Phase 2 출시 조건(W7) |
