# AGENTS.md — platform-docs

> 모든 AI 코딩 도구(Claude Code · ChatGPT Codex · Gemini CLI · OpenCode · Cursor)가 읽는 **단일 정본**. 80줄 이내로 유지한다.
> 저장소 전체 안내는 `README.md`(장 번호로 필요한 곳만 읽는다).

## 1. 무엇인가
NOMAD 제품군(기획 제품 16개)을 만드는 사람과 에이전트를 위한 통합 기획·개발 문서 저장소. **앱 코드는 없고 Markdown·SQL과 생성·검사 스크립트만** 있다. 실제 개발은 저장소 밖 `D:\WorkSpace\DEV\<제품>\`에서 한다(`README.md` 6장).

## 2. 구성
| 영역 | 내용 | 위치 |
|---|---|---|
| 근거 | 원본 프로젝트 코드 리뷰(읽기 전용) | `reviews/` |
| 기획 정본 | 통합 분석·공용 코어·통합 DB·제품별 01~07 | `products/` |
| 가격 | 공용 원칙·제품별 플랜 | `Price_Plans/` |
| 개발 묶음(생성물) | V1 안내서·사본 묶음 / 공용모듈 개발서 | `develop/` · `develop_V2/` |
| 공용 설계 | 화이트라벨 · 데스크톱 · 모바일 | `Multi-tenant_Theming/` · `Tauri/` · `Capacitor/` |
| 도구 | 리뷰 템플릿·PDF·폴더 트리 / SQL 검사 | `_tools/` · `products/_tools-sqlcheck/` |

별도 레포(`README.md` 11장): 디자인 `nomad-design-modules`, PDF `PDF_Collections`, BM·사업계획 `BM-CORE`.

## 3. 명령
| 목적 | 명령 |
|---|---|
| SQL 적용 검사 | `cd products/_tools-sqlcheck && npm ci && node check.mjs --vector mod <SQL 파일들>` (`mono`는 제품 모놀리스) |
| 폴더 트리 갱신 | `python3 -I _tools/folder_tree.py` |
| V1 묶음 재생성 | `python -I develop/_shared/tools/build_root.py <제품>` · 경로 검사 `--check <제품>` |
| V2 개발서 재생성 | `python -I develop_V2/_shared/tools/gen_v2.py` |
| 문서 → PDF | `python _tools/md2pdf.py <입력.md> <출력.pdf>` |

- `build_root.py`는 스크립트에 고정된 `D:/WorkSpace/platform/docs`를 읽고 쓴다. 이 클론과 위치가 다르면 실행 전에 어느 폴더가 바뀌는지 확인한다.
- 긴 출력 명령은 `~/.claude/nomad/bin/q <명령>`으로 실행한다.

## 4. 절대 규칙 (전체는 `README.md` 7장)
- 생성물은 직접 고치지 않는다. `develop/<제품>/<제품>-root/`(`build_root.py`), `develop_V2/<제품>/`(`gen_v2.py`)는 원본을 고친 뒤 다시 만든다.
- 정본을 먼저 고친다(`README.md` 4장). 확정 결정은 `products/00_MERGE_ANALYSIS.md` 상단이 분석 본문보다 우선한다.
- 요금 정본은 제품 `01_PRD.md` 4장과 seed다. 가격 플랜에서 바꾸기로 정하면 함께 고친다.
- 공용 폴더 `products/_platform-core/`, `products/_supabase-modular/`는 제품 작업에서 고치지 않고 제품 `06_AGENT_PLAN.md` 6절 "공용 모듈 요청"에 적는다.
- DB 정본은 `products/_supabase-modular/migrations/`의 모듈러 조각이고 제품 모놀리스는 변환본이다. SQL은 `_tools-sqlcheck`를 통과해야 하며, 원격 적용(`supabase db push`)은 사람이 확인 후 실행한다.
- 표기: 한국어, Markdown 표만(HTML·이모지 금지), 근거는 `상대경로:줄번호`, 근거 없는 수치·정책은 "제안", 확인하지 않은 외부 사실은 "미확인"(`products/_platform-core/DOC_TEMPLATE.md` 0장).
- 다른 문서가 `파일:줄`로 인용하는 파일에 줄을 넣거나 뺄 때는 인용이 밀리지 않는지 확인한다.
- 비밀(API 키 · service_role · 결제 키)은 저장소·로그에 넣지 않는다. 새 의존성은 `secscan license`로 확인(GPL·AGPL 거부).

## 5. 문서 지도 (필요한 장만 읽는다)
| 문서 | 내용 |
|---|---|
| `README.md` | 1장 문서 흐름 · 2장 폴더 지도 · 4장 정본 판단 · 5장 목적별 읽는 순서 · 7장 규칙 · 8장 현황 |
| `FOLDER_TREE.md` · `REPOSITORIES.md` | 전체 폴더 트리(생성물) · GitHub 레포 지도 |
| `products/00_MERGE_ANALYSIS.md` | 통합 분석과 확정 결정 |
| `products/_platform-core/` | 공용 규격(인증·조직·크레딧·결제·잡·AI·음성·보안·DB) |
| `products/<제품>/01~07` | 제품 기획서 |
| `tasks/README.md` · `tasks/NOW.md` | 작업 표 · 현재 상태 |

## 6. 작업 방식
변경은 브랜치 → PR → main 병합으로 한다. 원본을 고쳤으면 관련 생성물과 `FOLDER_TREE.md`까지 다시 만들었는지 확인한다.
커밋: `[영역] 요약`(예: `[docs]`, `[security]`, 작업 표를 쓰면 `[task-NNN]`) + 본문(무엇을 · 확인 방법).

## 7. 영역 규칙 · 도구별 로드
이 저장소에는 `apps/`, `supabase/`(루트), `docs/`(루트)가 없어 `.claude/rules/`의 경로 조건이 현재 적용되지 않는다. 문서 규칙은 이 파일 4장과 `README.md` 7장을 따른다.
- 읽지 않는 파일: `.env*` · lock 파일 · `node_modules/` · `.next/` · `dist/` · `build/` · `coverage/` (Claude는 `.claude/settings.json`, Gemini는 `.geminiignore`가 강제, ChatGPT Codex는 이 줄로 지킨다).
- `develop/*/*-root/`는 사본이 약 1,000개이므로 탐색할 때 제외하고 `products/`부터 찾는다.
- 도구별 설정: Claude Code `CLAUDE.md`·`.claude/` · ChatGPT Codex `.codex/config.toml` · Gemini CLI `.gemini/settings.json`·`.geminiignore`.

## 8. Codex 네이티브 팀
- 주 모델은 gpt-6.1-sol, 부 모델은 사용자가 확인한 지원 ID로만 지정한다. 초기 설정은 비활성이다.
- `nomad-os codex init . --worker-model <ID>` 적용 후 새 세션에서 시작하고 `nomad-os codex check .`로 검사한다.
- nomad_scout/designer/builder/tester/reviewer, 부 작업 최대 3개·깊이 1. 소유 파일을 명시하고 타인의 변경을 되돌리지 않는다.
- 설정 검사와 실제 모델 실행은 별개다. 운영 지침: NOMAD `global/nomad/CODEX_TEAM.md`.
