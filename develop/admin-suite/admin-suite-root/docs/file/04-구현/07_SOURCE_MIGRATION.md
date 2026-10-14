# 07 원본 이식과 폐기: Admin Suite

원본 폴더는 수정하지 않는다. 읽기는 파일 열람과 `git show <커밋>:<경로>`만 쓴다.

AI 관련 원본 자산(2026-10-13 점검): 세 원본 모두 AI 기능이 없다(`docs/reference/reviews/ERP-Wesite.md:20`, `docs/reference/reviews/Hospital.md:14`, `docs/reference/reviews/School_Management_System.md:14`가 "AI 없음"). RAG, 위키, Dify, 음성, LangGraph는 원본에 없어 모두 신규이며 이식 대상이 없다. 아래 1절 끝의 "AI 관련" 표가 그 대응이다. 원본 CLAUDE.md·PRD의 AI 언급은 없어 폐기 항목도 없다.

## 1. 원본별 자산 분류

### 1.1 ERP-Wesite

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `supabase/migrations/001_initial_schema.sql` 테이블 정의 | 부분 | 참고(스키마 재작성) | `1600_erp.sql` | `docs/reference/reviews/ERP-Wesite.md:57` |
| 같은 파일 RLS 정책 | 결함 | 폐기 | - | `:65-66` |
| `app/actions/inventory.ts`, `sales.ts` | 부분(비원자) | 참고(RPC로 교체) | `apps/erp/src/server/` | `:68` |
| `app/actions/hr.ts` | 부분 | 참고 | `apps/erp/src/server/hr.ts` | `:39` |
| `app/actions/logs.ts` | 부분 | 폐기(감사 로그 화면으로 대체) | admin-kit audit | `analysis:1138` |
| `components/{inventory,sales,hr,dashboard}/*Client.tsx` | 동작 | 이식(모달 분리, admin-kit UI로 교체) | `apps/erp/src/app/(app)/*` | `:54`, `:107` |
| `components/settings/SettingsClient.tsx` | 목업 | 폐기(현재 내용) | - | `:72-73` |
| `components/layout/{Sidebar,Header}.tsx` | 동작 | 참고(AppShell로 흡수) | admin-kit ui | `analysis:1145` |
| `app/(dashboard)/{inventory,sales,hr,settings}/page.tsx` | 중복 | 폐기 | - | `:74` |
| `middleware.ts`, `lib/supabase/*` | 부분 | 폐기(admin-kit 흡수) | - | `analysis:1223` |
| `types/index.ts` | 수기 | 폐기(생성 타입) | - | `:106` |
| `PRD.md`, `UI DESIGN.md`, `ERP-Website.pen` | 기획 | 참고 | 01장, 03장 | - |
| `ERP_Website/`(gitlink) | 빈 저장소 | 폐기 | - | `:9`, `:83` |

### 1.2 Hospital

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `src/proxy.ts` | 부분 | 참고(골격만, 역할 기본값 제거) | admin-kit auth | `docs/reference/reviews/Hospital.md:56` |
| `src/lib/permissions.ts` | 동작 | 이식(형태만, 서버 강제) | `apps/hms/src/access.ts` | `analysis:1131` |
| `src/lib/lab-ranges.ts` | 동작 | 이식(seed `lab_test_catalog`) | `hms/seed.sql` | `:34` |
| `src/hooks/use-realtime-queue.ts`, `components/queue/*` | 동작(이중 구독) | 이식(단일 구독으로) | `apps/hms/src/app/(app)/queue/` | `:61` |
| `src/app/(dashboard)/calendar/*` | 부분 | 이식(범위 조회, 주말, 슬롯 예약 추가) | `apps/hms/.../calendar/` | `:63`, `:75` |
| `src/app/(dashboard)/patients/*` | 부분 | 이식(성별, 타임라인 실데이터) | `apps/hms/.../patients/` | `:65` |
| `src/app/(dashboard)/lab/*` | 동작 | 이식(검증·승인 추가) | `apps/hms/.../lab/` | `:68` |
| `components/dashboard/*` 차트 | 목업 | 참고(레이아웃만) | `apps/hms/.../dashboard/` | `:64` |
| `components/layout/with-page-guard.tsx`, `page-guard.tsx` | 결함 | 폐기 | - | `:54` |
| `src/app/api/auth/verify-admin/route.ts`, `OVERRIDE_PASSWORD` | 결함 | 폐기 | - | `:55` |
| `src/components/ui/`(shadcn 10개), zustand | 미사용 | 폐기 | - | `:71` |
| `src/types/supabase.ts`(수기) | 수기 | 폐기 | - | `:67` |
| `PRD.md`, `CLAUDE.md`, `Design_UI.md` | 기획 | 참고 | 01장, 03장 | - |

### 1.3 School_Management_System

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| HEAD `3c19d1e`: `src/lib/actions.ts` | 동작 | 이식(RPC/정책으로, `requireRole` + zod) | `apps/sms/src/server/roster.ts` | `docs/reference/reviews/School_Management_System.md:67` |
| HEAD: `src/app/admin/attendance/page.tsx` | 동작 | 이식 | `apps/sms/.../admin/attendance/` | `:67` |
| HEAD: `src/app/admin/{classes,subjects,students,settings}` | 동작 | 이식(students → members) | `apps/sms/.../admin/*` | `:39` |
| HEAD: `src/app/student/{layout,dashboard}` | 동작 | 이식 | `apps/sms/.../student/` | `:58` |
| 작업 트리 `src/app/admin/dashboard/page.tsx` | 부분 | 이식(분모 통일, RPC화) | `apps/sms/.../admin/dashboard/` | `:55` |
| `src/components/realtime/*` | 동작/미사용 | 이식(부분 갱신, 학생 알림 연결) | `apps/sms/...` | `:22`, `:59` |
| 루트 `middleware.ts` | 미로드 | 폐기(로직은 access.ts로) | - | `:48` |
| `src/components/ui/Sidebar.tsx` 이모지 | 동작 | 폐기(lucide) | - | `:62` |
| `CLAUDE.md` RLS 예시 | 결함 | 폐기 | - | `:49` |
| `PRD.md`, `Design_UI.md`, `.pen` | 기획 | 참고 | 01장, 03장 | - |

### 1.4 AI 관련 (2026-10-13)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| 원본 3개의 AI 코드·설정·프롬프트 | 없음 | 해당 없음(전부 신규) | `packages/admin-kit/src/ai/`, `apps/api/` | 위 세 리뷰의 "AI 없음" |
| Hospital `src/lib/permissions.ts` 역할 → 페이지 매트릭스 형태 | 동작 | 이식(형태만): AI 컬렉션 접근도 같은 방식(역할 → 컬렉션 매핑 `collections.json`)으로 선언하되 판정은 서버가 DB 역할로 한다 | `packages/admin-kit/src/ai/collections.json` | `analysis:1131`, 01장 3.7절 |
| 원본 기획 문서(PRD, 업무 매뉴얼류)의 업무 규칙 문장 | 기획만 | 참고: 고객사 규정·매뉴얼 샘플 문서로 쓰지 않는다(실데이터 금지). 평가셋 샘플은 개인정보 없는 공개 지침·가상 규정으로 새로 쓴다 | `apps/api/tests/admin/eval/` | ADM-06-056 |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| ERP 화면 Client 컴포넌트 | 400줄 파일에서 모달 분리(`ProductFormModal`, `InventoryMoveModal`, `NewSaleModal`, `PermissionModal`), `revalidatePath` 대신 Server Action 반환 + `router.refresh`, 상태 가짜 생성 제거, ADJUSTMENT 부호 표시 |
| ERP 서버 액션 | 쓰기를 `erp.record_*`/`cancel_sale` RPC 호출로 교체, 첫 줄 `requireRole`, 클라이언트 금액 미사용 |
| Hospital permissions | `ROLE_ACCESS`를 `defineAccess`로 옮기고 proxy와 사이드바가 같은 매트릭스를 쓴다. 기본 역할 없음 |
| Hospital 대기열 훅 | 페이지에서 1회 호출, org 필터, payload로 부분 갱신, 상태 변경은 `transition_appointment` |
| Hospital lab 입력 | `parseFloat` 실패 시 0 대체 제거, 저장은 `save_lab_result`, 이탈 판정은 서버 결과 표시(클라이언트 즉시 표시는 보조) |
| Hospital 환자 상세 | 민감 항목은 `GET /api/hms/patients/:id`(서버 복호화, 접근 기록), 차트는 doctor 전용 경로 |
| School HEAD 액션 | `setStudentRole`(프로필 role 직접 update)은 폐기하고 `sms.set_member_role` RPC, `assignStudentClass`는 `sms.assign_class` |
| School 출석 보드 | upsert를 `mark_attendance_bulk`로, 상태 리터럴을 한글에서 코드(present/late/early_leave/absent)로, 채널명 `sms:<org>:attendance` |
| School 학생 대시보드 | 이번 달 통계를 `sms.student_summary`로, `RealtimeStudentNotif` 연결 |
| lab-ranges | 정상 범위 수치는 원본 그대로 seed로 옮겼다. 임상 검증 전 "참고 범위"로 표기 |
| 원본 Tailwind 설정 (2026-10-13) | 원본 세 앱의 `tailwind.config.*`와 v3 문법(`@tailwind base` 등)은 이식하지 않는다. 토큰은 Tailwind CSS v4 `@theme`로 새로 쓴다(`apps/<app>/src/theme/tokens.css`, ADM-06-042) |
| 원본 UI 컴포넌트 (2026-10-13) | 앱 코드 안 hex 색을 `tokens.css` 의미 기반 변수로 바꾼다. 기본 컴포넌트는 admin-kit `ui/`에서 한 번만 만든다(4단계 완료 뒤 화면 이식, ADM-06-044) |

## 3. 폐기 목록과 사유

분석 "폐기" 분류(`analysis:1132`, `:1133`, `:1151`, `:1152`, `:1170`, `:1190`)와 "버려지는 것"(`analysis:1216-1224`) 전부다.

| # | 폐기 항목 | 사유 | 근거 |
|---|---|---|---|
| 1 | Hospital 클라이언트 PageGuard(`with-page-guard.tsx`, `page-guard.tsx`) | 잠금 상태에도 RSC 페이로드가 전송되고 DevTools로 우회된다. 서버 가드로 대체 | `analysis:1132`, `:1218` |
| 2 | Hospital 비밀번호 임시 접근(OVERRIDE 1234) | 공유 4자리로 모든 역할 우회 | `analysis:1133`, `:1218` |
| 3 | Hospital verify-admin API | 위 우회의 서버 측 구현, 시도 제한·감사 없음 | `analysis:1218` |
| 4 | ERP 중복 라우트 4개(`/inventory`, `/sales`, `/hr`, `/settings`) | 바이트 단위 중복이고 가드 밖 | `analysis:1170`, `:1219` |
| 5 | ERP 미사용 조회 액션(`getProducts`, `getProfiles`, `getSalesTransactions`, `getTodaySalesTotal`) | 호출되지 않는 이중 조회 경로 | `analysis:1219`, `docs/reference/reviews/ERP-Wesite.md:81` |
| 6 | ERP 설정 화면 현재 내용 | 저장 안 되는 목업, 실 Supabase URL·anon key 노출. 코어는 계정 정보만 | `analysis:1151`, `:1219` |
| 7 | ERP 헤더 검색과 알림 벨 | 무동작 장식 | `analysis:1152`, `:1220` |
| 8 | Hospital 미사용 shadcn 10개, zustand | import 0건, admin-kit UI로 대체 | `analysis:1221` |
| 9 | Hospital `as any` 20건 | 타입 안전성 0, 생성 타입으로 대체 | `analysis:1221` |
| 10 | School 루트 `middleware.ts` | 위치 때문에 로드되지 않는 코드 | `analysis:1222` |
| 11 | School 이모지 아이콘 | lucide로 교체 | `analysis:1190`, `:1222` |
| 12 | 각 앱의 자체 Supabase 클라이언트, 가드, 날짜 코드 | admin-kit로 흡수(편차 재발 방지) | `analysis:1223` |
| 13 | ERP `ERP_Website` gitlink, Hospital/School nested git 이중 추적 | 모노레포로 정리 | `analysis:1224` |

AI 계층·디자인 시스템 도입(2026-10-13)으로 생긴 추가 폐기. 분석 목록 밖이라 따로 번호를 붙인다(위 13개는 그대로).

| # | 폐기 항목 | 사유 | 근거 |
|---|---|---|---|
| A-1 | 원본의 Tailwind v3식 설정 파일과 문법 | 모든 앱을 Tailwind CSS v4로 통일한다. 설정이 둘이면 AI가 v3로 만든다 | `docs/file/03-설계/디자인/DESIGN_SYSTEM.md:23`, `:67` |

## 4. 복사 금지 결함

`SECURITY_BASELINE.md` 14장 중 해당 항목 + 리뷰에서 찾은 제품 고유 결함.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| OVERRIDE 비밀번호로 전 역할 우회, verify-admin API | `Hospital/src/app/api/auth/verify-admin/route.ts:6-9` | 의료 데이터 전면 노출 | 역할 변경 RPC + 감사, 금지 env 기동 검사 |
| 프로필 없으면 admin, 클라이언트 PageGuard | `Hospital/src/proxy.ts:57`, `:69` | 권한 상승, RSC 노출 | `createAdminProxy`(프로필 없음 로그아웃) |
| RLS 정책 안 자기참조 재귀 + 권한 상승 | `ERP-Wesite/supabase/migrations/001_initial_schema.sql:76-89`, `School_Management_System/CLAUDE.md:80-87` | 42P17 전면 장애 또는 셀프 상승 | DEFINER 헬퍼 + 역할 테이블 쓰기 차단 |
| `FOR ALL` 정책 | 같은 파일 `:83`, `:100`, `:117` | 의도치 않은 쓰기 허용 | 연산별 정책 + `with check` |
| 브라우저 anon key 직접 update(상태, 가용, 검사값) | `Hospital/src/app/(dashboard)/queue/queue-client.tsx:35-37`, `lab/lab-client.tsx:95-100` | 임의 레코드 변조 | RPC + guard 트리거 |
| 읽기-계산-쓰기 재고 차감 | `ERP-Wesite/app/actions/sales.ts:20-43` | 동시성 손실, 음수 재고 | 조건부 UPDATE RPC |
| 가짜 판매 상태, 하드코딩 KPI | `ERP-Wesite/components/sales/SalesClient.tsx:174-175`, `Hospital/src/app/(dashboard)/dashboard/page.tsx:69-71` | 장애를 mock으로 숨김(`SECURITY_BASELINE.md` 11장) | 실데이터 RPC, 빈 상태 표시 |
| UTC 날짜 문자열로 "오늘" 계산 | `toISOString().split("T")[0]` 3앱 공통 | KST 00~09시 누락 | `kstDayRange`, SQL KST 경계 |
| 루트 middleware(미로드) | `School_Management_System/middleware.ts` | 가드 0 | `src/proxy.ts` + 빌드 확인 |
| 빈 값 0 대체 저장 | `Hospital/src/app/(dashboard)/lab/lab-client.tsx:66` | 거짓 검사값 | 숫자 필수 검증(HM004) |
| 실 URL·키 화면 노출 | `ERP-Wesite/components/settings/SettingsClient.tsx:232-241` | 정보 노출 | 표시 금지 |
| 실키가 든 `.env` 커밋 위험, `.gitignore` 삭제 | `docs/reference/reviews/School_Management_System.md:50` | 키 유출 | 루트 `.gitignore`, `.env.example`, 키 재발급 |
| `as any` 캐스팅 | `docs/reference/reviews/Hospital.md:67` | 타입 우회 | 생성 타입 |
| LLM·음성 키를 브라우저·Vercel(hms는 어디에도)에 두기 | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:299` | 키 유출, 비용 남용 | LLM 키는 `api-shared` 전용, ElevenLabs 키와 토큰 개인키는 erp·sms Next.js 서버 전용, hms는 상용 키 자체가 없다 |
| 브라우저에서 Dify·FastAPI·AI 제공자 직접 호출 | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:299` | 인증·한도 우회 | `/api/ai/*`, `/api/voice/*` |
| Dify 입력에 토큰·org·역할·개인정보 | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md:285` | Dify 로그에 평문으로 남음 | 대화 매핑(`platform_conversation_id`, `dify_user`)만 |
| 요청 본문·토큰 클레임의 역할을 믿고 문서 접근 판정 | 제안 | 클라이언트가 역할을 위조해 제한 문서 열람 | FastAPI가 DB에서 역할을 직접 확인(02장 5.3절) |
| 전체 컬렉션 검색 후 결과 필터링 | 제안 | 허용 밖 청크가 서버 메모리·로그에 올라옴 | 허용 컬렉션마다 `match_ai_chunks`(컬렉션 id 지정) |
| `ai_runs`·`ai_run_steps`에 질문·답변·청크 본문 저장 | `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/0008_core_ai.sql:623-633` | 코어 RLS가 구성원 전원에게 SELECT를 열어 둠 | id, 개수, 상태만(02장 5.3절 8항) |
| 제한 컬렉션 문서로 위키 생성 | 같은 정책 | 위키 본문이 구성원 전원에게 보임 | "위키 대상" 컬렉션만(01장 3.7절), 코어 개정 R-14 |
| hms에서 상용 API·공용 AI 서버·공용 Dify 사용, 장애 시 대체 | 사용자 결정 2026-10-13 | 진료 관련 정보의 외부 반출 | 전용 서버만, 대체 없이 실패, 금지 변수 기동 검사 |
| 환자 식별정보를 질문·문서로 AI에 보내기 | 01장 6.6절 | 의료정보 유출 | 입력 차단(`AI_PHI_BLOCKED`), 문서 반입 탐지, 환자 테이블 비접근 |
| 클라이언트가 보낸 임의 텍스트를 TTS | 제안 | 음성 생성 남용 | DB의 assistant 메시지만 낭독 |
| 설정 파일 없이 "Tailwind로"만 지시해 v3 설정 생성 | `docs/file/03-설계/디자인/DESIGN_SYSTEM.md:23` | v3 설정 혼입 | 지시와 문서에 Tailwind CSS v4 명시, `tailwind.config.js` 금지(린트) |
| 3D 라이브러리를 업무 앱에 추가 | `docs/file/03-설계/디자인/HERO_3D.md:92` | 번들 증가, 업무 효율 저해 | 적용 제외(03장 4.5절), import 금지 린트 |

## 5. 아카이브 절차

| 단계 | 작업 |
|---|---|
| 1 | 모노레포에 `apps/erp`, `apps/hms`, `apps/sms` 이식 완료 후 원본 3개를 `archive/ERP-Wesite`, `archive/Hospital`, `archive/School_Management_System`으로 이동(읽기 전용, 빌드 대상 제외) |
| 2 | School은 이동 전에 nested 저장소 HEAD `3c19d1e`를 기준으로 보관(작업 트리 변경분은 별도 패치 파일로 보존). 작업 트리 삭제가 의도였는지 원작성자 확인 |
| 3 | nested `.git`(Hospital, School)과 ERP `ERP_Website` gitlink 제거, 상위 저장소 하나로 추적 |
| 4 | 키 재발급: 세 앱의 `.env.local`에 있던 Supabase anon key, Hospital `OVERRIDE_PASSWORD`는 폐기하고 새 프로젝트 키를 발급 |
| 5 | `.pen` 디자인 파일은 `archive/design/`로 이동, 중복 사본 정리 |

## 6. 인증 단계 관련 복사 금지 (2026-10-14 추가, 확정 결정 22)

4절 표에 이어서 본다. 허용되는 Mock은 `docs/file/03-설계/공용코어/AUTH_ROADMAP.md` 2장(로컬 Supabase 시드 계정으로 실제 JWT, `isMockAuthAllowed()` 가드, 배포 환경 404, 05장 10절 페르소나)뿐이다. 원본 3개의 로그인·콜백 코드는 이식하지 않고 admin-kit `src/auth/`(ADM-06-007, 058)로 새로 만든다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 로그인 화면의 역할 선택 UI와 클라이언트 역할 일치 검사(프로필이 없으면 고른 역할을 신뢰) | `Hospital/src/app/(auth)/login/page.tsx:66-76`(`docs/reference/reviews/Hospital.md:60`) | 사용자가 고른 역할로 홈·메뉴가 정해져 권한이 위조된다 | 역할은 DB(`my_role`)에서만. 개발 중 역할 전환은 Mock 페르소나를 바꿔 다시 로그인(05장 10절) |
| 콜백 라우트가 사용자 세션으로 profiles를 직접 INSERT(역할 `Staff`, 상태 `Pending` 기본값) | `ERP-Wesite/app/api/auth/callback/route.ts:28-41`(`docs/reference/reviews/ERP-Wesite.md:49`, 5장 #2) | 이메일 가입자는 콜백을 거치지 않아 프로필이 없고, 콜백 경로마다 기본 역할이 생긴다. 클라이언트 권한으로 프로필·역할 행을 만들면 역할 위조 경로가 되고 코어 가입 트리거와 이중 생성된다 | 코어 가입 트리거 + `finishLogin`의 `bootstrap_app_for_org('erp')`(활성 기관 구성원에게는 호출 0, 04장 8.2절 3번) |
| `signUp`에 `full_name`·`signup_app` 미전달 | `ERP-Wesite/app/(auth)/login/page.tsx:49`(`docs/reference/reviews/ERP-Wesite.md:69`) | 프로필·엔타이틀먼트 누락 | ADM-06-058의 `signUp({ options: { data: { signup_app: 'erp', full_name } } })` |
| UI 없는 OAuth 콜백 남겨 두기 | `Hospital/src/app/api/auth/callback/route.ts`(`docs/reference/reviews/Hospital.md:38`) | hms는 Google을 쓰지 않는데(01장 D-21) 열린 코드 교환 경로가 남는다 | hms 콜백은 058이 admin-kit 팩토리로 새로 두고 `AUTH_PROVIDERS=email` 외 값은 기동 실패(02장 9.3절) |
| 쿠키 역할 Mock(`mock-auth.ts`, `nomad_role`, `nomad_plan` 쿠키, localStorage 역할·플랜) | `D:/WorkSpace/platform/docs/products/nomad-blog/07_SOURCE_MIGRATION.md`, `D:/WorkSpace/platform/docs/products/nomad-commerce/07_SOURCE_MIGRATION.md`(다른 제품 원본, `AUTH_ROADMAP.md` 1장) | 권한 위조, 프로덕션 노출. 이 제품 원본에는 없지만 재발명을 막으려고 둔다 | `AUTH_ROADMAP.md` 2장 Mock 로그인(ADM-06-007), CI 금지 문자열(ADM-06-039) |
| 콜백 `next` 무검증 연결(`${origin}${next}`), 요청 URL에서 origin 계산 | `AUTH_ROADMAP.md` 3.2절 5번, `docs/file/03-설계/공용코어/SECURITY_BASELINE.md` 17장, `ERP-Wesite/app/api/auth/callback/route.ts:6`, `:42` | 외부 리다이렉트, Host 헤더 조작으로 피싱 | `finishLogin` 화이트리스트(`/`로 시작, `//`·`@`·`\` 없음), origin은 `NEXT_PUBLIC_APP_URL` 고정 |
| 기능 코드의 `if (mock)`·페르소나 이메일(`@dev.test`) 분기 | `AUTH_ROADMAP.md` 0장 불변 조건, 2.5절 | 단계 전환 때 권한 경로가 달라진다 | 단계 분기는 admin-kit `src/auth/`와 앱의 `api/dev/login/`·`auth/callback/`·`(auth)/`에만(02장 9.2절) |
| 앱마다 다른 콜백 경로(ERP `/api/auth/callback`, School `/auth/callback`)와 오류 코드(`auth_callback_failed`) | `ERP-Wesite/app/(auth)/login/page.tsx:35`, `ERP-Wesite/app/api/auth/callback/route.ts:46`, `School_Management_System/src/app/login/page.tsx:33` | Supabase Redirect URLs와 오류 화면이 앱마다 달라지고, 콜백 처리가 admin-kit 밖에서 따로 자란다 | 3앱 공통 `GET /auth/callback`(admin-kit 팩토리 re-export, 04장 8.2절), 실패는 `/login?error=callback`(04장 8.4절), 토큰·코드 미기록 |
| `dev-user`·고정 사용자 id 우회, 원격 DB에 개발 계정 생성, hms 개발 환경에 실제 환자 데이터 | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md` 14장, 17장, 05장 10.4절 | 인증 우회, 운영 데이터 오염, 의료정보 유출 | 시드 스크립트는 루프백 Supabase만(원격이면 exit 1), hms 훅은 환자 행을 만들지 않는다 |
| hms에 Google·카카오·네이버 버튼 추가 | 01장 8.1절 D-21, `AUTH_ROADMAP.md` 8장 | 병원 직원 계정을 외부 개인 계정에 묶음(정책 미확인) | hms는 초대 메일 + 이메일 로그인만(D-21 (b) 확정 전), C단계 제외 |
