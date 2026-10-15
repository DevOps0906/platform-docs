# 06 에이전트 작업 계획: 로컬뉴스 클라우드(가칭)

작업 ID 접두사 `NW`(SQLSTATE 접두사와 같다, `docs/products/_platform-core/DOC_TEMPLATE.md` 0장). 작성일 2026-10-15. 경로는 앱 저장소 기준이며 `apps/web/`은 생략해 `src/...`로 적는다(02장 2절 트리와 같다). 작업 수 56개(사람 작업 1개 포함, 모델 작업 55개)는 `DOC_TEMPLATE.md`의 15~40개 권장을 넘는다. 신문사 SaaS가 편집국·독자 사이트·운영 콘솔 3개 화면 묶음과 공통모듈 8개, 화이트라벨, AI·음성, 인증 2개 대상(편집국·독자)을 함께 갖기 때문이며, 검증할 수 있는 크기(`docs/products/_design-guide/DESIGN_SYSTEM.md:24`)를 지키려고 합치지 않았다.

## 1. 원칙과 소유 경계

| 원칙 | 내용 |
|---|---|
| 디렉토리 단위 소유 | 한 작업은 2절 표의 소유 경로만 만진다. 두 작업이 같은 파일을 만지지 않는다. 다른 작업 파일에 한 줄(라우트 등록, 컴포넌트 장착)이 필요하면 그 작업 소유자에게 "1줄 요청"을 남긴다 |
| 모듈 경계 | `src/modules/<모듈>/`은 02장 2절의 공통모듈 단위(M1~M8, local-life)다. 다른 모듈은 `server/index.ts` 공개 함수만 import한다(린트, NW-06-006). 다른 모듈의 표에 직접 쓰지 않는다(`modules/README.md` 경계 규칙) |
| SQL 정본 | `docs/products/_supabase-modular/migrations/2500_news.sql`이 정본, 모놀리스 `0003_local_news_domain.sql`은 변환 스크립트(`docs/products/local-news/supabase/tools/to_monolith.py`) 결과다. SQL은 NW-06-001(Fable)만 고친다. 다른 작업은 필요한 RPC·컬럼을 001 소유자에게 요청한다 |
| 공개 읽기 | 독자 사이트의 공개 콘텐츠는 항상 anon 키 서버 클라이언트로 읽는다(쿠키 없음, ISR 캐시 공유). 기사 본문은 `news.read_article`만(05장 4절, `DATA_SUMMARY` 5절 계약) |
| 디자인 시스템 순서 | 화면 작업은 NW-06-010(디자인 시스템 4단계) 뒤에 시작한다(`DESIGN_SYSTEM.md` 4장). 토큰 파일 `src/styles/tokens.css`는 NW-06-008 소유 |
| 인증 단계 경계 | `AUTH_MODE`·제공자 목록을 읽는 코드는 `src/lib/auth/`, `src/app/(auth)/`, `src/app/auth/`, `src/app/api/dev/login/`, 독자 로그인 `src/app/(reader)/_t/[host]/login/`에만(02장 9.2절, CI 검사 NW-06-006) |
| 테넌트 경계 | 테넌트 해석은 `src/proxy.ts` → `src/lib/tenancy/`만. 코드에 테넌트 slug·org_id 리터럴 분기 금지(`Multi-tenant_Theming/03_CODE_STRUCTURE.md:155-163`) |
| 사람 작업 | NW-06-009(디자인 시스템 3단계 비주얼 검토)는 사람이 수행한다. 비율 계산에서 뺀다 |
| 독자 사이트 경로 소유 | `src/app/(reader)/_t/[host]/`의 레이아웃·홈·기사·분류·검색은 NW-06-021, 그 아래 하위 경로는 표에 적은 작업이 각각 소유한다(login·account 023, membership 024, newsletter 028, tips 030, corrections 034, life/obituaries·life/people 032, life/events 036, listings·notices 026, legal 022, live 016, 배포 파일 033) |

## 2. 작업 목록

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 | 출처 |
|---|---|---|---|---|---|---|---|---|
| NW-06-001 | DB 적용: 모놀리스 0001~0003·seed를 로컬 Supabase에 적용, 변환 스크립트를 앱 저장소로 이동, 타입 생성 | `supabase/`, `scripts/db/` | 없음 | P0 | M | Fable | `supabase db reset` 성공, `scripts/db/to_monolith.py` 재실행 결과와 커밋된 `0003` diff 0, `pnpm db:types` 후 diff 0. 05장 9절 체커 명령 5개 OK | 05장 9절, `DATA_SUMMARY` 5절 |
| NW-06-002 | 모노레포·앱 골격(apps/web, worker, apps/api 설치 껍데기), 기본 CI | `package.json`, `pnpm-workspace.yaml`, `turbo.json`, `.github/workflows/`, `apps/web/package.json`, `worker/package.json` | 없음 | P0 | S | Haiku | `pnpm -r build` 통과, CI에서 lint·typecheck·test 단계 실행. 버전 고정·lockfile 커밋(`latest` 0) | 02장 1절 |
| NW-06-003 | RLS·권한 회귀를 CI로: `tests/rls_smoke.sql` 314항목(mono·mod 두 대상)과 실 Supabase 재검증 | `tests/rls/` | NW-06-001 | P0 | M | Fable | CI에서 PASS=314 FAIL=0(두 대상), 실 Supabase(`supabase db reset` 후) 같은 결과, 실패 시 머지 차단 | 05장 4·9절 |
| NW-06-004 | 인증 Stage A: `src/lib/auth/`(getAuthConfig, isMockAuthAllowed, listLoginOptions, finishLogin 호스트 분기), 편집국 로그인 화면 A 구성, `/api/dev/login`, 시드 스크립트 + 제품 훅(편집국·독자 페르소나) | `src/lib/auth/`, `src/app/(auth)/`(A 구성, 052가 이어 받음), `src/app/api/dev/login/`, `scripts/dev/` | NW-06-001, NW-06-002 | P0 | M | Fable | 05장 10절 페르소나 15개가 기대 결과대로(`viewer` 편집국 0행, `reader_other`의 owner 신문 댓글 NW008, `outsider` 교차 신문 0행), 시드 2회 실행 멱등, 루프백 아닌 호스트면 시드 종료, `isMockAuthAllowed()` 거짓이면 `/api/dev/login` 404, `AUTH_MODE=mock VERCEL_ENV=production` 빌드 실패, 쿠키·localStorage 역할 쓰기 0 | `AUTH_ROADMAP.md` 2장, 01장 NW-F-005·006, 02장 9절 |
| NW-06-005 | 테넌시 연결(MT-03~05 제품 쪽): `src/proxy.ts` Host 분기(reader·newsroom·ops·marketing, 위조 헤더 제거), `src/lib/tenancy/` 어댑터, 캐시 태그 정본, 루트 레이아웃 테마 CSS 서버 주입 | `src/proxy.ts`, `src/lib/tenancy/`, `src/lib/cache/`, `src/app/layout.tsx` | NW-06-001, NW-06-002 | P0 | M | Fable | 클라이언트가 보낸 `x-tenant-*`·`x-host-kind` 헤더 무시, 비활성·미등록 도메인은 오류 화면(플랫폼 브랜드로 기사 노출 0, 02장 10절), 테마 CSS가 첫 HTML에 포함(깜빡임 0), 해석 결과 캐시 태그 `tenant:<org>`·`host:<hostname>` | 02장 10절, `Multi-tenant_Theming/05_RUNTIME_AND_DOMAINS.md` |
| NW-06-006 | 저장소 위생과 금지 검사: `.env.example`, env 검증, ESLint 규칙(모듈 간 import는 공개 API만, `bg-[#...]` hex 금지, 쿠키 역할 Mock·`mock-auth`, 인증 모듈 밖 `AUTH_MODE`, 테넌트 리터럴 분기) | `src/env/`, `eslint.config.mjs`, `.env.example`, `.gitignore` | NW-06-002 | P0 | S | Haiku | `pnpm lint` 오류 0, 금지 패턴을 넣은 시험 파일에서 규칙이 실패, 서버 전용 변수가 `NEXT_PUBLIC_*`에 0개 | 02장 8절, 07장 4절 |
| NW-06-007 | 디자인 시스템 1단계: 레퍼런스 확정(뉴스 벤치마크 + `REFERENCES.md`), 가져올 것·안 가져올 것, 템플릿 3종 방향 | `docs/file/03-설계/디자인/DESIGN.md`(1절) | 없음 | P0 | S | Sonnet | 03장 4절의 벤치마크 표와 직접 확인·미확인 구분이 DESIGN.md 1절에 있고, 링크를 열어 본 결과(열림·교체)가 기록됨 | `DESIGN_SYSTEM.md` 4장 1단계, 03장 4절 |
| NW-06-008 | 디자인 시스템 2단계: Tailwind CSS v4 토큰 3계층(테넌트 허용 목록), 서체 프리셋(Pretendard, Noto Serif KR, 본명조, 나눔명조), 기본 컴포넌트, `/dev/components` | `src/styles/`, `src/components/ui/`, `src/app/dev/components/` | NW-06-002, NW-06-007 | P0 | L | Sonnet | hex 하드코딩 0, `tailwind.config.js` 0, 라이트·다크 미리보기, 대비 4.5:1, 본문 17px 기본·글자 크기 4단계, 서체 키가 MT 서체 레지스트리 키와 같음 | `DESIGN_SYSTEM.md` 4장 2단계, 03장 3.9절 |
| NW-06-009 | 디자인 시스템 3단계: 사람 비주얼 검토(템플릿 3종 × 라이트·다크 × 시험 테넌트 3개, 상태 6종). **사람이 수행** | `docs/file/03-설계/디자인/review/` | NW-06-008 | P0 | M | 사람(보조 Sonnet) | 스크린샷과 사람이 고친 수치 기록, 대비·포커스 링 확인 | `DESIGN_SYSTEM.md` 4장 3단계 |
| NW-06-010 | 디자인 시스템 4단계: 코드를 정답으로 확정, DESIGN.md·COMPONENTS.md를 코드 기준으로 재작성 | `docs/file/03-설계/디자인/DESIGN.md`(2절 이후), `docs/file/03-설계/디자인/COMPONENTS.md` | NW-06-009 | P0 | S | Opus | 문서 토큰 값과 `tokens.css`가 스크립트 비교로 100% 일치, 외부 파일 링크 0 | `DESIGN_SYSTEM.md` 4장 4단계 |
| NW-06-011 | M1 서버: 기사 저장·제출·검토·예약·게시·게시 취소·정정 RPC 래퍼(zod), 수정 이력, 편집국 미리보기 토큰 | `src/modules/newsroom-cms/server/`, `src/app/api/newsroom/articles/` | NW-06-004, NW-06-005 | P0 | L | Opus | `save_article` 허용 키 밖이면 NW015, 게시 후 내용 수정 시 `change_note` 없으면 거부, 기자·기고자의 승인·게시 42501, 매체정보 미완성 게시 NW003, 미리보기는 10분 서명·`noindex`·ISR 미포함 | 01장 NW-F-010~012·017, 04장 2.2·3절 |
| NW-06-012 | M1 화면: 블록 에디터(문단·소제목·사진·인용·표·임베드), 메타 패널(유형·섹션·지역·엠바고·라벨·AI 표시), 자동 저장, 기사 목록, 데스크 큐 | `src/modules/newsroom-cms/components/`, `src/app/(newsroom)/articles/`, `src/app/(newsroom)/desk/` | NW-06-010, NW-06-011 | P0 | L | Sonnet | 자동 저장 10초(이력 스냅샷 생략), `sponsored` 선택 시 라벨 필수 표시, AI 보조 시 표시 문구 필수, 데스크 큐에서 승인·반려 2클릭 | 03장 3절, NW-F-010~012 |
| NW-06-013 | 홈 편집: 템플릿 선택, 블록 순서·ON/OFF, 톱·서브 지정, 예약 게시, 미리보기 | `src/app/(newsroom)/home-editor/` | NW-06-011, NW-06-020 | P0 | M | Sonnet | 게시 후 60초 안에 독자 홈 반영(캐시 태그 무효화), 예약 게시가 지정 시각 ±1분, 블록 레지스트리 밖 블록 저장 거부 | NW-F-013, 03장 3절 |
| NW-06-014 | 미디어 라이브러리(서명 업로드, 파생본, alt·출처 필수, AI 생성 표시)와 지면 PDF 보관 | `src/app/(newsroom)/media/`, `src/app/(newsroom)/print/`, `src/app/api/newsroom/media/` | NW-06-011 | P0 | M | Opus | alt·credit 없는 저장 23514, 경로 첫 폴더 = org_id, 10MB 초과 거부, 지면 PDF는 `news_print_pdf` 없는 플랜에서 NW014 | NW-F-014·015, 05장 Storage |
| NW-06-015 | 섹션·지역(시·군·읍면)·태그 관리, 구성원 초대·역할, 내 기자 프로필 | `src/app/(newsroom)/sections/`, `src/app/(newsroom)/staff/` | NW-06-010, NW-06-011 | P0 | M | Sonnet | `news_staff_max` 초과 초대 NW014, editor가 editor 부여 시 42501, publisher 제거 불가 | NW-F-004, 04장 3절 |
| NW-06-016 | 라이브 기사(업데이트 타임라인)와 속보 바 | `src/app/(newsroom)/live/`, `src/app/(reader)/_t/[host]/live/` | NW-06-011, NW-06-021 | P1 | S | Sonnet | 업데이트 게시 후 독자 화면 30초 안 반영, 숨김 업데이트 비노출 | NW-F-016 |
| NW-06-017 | 신문사 개설 신청과 승인: 신청 화면(등록증 업로드), 운영 콘솔 심사, `approve_newspaper`(service) 호출 | `src/app/(newsroom)/apply/`, `src/app/(ops)/applications/`, `src/app/api/ops/` | NW-06-004, NW-06-005 | P0 | M | Fable | 같은 slug 재신청 NW001, 승인 시 조직·owner·trialing 구독·엔타이틀먼트 30일·발행인 staff가 한 번에 생성, 운영자 외 승인 경로 0 | NW-F-001, 04장 3절 |
| NW-06-018 | 기존 CMS 이관: 가져오기 화면, ingest 워커(RSS·CSV·XML·사이트맵), 사진 재호스팅, 301 리디렉션 맵 | `src/app/(newsroom)/import/`, `worker/src/handlers/ingest/` | NW-06-011, NW-06-014 | P1 | L | Opus | 시험 RSS 1,000건 가져오기 중복 0(`legacy_id`), 이관 기사 원래 URL 301 응답 100%, 실패 행 보고서 | NW-F-063, 07장 2절 |
| NW-06-019 | 신문사 해지·데이터 내보내기(기사·사진·독자 동의 기록) | `src/app/(newsroom)/settings/export/`, `worker/src/handlers/export/` | NW-06-011 | P1 | M | Opus | 내보내기 파일에 기사 전량·사진 경로·독자 행, 링크 24시간 서명 만료, 감사 1행 | NW-F-064 |
| NW-06-020 | 독자 홈 템플릿 3종(전통 신문형·모던 매거진형·모바일 피드형)과 블록 레지스트리, 광고 슬롯 공간 예약 | `src/features/reader-home/` | NW-06-005, NW-06-010 | P0 | L | Sonnet | 03장 4절 와이어프레임과 블록 순서 일치, 슬롯마다 크기 예약(CLS 0.1 이하), 팝업·전면광고 컴포넌트 0 | NW-F-020, 03장 4절 |
| NW-06-021 | 독자 사이트 레이아웃·홈·기사 상세(`read_article`, 잠금, 수정·정정·AI 표시, 광고 라벨)·섹션·지역·태그·기자·검색 화면 | `src/app/(reader)/_t/[host]/`(1절 하위 경로 제외) | NW-06-011, NW-06-020 | P0 | L | Sonnet | 미게시·엠바고 기사 404, 공개 콘텐츠를 사용자 세션으로 읽는 코드 0, 기사 상세에 수정 시각·사유, NewsArticle 메타 자리 | NW-F-021·022, 03장 3절 |
| NW-06-022 | 법정 표기: 매체정보 설정 화면, 법정 푸터 컴포넌트(전 페이지), 정책 페이지, 미완성 시 공개 차단 | `src/modules/compliance-desk/footer/`, `src/app/(newsroom)/settings/profile/`, `src/app/(reader)/_t/[host]/legal/` | NW-06-005, NW-06-010 | P0 | M | Opus | 필요적 게재사항 10개 중 하나라도 없으면 독자 사이트 공개 차단(NW003), 청소년보호책임자 성명이 모든 독자 페이지 첫 화면 푸터에 표시, 숨김 설정 불가 | NW-F-002·028, 01장 6절 |
| NW-06-023 | M2 독자: 독자 가입(`ensure_reader`, 동의·만 14세 확인), 독자 로그인 A 구성, 계정·탈퇴 | `src/modules/reader-membership/`(`payments/` 제외), `src/app/(reader)/_t/[host]/login/`(A 구성, 053이 이어 받음), `src/app/(reader)/_t/[host]/account/`, `src/app/api/r/account/` | NW-06-004, NW-06-021 | P0 | M | Opus | 독자는 조직 멤버가 되지 않음(org_members 0행), 다른 신문 독자 행 0, 닉네임 중복 23505 안내, 탈퇴 시 멤버십이 남아 있으면 NW004 | NW-F-006, 05장 2절 |
| NW-06-024 | M2 결제: 신문사 Toss 가맹 키 등록(암호화 저장), 후원·멤버십 결제, 웹훅(`/api/webhooks/toss/[org_id]`), 미터형 페이월, 정기 청구 | `src/modules/reader-membership/payments/`, `src/app/(reader)/_t/[host]/membership/`, `src/app/(newsroom)/settings/payments/`, `src/app/api/webhooks/toss/`, `worker/src/handlers/stats/membership_renew.ts` | NW-06-023 | P1 | L | Fable | 금액 위조 시 기록 거부(NW015), 웹훅 서명 실패 401, 같은 이벤트 2회 처리 1회 반영, 키 평문 저장 0, 미터 초과 시 가입·멤버십 안내 | NW-F-035·036, 01장 D-4 |
| NW-06-025 | M3 광고: 슬롯·광고주·캠페인·소재 검수, `serve_ads`, 노출·클릭 집계 롤업, 라벨 강제 | `src/modules/ad-manager/`, `src/app/(newsroom)/ads/`, `src/app/api/newsroom/ads/`, `src/app/api/r/ad-event/`, `worker/src/handlers/stats/ad_stats_rollup.ts` | NW-06-011, NW-06-020 | P0 | L | Opus | 라벨 없는 소재 23514, 정부 광고주 직판 NW013, 집계는 service만, 광고 없으면 하우스 광고(슬롯 접힘 0) | NW-F-030·032 |
| NW-06-026 | 지역 업소 셀프 광고(신청·검수·게재)와 지자체 공고 게재·증빙 리포트 | `src/app/(newsroom)/listings/`, `src/app/(newsroom)/notices/`, `src/app/(reader)/_t/[host]/listings/`, `src/app/(reader)/_t/[host]/notices/`, `src/app/api/r/listings/` | NW-06-023, NW-06-025 | P1 | M | Sonnet | 승인 전 업소 비노출, 게재 기간 끝나면 자동 만료, 공고 게재 증빙 PDF·CSV | NW-F-033·034 |
| NW-06-027 | 외부 광고망 태그(Google Ad Manager·AdSense) | `src/modules/ad-manager/external/`(025에서 이어 받음) | NW-06-025 | P1 | S | Sonnet | 외부 태그도 예약 슬롯 안에서만, 동의 없는 개인화 광고 0(제안) | NW-F-031 |
| NW-06-028 | M4 뉴스레터: 목록, 이중 동의 구독·확인·해지(POST), 아침 브리핑 구성·발송, 2년 재확인, 열람 집계, 메일 어댑터 | `src/modules/notify-newsletter/`(`push/` 제외), `src/app/(newsroom)/newsletter/`, `src/app/(reader)/_t/[host]/newsletter/`, `src/app/api/r/newsletter/`, `worker/src/handlers/newsletter/` | NW-06-011, NW-06-023 | P0 | L | Opus | 확인 전 발송 0, 토큰 원문 저장 0, 광고 포함 제목에 '(광고)' 없으면 23514, 야간(21~08시) 광고 발송은 야간 동의자만, 플랜 월 한도 초과 NW014 | NW-F-037, 01장 6절 |
| NW-06-029 | 속보 웹 푸시(VAPID, 구독 등록·해지, 발송) | `src/modules/notify-newsletter/push/`(028에서 이어 받음), `src/app/api/r/push/`, `public/sw.js` | NW-06-028 | P1 | M | Opus | 권한 거부 시 화면 정상, 만료 엔드포인트 자동 해지, 속보 1건당 발송 1회(멱등) | NW-F-038 |
| NW-06-030 | M5 제보·투고: 제보 폼(Turnstile·허니팟·레이트 리밋, 첨부 서버 업로드), 편집국 제보함, 배정 | `src/modules/community/tips/`, `src/app/(reader)/_t/[host]/tips/`, `src/app/api/r/tips/`, `src/app/(newsroom)/tips/` | NW-06-004, NW-06-021 | P0 | M | Opus | 비로그인 제보 가능, 제보 원문·첨부는 DESK와 배정 기자만, 보존 기한 후 자동 파기, 같은 IP 10분 5건 초과 NW011 | NW-F-025, 05장 7절 |
| NW-06-031 | M5 댓글: 작성·신고·임시조치(권리침해 주장 즉시 30일)·모더레이션(+AI 보조), 기사별 on/off | `src/modules/community/comments/`, `src/app/api/r/comments/`, `src/app/(newsroom)/comments/` | NW-06-023 | P1 | M | Opus | 댓글 기본 꺼짐(D-6), 금칙어 NW010, 신고 5건 자동 숨김, 선거 모드 댓글 정책 적용, AI 판정은 제안만(사람이 결정) | NW-F-026, 01장 6절 |
| NW-06-032 | M5 경조사(부고·인사·동정·화촉) 신청·검토·게시 | `src/modules/community/life-events/`, `src/app/(reader)/_t/[host]/life/obituaries/`, `src/app/(reader)/_t/[host]/life/people/`, `src/app/(newsroom)/life-events/` | NW-06-023 | P1 | M | Sonnet | 승인 전 비노출, 신청자 본인 철회 가능, 홈 블록 연동 | NW-F-024 |
| NW-06-033 | M6 배포·SEO: RSS, 사이트맵·뉴스 사이트맵(최근 2일·1,000개), NewsArticle 구조화 데이터, OG·canonical, robots·llms.txt(AI 크롤러 정책), 전재 계약 화면 | `src/modules/distribution-seo/`, `src/app/(reader)/_t/[host]/rss.xml/`, `src/app/(reader)/_t/[host]/sitemap.xml/`, `src/app/(reader)/_t/[host]/sitemap-news.xml/`, `src/app/(reader)/_t/[host]/robots.txt/`, `src/app/(reader)/_t/[host]/llms.txt/`, `src/app/(newsroom)/wire-contracts/` | NW-06-021 | P0 | M | Opus | 뉴스 사이트맵이 Google 규격 통과(최근 2일, 1,000개 이하), 리치 결과 테스트 오류 0, 전재 계약 만료 기사 비노출, AI 학습 크롤러 기본 차단 | NW-F-040·043·045 |
| NW-06-034 | M7 준수 데스크: 정정·반론·추후보도 청구(폼·SLA 타이머·응답·원기사 연결), 자체기사 비율 대시보드, 선거 모드 | `src/modules/compliance-desk/`(`footer/` 제외), `src/app/(reader)/_t/[host]/corrections/`, `src/app/api/r/corrections/`, `src/app/(newsroom)/corrections/`, `src/app/(newsroom)/compliance/`, `src/app/(newsroom)/elections/`, `worker/src/handlers/stats/compliance_weekly.ts`, `worker/src/handlers/stats/correction_sla.ts` | NW-06-011, NW-06-022 | P0 | L | Opus | 접수 시 통지 기한(+3일)·게재 기한(수용+7일) 고정, 기한 24시간 전·초과 시 알림, 주간 자체기사 비율 30% 미만·주간 신규 0건 경고, 여론조사 공표 금지 기간 게시 NW007 | NW-F-027·041·044, 01장 6절 |
| NW-06-035 | M8 검색·분석: `/api/r/view`(봇 필터·IP 해시 레이트 리밋·묶음 증분), 많이 본 뉴스, 검색 API, 편집국 대시보드, 지원사업 리포트 | `src/modules/search-analytics/`, `src/app/api/r/view/`, `src/app/api/r/search/`, `src/app/api/r/most-read/`, `src/app/(newsroom)/dashboard/`, `src/app/(newsroom)/reports/`, `worker/src/handlers/stats/stats_rollup.ts`, `worker/src/handlers/stats/support_report.ts` | NW-06-011, NW-06-021 | P0 | L | Opus | 같은 IP 1분 30회 초과 집계 제외, 묶음 증분 1회 최대 1,000, 검색 응답 p95 300ms(기사 5만 건, 제안), 대시보드 KPI 5종 | NW-F-022·060·061 |
| NW-06-036 | 지역 생활: 행사 캘린더, 날씨·미세먼지 블록(외부 API 캐시) | `src/modules/local-life/`, `src/app/(reader)/_t/[host]/life/events/`, `src/app/(newsroom)/events/`, `src/app/api/r/life/` | NW-06-020 | P1 | M | Sonnet | 외부 API 장애 시 블록 숨김(오류 노출 0), 캐시 30분(제안), 출처 표기 | NW-F-023, 01장 D-8 |
| NW-06-037 | 게시 파이프라인 워커: 예약 게시(매분 `run_scheduled_publishing`), 게시 후 처리(캐시 무효화·사이트맵·푸시 트리거), 발신 웹훅 | `worker/src/handlers/publish/`, `src/app/api/internal/revalidate/` | NW-06-005, NW-06-011 | P0 | M | Opus | 예약 시각 ±1분 게시, 게시 후 독자 홈 60초 안 반영, 발신 웹훅 HMAC 서명·재시도 3회 | 02장 4절, 04장 4·5절 |
| NW-06-038 | 운영 콘솔: 신문사 목록·상태, 플랜·엔타이틀먼트, 도메인 상태, 잡·장애, 감사 열람 | `src/app/(ops)/`(`applications/` 제외) | NW-06-017 | P0 | M | Sonnet | `platform_admin` 외 404, 조회마다 감사 1행, 신문사 기사 본문 열람 화면 0 | NW-F-062 |
| NW-06-039 | 브랜딩·도메인 설정(MT-06~09·12 제품 쪽): 로고 업로드·색 추출·대비 검사·미리보기·게시, 서브도메인, 커스텀 도메인 연결·검증 워커 | `src/app/(newsroom)/settings/branding/`, `src/app/(newsroom)/settings/domains/`, `src/app/api/tenant/`, `worker/src/handlers/domain/` | NW-06-005, NW-06-010 | P0 | L | Opus | 대비 미통과 게시 TM002, 플랜 도메인 수 초과 거부(`news_custom_domains`), 도메인 활성 후 독자 로그인 Redirect URL 등록 잡 생성(D-3 (a)), 검증 실패 상태 표시 | NW-F-003, 02장 10절, `Multi-tenant_Theming/06_ADOPTION_PLAN.md` |
| NW-06-040 | 플랫폼 마케팅 랜딩(신문사 대상, 선택 3D 히어로) | `src/app/(marketing)/`, `src/features/hero3d/` | NW-06-010 | P1 | M | Sonnet | 01장 6절 금지 문구 0, 3D는 `HERO_3D.md` 성능 예산·정지 이미지 대체, 독자 사이트에서 3D import 0 | 01장 D-11, 03장 4절 |
| NW-06-041 | AI 서비스 설치: `apps/api` news 확장 설정, 서명 토큰 검증, 라우팅 seed 14행 검증, 오픈소스 강제 경로 | `apps/api/app/ai/products/news/`(`knowledge.py`·`prompts/` 제외), `apps/api/tests/news/platform/` | NW-06-001 | P0 | M | Fable | 다른 app `aud`·만료 토큰 401, `news.moderation`·`news.stt` 상용 호출 0, 라우팅 해석 스냅샷이 seed와 일치 | 02장 5절, `AI_ARCHITECTURE.md` 2·4장 |
| NW-06-042 | AI 게이트: `/api/ai/*`, `/api/voice/*`(newsroom 호스트만), 크레딧 선차감·정산·환불, 입력 마스킹, 서명 토큰 발급 | `src/app/api/ai/`, `src/app/api/voice/`, `src/server/ai/` | NW-06-004, NW-06-041 | P0 | M | Fable | 크레딧 부족 402(CR001), 실패 시 전액 환불, 독자 호스트에서 AI 경로 404, 연락처·주민번호 패턴 마스킹 | 04장 2.4절, 01장 4절 |
| NW-06-043 | AI 기사 보조: 그래프 `news.press_to_draft`·`news.assist`(제목·요약·교정·alt), compliance 노드, 에디터 AI 패널 | `apps/api/app/ai/graphs/`, `apps/api/app/ai/compliance/news.py`, `apps/api/app/ai/products/news/prompts/`, `src/features/ai-assist/`(에디터 장착은 012에 1줄 요청) | NW-06-011, NW-06-042 | P0 | L | Opus | AI 초안은 `origin='ai_press_release'`·유형 `press_release`·AI 표시 필수, 사람 승인 없는 게시 0(NW006), 출처 보도자료 연결 | NW-F-050·051·055, 01장 D-9 |
| NW-06-044 | 편집국 AI 어시스턴트: 과거 기사·사내 규정 RAG 색인, Dify 앱, 채팅 위젯 | `apps/api/app/ai/products/news/knowledge.py`, `infra/dify/`, `src/app/(newsroom)/assistant/`, `src/features/ai-chat/` | NW-06-042 | P0 | L | Opus | 답변마다 출처 1개 이상 또는 근거 없음 안내, 다른 신문사 기사 근거 0, Dify 입력에 토큰·org 0 | NW-F-053, `AI_ARCHITECTURE.md` 3장 |
| NW-06-045 | 음성: 인터뷰 받아쓰기(STT, 원본 미저장) 화면과 오디오 기사(TTS 잡) | `src/features/voice/`, `worker/src/handlers/ai/` | NW-06-042 | P0 | M | Opus | 녹음 동의 전 STT 403, `store_audio=false` 100%, 마이크 거부 시 텍스트 입력 정상, 오디오 기사에 AI 음성 표시 | NW-F-052·054, `VOICE_ARCHITECTURE.md` |
| NW-06-046 | AI 평가셋과 AI 보안 회귀: 보도자료 초안 평가 20건, 어시스턴트 30문항, 서명 토큰·교차 신문사·AI 표시 누락·사람 승인 우회 | `apps/api/tests/news/eval/`, `apps/api/tests/news/security/`, `tests/ai/` | NW-06-043, NW-06-044, NW-06-045 | P0 | M | Fable | AI 표시 누락 0, 사람 승인 없는 게시 0, 교차 신문사 근거 0, 금지 문구 0, CI 실패 시 머지 차단 | `SECURITY_BASELINE.md` 16장 |
| NW-06-047 | 핵심 E2E(Playwright, 페르소나 storageState): 개설 신청→승인→매체정보→기사→데스크 승인→게시→홈, 독자 가입→뉴스레터 확인, 제보, 정정 청구 | `tests/e2e/`(`payments/` 제외), `playwright.config.ts` | NW-06-012, NW-06-013, NW-06-021, NW-06-023, NW-06-028, NW-06-030, NW-06-034 | P0 | L | Opus | `globalSetup`이 페르소나마다 `/api/dev/login` storageState 저장, Mock으로 로컬 녹색(G1 근거, 8.2절), 052·053 후 스테이징 재실행 | 03장 2절, `AUTH_ROADMAP.md` 4장 |
| NW-06-048 | 결제 E2E(신문사 Toss 테스트 키): 후원·멤버십 성공, 금액 위조, 웹훅 서명 실패, 중복 이벤트 | `tests/e2e/payments/` | NW-06-024 | P1 | M | Fable | 시나리오 4개 녹색, 플랫폼 수수료 계산이 플랜 `news_reader_fee_bps`와 일치 | `DOC_TEMPLATE.md` 2.7절 필수 작업 |
| NW-06-049 | 성능 예산 CI: Lighthouse(템플릿 3종 × 모바일·데스크톱), 광고 슬롯 CLS, ISR 캐시 적중 | `tests/perf/`, `.lighthouserc.json` | NW-06-020, NW-06-021 | P0 | M | Opus | LCP 2.5초·INP 200ms·CLS 0.1 이하(p75 근사), 예산 초과 시 CI 실패 | 01장 5절, 03장 4절 |
| NW-06-050 | 접근성·시각 회귀(MT-16): 템플릿 3종 × 시험 테넌트 3개 × 라이트·다크 | `tests/visual/` | NW-06-020, NW-06-039 | P1 | M | Sonnet | axe 위반 0, 기준 스크린샷 차이 임계값 이하 | `Multi-tenant_Theming/06_ADOPTION_PLAN.md` MT-16 |
| NW-06-051 | 문구 점검: 금지 문구(허위 수치·보장 표현), 법정 문구, 오류 문구, 광고 라벨 표기 일관성 | `scripts/copy-check/` | NW-06-021 | P1 | S | Haiku | 금지 문구 목록 일치 0건, 오류 문구에 원인과 다음 행동 | 01장 6절 |
| NW-06-052 | 인증 Stage B 편집국(8절) | 8.1절 | 8.1절 | P0 | M | Fable | 8.1절 | `AUTH_ROADMAP.md` 5장 |
| NW-06-053 | 인증 Stage B 독자(8절) | 8.1절 | 8.1절 | P0 | M | Fable | 8.1절 | `AUTH_ROADMAP.md` 5장, 01장 D-3·D-15 |
| NW-06-054 | 인증 Stage C1 카카오(8절) | 8.1절 | 8.1절 | P1 | S | Opus | 8.1절 | `AUTH_ROADMAP.md` 7.1절 |
| NW-06-055 | 인증 Stage C2 네이버(8절) | 8.1절 | 8.1절 | P1 | M | Fable | 8.1절 | `AUTH_ROADMAP.md` 7.2절 |
| NW-06-056 | 운영 문서: 배포 체크리스트, 인증 체크리스트, 신문사 온보딩 SOP(매체정보·도메인·이관) | `docs/local-news/ops/` | NW-06-052 | P1 | S | Haiku | 체크리스트 항목이 02장 7·8·9절과 1:1, SOP가 03장 2절 첫 플로우와 같은 순서 | 02장 7절 |

P0 작업과 테스트 대응은 7절 표에 있다.

## 3. 웨이브(병렬 실행 순서)

| 웨이브 | 작업 ID | 병렬 수 | 진입 조건 | 산출물 |
|---|---|---|---|---|
| W0 | 001, 002, 007 | 3 | 없음 | DB 적용, 골격, 디자인 레퍼런스(1단계) |
| W1 | 003, 004, 005, 006, 008, 041 | 6 | W0 | RLS CI, 인증 Stage A, 테넌시 연결, 금지 검사, 토큰·기본 컴포넌트(2단계), AI 서비스 설치 |
| W1-D | 009 → 010(직렬) | 1 | 008 | 사람 비주얼 검토(3단계), 코드 정답 확정(4단계). 화면 작업의 진입 조건 |
| W2 | 011, 017, 042 | 3 | W1 | M1 서버, 개설 신청·승인, AI 게이트 |
| W3 | 012, 014, 015, 020, 022, 037 | 6 | 011, 010 | 에디터·데스크, 미디어, 분류·구성원, 독자 홈 템플릿, 법정 표기, 게시 파이프라인 |
| W4 | 013, 021, 025, 034, 039, 043, 044 | 7 | W3 | 홈 편집, 독자 사이트, 광고, 준수 데스크, 브랜딩·도메인, AI 기사 보조, AI 어시스턴트 |
| W5 | 016, 018, 023, 030, 033, 035, 036, 040, 045 | 9 | W4 | 라이브, 이관, 독자 가입, 제보, 배포·SEO, 검색·분석, 지역 생활, 마케팅 랜딩, 음성 |
| W6 | 019, 024, 026, 027, 028, 031, 032, 038 | 8 | W5 | 내보내기, 독자 결제, 업소·공고, 외부 광고망, 뉴스레터, 댓글, 경조사, 운영 콘솔. 마지막 기능 웨이브 |
| W7 | 052·053(G1 통과 후 먼저), 029, 046, 047, 048, 049, 050, 051 | 9 | W6. 052·053은 `[DECISION] G1 통과` 후 시작하고 047의 스테이징 재실행은 두 작업 완료를 기다린다. G1 근거인 Mock E2E는 047이 W6 종료 직후 로컬에서 먼저 녹색으로 만든다 | Google·이메일 로그인 전환(편집국·독자), 웹 푸시, AI 회귀, E2E, 결제 E2E, 성능·시각 회귀, 문구. 공개 베타 조건 |
| W8 | 056, 054·055(G2 통과 후) | 3 | 공개 베타 후. 054·055는 G2 통과 후 | 운영 문서, 카카오·네이버(독자 P1, 편집국은 01장 D-17) |

같은 웨이브 안에서도 선행 작업 열이 우선한다(예: 023 → 028·031은 다음 웨이브). 모든 작업이 정확히 한 번씩 있고 선행 작업보다 앞 웨이브에 있지 않다(스크립트로 확인, 4절 아래).

## 4. 모델별 비율

| 모델 | 작업 수 | 비율 | 규모 가중(S=1, M=2, L=3) 비율 |
|---|---|---|---|
| Fable | 13 (001, 003, 004, 005, 017, 024, 041, 042, 046, 048, 052, 053, 055) | 23.6% | 27 / 116 = 23.3% |
| Opus | 23 (010, 011, 014, 018, 019, 022, 023, 025, 028, 029, 030, 031, 033, 034, 035, 037, 039, 043, 044, 045, 047, 049, 054) | 41.8% | 54 / 116 = 46.6% |
| Sonnet | 15 (007, 008, 012, 013, 015, 016, 020, 021, 026, 027, 032, 036, 038, 040, 050) | 27.3% | 31 / 116 = 26.7% |
| Haiku | 4 (002, 006, 051, 056) | 7.3% | 4 / 116 = 3.4% |
| 합계 | 55 | 100% | 116 |

비율은 모델 작업 55개 기준이다. 사람 작업 1개(NW-06-009, M)는 뺐다. 이 표는 2절 표의 행을 스크립트로 세어 맞췄다(작업 행 56, 사람 1). Fable은 DB·RLS·인증·테넌트 해석·개설 승인·독자 결제·AI 보안 경계를 맡고, 기능 서버·API·AI 그래프·테스트 설계는 Opus, 독자 사이트·편집국 화면·디자인 시스템은 Sonnet, 골격·린트·문구·운영 문서는 Haiku다(`docs/products/_platform-core/DOC_TEMPLATE.md:27-34`).

## 5. 리뷰 작업 흡수표

해당 없음: 원본 프로젝트와 리뷰가 없는 신규 제품이다(README 3장). 대신 공통모듈 기획서의 열린 질문(`modules/README.md` MQ-1~MQ-7)과 01장 결정을 작업에 흡수한다.

| 항목 | 내용 | 흡수 작업 ID |
|---|---|---|
| MQ-1 | 독자 결제 주문·빌링키 위치(코어 결제는 조직 기준) | NW-06-024, 6절 R-5 |
| MQ-2 | 이벤트 outbox 표 여부 | NW-06-037(1차는 잡 + 주기 재조정) |
| MQ-3 | 금칙어·댓글 설정이 M1 표에 있음 | NW-06-031(해석은 M5), NW-06-015(쓰기는 M1 설정) |
| MQ-4 | `ads` 공용 스키마 번호 | 6절 R-9(추출 시 결정) |
| MQ-5 | 장 사이 이름 불일치 | 해결됨(2026-10-15, 05장 SQL 기준) |
| MQ-6 | 검색 필터(섹션·지역·기간) | NW-06-035, NW-06-001(인자 추가 요청) |
| MQ-7 | 유입 분류 컬럼 | NW-06-035(1차 미제공) |
| D-3 | 독자 로그인 도메인 | NW-06-039(등록 잡), NW-06-053 |
| D-4 | 독자 결제 방식 | NW-06-024 |
| D-6 | 댓글 기본값 | NW-06-031 |
| D-7 | 검색 엔진 | NW-06-035 |
| D-8 | 외부 API | NW-06-036 |
| D-9 | AI 초안 표시·비율 | NW-06-043, NW-06-034 |
| D-10 | 이관 범위 | NW-06-018 |
| D-11 | 3D 히어로 | NW-06-040 |

## 6. 공용 모듈 요청

| ID | 요청 | 대상 | 이유 | 제품의 임시 대응 |
|---|---|---|---|---|
| R-1 | `AUTH_ROADMAP.md` 8장 매트릭스에 `news` 행(편집국: 승인·초대, C P2 / 독자: 공개, B 이메일 매직 링크 + Google, C1·C2 P1) | `_platform-core` | 두 대상의 단계 우선순위가 다르다(01장 2절). 현재는 11장 끝에만 적혀 있다 | 이 제품 01·02·06장을 정본으로 사용 |
| R-2 | 독자 매직 링크 로그인 예외 승인(`AUTH_ROADMAP.md`는 매직 링크를 범위 밖으로 둠) | `_platform-core` | 고령 독자의 비밀번호 부담(01장 D-15) | D-15 결정 전에는 이메일 + 비밀번호로 구현 가능하게 둔다 |
| R-3 | `AUTH_PROVIDERS_READER` 환경변수(호스트 종류별 제공자 목록)를 코어 인증 모듈 규격에 추가 | `_platform-core` | 편집국과 독자의 로그인 수단이 다르다(02장 9절) | 제품 `src/lib/auth/`에 구현 |
| R-4 | Theming `0011` 코어 승격, 서체 레지스트리에 세리프(Noto Serif KR, 본명조, 나눔명조) 추가, 조직당 도메인 상한을 플랜 features로 | `Multi-tenant_Theming` | 이 제품이 첫 판매 적용 제품이다. 신문 제호는 세리프가 기본이다 | 모놀리스 `0002_tenant_theming.sql` 변환본, 엔터프라이즈 도메인 5 |
| R-5 | 코어 결제에 "지불 주체 = 독자, 수취 = 신문사 자기 가맹" 확장 또는 독자 결제 표준 | `_platform-core` | 코어 `payment_orders`는 조직이 플랫폼에 내는 돈 기준(MQ-1, D-4) | M2 표에 주문 id·상태, 빌링키는 `core.encrypted_credentials` |
| R-6 | 모듈러 통합 `seed.sql`에 `news` 앱·플랜·라우팅 행 | `_supabase-modular/seed.sql` | 지금은 조각이 `on conflict do nothing`으로 넣는다 | 조각 안 `@@MODULAR_ONLY` 절 |
| R-7 | `REFERENCES.md`에 local-news 절, `HERO_3D.md`에 local-news 행(독자 사이트 미적용) | `_design-guide` | 03장 4절 레퍼런스가 뉴스 벤치마크라 기존 목록에 없다 | 03장 4절에 출처 직접 기재 |
| R-8 | `COMMON_MODULES_ROADMAP.md` notify 추출 시 M4 뉴스레터·푸시를 기준 구현으로 | `_platform-core` | 두 번째 제품이 쓰면 공용화(2장 원칙) | M4는 `news` 스키마 안 |
| R-9 | 광고 모듈(M3) 공용 스키마 번호 범위 | `_platform-core` | 해결(2026-10-15): `ads` 0650(`common-modules/README.md` 2장) | - |
| R-10 | 네이버 브리지를 택하면 `staged/0010_core_auth_identity_links.sql` 적용 | `_platform-core` | `AUTH_ROADMAP.md` 7.2.3절 | 독자 C2는 `supabase_custom` 우선(02장 9절) |
| R-11 | 공용모듈 7개(compliance, media, editorial, community, search, membership, ads) v1.0 출시 후 local-news 전환 | `_platform-core/common-modules/`, `develop/_shared/modules/` | M1~M8 제품 무관 부분을 공용으로 정의함(2026-10-15) | 1차는 `news` 스키마, 이름·계약은 공용 기획서와 같은 뜻으로 |

## 7. 완료 정의

| 조건 | 명령/기준 |
|---|---|
| 빌드·타입·린트 | `pnpm -r build`, `pnpm -r typecheck`, `pnpm lint` 오류 0 |
| SQL | 05장 9절 체커 명령 5개 OK(모듈러 2회 적용, Theming 없이, 전 조각, 모놀리스 재적용) |
| RLS 스모크 | `node supabase/monolith/tests/run-smoke.mjs --target mono`·`--target mod` 각 PASS=314 FAIL=0, 실 Supabase 재검증 |
| E2E | NW-06-047 녹색(Mock 로컬, 스테이징 B 구성) |
| 결제 E2E | NW-06-048 시나리오 4개(신문사 Toss 테스트 키) |
| AI·음성 | NW-06-046 녹색, 사람 승인 없는 게시 0, AI 표시 누락 0, `store_audio=false` 100% |
| 성능 | NW-06-049: LCP ≤2.5초, INP ≤200ms, CLS ≤0.1(템플릿 3종 × 모바일·데스크톱) |
| 법정 표기 | 필요적 게재사항 미완성 시 공개 차단, 청소년보호책임자 첫 화면 표시, 기사형 광고 라벨 100%, 정정 청구 기한 고정, 자체기사 비율 대시보드 동작 |
| 디자인 시스템 | 4단계(NW-06-010) 완료, hex 하드코딩 0, `tailwind.config.js` 0 |
| 인증 | G1·G2 판정 기록(8.2절), 052·053 수용 기준 통과 |
| 작업 | 2절 P0·P1 작업 완료(054·055는 G2 이후라 공개 베타 완료 정의에서 제외) |

| P0 작업 | 대응 테스트 |
|---|---|
| 001, 004, 005, 017 | 003(RLS 314), 047 |
| 011, 012, 013, 014, 015, 021, 022, 037 | 047, 049 |
| 020 | 049, 050 |
| 023, 028, 030, 034 | 047, 003 |
| 025, 033, 035 | 047, 049 |
| 039 | 050, 047 |
| 041, 042, 043, 044, 045 | 046 |
| 002, 006 | CI 자체 |
| 007~010 | 디자인 시스템 4단계 문서-코드 일치 검사, 009는 사람 기록 |
| 052, 053 | 047 스테이징 재실행, 수동 점검표(B-5) |

## 8. 인증 단계 작업 (2026-10-15, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md`(9장 작업 계획 반영 규칙)와 이 제품 01장 2·3·8.1절, 02장 9절, 04장 8절, 05장 10절이다. 이 제품은 로그인 대상이 둘이다: 편집국(승인·초대, `newsroom.<플랫폼>`)과 독자(공개, 신문사 도메인). Stage A는 NW-06-004(편집국 로그인 화면)와 NW-06-023(독자 로그인 화면)이 맡고, 아래 4개를 더한다.

### 8.1 작업 상세

| ID | 작업 | 소유 파일/디렉토리 | 선행 작업 | 우선순위 | 규모 | 권장 모델 | 수용 기준 |
|---|---|---|---|---|---|---|---|
| NW-06-052 | Stage B 편집국: Google + 이메일·초대 메일, `/auth/callback` 편집국 분기(`session_context` + staff 역할), 첫 OAuth 로그인 약관 단계, 배포 체크리스트(Google 콘솔·Supabase Providers·Redirect URLs) | `src/app/(auth)/`(004에서 이어 받음), `src/app/auth/`, `src/lib/auth/providers/google.ts` | NW-06-004. 진입 조건 G1 | P0 | M | Fable | `AUTH_ROADMAP.md` 5.3절 B-1~B-6. B-1은 invite 앱 해석: 초대 없는 새 Google 계정 → staff 0 → 개설 신청 안내, 초대받은 이메일 → `accept_staff_invite`. B-2 `next` 공격 문자열 → 기본 경로. B-4 배포 빌드에서 `/api/dev/login` 404 |
| NW-06-053 | Stage B 독자: 이메일(D-15 결정 방식) + Google, 독자 로그인 화면 B 구성, 호스트별 제공자 허용 검사(`error=provider`), `/account/welcome`에서 `ensure_reader`(동의·만 14세), 커스텀 도메인 Redirect URL 등록(D-3 (a), 039 도메인 워커에 1줄 요청) | `src/app/(reader)/_t/[host]/login/`(023에서 이어 받음), `src/lib/auth/reader/` | NW-06-023, NW-06-039. 진입 조건 G1 | P0 | M | Fable | 새 Google 계정 첫 로그인 → 동의 화면 → `news.readers` 1행, 조직 멤버 0. 다른 신문 도메인에서 같은 계정 → 그 신문 독자 행 별도 생성. 등록되지 않은 도메인의 콜백 → 서브도메인으로 대체 후 안내. B-2·B-3·B-6 |
| NW-06-054 | Stage C1 카카오(독자 P1, 편집국은 01장 D-17 결정 시만): 버튼(카카오 디자인 가이드), 설정 → 로그인 방법 | `src/lib/auth/providers/kakao.ts`, `src/modules/reader-membership/login-methods/`(023에서 이어 받음) | NW-06-053. 진입 조건 G2, 01장 D-13 | P1 | S | Opus | `AUTH_ROADMAP.md` 7.1.3절 C1-1~C1-5. 독자 해석: C1-1 새 카카오 계정 → 독자 가입 화면, C1-3 (b)면 뉴스레터·결제 전 연락 이메일 입력 |
| NW-06-055 | Stage C2 네이버(독자 P1): 스파이크 → `custom:naver`(권고) 또는 브리지, 네이버 검수 자료 | `src/lib/auth/providers/naver.ts`, `scripts/auth/`, `docs/local-news/ops/naver-review/` | NW-06-053. 진입 조건 G2, 01장 D-14 | P1 | M | Fable | `AUTH_ROADMAP.md` 7.2.4절 C2-1~C2-6. 브리지는 중앙 로그인 도메인(D-3 (b))이 있어야 하므로 (a) 경로에서는 `supabase_custom`만 |

### 8.2 게이트와 웨이브

| 게이트·웨이브 | 작업 | 진입 조건 | 판정 |
|---|---|---|---|
| Stage A | NW-06-004(W1), NW-06-023(W5) | 004 앞 웨이브(W0) 작업은 시드 없이 SQL·단위 테스트로 검증 | - |
| G1 | - | `AUTH_ROADMAP.md` 4장을 이 제품에 맞춘다. 1) 2절 P0 기능 작업 완료(W6까지, B·C와 W7 통합 작업 제외) 2) NW-06-047 Mock E2E 로컬 녹색 3) NW-06-003 RLS 314 + `outsider`·`reader_other` 격리 4) 결제 E2E는 독자 결제가 P1이라 G1 조건에서 빼고 공개 베타 전 NW-06-048로 확인 5) 단계 분기 코드가 인증 모듈 밖 0건(NW-06-006) 6) Google Cloud 로그인 프로젝트·동의 화면(플랫폼 브랜드, `develop/_shared/auth/README.md` AUTH-D1), 운영 Supabase 프로젝트 | 사람(대표님)이 task `log.md`에 `[DECISION] G1 통과` |
| Stage B | NW-06-052, NW-06-053 | W7 맨 앞. 047의 스테이징 재실행은 두 작업 완료를 기다린다 | - |
| G2 | - | `AUTH_ROADMAP.md` 6장: 공개 베타 2주(제안), 인증 P0·P1 장애 0, `/auth/callback` 오류율 1% 미만(제안), 독자 가입 후 `readers` 행 누락 0, 카카오 비즈 앱 전환(D-13), 네이버 애플리케이션 등록·검수 자료 | 사람이 `[DECISION] G2 통과` |
| Stage C | NW-06-054, NW-06-055 | W8, G2 후. 병렬 가능 | - |

### 8.3 달라진 점

| 항목 | 내용 |
|---|---|
| 대상 2개 | 다른 제품과 달리 B·C를 편집국과 독자로 나눴다. 독자 카카오·네이버가 P1(지역 독자 핵심), 편집국은 P2 선택(D-17) |
| 로그인 화면 소유 | 편집국 `(auth)/`는 004 → 052, 독자 `login/`은 023 → 053이 이어 받는다(웨이브가 달라 동시 쓰기 없음) |
| 공용 파일 요청 | 004: `MOCK AUTH · 로컬 전용` 배지 장착은 `src/app/layout.tsx`(005)에, `db:seed-users` 스크립트는 `package.json`(002)에 1줄 요청. 053: 도메인 활성 시 Redirect URL 등록 잡은 039 워커에 1줄 요청 |

## 9. 멀티테넌트(Theming) 적용 작업

`Multi-tenant_Theming/06_ADOPTION_PLAN.md`의 MT 작업과 이 제품 작업의 대응이다. 코어 쪽(테넌트 SQL 승격, `core-tenancy` 패키지)은 6절 R-4로 요청하고, 이 제품은 모놀리스 변환본과 제품 어댑터로 먼저 동작시킨다.

| MT 작업 | 내용 | 이 제품 작업 | 비고 |
|---|---|---|---|
| MT-01 | 테넌트 마이그레이션·타입 | NW-06-001 | 모놀리스 `0002_tenant_theming.sql` |
| MT-02 | 토큰 3계층, 하드코딩 색 제거 | NW-06-008, NW-06-006 | 서체 프리셋에 세리프 추가(R-4) |
| MT-03~05 | core-tenancy 연결, proxy 판별, 레이아웃·메타 | NW-06-005 | 실패 시 플랫폼 기본 테마 대신 오류 화면(02장 10절) |
| MT-06~09 | 자산 업로드, 팔레트·대비, 브랜딩 화면, 고객센터·푸터 | NW-06-039, NW-06-022 | 법정 푸터는 테넌트 설정이 아니라 `news.newspapers`(M7) |
| MT-10~11 | 라벨·메뉴 | 해당 없음(1차) | 편집국 메뉴는 플랜 기능으로만 숨김 |
| MT-12 | 커스텀 도메인 | NW-06-039 | 독자 로그인 Redirect URL 등록 추가(D-3) |
| MT-13 | 기능 오버라이드 운영 화면 | NW-06-038 | |
| MT-14~15 | 슬롯·훅(L3/L4) | 해당 없음(엔터프라이즈 건별) | |
| MT-16 | E2E·시각 회귀 | NW-06-050 | |
