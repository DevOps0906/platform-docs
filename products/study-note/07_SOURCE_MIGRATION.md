# 07 원본 이식과 폐기: Study Note

작성일 2026-10-12. 원본: `study-note-organizer-codex-01/` (React 19 + Vite 8 + Tailwind CSS v4, 코드 약 1,090줄, 백엔드 없음).

AI 관련 원본 자산 점검(2026-10-13): 원본의 AI 사용은 브라우저에서 OpenRouter를 직접 부르는 일지 정리 한 가지뿐이다(`study-note-organizer-codex-01/src/hooks/useOpenRouter.ts`, 프롬프트 `src/utils/prompts.ts`). RAG, 과목별 위키, 노트 정리 그래프, 퀴즈, 채팅, 음성(강의 녹음 포함), Dify, 3D는 원본에 없어 모두 신규다. 원본 PRD에도 복습·퀴즈 근거가 없다(`docs/design-module/_design-guide/REFERENCES.md:246-248`이 방향만 제시). 아래 1.1절이 AI·디자인 관련 이식 판단을 모은다.

## 1. 원본별 자산 분류

### study-note-organizer-codex-01

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `src/utils/prompts.ts` (49줄) | 동작 | 이식(수정) | `src/lib/pipeline/prompts.ts` | 리뷰 `:37`. 입력 구분자와 인젝션 방어 문구 추가 |
| `src/utils/formatters.ts` (62줄) | 부분(`todayIso` UTC 버그) | 이식(수정) | `src/lib/pipeline/` | 리뷰 #5. `todayKst`로 교체, 모델 목록 의존(`getModelName`) 제거 |
| `src/utils/download.ts` (11줄) | 동작 | 이식 | `src/lib/client/` | 브라우저 TXT 생성 유지 |
| `src/utils/constants.ts` (54줄) | 부분 | 참고 | `notes.model_catalog` seed | 모델 13개를 DB 화이트리스트로. `VITE_` 폴백 폐기 |
| `src/hooks/useOpenRouter.ts` (89줄) | 동작 | 참고 | 워커 `llm/` | 브라우저 직접 호출 폐기. 에러 매핑 문구와 `temperature 0.2`만 계승 |
| `src/context/AppContext.tsx` (163줄) | 부분 | 참고 | `src/lib/client/` | useReducer 패턴 유지. localStorage 영속화는 DB로 대체 |
| `src/App.tsx` (133줄) | 부분(경쟁 상태) | 참고 | `usePipeline` + 서버 | 오케스트레이션은 워커로 이동 |
| `components/Header, ResultCard, ErrorDisplay, LoadingSpinner` | 동작 | 이식 | `src/components/common/` | 크레딧 표시, 재사용 카드 표시 추가 |
| `components/InputSection, ResultSection, SettingsPanel, HistoryPanel` | 부분 | 재작성 | workspace/settings/history | 리뷰 #3, #4, #12. 버그 코드 복사 금지 |
| `PRD.md` | 기획 | 참고 | 01~04장에 반영 | 16장의 `.env.example` VITE 키 요구는 폐기 |
| `README copy.md` | 동작(문서) | 폐기 | - | 3절 |
| `src/hooks/useLocalStorage.ts` | 미사용 | 폐기 | - | 3절 |
| `dist/`, `node_modules/` | 산출물 | 폐기 | - | 3절 |

### 1.1 AI·음성·3D·디자인 시스템 관련 자산 매핑 (2026-10-13)

| 원본 자산 | 상태 | 처리 | 대상 | 근거 |
|---|---|---|---|---|
| `src/hooks/useOpenRouter.ts`의 브라우저 직접 호출 | 동작(보안 결함) | AI 기능에 쓰지 않는다. 새 AI 기능은 FastAPI 라우터 경유. 일지 정리는 이미 서버 워커로 이동 | 02장 4·5절 | 리뷰 #1, `docs/products/_platform-core/SECURITY_BASELINE.md:299` |
| `src/utils/prompts.ts` 일지 프롬프트 2종 | 동작 | 일지 전용으로 이식(기존 계획). 노트 정리·퀴즈·채팅 프롬프트는 신규이고 입력 구분자 방식(`<<<원문 시작>>>`)을 같은 원리로 쓴다 | `src/lib/pipeline/`(일지), `apps/api/app/ai/`(신규) | 2절, NT-F-017 |
| `src/utils/constants.ts` 모델 13종 | 부분 | 일지 정리의 `notes.model_catalog`로만 이식. AI 기능은 `ai_routing_settings` 체인을 쓰고 모델을 사용자가 고르지 않는다 | 05장 2.1절, 02장 5.3절 | 01장 D-12 |
| `src/index.css`의 `@import "tailwindcss"`, `@custom-variant dark (&:where(.dark, .dark *))` (`:1-3`) | 동작 | 이미 Tailwind CSS v4 CSS 우선 설정이다. 그대로 이식하되 `package.json`의 `latest`(`tailwindcss`, `@tailwindcss/vite`)는 4.3.0 고정. 하드코딩 hex는 `tokens.css`의 의미 기반 토큰으로 대체 | `src/styles/tokens.css`(NT-06-032) | `docs/design-module/_design-guide/DESIGN_SYSTEM.md:63-73`, 리뷰 #8 |
| `html.dark` 테마 클래스 | 동작 | 유지(전환 방식 하나) | 디자인 시스템 | NT-F-010 |
| `components/Header, ResultCard, ErrorDisplay, LoadingSpinner` | 동작 | 디자인 시스템 기본 컴포넌트(NT-06-032~034) 위에서 이식(016은 034 뒤) | `src/components/common/` | 1절 |
| 랜딩 | 원본에 없음 | 신규. 3D 히어로는 03장 4.6절 | `src/components/hero3d/` | 확정 결정 15 |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| 프롬프트 | 원문을 `<<<원문 시작>>>`/`<<<원문 끝>>>`로 감싸고 데이터로 취급한다는 시스템 지시를 추가. 분량/형식 요구는 그대로. 통합 프롬프트의 키워드 규칙(공백/특수문자 없는 짧은 명사) 유지 |
| 날짜/파일명 | `todayIso`(UTC) → `Intl` `Asia/Seoul` 기준. `getDateParts`는 `T00:00:00` 로컬 파싱을 UTC 안전 연산으로. 파일명 조각 규칙(한글/영문/숫자, 24자)은 유지 |
| 키워드 추출 | `extractKeywords`의 정규식이 첫 `[핵심 키워드]` 이후 전부를 잡으므로, 본문에 같은 문자열이 있어도 마지막 출현을 쓰도록 수정하고 단위 테스트 추가 |
| 카드 UI | 모델 정보를 `run_steps`에서 받는다. `status`에 `reused`, `skipped`, `canceled` 표현 추가 |
| 에러 문구 | 401 "API Key가 올바르지 않습니다"는 사용자에게 보이지 않는다(서버 키). 429, 모델 비활성, 네트워크 문구는 유지 |
| 모델 목록 | DB 시드로 이동, 등급/크레딧 부여, `:free` 모델 표시 |

## 3. 폐기 목록과 사유

분석 "폐기" 항목(`docs/products/00_MERGE_ANALYSIS.md:1319`) 3건 전부 + 이 기획에서 추가로 폐기한 것.

| 항목 | 출처 | 사유 | 대체 |
|---|---|---|---|
| `VITE_OPENROUTER_API_KEY` 폴백 (`constants.ts:20`, `AppContext.tsx:48`) | 분석 `:1319`, 리뷰 #1 | 번들에 평문 인라인되어 배포 즉시 키 유출. 가입 개방 제품에서 치명적 | 서버 환경변수 `OPENROUTER_API_KEY`, 워커 전용 |
| `README copy.md` | 분석 `:1319`, 리뷰 #10 | 실제 문서가 사본에 있고 env 키 사용을 권장하는 문단을 포함 | 새 `apps/study-note/README.md`(NT-06-023) |
| `src/hooks/useLocalStorage.ts` | 분석 `:1319`, 리뷰 #11 | 어디서도 import하지 않는 데드 코드. 저장 로직이 `readJson`과 중복 | 초안 캐시 하나(`lib/client`), 나머지는 DB |
| `RESET_RESULTS` 액션 | 리뷰 #11 | 미사용 | 삭제 |
| localStorage의 API Key 평문 저장 | 리뷰 #7 | 같은 오리진 XSS, 공용 PC에서 노출. BYOK는 금지(`SECURITY_BASELINE.md:121`) | 입력란 자체를 만들지 않음 |
| localStorage 기반 히스토리 50건(최대 바이트 무제한) | 리뷰 #6 | QuotaExceeded로 앱이 깨질 수 있음. 기기 간 공유 불가 | DB 보관함 + 보존 정책(05장) |
| 브라우저 → OpenRouter 직접 호출 | 리뷰 `:80` | 공개 배포에서는 키/비용 보호 불가 | 서버 워커 호출 |
| `"latest"` 의존성 | 리뷰 #8 | 재현 불가 | 정확한 버전 고정 |
| `dist/` 커밋 가능성, 중첩 `.git` | 리뷰 #2 | gitlink 혼란과 산출물 유입 | `archive/`로 이동 후 새 앱을 플랫폼 저장소에 둔다 |
| PRD 16장의 `.env.example`(`VITE_OPENROUTER_API_KEY=`) | 분석 `:1323` | 리뷰의 보안 지적과 충돌 | 변수 이름만 있는 `.env.example`, 비밀 값 키 없음 |
| `package.json`의 `latest` 태그(`tailwindcss`, `@tailwindcss/vite`, `tailwind-merge`) | 원본 `package.json`, 리뷰 #8 | 재현 불가, 지시에 "Tailwind"만 적으면 v3가 섞일 수 있음 | Tailwind CSS v4 4.3.0 고정, lockfile 커밋 |
| 하드코딩 hex 색(`src/index.css` 등) | 원본 `src/index.css` | 토큰 밖 색, 다크 전환 시 불일치 | `tokens.css` 의미 기반 토큰 |

## 4. 복사 금지 결함

`SECURITY_BASELINE.md` 14장 중 해당 항목과 리뷰 고유 결함.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 번들에 인라인되는 비밀 환경변수(`VITE_*KEY`) | 리뷰 #1 | 키 유출 | 서버 전용 env + CI 번들 검사 |
| 실키가 든 `.env` 커밋 가능 상태 | SB 14장, 리뷰 #2 | 키 유출 | `.gitignore` + gitleaks |
| 인증 없는 공개 AI 프록시 | SB 14장 | 키 도용, 비용 폭증 | `requireSession` + 레이트 리밋 + 크레딧 |
| 사용자 키 평문 저장(BYOK) | SB 5장 | 탈취 | 서버 키 |
| 비원자 크레딧 차감, 클라이언트 단독 한도 | SB 14장 | 이중 실행 시 이중 과금 | `start_run` 원자 선차감 |
| 실행 중 재실행 허용, 요청 식별자 없음 | 리뷰 #3 | 결과 혼선과 비용 2배 | 4중 차단(02장 6절) |
| 클로저로 잡은 stale 상태를 쓰는 재시도 | 리뷰 #9 | 통합이 조용히 생략 | 서버 부모 실행 재사용 |
| `useEffect` 없이 한 번만 초기화하는 draft 상태 | 리뷰 #4 | 취소한 편집/테마 되돌림 | 열 때마다 재초기화 |
| `toISOString()`으로 날짜 계산 | 리뷰 #5 | KST 새벽 날짜 오류 | `todayKst` |
| 예외 처리 없는 `localStorage.setItem` | 리뷰 #6 | 앱 중단 | try/catch, 서버 저장 |
| 클라이언트 PageGuard/기본 역할 admin | SB 14장 | 해당 없음(역할 단일) | `requireSession` 서버 가드 |

AI·디자인 도입(2026-10-13)으로 추가된 금지 패턴:

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| LLM·음성 키를 브라우저·Vercel에 두기(워커·FastAPI 외) | `SECURITY_BASELINE.md:284`, 리뷰 #1 | 키 유출, 비용 폭증 | LLM 키는 워커(OpenRouter)와 FastAPI만, ElevenLabs 키와 서명 개인키는 Next.js 서버만 |
| 브라우저에서 Dify·FastAPI·AI 제공자 직접 호출 | `SECURITY_BASELINE.md:299` | 인증·과금 우회 | `/api/ai/*`, `/api/voice/*` |
| Dify 입력에 토큰·org·개인정보 | `SECURITY_BASELINE.md:285` | Dify 로그에 평문 잔존 | 대화 매핑(`platform_conversation_id`, `dify_user`) |
| 클라이언트가 보낸 임의 텍스트를 TTS | 제안 | 음성 생성 남용, 과금 우회 | DB의 assistant 메시지와 퀴즈 JSON만 낭독 |
| 퀴즈 조회 응답에 정답·해설 포함 | 제안 | 서버 채점 흐름(음성·단답) 우회 | 서버 채점 결과로만 정답 공개 |
| 강의 녹음(제3자 음성)을 상용 제공자로 전송하거나 대체 | `VOICE_ARCHITECTURE.md:95` | 제3자 음성의 국외 이전 | `lecture_note` 강제 오픈소스 |
| 사용자가 고친 위키 블록 덮어쓰기, `expected_version` 없는 저장 | `LLM_WIKI.md:30-31` | 사용자 편집 손실, 동시 쓰기 충돌 | 사람 소유 블록은 제안으로만, 낙관적 잠금 |
| 한글 제목을 위키 slug로 사용 | `0008_core_ai.sql:156` | DB 제약 위반 | 해시 기반 slug + 한글 `title` |
| 비상업 라이선스 모델·가중치 사용 | `SECURITY_BASELINE.md:301` | 유료 서비스 라이선스 위반 | 라이선스를 `ai_model_prices.license`에 기록 |
| 3D 재질에 토큰 밖 색, 파스텔 스티커·손글씨 장식, 별 파티클 | `HERO_3D.md:52-53` | 피할 인상 | 03장 4.6절 토큰 표 |
| 지시·문서에 "Tailwind"만 적기, `tailwind.config.js` | `DESIGN_SYSTEM.md:63-73`, `:75-82` | v3 혼입 | "Tailwind CSS v4"로 명시 |

## 5. 아카이브 절차

| 단계 | 작업 |
|---|---|
| 1 | 원본 폴더를 `archive/study-note-organizer-codex-01/`로 이동한다. 이동 시 중첩 `.git`(README 1파일만 커밋됨)은 보존용으로만 두고 상위 저장소에 추가하지 않는다(gitlink 방지) |
| 2 | `node_modules/`, `dist/`는 이동하지 않고 삭제한다. 번들에 실제 키가 없었는지 `dist/assets/*.js`에서 `sk-or-` 검색(리뷰는 placeholder만 있다고 확인, `:69`) |
| 3 | 원본 `.env`가 있었다면 그 키를 OpenRouter에서 재발급하고 폐기한다 |
| 4 | zip/사본 중복이 있으면 하나만 남긴다 |
| 5 | 새 `apps/study-note`에서 위 이식 자산만 복사하고, `git ls-files`에 `node_modules`, `dist`, `.env`가 없는지 확인한다 |

## 6. 인증 단계 관련 복사 금지 (2026-10-14 추가, 확정 결정 22)

원본(`study-note-organizer-codex-01`)은 로그인이 없는 로컬 도구라 아래 패턴의 원본 출처는 없다. 다른 제품 원본에서 확인된 결함이며(`docs/products/_platform-core/AUTH_ROADMAP.md:30`), 이 제품에서 새로 만들거나 다른 제품 코드에서 가져오지 않도록 4절 표에 이어 적는다. 허용되는 Mock은 `AUTH_ROADMAP.md` 2장(로컬 Supabase 시드 계정으로 실제 로그인)뿐이다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 쿠키 역할 Mock(`mock-auth.ts`, `mock-login`, `nomad_role`, `nomad_plan` 쿠키, localStorage 역할·플랜) | `docs/products/nomad-blog/07_SOURCE_MIGRATION.md:88`, `docs/products/nomad-commerce/07_SOURCE_MIGRATION.md:96` | 권한 위조, 프로덕션 노출. RLS·크레딧이 Mock 단계에서 검증되지 않는다 | `AUTH_ROADMAP.md` 2장 Mock 로그인(실제 JWT, `isMockAuthAllowed()`, 배포 404). CI 금지 문자열(NT-06-022) |
| 콜백 `next` 무검증 리다이렉트 | `AUTH_ROADMAP.md` 3.2절 5번, B-2 | 오픈 리다이렉트 | `/`로 시작하고 `//`·`@`·`\` 없음만 허용, 아니면 `/app`. origin 고정 |
| 기능 코드의 `if (mock)`, 페르소나 이메일 분기, 인증 모듈 밖 `AUTH_MODE` 참조 | `AUTH_ROADMAP.md` 0장 불변 조건, 2.5절 | 단계 전환 시 기능 코드가 바뀌고 배포에 Mock 경로가 남는다 | 권한은 `session_context`로만. 분기는 `src/lib/auth/`·로그인 화면·콜백만 |
| `dev-user` 같은 인증 우회 사용자, 원격 DB를 가리키는 Mock | `SECURITY_BASELINE.md` 14장, `AUTH_ROADMAP.md` 2.4절 | 배포 환경 인증 우회 | 시드 스크립트는 로컬 호스트가 아니면 exit 1, 기동 시 env 검증 실패 |

CLAUDE.md 2장 "장애: mock 응답으로 숨기지 않는다"는 LLM·외부 호출 장애의 가짜 응답을 금지하는 규칙이며, 위의 허용된 Mock 로그인과 별개다.
