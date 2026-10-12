# CLAUDE.md: Floria (website-floria)

## 1. 먼저 읽을 문서

1. `docs/products/_platform-core/`의 `CORE_SPEC.md`, `SHARED_MODULES.md`, `SECURITY_BASELINE.md`, `DB_CONVENTIONS.md`, `DOC_TEMPLATE.md`, `MONOLITH_CORE_LITE.sql`
2. 이 폴더의 `01_PRD.md` ~ `07_SOURCE_MIGRATION.md`. 작업 전에 `06_AGENT_PLAN.md`에서 자기 작업 ID와 소유 디렉터리를 확인한다.

## 2. 절대 규칙

- `SUPABASE_SERVICE_ROLE_KEY`는 서버 전용이다. `NEXT_PUBLIC_` 접두사 금지, 관리자 클라이언트는 서버 파일에서만 import한다.
- 방문자 쓰기는 `src/app/api/` → service_role → `site.*` RPC 한 줄기뿐이다. 브라우저에서 쓰기 RPC를 직접 부르지 않는다.
- 이 제품에는 크레딧·결제가 없다. 만들지 않는다.
- 코어 재정의 금지. `_platform-core/`, `_supabase-modular/`의 다른 파일을 수정하지 않는다. `core.*`를 ALTER하지 않는다.
- 증빙 없는 후기, 수치, 연락처, 평점을 화면과 JSON-LD에 넣지 않는다(01장 6절).
- 확인/해지 링크는 GET으로 상태를 바꾸지 않는다.

## 3. 디렉토리와 소유 경계

02장 2절의 모듈 표와 06장 2절의 소유 파일 열이 정본이다. 요약: `src/content/`(SI-06-006), `src/styles/`(005), `src/components/sections/*`(008~010), `src/lib/routes.ts`·layout(011), `src/app/api/inquiries`·`src/lib/forms`(016), `src/app/api/newsletter`·`src/lib/newsletter`·`src/lib/mail`(017), `src/lib/auth`·콘솔 가드(019), `worker/notify`(018), `scripts/`·CI(024), `tests/*`(004, 025, 026). 남의 디렉터리를 고치지 말고 요청한다.

## 4. 코어 사용 규칙

- 콘솔 라우트 진입부는 `requireSession('site')`. 프로필이 없으면 로그아웃, 기본 역할을 admin으로 두지 않는다.
- 레이트 리밋은 `core.rate_limit_hit`(Route Handler에서 IP 해시 키 `site:inq:ip:<hash>`).
- 감사는 RPC 안에서 `core.write_audit`. 개인정보 전문을 기록하지 않는다.
- 크레딧, 잡, 자격증명 vault, Storage는 쓰지 않는다.
- 스키마는 환경변수(`SUPABASE_DB_SCHEMA`, `SITE_DB_SCHEMA`)로 전환한다. 모듈러는 `core`/`site`, 모놀리스는 둘 다 `public`.

## 5. 코드 규칙

- 스택: Next.js 16, React 19.2, TypeScript 6.0, Tailwind v4 `@theme`(02장 1절). `latest` 태그 금지, lockfile 커밋.
- 색, 서체, 간격은 `src/styles/`의 CSS 변수로만. 컴포넌트에 hex 금지(03장 4.3).
- 인라인 `style`로 grid/width 지정 금지. 내부 링크는 `src/lib/routes.ts` 키로만.
- 입력은 zod로 검증한다. Supabase 타입을 `any`로 우회하지 않는다.
- 타입 생성: 모듈러 `supabase gen types typescript --local --schema core,site > src/types/db.ts`, 모놀리스는 기본 스키마.
- 사용자 노출 문구는 한국어. 오류는 무엇을 고칠지 쓰고 사과하지 않는다.

## 6. 테스트와 완료 조건

- `npm run lint && npx tsc --noEmit && npm run build`
- SQL 체커: `docs/products/_tools-sqlcheck`에서 `node check.mjs mono ...`, `node check.mjs mod ...`(06장 7절)
- RLS 스모크(SI-06-004), API 통합(026), e2e(025), CI 게이트(024)가 통과해야 완료. 결제 E2E는 해당 없음.

## 7. 금지 패턴

07장 4절 요약: 가상 후기·미검증 수치·가짜 연락처, 외부 CDN/임시 이미지 URL, `href="#"`과 미정의 라우트, 인라인 grid, 영상 autoplay+preload auto와 전량 프리로드 로더, 중첩 `.git`/LFS, 프로필 없으면 admin, 오류를 성공으로 위장, CORS `*`, 서명 없는 토큰.
