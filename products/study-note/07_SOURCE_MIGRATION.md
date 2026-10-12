# 07 원본 이식과 폐기: Study Note

작성일 2026-10-12. 원본: `study-note-organizer-codex-01/` (React 19 + Vite 8 + Tailwind 4, 코드 약 1,090줄, 백엔드 없음).

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

## 5. 아카이브 절차

| 단계 | 작업 |
|---|---|
| 1 | 원본 폴더를 `archive/study-note-organizer-codex-01/`로 이동한다. 이동 시 중첩 `.git`(README 1파일만 커밋됨)은 보존용으로만 두고 상위 저장소에 추가하지 않는다(gitlink 방지) |
| 2 | `node_modules/`, `dist/`는 이동하지 않고 삭제한다. 번들에 실제 키가 없었는지 `dist/assets/*.js`에서 `sk-or-` 검색(리뷰는 placeholder만 있다고 확인, `:69`) |
| 3 | 원본 `.env`가 있었다면 그 키를 OpenRouter에서 재발급하고 폐기한다 |
| 4 | zip/사본 중복이 있으면 하나만 남긴다 |
| 5 | 새 `apps/study-note`에서 위 이식 자산만 복사하고, `git ls-files`에 `node_modules`, `dist`, `.env`가 없는지 확인한다 |
