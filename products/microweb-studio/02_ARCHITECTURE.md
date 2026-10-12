# 02 아키텍처: Microweb Studio

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 앱 | Next.js App Router, React, TypeScript strict | Next.js 16, React 19 | 확정 결정 11, `00_MERGE_ANALYSIS.md:1089` |
| 스타일 | Tailwind CSS 빌드 타임(`@tailwindcss/postcss`), CSS 변수 토큰 | 4.x | CDN 런타임 금지(`premium-wedding-invitation.md:72`) |
| 모션 | framer-motion(템플릿 모션만), canvas-confetti 제거 검토 | 12.x | `premium-wedding-invitation/CLAUDE.md:72-84` |
| 검증 | zod | 3.x | `SECURITY_BASELINE.md` 10장 |
| DB/인증 | Supabase(Postgres 15, Auth, Storage, Realtime), 모듈러 `microweb` 스키마 | - | `_supabase-modular/ARCHITECTURE.md:41` |
| 이미지 처리 | sharp(워커) | 0.33.x | 제안. EXIF 제거와 webp 파생본 |
| 워커 | TS 워커 1개(`core.jobs` 큐 `microweb.media`) | Node 22 | `CORE_SPEC.md` 9장. 영상 워커(확정 결정 6)와 무관 |
| 결제 | Toss Payments(Phase 2 크레딧팩) | - | 확정 결정 4 |
| 지도/공유 | 카카오 JS SDK(공유, 지도), 네이버 지도 딥링크 | 공식 SRI | `premium-wedding-invitation.md:96` |
| 버전 고정 | lockfile 커밋, `latest` 금지 | - | `SECURITY_BASELINE.md` 13장 |

## 2. 모듈 경계

```
apps/microweb-studio/
  src/app/(showroom)/        /, /portfolio, /pricing, /simulator, /templates, /contact   (쇼룸, 공개)
  src/app/i/[slug]/          하객 공개 페이지 (anon, 게시 스냅샷만)
  src/app/p/[token]/         고객 시안 확인 (토큰, service_role 조회)
  src/app/studio/            운영자 화면 (requireSession + studio_access)
  src/app/api/public/        하객/문의 쓰기 Route Handler (방명록, RSVP, 축하말, 문의, 승인)
  src/app/api/studio/        운영자 Route Handler (업로드, 게시, 내보내기)
  src/app/api/billing/       Toss 주문/confirm (Phase 2)
  src/engine/schema/         블록 zod 스키마, content 검증, 템플릿 레지스트리
  src/engine/blocks/         블록 렌더러 17종 (원본 섹션 컴포넌트 이식)
  src/engine/themes/         템플릿 테마 토큰
  src/showroom/data/         업종, 등급, 가격표, CRM 옵션 (geoMeta 이식, 단일 출처)
  src/showroom/components/   시뮬레이터, 가격표, 포트폴리오
  src/studio/                편집기 컴포넌트, 미리보기
  src/server/                microweb 서비스 계층 (publish, guest, leads, storage, ip-hash)
  worker/                    microweb.media 워커 (asset.process, site.publish, site.unpublish_assets, site.purge, 스케줄)
  supabase/                  _supabase-modular 링크 + tests/rls_smoke
```

| 모듈 | 책임 | 의존 |
|---|---|---|
| engine | content JSON → React. 데이터 소스를 모른다 | 없음 |
| showroom | 정적 데이터 + `templates`/`portfolio_items` 읽기, 문의 제출 | engine(미리보기), server |
| public-site | `site_publications` 읽기(anon 키), 방명록/RSVP/축하말 제출 | engine, server |
| studio | 사이트/리드/주문 CRUD(사용자 세션 + RPC), 업로드, 게시 요청 | engine, server, core-auth |
| server | service_role 호출을 한곳에 모은다. `createAdminClient`는 여기서만 import | core-db, core-billing, core-ai, core-jobs |
| worker | 이미지 처리와 게시 파일 복사, 만료/정리 스케줄 | core-jobs, storage |

## 3. 공용 모듈 사용

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 운영자 로그인, `requireSession('microweb')` | `src/app/studio/layout.tsx`, `api/studio/*` | 공개 가입 끔(초대제) |
| org | 개인 조직, 역할(owner/admin/member) | RPC 내부 `has_org_role` | 1인 1워크스페이스 |
| credits | 셀프 발행 차감·환불(Phase 2) | `api/studio/sites/[id]/publish` | 대행 모드는 쓰지 않음 |
| toss | 크레딧팩 결제(Phase 2) | `api/billing/*` | `confirm_payment_order` 결함 회피(4장) |
| webhooks | Toss 상태 동기화(Phase 2) | `api/webhooks/toss` | 지급은 confirm 경로만 |
| llm gateway | AI 축하말 purpose `microweb_greeting` | `api/public/greeting` | 0크레딧 호출 지원 여부 코어 확인 요청 |
| storage | `org-files`(원본·파생본), `public-assets`(게시 파생본만) | 업로드 라우트, 워커 | 경로 `<org>/microweb/<entity>/<uuid>.<ext>` |
| audit | 모든 RPC 내부 `write_audit`, 서버 경로 service INSERT | DB, server | 개인정보는 감사에 넣지 않음 |
| jobs | `microweb.media` 큐 | server(enqueue), worker | 진행률 Realtime |
| rate limit | `core.rate_limit_hit` | DB 함수 내부 + 라우트 | Redis 없음 |
| 사용 안 함 | oauth, affiliate, fal, weasyprint, sns uploader, automation-core, compliance | - | 모놀리스에서 6-A, 6-B, 9절 제거 |

## 4. 잡과 워커

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `asset.process` | `microweb.media` | TS(sharp) | 없음 | 3회, 지수 백오프 | - |
| `site.publish` | `microweb.media` | TS | 셀프 모드 첫 게시만(`credit_ledger_id`) | 2회 | 최종 실패 시 core `fail_job` 자동 환불 + `microweb.fail_publish` |
| `site.unpublish_assets` | `microweb.media` | TS | 없음 | 5회 | - |
| `site.purge` | `microweb.media` | TS | 없음 | 5회 | - |
| 스케줄 `expire` | 워커 크론 10분 | TS | - | - | `microweb.expire_sites()` → 반환 id마다 `site.unpublish_assets` enqueue |
| 스케줄 `purge` | 워커 크론 매일 03:30 KST | TS | - | - | `microweb.purge_expired_data()`, 보관 30일 지난 사이트 `site.purge` |

워커는 service_role로 `claim_jobs → heartbeat_job(60초) → complete_job | fail_job`을 쓴다(`CORE_SPEC.md` 9장). 공개 라우트에 크론 시크릿을 두지 않는다(`SECURITY_BASELINE.md` 13장).

게시 시퀀스:

| 단계 | 주체 | 동작 |
|---|---|---|
| 1 | 라우트 | `requireSession` owner/admin, content zod 검증(필수 블록) |
| 2 | 라우트(셀프, 미과금) | `consume_credits(org, template.self_publish_credits, 'microweb', 'site_publish', 'site', site_id, 'consume:microweb:<request_id>')` |
| 3 | 라우트 | `microweb.request_publish(site, actor, ledger)` → status publishing |
| 4 | 라우트 | `enqueue_job('site.publish', credit_ledger_id, 'job:microweb:<request_id>')`, 실패하면 `fail_publish` + `refund_credits` |
| 5 | 워커 | ready 파생본을 `public-assets/<org>/microweb/site-public/<site>/` 로 복사, URL로 스냅샷 content 생성 |
| 6 | 워커 | `microweb.finalize_publish` → published, 스냅샷 is_live |
| 7 | 실패 | `fail_job` 자동 환불 → `microweb.fail_publish` 상태 복구 |

## 5. AI 라우팅

| purpose | 모델 | 크레딧 | 폴백 |
|---|---|---|---|
| `microweb_greeting` | fast 모드 1종 고정(게이트웨이 모델 맵) | 0(비용은 `ai_usage`) | 폴백 모델 1회, 실패 시 오류 표시(고정 문구로 위장 금지) |

입력은 이름 20자, 관계 enum만. 프롬프트는 서버 상수. 사용자 문자열은 구분자 안에 넣고 지시로 해석하지 않게 한다. 출력 200자 초과는 자른다. 이미지 생성 제공자는 MVP에 없다(Phase 3 히어로 보정 때 fal client 검토).

## 6. 리뷰 "높음" 결함의 차단 설계

리뷰 "높음" 10건 중 구조·제품 결함 8건은 이 표, 보안·데이터 결함 2건(premium #3, webcraft #2)은 `05_DATA_MODEL.md` 7장에 있다.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/premium-wedding-invitation.md` 3장 #1 | `premium-wedding-invitation/frontend/components/Hero.tsx:24-31` | 방문마다 Imagen 4장 생성, 하객 수에 비례한 비용 | 하객 경로(`/i/*`, `api/public/*`)에 이미지 생성 호출을 두지 않는다. 히어로는 `site_assets`(업로드, EXIF 제거) → 게시 때 `public-assets` 정적 URL. CI에 `/i` 번들에서 LLM/이미지 SDK import 금지 검사 | MW-06-010, MW-06-021 |
| `premium-wedding-invitation.md` 3장 #2 | `frontend/services/imageService.ts:11-13,47` | 히어로가 가상 커플, 지도가 AI가 그린 가짜 | hero 블록 스키마는 `asset_id` 배열만 허용(프롬프트 필드 없음). location 블록은 주소+좌표+카카오맵 임베드/딥링크. AI 지도 코드는 이식하지 않음(07장) | MW-06-010 |
| `nexus-micro-web-builder.md` 3장 #1 | `backend/server.js:1-453` | 호출 없는 Vertex 프록시가 dev 실행에 GCP ADC 강제 | 프록시·인터셉터를 이식하지 않는다. 새 앱 기동 필수 env는 8장 표뿐이며 GCP 변수가 없다 | MW-06-001, 07장 3절 |
| `nexus-micro-web-builder.md` 3장 #2 | `frontend/contexts/AuthContext.tsx:2` | 존재하지 않는 타입 import, 컴파일 불가 고아 코드 | nexus 코드는 이식하지 않고 `models.ts` 데이터만 SQL 카탈로그(`1500_microweb.sql:1510`)로 옮긴다. 새 앱은 `tsc --noEmit` strict가 CI 필수 | MW-06-001, MW-06-005 |
| `nexus-micro-web-builder.md` 3장 #3 | `frontend/pages/Login.tsx:2` | 미설치 react-router-dom import | 위와 같음. 라우팅은 App Router 하나. 의존성은 lockfile 고정 | MW-06-001 |
| `webcraft-agency-simulator.md` 3장 #1 | 저장소 루트(.gitignore 없음) | node_modules 8,655개 커밋 | 새 앱은 모노레포 루트 `.gitignore`(node_modules, .next, dist, .env*) 상속, CI에서 추적 파일 중 node_modules 0개 검사. 원본은 아카이브만(07장 5절) | MW-06-001, MW-06-034 |
| `webcraft-agency-simulator.md` 3장 #3 | `backend/server.js:1-455` | 미사용 프록시 백엔드가 `npm run dev`에 묶임 | 프리미엄 #3/nexus #1과 같은 처리. 백엔드 없음, AI는 `api/public/greeting` 1개 | MW-06-001 |
| `webcraft-agency-simulator.md` 3장 #4 | gitlink 5d0f978 | `.gitmodules` 없는 중첩 repo | 원본 폴더를 이식하지 않는다. 새 앱 디렉토리에 `.git` 하위 폴더 금지 검사(CI `find apps -name .git -mindepth 2`) | MW-06-034 |

## 7. 배포 토폴로지

| 구성요소 | 위치 | 네트워크 |
|---|---|---|
| Next.js 앱(쇼룸, 하객, 스튜디오, 라우트) | Vercel | 공개. `/i/*`는 anon 키로 Supabase 읽기, `s-maxage=30` |
| 워커 `microweb.media` | Railway(제안) | 아웃바운드만. service_role 키 |
| Supabase(모듈러 통합 프로젝트) | Supabase | `[api].schemas`에 `microweb` 추가 |
| Storage | `org-files`(비공개), `public-assets`(게시 파생본) | BGM은 `public-assets`가 이미지 전용이라 `/api/public/[slug]/bgm`이 게시 확인 후 1시간 서명 URL로 302 |
| 도메인 | 쇼룸과 하객 페이지 같은 도메인(카카오 도메인 등록 1개) | robots.txt `Disallow: /i/`, `/p/`, `/studio` |

## 8. 환경변수

| 변수 | 용도 | 공개 여부 | 누락 시 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 클라이언트/anon 읽기 | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | server, worker | 서버 전용 | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | `core`/`public` 전환 | 서버 | 기동 실패 |
| `MICROWEB_STUDIO_ORG_ID` | 문의를 받을 스튜디오 조직 | 서버 | 기동 실패 |
| `IP_HASH_SALT_SEED` | 일 단위 IP 해시 솔트 | 서버 | 기동 실패 |
| `NEXT_PUBLIC_KAKAO_JS_KEY` | 카카오 공유/지도(도메인 제한) | 공개 | 공유는 Web Share 폴백, 경고 로그 |
| `LLM_*`(게이트웨이 설정) | AI 축하말 | 서버 | 축하말 버튼 숨김(기동은 계속) |
| `LEAD_NOTIFY_EMAIL`, `SMTP_*` 또는 메일 API 키 | 문의 알림 | 서버 | 기동 실패(문의 유실 방지) |
| `TOSS_CLIENT_KEY`(공개), `TOSS_SECRET_KEY`, `TOSS_WEBHOOK_SECRET` | Phase 2 결제 | 시크릿은 서버 | Phase 2 플래그가 켜져 있으면 기동 실패 |
| 금지 | `GOOGLE_CLOUD_PROJECT`, `PROXY_HEADER` 등 원본 Vertex 변수 | - | 존재하면 CI 경고 |
