# 03 화면과 UX: NOMAD Docs

작성일 2026-10-13. 장 구조는 `docs/products/_platform-core/DOC_TEMPLATE.md:144-177`(2.4절, AI·음성·3D와 디자인 시스템 필수 내용 포함)을 따른다. 메인페이지 절은 `docs/products/_design-guide/DESIGN_PRINCIPLES.md` 절차(`docs/products/_PRODUCT_AGENT_BRIEF.md:65-67`), 3D 히어로는 `docs/products/_design-guide/HERO_3D.md`, 디자인 시스템은 `docs/products/_design-guide/DESIGN_SYSTEM.md`를 따른다. 음성 공통 요소는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:106-110`, 위키 화면은 `docs/products/_platform-core/LLM_WIKI.md:45`, 채팅 동작은 `docs/products/_platform-core/AI_ARCHITECTURE.md` 2·5·7절을 인용만 한다.

표기 규칙:
- 테이블·RPC·잡·SQLSTATE 이름은 설계 기준서(제품 공통) 6~8장 이름을 그대로 쓴다(`docs.projects`, `docs.finalize_document`, `docs.generate`, `DC005` 등). 기능 ID는 01장 `DC-F-###`.
- Route Handler 경로(`/api/...`)는 화면 설명을 위한 이름이며 정본은 04장이다. 04장과 다르면 04장을 따른다(제안).
- 크레딧 숫자는 01장 4절 단가 표(전부 제안)를 화면에 옮긴 것이다. 음성 단가는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104`.
- 근거 없는 수치(화면 폭, 시간, 개수 상한 등)는 "제안"이다.

## 1. 정보 구조와 화면 목록

역할은 코어 조직 역할 owner/admin/member/viewer(`docs/products/_platform-core/CORE_SPEC.md:71`)와 운영자 `platform_admin`(`docs/products/_platform-core/CORE_SPEC.md:69`)을 쓴다. viewer는 모든 프로젝트 화면을 읽기 전용으로 본다(생성·편집·확정 버튼 숨김, 제안). 플랜 접근은 `core.plans.features` 키(01장 4절: `projects_max`, `formats`, `watermark`, `doc_phase`, `members_max`, `integrations`, `approvals`, `share_links`)로 판정하며 화면 잠금은 UX 보조이고 서버(`DC006`)가 정본이다.

화면 표의 `패턴` 열은 `docs/products/_design-guide/DASHBOARD_PATTERNS.md`(구조 A~O), `시각` 열은 `docs/products/_design-guide/DASHBOARD_VISUAL.md`(시각 V-A~V-N, 1장 분석 절차)를 따른다. 값은 제안이며 화면 착수 시 1장 7단계로 다시 확인한다(2026-10-16).

### 1.1 공개, 인증, 온보딩

| 경로 | 화면 | 패턴 | 시각 | 역할 접근 | 플랜 접근 | 우선순위 |
|---|---|---|---|---|---|---|
| `/` | 메인페이지(랜딩, 동적 3D 히어로 + 3D 영상, DC-F-041, DC-F-049) | 고유(3D 히어로) | - | 누구나 | - | P0 |
| `/pricing` | 요금(Free, Pro, 크레딧팩, 작업별 크레딧 표) | 고유 | - | 누구나 | - | P0 |
| `/legal/terms`, `/legal/privacy`, `/legal/ai-notice`, `/legal/contract-notice` | 이용약관, 개인정보처리방침, AI 처리 고지, 계약서 초안 고지(법률 자문 아님) | 고유 | - | 누구나 | - | P0 |
| `/signup`, `/login`, `/reset-password` | 가입, 로그인, 비밀번호 재설정(DC-F-001). 단계별(7절): A는 `/login` 개발용 패널만(`/signup`, `/reset-password` 없음), B는 Google 버튼 + 이메일 폼·가입·재설정, C는 카카오·네이버 버튼 추가 | 고유 | - | 비로그인 | - | P0 |
| `/auth/callback` | 이메일 인증·OAuth 콜백(B부터, `finishLogin`. A는 `/api/dev/login`이 같은 함수를 거친다) | 고유 | - | - | - | P0 |
| `/onboarding/terms` | 약관 동의(OAuth 첫 로그인처럼 가입 폼을 거치지 않은 사용자, B부터, 7.3절) | 고유 | - | 로그인 전원 | 전 플랜 | P0 |
| `/onboarding/ai` | AI 처리 방식 선택과 국외 이전 동의(DC-F-025) | 고유 | - | 로그인 owner(그 외 역할은 결과만 보기) | 전 플랜 | P0 |
| `/onboarding/company` | 자사 정보 빠른 입력(`docs.parties` kind `self`, 문서번호 형식 기본값 확인) | I(첫 설정) | V-K(#23) | 로그인 owner/admin | 전 플랜 | P0 |

### 1.2 작업 공간

| 경로 | 화면 | 패턴 | 시각 | 역할 접근 | 플랜 접근 | 우선순위 |
|---|---|---|---|---|---|---|
| `/app` | 대시보드(최근 프로젝트, 재생성 필요 문서, 진행 중 잡, 잔액, 플랜 사용량, 연동 알림) | B 변형(오늘 처리할 일) + N | V-D | owner/admin/member/viewer | 전 플랜 | P0 |
| `/app/pipeline?view=board\|table` | CRM형 파이프라인 보드·표(프로젝트를 단계 열로, DC-F-047, 3.26절) | D + B(표 전환) | V-D(표 보기) | 전원 | 전 플랜 | P0 |
| 전역 ⌘K / Ctrl+K | 커맨드 팔레트(프로젝트·거래처·문서 검색, "새 견적서" 같은 명령, DC-F-047) | A의 커맨드 팔레트 | - | 전원(명령은 역할에 따라 숨김) | 전 플랜 | P0 |
| `/app/projects/[pid]/activity` | 프로젝트 활동 타임라인(생성·버전·확정·업로드, DC-F-047) | G(활동 타임라인) | - | 전원 | 전 플랜 | P1 |
| 생성 진행 오버레이(문서 목록·패키지·편집기 위) | 문서 생성 단계별 진행 애니메이션(DC-F-048, 3.27절) | N 변형(오버레이) | - | 전원(취소는 시작한 사람·owner/admin) | 전 플랜 | P0 |
| `/app/parties`, `/app/parties/[id]` | 거래처(당사자) 목록·상세(DC-F-003). 상세는 거래처 360(프로젝트·문서·금액·활동, DC-F-047) | B → G페이지(거래처 360) | V-D | 읽기 전원, 쓰기 member 이상 | 전 플랜 | P0 |
| `/app/projects` | 프로젝트 목록(상태 필터, 보관 탭) | B | V-D | 전원 | 전 플랜(생성 한도 `projects_max`) | P0 |
| `/app/projects/new` | 프로젝트 만들기(유형, 기간, 예산, 거래처, 시작 방식: 체크리스트 / RFP 올리기) | I(폼 1장) | - | member 이상 | `projects_max` | P0 |
| `/app/projects/[pid]` | 프로젝트 홈(진행 단계, 정본 요약, 문서 묶음 상태, 다음 행동) | G | - | 전원 | 전 플랜 | P0 |
| `/app/projects/[pid]/checklist?step=1..3` | 체크리스트 마법사 3단계 + 효과 미리보기 패널(DC-F-005, DC-F-006) | I + 미리보기 패널 | V-K(#23) | 쓰기 member 이상, viewer 읽기 | 전 플랜 | P0 |
| `/app/projects/[pid]/requirements` | 요구사항 보드(FR/NFR/CON, MoSCoW, 상태, DC-F-007) | B + G시트(D 전환) | V-D | 쓰기 member 이상 | 전 플랜 | P0 |
| `/app/projects/[pid]/artifacts?kind=screen` | 산출물 항목(화면, 마일스톤, 산출물 탭, DC-F-008) | B(탭) | V-D | 쓰기 member 이상 | 전 플랜 | P0 |
| `/app/projects/[pid]/costs` | 비용 항목과 합계(DC-F-009) | O | - | 쓰기 member 이상 | 전 플랜 | P0 |
| `/app/projects/[pid]/documents` | 문서 목록(유형, 상태, 버전, 재생성 필요, 문서번호) | B | V-D | 전원 | 전 플랜(Phase 2 유형은 `doc_phase`) | P0 |
| `/app/projects/[pid]/package` | 패키지 생성기(`outsourcing_basic`, DC-F-012. Phase 2 content 프로젝트는 `shorts_agency`, DC-F-046) | N(묶음 실행) | - | member 이상 | 전 플랜 | P0 |
| `/app/projects/[pid]/documents/[did]` | 문서 편집기(Tiptap, 섹션, 고정 섹션 잠금, AI Diff 카드, lint·compliance 패널, DC-F-013, DC-F-016) | J(문서형) + 검사 패널 | - | 편집 member 이상, viewer 읽기 | 전 플랜(AI 제안은 저위험 유형만) | P0 |
| `/app/projects/[pid]/documents/[did]/versions?a=..&b=..` | 버전 이력과 두 버전 비교(DC-F-014) | B + 고유(버전 비교) | - | 전원 | 전 플랜 | P0 |
| 편집기 위 대화 상자 | 확정 대화 상자(문서번호, 게이트, WARN 확인, DC-F-015) | 고유(확정 게이트) | - | member 이상(제안: Phase 2 승인 흐름이 켜지면 승인자) | 전 플랜 | P0 |
| `/app/projects/[pid]/exports` | 내보내기 기록(PDF, DOCX, ZIP, 만료, DC-F-018) | B + N | - | 전원(만들기는 member 이상) | `formats`, `watermark` | P0 |
| `/app/projects/[pid]/trace` | 요구사항 추적표 보기(DC-F-017) | B(추적 매트릭스) | V-D | 전원 | 전 플랜 | P0 |
| `/app/projects/[pid]/uploads` | 자료 올리기·색인 상태(RFP, 참고 자료, DC-F-021) | B + N(색인) | - | 올리기 member 이상 | 전 플랜 | P0 |
| `/app/projects/[pid]/uploads/[uid]/review` | RFP 추출 결과 검토(체크 후보·요구사항 후보 채택/거절, DC-F-022) | 고유(원문 + 후보 2단) | - | member 이상 | 전 플랜 | P0 |
| `/app/projects/[pid]/meetings`, `/app/projects/[pid]/meetings/new` | 회의 녹음·업로드 → 회의록 + 요구사항 후보(DC-F-026) | B + 고유(녹음) | - | member 이상 | 전 플랜 | P0 |
| 오른쪽 시트(모든 `/app` 화면), `/app/chat` | 프로젝트 Q&A 채팅 + 음성(DC-F-023, DC-F-027), 대화 목록 | A의 AI 패널, F 변형 | - | 전원(viewer 포함, 읽기 질문만) | 전 플랜 | P0 |
| `/app/projects/[pid]/wiki`, `/app/projects/[pid]/wiki/[...slug]`, `/app/projects/[pid]/wiki/lint` | 프로젝트 용어 위키 목록·페이지·이력·점검(DC-F-024) | B + J(문서형) | - | 읽기 전원, 편집 member 이상 | 전 플랜 | P0 |

### 1.3 연동, 설정, 결제, 계정, 운영

| 경로 | 화면 | 패턴 | 시각 | 역할 접근 | 플랜 접근 | 우선순위 |
|---|---|---|---|---|---|---|
| `/app/integrations` | 연동 홈(연결 목록, 상태, 마지막 동기화) | B | - | owner/admin | 전 플랜(목록은 `integrations` 값으로 잠금 표시) | P0 |
| `/app/integrations/csv` | CSV/Excel 가져오기 마법사(거래처, 비용 단가표, DC-F-028) | I | V-K(#23) | owner/admin/member | `integrations` 에 `csv`(Free 포함) | P0 |
| `/app/integrations/connect/[provider]` | HubSpot, admin-suite ERP, n8n 연결(DC-F-030~032) | I | V-K(#23) | owner/admin | team(Phase 2) | P2 |
| `/app/integrations/[cid]/mappings` | 필드 매핑(`docs.field_mappings`) | O | - | owner/admin | team(Phase 2), CSV 매핑은 마법사 안에서 전 플랜 | P2 |
| `/app/integrations/[cid]/sync` | 동기화 기록(`docs.sync_runs`), 외부 변경 충돌 목록 | N + B | - | owner/admin | team(Phase 2) | P2 |
| `/app/integrations/webhooks` | 발신 웹훅(엔드포인트, 이벤트, 전송 기록, DC-F-029) | B + G시트 | - | owner/admin | pro 이상(Phase 2) | P2 |
| `/app/settings/workspace` | 워크스페이스(이름, 기본 일단가, VAT 기본, 기본값) | H | - | owner/admin(member 읽기) | 전 플랜 | P0 |
| `/app/settings/company` | 자사 정보(`parties` kind `self`) | H | - | owner/admin | 전 플랜 | P0 |
| `/app/settings/seal` | 직인 이미지 등록·미리보기 | H | - | owner/admin | 전 플랜 | P0 |
| `/app/settings/numbering` | 문서번호 형식과 연도별 현황 | H | - | owner/admin | 전 플랜 | P0 |
| `/app/settings/ai` | AI 처리 방식 변경·철회(국외 이전) | H | - | owner | 전 플랜 | P0 |
| `/app/settings/members` | 구성원 초대·역할(Phase 2 team) | H | - | owner/admin | `members_max` 2 이상(team) | P2 |
| `/app/settings/login-methods` | 로그인 방법(연결된 제공자, 연결·해제, C단계, 7.4절) | H | - | 본인(전 역할) | 전 플랜 | P1 |
| `/app/billing`, `/app/billing/success`, `/app/billing/fail` | 잔액(plan/pack), 사용 내역, 크레딧팩, Pro 구독, Toss 복귀(DC-F-038) | H | - | owner(admin 읽기, 제안) | 전 플랜 | P0 |
| 대화 상자(문서 생성 진입점) | 고위험 문서 고지 모달(DC-F-020) | 고유(고지 모달) | - | owner/admin/member(동의는 조직 1회) | 전 플랜 | P0 |
| `/app/account` | 계정, 데이터 내보내기, 계정·워크스페이스 삭제(DC-F-042) | H | - | 본인(워크스페이스 삭제는 owner) | 전 플랜 | P0 |
| `/admin/catalog`, `/admin/catalog/doc-types/[code]`, `/admin/catalog/checklist`, `/admin/catalog/clauses` | 운영자 카탈로그 관리(유형 버전, 체크리스트 항목·효과, 조항 게시, DC-F-040) | B → G페이지 | V-D | platform_admin | - | P0 |
| `/admin/ops` | 운영 상한(`docs.runtime_config`), 실패 잡, 일일 플랫폼 크레딧 사용량(DC-F-039) | H + N(실패 잡) | - | platform_admin | - | P1 |
| `/dev/components` | 컴포넌트 미리보기(디자인 시스템 3단계, 개발 환경만) | 고유 | - | 개발자 | - | P0 |

사이드바(프로젝트 안): 개요, 체크리스트, 요구사항, 화면·일정, 비용, 문서, 추적표, 자료, 회의, 위키. 프로젝트 밖: 대시보드, 거래처, 프로젝트, 연동, 설정, 결제. 사이드바 순서는 정본 데이터 → 문서 순서(설계 기준서 2장 원칙 1 "입력 한 번, 문서 여러 개")를 따른다.

## 2. 사용자 플로우

공통: 비용이 드는 모든 행동은 실행 버튼 옆에 "예상 N크레딧"을 먼저 보이고, 잔액보다 크면 버튼 대신 부족량과 구매 경로를 보인다. 잡 진행은 `core.jobs` Realtime 구독(`docs/products/_platform-core/CORE_SPEC.md:310`)과 `docs.generation_runs`를 함께 본다.

### 2.1 (a) 가입 → 부트스트랩 → 첫 패키지 (목표 30분 이내, 제안: 01장 7절 KPI와 같은 값)

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/` | [무료로 문서 묶음 만들기] | `/signup` 이동 | - |
| 2 | `/signup`(Stage B부터. Stage A는 `/login` 개발용 패널의 `owner` 페르소나 버튼으로 바로 3단계의 `/onboarding/ai`) | 이메일·비밀번호 또는 Google, 약관 동의 | `signUp({options:{data:{signup_app:'docs'}}})` → 개인 조직, Free 엔타이틀먼트, 가입 크레딧 50 | 이미 가입: "로그인하거나 비밀번호를 재설정하세요" |
| 3 | `/auth/callback` → (Google 첫 로그인이면 `/onboarding/terms`, 7.3절) → `/onboarding/ai` | 메일 링크 클릭(Google은 계정 선택 후 자동) 후 AI 처리 방식 선택(상용 AI 함께 사용 + 국외 이전 동의 / 국내 오픈소스만) | `rpc('set_ai_cross_border_ack')` + 감사 기록, 고지문 버전 저장(`docs/products/_platform-core/AI_ARCHITECTURE.md:86`) | 고지문 버전 불일치 409 → 최신 고지문 재표시. [나중에]는 미동의(오픈소스만)로 진행 |
| 4 | `/onboarding/company` | 회사명, 사업자등록번호, 대표자, 주소, 연락처 입력(주민등록번호 입력란 없음) | `docs.parties`(kind `self`) INSERT, `docs.workspace_settings` 기본값(VAT 10%, 기본 일단가, 문서번호 형식) 확인 | 입력 lint: 13자리 주민번호 형식이 감지되면 저장 차단 "주민등록번호는 받지 않습니다" |
| 5 | `/app/projects/new` | 프로젝트명, 유형(web/app/ai/mixed/other), 기간, 예산, 거래처(새로 입력 가능), 시작 방식 "체크리스트로 시작" | `docs.projects` INSERT(status `draft`), 거래처는 `docs.parties` kind `client` | Free 3번째 프로젝트: `DC006` → "Free는 프로젝트 2개까지입니다. 보관하거나 Pro로 바꾸세요" |
| 6 | `/app/projects/[pid]/checklist?step=1` | 공통 프로필(group `profile`, `project_type`) 답변 | `docs.checklist_answers` upsert(source `user`), 오른쪽 효과 미리보기 갱신 | 필수 누락 표시(빨간 점 + "필수"), 다음 단계는 이동 가능하나 생성 단계에서 `DC004` |
| 7 | `step=2`, `step=3` | 기능·비기능·납품 체크(`feature`, `nfr`, `delivery`), 문서별 옵션(`contract_terms`: 지급 조건, 하자보수 기간, 지식재산 귀속) | 서버가 효과 엔진으로 미리보기 계산(결정적, 저장 전), [적용] 시 `docs.requirements`·`docs.artifacts`·`docs.line_items` 생성/제거 | 적용 실패(동시 수정): 409 → 최신 답 다시 읽기 |
| 8 | `/app/projects/[pid]/package` | 구성 확인(7종 + 추적표), 예상 28크레딧 확인 | `dev_contract`가 포함되면 고위험 고지 동의 여부 확인 | 미동의: 2.8절 고지 모달을 먼저 띄움(`DC007` 428). D-3 게이트로 `dev_contract`가 비활성이면 "계약서는 준비 중" 표시 + 구성 합계 26 |
| 9 | 같은 화면 | [문서 묶음 만들기] | `docs.package` 부모 잡 + 자식 `docs.generate` 잡을 의존 순서로(설계 기준서 3장 순서), 자식 단위 선차감 | 402 `CR001`: 부족량 모달. 이미 진행 중 `DC002` 409 |
| 10 | 같은 화면 | 진행 보기(문서별 칩 대기 → 생성 중 → 완료/실패) | Realtime 진행, 자식 실패 시 그 문서 환불, 하류는 canceled + 환불 | 일부 실패: "견적서 생성에 실패해 2크레딧을 돌려드렸습니다. 이어지는 과업지시서도 멈췄습니다" + [실패한 문서만 다시 만들기] |
| 11 | `/app/projects/[pid]/documents/[did]` | 문서를 열어 확인, lint 패널 확인 | `docs.document_versions` 최신 버전 표시 | lint 오류는 확정 단계에서만 차단(편집은 가능) |
| 12 | `/app/projects/[pid]/exports` | [PDF 내보내기] (예상 1크레딧) 또는 [묶음 ZIP] (Pro) | `render.pdf` 잡, Free는 워터마크 | 렌더 실패: 환불 + [다시 시도] |

### 2.2 (b) RFP 올리기 → 추출 → 확인 → 효과 → 패키지

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/app/projects/new` 또는 `/app/projects/[pid]/uploads` | "RFP로 시작" → 파일 선택(pdf, docx, md, txt), "이 자료를 사용할 권한이 있습니다" 체크(필수), 쪽수 기준 예상 크레딧 확인(50쪽까지 10, 이후 50쪽당 +5) | 서명 업로드 URL → Storage 직접 업로드 → `docs.uploads`(purpose `rfp`) 행(서버) → `rag.index` + `docs.extract` 잡(선차감) | 20MB 초과 413, 형식·매직바이트 불일치 415, 같은 sha256 재업로드 409 "이미 올린 파일입니다" |
| 2 | 같은 화면 | 진행 보기(읽기 → 색인 → 체크 항목 찾기 → 요구사항 찾기 → 중복 정리 → 검사) | `docs.extract` 그래프 노드 단계 표시(설계 기준서 9장). 결과는 `checklist_answers`(source `extract`, `is_confirmed=false`)와 `requirements`(source `extract`, status `proposed`)에 제안으로 저장 | 파싱 실패: "문서에서 글자를 읽지 못했습니다. 텍스트가 있는 PDF인지 확인하세요" + 전액 환불 |
| 3 | `/app/projects/[pid]/uploads/[uid]/review` | 체크 후보 목록(근거 문장·쪽 번호와 함께)에서 채택/거절, 요구사항 후보에서 채택/수정/거절 | 체크 채택은 `docs.confirm_checklist_suggestions(p_project_id, p_item_keys)`, 요구사항 채택은 status `accepted`, 거절은 `rejected` | 이미 사용자가 답한 항목과 다르면 "기존 답: 예 / RFP: 아니오" 충돌 표시, 기본 선택은 기존 답 유지 |
| 4 | 같은 화면 | [채택한 항목 적용] | 효과 엔진 미리보기(2.1절 7단계와 같은 패널) → 적용 | 적용 중 다른 사용자가 수정: 409 → 다시 계산 |
| 5 | `/app/projects/[pid]/package` | 2.1절 8~12단계 | 같음 | 같음 |

### 2.3 (c) 편집 → lint → 확정 → PDF/DOCX 내보내기

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | 편집기 | 변수·서술 섹션 수정, 고정 섹션은 잠금 표시만 | 브라우저 초안 저장(로컬, 실패해도 동작). 서버 저장 전 "저장하지 않은 변경 있음" 표시 | 고정 섹션 편집 시도: 커서 진입 불가 + 툴팁 "표준 서식 절은 고칠 수 없습니다. 조항 옵션은 체크리스트 3단계에서 바꿉니다" |
| 2 | 편집기 | (저위험 문서만) 문단 선택 → [다시 쓰기 제안] (1크레딧) → Diff 카드에서 수락/거절 | `docs.assist` 단건 실행, 수락하면 본문에 반영(아직 버전 아님) | 고위험 문서: AI 버튼 없음. 실패: 환불 + 원문 유지 |
| 3 | 편집기 | [버전 저장] 또는 Ctrl+S | Route Handler가 sanitize(2MB 상한) 후 `docs.document_versions` 새 행(created_kind `edited`, expected_version 확인) → lint 재실행 | `DC010` 409: 버전 충돌 대화 상자(2.3절 표 아래) |
| 4 | 편집기 오른쪽 패널 | lint·compliance 결과 확인, 항목 클릭으로 해당 섹션 이동 | 최신 버전의 `lint_result`, `compliance_verdict` 표시 | lint 오류(예: 견적서 합계와 계약 금액 불일치)는 "어디서 고치는지" 링크(비용 항목, 체크리스트)로 안내 |
| 5 | 확정 대화 상자 | [확정하기] → 게이트 결과 확인 → WARN이 있으면 "경고를 확인했습니다" 체크 → [확정] | `docs.finalize_document(p_document_id, p_expected_version, p_ack_warn)` → status `final`, 문서번호 부여(`docs.doc_counters`), `finalized_at` | `DC004` 필수 입력 누락 목록, `DC005` FAIL 또는 lint 오류 목록, `DC008` WARN 미확인, `DC010` 버전 충돌, `DC003` 이미 확정 |
| 6 | 편집기(확정 후 읽기 전용) | 상단 배지 "확정 DOC-2026-012" 확인 | 문서 잠금. 고치려면 [개정본 만들기] → `docs.create_revision` | - |
| 7 | 편집기 또는 `/exports` | [PDF] (1크레딧), [DOCX] (1크레딧, Pro), 직인 포함 여부 선택 | `render.pdf` / `render.docx` 잡 → `docs.doc_exports` | Free에서 DOCX: `DC006` 403 "DOCX는 Pro에서 받을 수 있습니다". DOCX 렌더가 아직 없으면(코어 요청 C-1 전) 버튼 비활성 "준비 중" |
| 8 | 같은 화면 | [받기] | 서명 URL, `expires_at` 이후 "만료" + [다시 만들기] | 렌더 실패: 전액 환불 + [다시 시도] |

### 2.4 (d) 문서가 있는 상태에서 체크리스트 변경 → 재생성 필요 → 재생성과 비교

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | 체크리스트 | "결제 기능" 체크 해제 | 효과 미리보기: "제거: FR-007 결제 연동, SCR-012 결제 화면, 비용 3행. 사용자 수정분 1건(FR-007 수용 기준)은 보존 후 '변경됨'으로 표시". 영향 문서 목록(요구사항정의서, 화면목록, 견적서, 과업지시서, 계약서) | 확정 문서가 영향 목록에 있으면 "확정 문서는 바뀌지 않습니다. 개정본을 만들어야 반영됩니다" 경고 |
| 2 | 같은 화면 | [적용] | 정본 변경, 영향 문서의 `docs.documents.needs_regeneration=true` | - |
| 3 | 문서 목록, 프로젝트 홈, 대시보드 | "재생성 필요 5" 배지 확인 | 목록에서 해당 문서 행에 아이콘 + "재생성 필요" 텍스트 | - |
| 4 | 문서 목록 | 문서 선택(복수 가능) → [다시 만들기] (예상 크레딧 합계) | `docs.generate`(문서당 활성 1개), 새 버전 created_kind `generated` | `DC002` 이미 생성 중, 402 |
| 5 | 버전 비교 | 완료 알림의 [달라진 점 보기] | `/versions?a=이전&b=새` 섹션별 diff. 이전 버전에서 사람이 고친 서술 섹션은 "직접 고친 내용이 새 버전에서 바뀌었습니다" 경고 + [이전 문단 다시 넣기] (새 edited 버전 생성) | - |
| 6 | 확정 문서 | [개정본 만들기] | `docs.create_revision` → 새 문서(`supersedes_document_id`) draft → 4단계 | - |

### 2.5 (e) 회의 녹음 → 회의록 → 요구사항 후보

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/app/projects/[pid]/meetings/new` | 회의명, 일시, 참석자(거래처 담당자 선택 또는 이름만), 방식 선택(브라우저 녹음 / 녹음 파일 올리기 / 텍스트 붙여넣기) | 허용 시간과 예상 크레딧(STT 분당 1 + 회의록 5) 표시 | - |
| 2 | 녹음 고지 모달 | 고지문(참석자 목소리가 녹음됨, 참석자에게 알릴 책임, 원본 보존 기간(D-11, 기본 24시간 후 삭제 제안), 고지문 버전) 확인 → [확인하고 녹음 시작] | 감사 기록, 음성 작업 `consent_kind='third_party_notice'`(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:94-95`). STT는 `meeting_minutes` 강제 오픈소스 | 취소: 텍스트 붙여넣기 경로 안내 |
| 3 | 녹음 중 | 경과·남은 시간, 일시정지, 재개, [녹음 끝내기] | 조각 단위 업로드(제안: 5분), `docs.uploads` purpose `minutes_audio` | 마이크 거부·미지원: 파일 올리기·텍스트 경로. 업로드 실패: 조각 보류 후 재전송 |
| 4 | 같은 화면 | 끝내기 | `docs.minutes` 잡: STT → 회의록 초안 → 결정·할 일 → 요구사항 후보 → compliance | STT 실패: 전액 환불 + [다시 시도]. 오픈소스 STT 장애 시 상용으로 대체하지 않는다 |
| 5 | 회의록 편집기 | 회의록 문서(`minutes`, 생성 방식 `ai`) 확인·수정, "AI가 정리한 회의록입니다. 발언 내용을 확인하세요" | 버전 저장은 2.3절과 같음 | - |
| 6 | 회의록 옆 "요구사항 후보" 패널 | 후보별 채택/수정/거절(근거 발언 시각 표시) | 채택: `docs.requirements` status `accepted`, source `minutes` | 기존 요구사항과 겹치면 "FR-004와 비슷합니다" + [합치기 제안 보기] |

### 2.6 (f) 결제: 크레딧팩, Pro 구독

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | 402 모달 또는 `/app/billing` | 팩 선택(`pack_100` 4,900원, `pack_300` 12,900원, `pack_1000` 39,000원) | 서버가 금액 결정, 주문 선저장(코어 Toss 모듈) | owner 아님: 403 "결제는 워크스페이스 소유자가 할 수 있습니다" |
| 2 | Toss 결제창 | 결제 | - | 사용자 취소 → `/app/billing/fail` "결제를 취소했습니다. 작업은 그대로 남아 있습니다" |
| 3 | `/app/billing/success` | 복귀 | confirm → pack 크레딧 지급, 잔액 갱신 | `PM001` 금액 불일치: "결제 확인에 실패했습니다. 승인 취소를 요청했습니다" |
| 4 | 원래 화면 | 402 모달에서 출발했다면 [이어서 만들기] | 같은 `request_id`로 재요청(중복 생성 없음) | - |
| 5 | `/pricing` 또는 `/app/billing` | [Pro 시작] (월 19,900원, VAT 포함) | 빌링키 발급 → 첫 결제 → 엔타이틀먼트 pro, 월 400크레딧 | 첫 결제 실패: 구독 생성 안 함 |
| 6 | 매월 | - | 정기결제, 실패 시 past_due 배너 "결제 수단을 확인하세요" | 해지: 기간 말까지 Pro, 이후 Free 한도 초과 프로젝트는 읽기 전용(제안) |

### 2.7 (g) HubSpot 딜 → 프로젝트 (Phase 2)

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | `/app/integrations/connect/hubspot` | [HubSpot 연결] → 권한 화면에서 승인 | OAuth state 서버 발급·1회 소비(`core.oauth_states`), 자격증명 `core.encrypted_credentials`, `docs.integration_connections`(status `active`) | 플랜 미달: `DC006` "HubSpot 연동은 Team에서 쓸 수 있습니다". 승인 거부: status `pending` 유지 + 다시 연결 |
| 2 | `/app/integrations/[cid]/mappings` | 기본 매핑 확인(회사 → 거래처, 딜 → 프로젝트, 금액 → 예산), 사용자 정의 필드 추가 | `docs.field_mappings` 저장, 변환(date, money, enum_map) 미리보기 1건 | 필수 매핑 누락: 저장 불가 + 누락 필드 목록 |
| 3 | 대시보드 알림 | HubSpot에서 딜 단계가 바뀌면 "ACME 딜이 '제안' 단계가 되었습니다. 문서를 만들까요?" | 수신 웹훅 서명 검증 → 알림만 생성(자동 생성 안 함, 설계 기준서 11장) | 서명 실패: 무시 + 운영 기록 |
| 4 | 알림 → `/app/projects/new?from=hubspot&deal=..` | 미리 채워진 프로젝트·거래처 확인 → [프로젝트 만들기] | `docs.projects`, `docs.parties`, `docs.external_refs` 매핑 | 이미 매핑된 딜: "이 딜은 '홈페이지 리뉴얼' 프로젝트와 연결되어 있습니다" + 열기 |
| 5 | 이후 확정 시 | 문서 확정·내보내기 | 확정 PDF와 링크를 딜 노트/첨부로 push(`integration.sync`) | 연결 해지·오류: `DC009` → 동기화 기록에 실패 + [다시 연결] |
| 6 | `/app/integrations/[cid]/sync` | 동기화 기록, "외부 변경 있음" 충돌 확인 | `etag` 비교 결과 표시, 거래처 연락처는 CRM이 정본(덮어쓰기 경고) | - |

### 2.8 (h) 계약서 첫 생성 → 위험 고지 동의

| 단계 | 화면 | 사용자 행동 | 시스템 동작 | 실패 분기 |
|---|---|---|---|---|
| 1 | 패키지 생성기 또는 문서 목록 | `dev_contract` 포함 생성 시작 | 서버가 `docs.risk_acknowledgements`(조직, 유형, 고지 버전) 확인 | 없음: `DC007` 428 → 2단계 |
| 2 | 고위험 문서 고지 모달 | 고지문 읽기(법률 자문 아님, 표준 조항 기반 초안, 변호사 검토 권고, AI가 조항을 만들거나 고치지 않음, 고지 버전), 스크롤 끝까지 읽어야 [동의하고 계속] 활성(제안) | `docs.ack_risk_notice(p_doc_type_code, p_notice_version)` → 감사 기록 | 취소: 계약서 제외하고 진행할지 묻기("계약서 없이 6종 + 추적표 만들기") |
| 3 | 원래 화면 | 생성 재시도(같은 `request_id`) | 생성 진행 | 고지 버전이 바뀌면 다음 생성 때 다시 묻는다 |
| 4 | 계약서 편집기 | 상단 고정 띠 "법률 자문이 아닙니다. 서명 전 변호사 검토를 권합니다" | 문서 꼬리말 표시 방식은 D-9 | - |

## 3. 화면별 명세

### 3.1 대시보드 `/app`

목적: 지금 해야 할 일 하나를 찾게 한다. 데이터: `docs.projects`, `docs.documents`(`needs_regeneration`, status), `docs.generation_runs`(활성), `core.jobs`(Realtime), 잔액(`credit_balances`), 플랜 features, 연동 알림.

```
+----------------------------------------------------------------------+
| NOMAD Docs   [프로젝트 검색]          잔액 42 크레딧   [결제] [계정]   |
+-----------+----------------------------------------------------------+
| 대시보드   | 이어서 할 일                                              |
| 거래처     |  - 홈페이지 리뉴얼: 재생성 필요 문서 3  [문서 보기]       |
| 프로젝트   |  - 사내 ERP 구축: 체크리스트 필수 2개 남음 [이어서 답하기] |
| 연동       |  - 견적서 생성 중 4/8 (Realtime)                          |
| 설정       +----------------------------------------------------------+
| 결제       | 최근 프로젝트 (표: 이름, 거래처, 상태, 문서 확정 수, 수정일) |
|           +----------------------------------------------------------+
| 프로젝트 1/2 (Free) | 알림: HubSpot 딜 단계 변경 (Phase 2)               |
+-----------+----------------------------------------------------------+
```

| 요소 | 동작 |
|---|---|
| 이어서 할 일 | 우선순위: 실패한 생성 > 재생성 필요 > 필수 누락 > 확정 대기(review). 최대 5행(제안) |
| 최근 프로젝트 | 카드가 아니라 표(Primer식 밀도). 행 클릭 → 프로젝트 홈 |
| 플랜 사용량 | "프로젝트 1/2"처럼 한도가 있는 값만 |
| 크레딧 | 상단바에 항상. 클릭 시 사용 내역 |

### 3.2 거래처 `/app/parties`

목적: 문서의 당사자 정보를 한 곳에서 관리. 데이터: `docs.parties`(kind client·vendor·freelancer, `deleted_at` 제외), `docs.external_refs`(연동 표시).

| 요소 | 내용 |
|---|---|
| 목록 표 | 이름, 구분, 사업자등록번호, 대표자, 담당자, 연결된 프로젝트 수, 외부 연동 표시(HubSpot 아이콘 + "HubSpot에서 관리") |
| 상세 | 폼(이름, 사업자등록번호 형식 검사, 대표자, 주소, 담당자 이름·이메일·전화, 메모). 주민등록번호 형식 입력은 차단 |
| 행동 | 만들기, 수정, 삭제(soft delete, 진행 중 프로젝트가 있으면 차단), CSV 가져오기 링크 |
| 연동 경고 | CRM 정본 필드를 수정하면 "다음 동기화 때 HubSpot 값으로 덮어씁니다" |
| 크레딧 | 없음 |

### 3.3 프로젝트 목록과 만들기

| 화면 | 목적 | 구성 | 데이터 | 행동 | 크레딧 |
|---|---|---|---|---|---|
| `/app/projects` | 프로젝트 찾기 | 상태 탭(draft, active, delivered, archived), 표(이름, 코드, 거래처, 유형, 기간, 확정 문서 수/전체, 재생성 필요) | `docs.projects`, `docs.documents` 집계 | 만들기, 보관(`docs.set_project_status`) | 없음 |
| `/app/projects/new` | 첫 입력 | 폼 1장: 이름, 유형 라디오, 기간(시작·종료), 예산(원, 선택), 거래처 콤보박스(새로 만들기 포함), 시작 방식(체크리스트 / RFP 올리기 / HubSpot 딜에서, Phase 2) | `docs.projects`, `docs.parties` | 만들기 | RFP 선택 시 "추출 예상 10크레딧~" 미리 안내 |

### 3.4 프로젝트 홈 `/app/projects/[pid]`

목적: 정본 상태와 문서 묶음 상태를 한 화면에서 보고 다음 단계로 이동. 데이터: `docs.projects`(profile, checklist_version), `docs.checklist_answers` 진행률, `docs.requirements`/`docs.artifacts`/`docs.line_items` 집계, `docs.documents`, `docs.trace_links` 커버리지.

```
+----------------------------------------------------------------------+
| 홈페이지 리뉴얼  (주)에이크미  web  2026-11-01 ~ 2027-01-31  [진행 중] |
+----------------------------------------------------------------------+
| 입력 단계: 체크리스트 18/24 (필수 0 남음) > 요구사항 23 > 비용 41,800,000원 |
|           (실제 순서라 단계 표시를 쓴다)                                  |
+-------------------------------+--------------------------------------+
| 문서 묶음                      | 다음 행동                             |
| 견적서        v3 검토  재생성필요 | [재생성 필요 문서 3개 다시 만들기]     |
| 과업지시서    v2 초안           |   예상 14크레딧                        |
| 요구사항정의서 v4 확정 DOC-...  |                                       |
| 개발용역계약서 v1 초안          | 추적표: 검수 항목 없는 요구사항 2      |
| ...                            | [추적표 보기]                          |
+-------------------------------+--------------------------------------+
```

| 행동 | 결과 |
|---|---|
| 단계 칩 클릭 | 해당 화면 이동 |
| 문서 행 | 편집기 열기 |
| 상태 변경 | `docs.set_project_status`(draft → active → delivered → archived, 위반 시 `DC001`) |

### 3.5 체크리스트 마법사 + 효과 미리보기 패널

목적: 체크 하나가 무엇을 만드는지 보면서 답하게 한다. 데이터: `docs.checklist_items`(group, label, help, input_type, options, is_required, applies_to, version, is_active), `docs.checklist_answers`, 효과 미리보기 API(서버가 `effects` jsonb를 결정적으로 적용한 결과, 저장 전 계산).

| 단계 | 포함 group | 설명 |
|---|---|---|
| 1 공통 프로필 | `profile`, `project_type` | 회사·거래처·기간·예산 확인, 유형별 기본 질문. `project_type=content`면 채널·월 편수·채널 수(`01_PRD.md` 3.3.1절)를 묻고 dev 전용 질문(플랫폼, 구축 유형)은 숨긴다(`checklist_items.applies_to`) |
| 2 프로젝트 체크 | `feature`, `nfr`, `delivery` | 기능(로그인, 결제, 관리자 등), 비기능(성능, 보안), 납품물 |
| 3 문서별 옵션 | `contract_terms`와 문서 유형별 옵션 | 지급 조건, 하자보수 기간, 지식재산 귀속, 견적 유효기간, VAT 포함 여부 |

```
+----------------------------------------------------------------------------+
| 체크리스트  [1 공통 프로필] [2 프로젝트 체크] [3 문서별 옵션]   18/24 답함   |
+--------------------------------------------+-------------------------------+
| 기능                                        | 이 체크로 생성/제거되는 항목   |
| [x] 회원가입·로그인            (?)           | (결제 기능을 켜면)             |
| [x] 결제 기능                  (?) 필수 아님  | + 요구사항 FR-0xx 결제 연동     |
|     결제 수단 [카드] [계좌이체] [간편결제]   | + 요구사항 NFR-0xx 결제 보안    |
| [ ] 관리자 화면                              | + 화면 SCR-0xx 결제, 결제 완료  |
| [ ] 다국어                                   | + 비용 개발 5.0인일 x 일단가     |
|                                             | + 조항 하자보수 범위에 결제 포함 |
| 비기능                                       | - 없음                          |
| [x] 개인정보 암호화              필수 *      | 영향 문서: 요구사항정의서,      |
|                                             | 화면목록, 견적서, 과업지시서    |
|                                             | 사용자 수정분 보존 1건          |
+--------------------------------------------+-------------------------------+
| [이전]                 변경 3건 대기 중      [미리보기 초기화] [적용] [다음] |
+----------------------------------------------------------------------------+
```

| 요소 | 동작 |
|---|---|
| 입력 형식 | input_type별 컨트롤: boolean 체크박스, single 라디오, multi 체크 그룹, number·money 숫자 입력(원, 천 단위 구분), text, date |
| 도움말 (?) | `help` 문구를 팝오버로. 문구는 운영자 카탈로그가 관리 |
| 필수 표시 | `is_required`는 "필수" 텍스트 + 기호(색만으로 구분하지 않음). 단계 탭에 남은 필수 개수 |
| 효과 미리보기 | 포커스된 항목 또는 대기 중인 변경 전체의 결과를 + 생성 / - 제거 / 보존(사용자 수정분, `is_user_modified=true`) 세 묶음으로. 항목 코드(FR, SCR)는 적용 후 서버가 부여하므로 미리보기에서는 "FR-0xx"로 표시 |
| 적용 | 답 저장과 효과 적용을 한 요청으로(서버 트랜잭션, 결정적). 같은 입력이면 같은 결과 |
| 영향 문서 | 이미 문서가 있으면 영향 문서 목록과 "적용하면 재생성 필요 표시가 붙습니다". 확정 문서는 "개정본 필요" |
| 추출 후보 | RFP에서 온 미확정 답(source `extract`, `is_confirmed=false`)은 점선 테두리 + "RFP 제안" 라벨, [채택]/[거절] 인라인 |
| 진행률 | 상단 "18/24 답함", 필수 누락이 있으면 "필수 2개 남음" |
| 크레딧 | 없음(효과 엔진은 LLM을 쓰지 않는다) |

### 3.6 요구사항 보드 `/app/projects/[pid]/requirements`

목적: FR/NFR/CON을 우선순위와 상태로 관리. 데이터: `docs.requirements`(req_code, kind, title, description, priority, acceptance_criteria, source, source_key, is_user_modified, status), `docs.trace_links`(연결 수).

| 요소 | 내용 |
|---|---|
| 보기 전환 | 표 보기(기본, 정렬·필터) / 보드 보기(열 = MoSCoW must·should·could·wont, Atlassian식 드래그 + 키보드 대안 이동) |
| 표 열 | 코드, 종류, 제목, 우선순위, 상태(proposed·accepted·rejected·changed), 출처(체크리스트·RFP·회의록·직접·연동), 수용 기준 유무, 연결(화면·검수 항목 수), 사용자 수정 표시 |
| 상세 패널 | 오른쪽 시트: 설명, 수용 기준(검수 항목으로 쓰임), 출처 근거(체크 항목 키, RFP 쪽, 회의 발언 시각), 연결된 화면·문서 절 |
| 행동 | 직접 추가(source `manual`), 수정(`is_user_modified=true`로 표시되고 효과 엔진이 덮어쓰지 않음), 후보 채택/거절, 상태 변경 |
| 코드 | req_code는 서버 트리거가 부여, 화면에서 편집 불가 |
| 크레딧 | 없음 |

### 3.7 산출물 항목 `/app/projects/[pid]/artifacts`

목적: 화면·마일스톤·산출물 목록을 문서의 원천으로 관리. 데이터: `docs.artifacts`(kind screen·milestone·deliverable, code, name, attributes, source, is_user_modified, sort_order).

| 탭 | 표 열 | 특이 동작 |
|---|---|---|
| 화면 | 코드(SCR-001), 화면명, 메뉴 경로(attributes), 연결 요구사항, 출처 | 드래그 정렬(키보드 대안), 메뉴 트리 미리보기(화면목록 문서와 같은 구조) |
| 마일스톤 | 코드, 이름, 시작·종료(attributes), 산출물 | 간트 막대 미리보기(읽기 전용, WBS 문서와 같은 계산) |
| 산출물 | 코드, 이름, 납품 형식, 마일스톤 | - |
| 테스트케이스, API | Phase 2 | 탭 비활성 + "준비 중" |

크레딧 없음.

### 3.8 비용 항목과 합계 `/app/projects/[pid]/costs`

목적: 금액의 정본. 숫자는 서버가 계산한다(설계 기준서 2장 원칙 4). 데이터: `docs.line_items`(category, name, unit, quantity, unit_price_krw, amount_krw generated, source, is_user_modified, sort_order), `docs.workspace_settings`(default_day_rate_krw, vat_rate_bp).

```
+--------------------------------------------------------------------------+
| 비용 항목                         기본 일단가 450,000원 [설정에서 변경]    |
+------+---------------------+--------+-------+------------+-------------+
| 구분  | 항목                 | 단위    | 수량   | 단가(원)    | 금액(원)     |
| 개발  | 결제 연동             | 인일    | 5.00  | 450,000    | 2,250,000   |
| 디자인| 화면 디자인 12종       | 식      | 1.00  | 3,000,000  | 3,000,000   |
| ...   |                      |        |       |            |             |
+------+---------------------+--------+-------+------------+-------------+
|                                       공급가액            38,000,000  |
|                                       부가세(10%)          3,800,000  |
|                                       합계                41,800,000  |
+--------------------------------------------------------------------------+
| 단가표에서 가져오기(CSV)   [행 추가]       합계는 서버가 계산합니다         |
+--------------------------------------------------------------------------+
```

| 요소 | 동작 |
|---|---|
| 숫자 | tabular 숫자, 오른쪽 정렬, 천 단위 구분. 수량 소수 2자리 |
| 합계 | 클라이언트는 표시만 하고 저장 후 서버 값으로 다시 그린다. 저장 전에는 "계산 중" |
| 출처 표시 | 체크리스트에서 온 행은 체크 항목 이름, 직접 수정한 행은 "직접 수정" |
| 영향 | 금액이 바뀌면 견적서·과업지시서·계약서에 재생성 필요 표시(3.5절과 같은 경고) |
| 크레딧 | 없음 |

### 3.9 문서 목록 `/app/projects/[pid]/documents`

목적: 문서 묶음 상태 파악과 생성 진입. 데이터: `docs.documents`(doc_type_code, title, status, current_version, doc_number, finalized_at, supersedes_document_id, needs_regeneration), `docs.doc_types`(risk_level, generation_mode), `docs.generation_runs`.

| 열 | 내용 |
|---|---|
| 유형 | 이름 + 위험도 표시(고위험은 "계약" 배지와 방패 아이콘) |
| 상태 | draft·generating·review·final·archived(아이콘 + 텍스트) |
| 버전 | 현재 버전, 최근 compliance(pass·warn·fail·skipped) |
| 문서번호 | 확정 시에만 |
| 재생성 필요 | 아이콘 + "재생성 필요" |
| 행동 | 열기, 다시 만들기(예상 크레딧: template 2 / hybrid 6 / ai 12), 개정본 만들기(확정만), 보관(`docs.archive_document`) |
| 새 문서 | [문서 추가] → 유형 선택(MVP 유형만, Phase 2 유형은 "준비 중") → 2.8절 고지(고위험) → 생성 |

### 3.10 패키지 생성기 `/app/projects/[pid]/package`

목적: 한 번의 실행으로 문서 묶음을 의존 순서대로 만든다. 데이터: `docs.doc_types`, `docs.documents`(이미 있는 문서), `docs.generation_runs`(package_code `outsourcing_basic`, Phase 2 `shorts_agency`), `core.jobs`.

```
+----------------------------------------------------------------------+
| 외주 개발 기본 묶음                                                   |
+----------------------------------------------------------------------+
| 순서 문서              생성 방식   필수 입력     크레딧  상태            |
| 1    요구사항정의서     hybrid     충족          6       대기           |
| 1    화면목록           hybrid     충족          6       대기           |
| 1    WBS·일정표         template   종료일 없음    2       입력 필요       |
| 2    견적서             template   충족          2       대기           |
| 3    과업지시서         hybrid     충족          6       대기           |
| 4    개발용역계약서     template   충족(고지 필요) 2      고지 동의 필요  |
| 5    검수확인서         template   충족          2       대기           |
| 6    요구사항 추적표     template   충족          2       부록 자동 포함  |
+----------------------------------------------------------------------+
| 예상 합계 28크레딧 . 잔액 42     이미 있는 문서는 새 버전으로 만듭니다  |
| [입력 채우러 가기]                         [문서 묶음 만들기]          |
+----------------------------------------------------------------------+
```

| 요소 | 동작 |
|---|---|
| 순서 열 | 설계 기준서 3장 의존 순서. 같은 번호는 병렬 |
| 필수 입력 | `doc_type_versions.required_fields` 검사 결과. 누락이면 실행 버튼 비활성 + 해당 화면 링크(`DC004` 예방) |
| 진행 중 | 행마다 상태 칩(대기, 생성 중, 완료, 실패, 취소됨)과 단계 진행 레인(3.27절, `generation_runs.progress`). 실패 자식 이후 하류는 "멈춤, 환불됨" |
| 동시 생성 | 조직 동시 생성 3(DC-F-039)에 걸리면 "다른 생성이 끝나면 시작합니다" 대기 표시 |
| 취소 | [취소]는 `docs.cancel_generation`만 부른다(코어 `cancel_job` 직접 호출 금지). 대기 중 부모·자식은 취소·환불되고 문서는 이전 상태로 돌아간다. 생성 중 문서는 끝까지 진행 |
| 크레딧 | 실행 전 예상 합계, 완료 후 실제 차감·환불 내역 |

### 3.11 문서 편집기 `/app/projects/[pid]/documents/[did]`

목적: 생성된 초안을 확인·수정하고 확정까지 가는 곳. 데이터: `docs.documents`, `docs.document_versions`(content 섹션 배열, body_html, variables_snapshot, lint_result, compliance_verdict, created_kind), `docs.doc_type_versions.structure`(섹션 key·title·kind fixed·variable·ai·table), `docs.clauses`(계약서 조항), `docs.trace_links`.

```
+------------------------------------------------------------------------------------+
| < 문서  견적서  v3 검토   재생성 필요     [버전 이력] [버전 저장 Ctrl+S] [확정하기]   |
+--------------+------------------------------------------------+--------------------+
| 목차          | 견적서                                          | 검사 결과           |
| 1 수신·발신 잠금| 1. 수신·발신  (잠금: 표준 서식)                 | 오류 1  경고 2      |
| 2 견적 개요    | 수신 (주)에이크미 귀하 ...                        | [오류] 합계가 계약서 |
| 3 견적 내역 표 | 2. 견적 개요                                     |  금액과 다릅니다     |
| 4 조건        | 본 견적은 ... [선택 영역] [다시 쓰기 제안 1크레딧] |  [비용 항목에서 고치기]|
| 5 유효기간 잠금| +-- AI 제안 -------------------------------+    | [경고] 유효기간이    |
|              | | - 본 견적은 귀사의 요청에 따라 ...         |    |  지났습니다          |
|              | | + 귀사가 요청한 범위를 기준으로 ...         |    | compliance: 경고    |
|              | |          [수락] [거절]                    |    | [다시 검사]          |
|              | +------------------------------------------+    |                    |
|              | 3. 견적 내역 (표: 비용 항목에서 자동, 직접 수정 불가)|                    |
+--------------+------------------------------------------------+--------------------+
| 마지막 저장 v3 10:42 . 저장하지 않은 변경 있음                        [채팅] [마이크] |
+------------------------------------------------------------------------------------+
```

| 섹션 kind | 편집 | 표시 |
|---|---|---|
| fixed | 불가(잠금) | 자물쇠 아이콘 + "표준 서식". 계약서 조항은 `docs.clauses` 본문 변수 치환 결과 |
| variable | 변수 값만(인라인 칩 클릭 → 원천 화면 링크) | 변수 칩: 거래처명, 금액, 기간 |
| ai | 자유 편집 + AI 다시 쓰기 제안(저위험 유형만) | "AI 초안" 라벨 |
| table | 불가(정본 데이터에서 생성) | "비용 항목에서 수정", "요구사항에서 수정" 링크 |

| 요소 | 동작 |
|---|---|
| Tiptap | 섹션 단위 노드. 붙여넣기는 서버 sanitize 규칙과 같은 허용 목록으로 클라이언트에서도 정리 |
| 선택영역 툴바 | 다시 쓰기, 요약, 표로 바꾸기(`docs.assist`, 각 1크레딧, 예상 표시). 고위험 유형(`risk_level='high'`)은 툴바 자체가 없고 상단에 "계약서는 AI가 조항을 만들거나 고치지 않습니다" |
| Diff 카드 | 삭제 줄(취소선 + "삭제" 텍스트), 추가 줄(밑줄 + "추가" 텍스트). 색만으로 구분하지 않는다. [수락]/[거절], 여러 개면 [모두 수락] |
| 저장 | 자동 저장은 브라우저 초안만. 서버 버전은 [버전 저장]으로만(append-only라 키 입력마다 버전을 만들지 않는다, 제안). 이탈 시 확인 대화 상자 |
| lint·compliance 패널 | 오류·경고 목록, 규칙 이름, 위치(섹션), 고치는 곳 링크. compliance 판정 배지. [다시 검사] (0크레딧, 결정적 lint + 경량 검사, 제안) |
| 재생성 필요 띠 | `needs_regeneration=true`면 상단 띠 "체크리스트가 바뀌었습니다. 다시 만들면 새 버전이 생깁니다 [다시 만들기 예상 2크레딧]" |
| 확정 문서 | 전체 읽기 전용, 상단 "확정 DOC-2026-012 . 2026-10-13", [개정본 만들기], [PDF], [DOCX] |
| 고위험 문서 | 상단 고정 띠 "법률 자문이 아닙니다. 서명 전 변호사 검토를 권합니다" |
| 크레딧 | 툴바 항목별 1, 다시 만들기 예상치, 내보내기 1 |

### 3.12 버전 이력과 비교 `/versions`

목적: 무엇이 언제 왜 바뀌었는지 확인. 데이터: `docs.document_versions`(version, created_kind generated·edited·imported, created_by, created_at, doc_type_version, inputs_hash, lint_result 요약, compliance_verdict).

| 요소 | 내용 |
|---|---|
| 목록 | 버전, 종류(생성·편집·가져오기), 만든 사람, 시각, 유형 버전, 검사 결과. 확정 버전에는 문서번호 |
| 비교 | 두 버전 선택(`a`, `b`) → 섹션별 나란히 보기 / 한 줄 보기 전환. 바뀐 섹션만 펼침. 변수 값 변경은 표로("계약 금액 38,000,000 → 41,800,000") |
| 입력 변경 | `inputs_hash`가 다르면 "정본 입력이 달라졌습니다" + 달라진 변수 목록(`variables_snapshot` 비교) |
| 행동 | [이 버전 내용으로 새 버전 만들기] (복원도 새 edited 버전, 기존 버전은 불변), PDF 받기(해당 버전) |
| 크레딧 | 없음 |

### 3.13 확정 대화 상자

목적: 확정 전에 게이트를 한 화면에서 확인. 데이터: 최신 `document_versions`(lint_result, compliance_verdict), `doc_type_versions.required_fields`, `docs.workspace_settings.doc_number_format`. 실행: `docs.finalize_document(p_document_id, p_expected_version, p_ack_warn)`.

```
+------------------------------------------------------+
| 견적서 v3를 확정합니다                                 |
+------------------------------------------------------+
| 확정하면 문서번호가 붙고 더는 고칠 수 없습니다.          |
| 고치려면 개정본을 새로 만들어야 합니다.                  |
|                                                      |
| 부여될 번호(예상)  QT-2026-013                         |
| 필수 입력          충족                                |
| lint 오류          0                                  |
| compliance         경고 2  [내용 보기]                  |
|   - 유효기간이 오늘 이전입니다                          |
|   - 특약 문구에 단정 표현이 있습니다                     |
| [ ] 경고 내용을 확인했고 이대로 확정합니다              |
|                                                      |
| 직인 넣기  [x] (설정에 등록된 직인)                    |
|                               [취소]  [확정]          |
+------------------------------------------------------+
```

| 게이트 | 화면 처리 | 서버 코드 |
|---|---|---|
| 필수 입력 누락 | 누락 목록 + 각 입력 화면 링크, [확정] 비활성 | `DC004` 422 |
| lint 오류 또는 compliance FAIL | 목록 + "고친 뒤 버전을 저장하세요", [확정] 비활성 | `DC005` 422 |
| compliance WARN | 경고 목록 + 확인 체크박스, 체크해야 [확정] 활성 | 체크 없이 호출 시 `DC008` 409 |
| 버전 충돌 | "다른 곳에서 새 버전 v4가 저장되었습니다. v4를 검토한 뒤 다시 확정하세요" | `DC010` 409 |
| 이미 확정 | 대화 상자 닫고 읽기 전용으로 새로고침 | `DC003` 409 |

번호 "예상"은 확정 시점에 바뀔 수 있다(동시 확정). 실제 번호는 응답 값으로 표시한다. 크레딧 없음.

### 3.14 내보내기 `/app/projects/[pid]/exports`

목적: PDF·DOCX·ZIP 결과물 받기. 데이터: `docs.doc_exports`(format pdf·docx·zip, status queued·rendering·ready·failed·expired, bytes, pages, watermark, expires_at), `docs.document_versions`.

| 요소 | 내용 |
|---|---|
| 만들기 | 문서·버전 선택(기본 최신 또는 확정 버전), 형식, 직인 포함(확정 문서만), 예상 1크레딧(ZIP은 구성 렌더에서 차감, "구성 문서 N개 x 1") |
| 기록 표 | 문서, 버전, 형식, 상태, 쪽수, 크기, 워터마크, 만료일, [받기] |
| 플랜 | Free: PDF만 + 워터마크("Free 플랜 워터마크가 들어갑니다"). DOCX·ZIP은 Pro 잠금 표시 |
| 만료 | "파일 보관 기간이 지났습니다. 같은 버전은 다시 만들 수 있습니다"(재생성 크레딧은 01장 정책을 따른다) |
| HWPX | 표시하지 않음(Phase 3) |

### 3.15 요구사항 추적표 보기 `/app/projects/[pid]/trace`

목적: 요구사항이 화면·문서 절·조항·비용·검수 항목까지 이어졌는지 확인. 데이터: `docs.trace_links`(requirement_id → to_kind artifact·document_section·clause·line_item·acceptance_item, to_ref, document_id), `docs.requirements`, `docs.artifacts`.

```
+--------------------------------------------------------------------------+
| 요구사항 추적표       필터 [빈칸 있는 행만]  [추적표 문서 만들기 2크레딧]   |
+--------+------------------+--------+-----------+------+------+----------+
| 코드    | 요구사항          | 화면    | 문서 절     | 조항  | 비용  | 검수 항목 |
| FR-001 | 회원가입          | SCR-002| 요구 3.1   | -    | 2행   | AC-001   |
| FR-007 | 결제 연동         | SCR-012| 요구 3.7   | 제9조 | 3행   | 없음(!)   |
+--------+------------------+--------+-----------+------+------+----------+
| 검수 항목 없는 요구사항 2 . 화면 없는 기능 요구사항 1                        |
+--------------------------------------------------------------------------+
```

셀 클릭 → 해당 화면·문서 절로 이동. 빈칸은 "없음" 텍스트 + 경고 아이콘(색만으로 표시하지 않음). 크레딧: 보기 0, 추적표 문서 생성 2.

### 3.16 자료 올리기와 RFP 추출 검토

| 화면 | 목적 | 구성 | 데이터 | 행동 | 크레딧 |
|---|---|---|---|---|---|
| `/uploads` | 자료 관리 | 파일 표(이름, 용도 rfp·reference·minutes_text·template_docx(Phase 2), 크기, 상태 parse_status, 색인 상태, 올린 날짜), 권리 확인 체크, 업로드 영역 | `docs.uploads`, `core.ai_documents` | 올리기, 다시 시도, 삭제, [추출 결과 보기] | 색인 1MB당 1, RFP 추출 10(50쪽 초과 50쪽당 +5) 예상치 |
| `/uploads/[uid]/review` | 추출 결과 채택 | 왼쪽: 원문 미리보기(쪽 이동, 근거 문장 강조). 오른쪽 탭 2개: 체크 후보, 요구사항 후보 | `docs.checklist_answers`(source `extract`, `is_confirmed=false`), `docs.requirements`(source `extract`, status `proposed`) | 행별 채택/거절, 수정 후 채택, [모두 채택], [채택한 항목 적용] | 0(추출 때 이미 차감) |

검토 화면 후보 행:

```
+----------------------------------------------------------------------+
| [x] 결제 기능 = 예          근거 p.12 "카드 및 간편결제 지원" [원문 보기] |
|     기존 답: 없음                                     [채택] [거절]    |
| [x] FR 후보: 관리자 통계 대시보드  우선순위 should  근거 p.15            |
|     비슷한 요구사항: FR-011 관리자 화면 [합치기] [따로 추가] [거절]      |
+----------------------------------------------------------------------+
| AI가 RFP에서 찾은 후보입니다. 채택한 것만 반영됩니다.                    |
+----------------------------------------------------------------------+
```

### 3.17 회의 녹음 → 회의록 `/meetings`

```
+------------------------------------------------------------------+
| 회의 기록      회의명 [2차 요구사항 회의]  일시 [2026-10-20 14:00]   |
| 참석자 [김대표(에이크미)] [박PM] [+]                                |
+------------------------------------------------------------------+
| 방식  (o) 브라우저 녹음  ( ) 파일 올리기  ( ) 텍스트 붙여넣기        |
| (녹음 전) 허용 90분(제안) . 예상 약 1크레딧/분 + 5   [녹음 시작]      |
| (녹음 중) 녹음 중 23:10 / 90:00   [일시정지] [녹음 끝내기]           |
|           조각 4 완료 . 조각 5 올리는 중                             |
| (끝난 뒤) 회의록 만드는 중: 받아쓰기 > 회의록 > 결정·할 일 > 요구사항 후보 |
+------------------------------------------------------------------+
| 원본 녹음은 24시간 뒤 삭제됩니다(설정은 D-11 결정 후).               |
+------------------------------------------------------------------+
```

| 요소 | 동작 |
|---|---|
| 데이터 | `docs.uploads`(purpose `minutes_audio`, `minutes_text`), `core.voice_jobs`, `docs.documents`(doc_type `minutes`), `docs.requirements`(source `minutes`) |
| 녹음 표시 | 표시등 + "녹음 중" 텍스트 + 스크린 리더 알림 |
| 이탈 방지 | 녹음 중 이탈 확인, 올라간 조각 보존 |
| 결과 | 회의록 편집기(3.11절, 생성 방식 `ai`, AI 다시 쓰기 허용), 오른쪽 요구사항 후보 패널(채택/거절, 근거 발언 시각 클릭 → 해당 구간 전사로 이동) |
| 크레딧 | 시작 전 예상(분 x 1 + 5), 끝난 뒤 실제 사용량 |

### 3.18 AI 채팅, 음성, 위키 화면

공통 요소는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:106-110`(음성)과 `docs/products/_platform-core/LLM_WIKI.md:45`(위키)를 따른다. 브라우저는 `/api/ai/*`, `/api/voice/*`만 부른다(`docs/products/_platform-core/AI_ARCHITECTURE.md:9`).

| 화면 | 목적 | 구성 | 데이터 출처 | 행동 | 크레딧 표시 |
|---|---|---|---|---|---|
| 채팅 패널(오른쪽 시트) | 프로젝트 자료·정본에 대한 질문(DC-F-023) | 머리: 제목, 프로젝트 칩(현재 프로젝트 자동), 닫기. 본문: 메시지 스레드(스트리밍, 출처 칩: 업로드 자료 쪽, 위키 페이지, 요구사항 코드, 문서 절), "AI가 생성한 답변", 대체 발생 표시, 정산 크레딧. 바닥: 마이크 버튼, 입력(1,000자, 민감 정보 안내), 보내기, 예상 크레딧과 잔액 | `core.ai_conversations`, `core.ai_messages`(citations, `docs/products/_platform-core/AI_ARCHITECTURE.md:105`), Dify 앱 `docs-chat` 경유 | 보내기, 중지, 출처 열기, 읽어 주기, 새 대화 | "약 1크레딧", 메시지별 실제 사용량 |
| 대화 목록 `/app/chat` | 지난 대화 | 행: 제목, 프로젝트, 마지막 시각, 삭제 | `core.ai_conversations` | 열기, 삭제 | - |
| 음성 입력 | 말로 묻기(DC-F-027) | 누르고 말하기 / 토글, 녹음 중 표시와 남은 시간(최대 60초, 제안), 변환 텍스트 미리보기와 수정 후 보내기 | `POST /api/voice/stt`(`voice_chat` STT, 원본 미저장) | 녹음, 취소, 수정, 보내기 | 오픈소스 0.5 / ElevenLabs 3 크레딧 분당 |
| 읽어 주기 | 답변 듣기 | 메시지별 [읽어 주기], 자동 재생 설정(기본 꺼짐), 재생 속도 | `POST /api/voice/tts {message_id}`(서버에 저장된 메시지만 낭독) | 재생, 정지, 속도 | 오픈소스 1 / ElevenLabs 5 크레딧 천 자당 |
| 음성 처리 고지 모달 | 첫 녹음 전 고지 | 목적, 원본 미저장, 처리 제공자와 국외 여부, 확인/취소 | 감사 기록 | 확인, 취소 | - |
| 위키 목록 `/wiki` | 프로젝트 용어 찾기(DC-F-024) | 검색, 종류 필터(당사자 party, 용어 term, 약어 acronym, 결정 decision), 행(제목, 요약 1줄, 마지막 편집자 에이전트/사람, 낡음 표시) | `core.wiki_pages`(RLS 조회) | 열기, 검색 | - |
| 위키 페이지 `/wiki/[...slug]` | 정의 확인과 편집 | 제목, 요약, 본문, "출처"(업로드 자료, 회의록), "관련" 링크, 백링크, "AI가 정리한 문서" 표시, [편집], [이 용어로 채팅 묻기], 변경 이력 탭 | 같음 + `core.wiki_revisions` | 편집(사람 소유 블록 표시, `expected_version`, `docs/products/_platform-core/LLM_WIKI.md:29-31`), 이력 보기, 에이전트 제안 적용/무시 | 편집 0 |
| 위키 점검 `/wiki/lint` | 정리 상태 확인 | 항목 표(모순, 낡음, 고아, 깨진 링크, 출처 없음) + 수정 제안 | `core.ai_runs`(graph `wiki.lint`) | 실행, 제안 반영, 무시 | 실행 전 예상치 |

채팅 패널 와이어프레임(PC 오른쪽 시트 400px, 767px 이하 전체 화면, 제안):

```
+------------------------------------------+
| 프로젝트에 묻기   [홈페이지 리뉴얼]   [x] |
+------------------------------------------+
| (나) 하자보수 기간을 RFP에서 몇 개월로     |
|      요구했나요?                          |
| (AI) RFP 18쪽에서 "검수 완료 후 12개월"로  |
|      요구합니다. 현재 체크리스트 답은      |
|      6개월입니다.                          |
|      출처 [RFP p.18] [체크리스트 하자보수] |
|      AI가 생성한 답변 . 1크레딧  [읽어 주기]|
+------------------------------------------+
| 주민등록번호, 계좌 비밀번호는 적지 마세요   |
| [마이크] [질문을 입력하세요       ] [보내기]|
| 약 1크레딧 . 잔액 42                        |
+------------------------------------------+
```

| 채팅 규칙 | 내용 |
|---|---|
| 정본 변경 없음 | 채팅은 읽기만 한다. 답변에 정본과 다른 값이 있으면 "체크리스트에서 바꾸기" 링크만 준다(직접 쓰지 않음) |
| 계약 질문 | 계약 조항 해석 질문에는 답변 아래 "법률 자문이 아닙니다" 고정 문구 |
| 근거 없음 | "이 프로젝트 자료에서 근거를 찾지 못했습니다" + "자료 밖 일반 설명"을 구분 표시 |
| 국외 미동의 | 패널 상단 "국내 오픈소스 AI로 답하고 있습니다. 설정에서 바꿀 수 있습니다" |

### 3.19 연동 화면

| 화면 | 목적 | 구성 | 데이터 | 행동 | 크레딧 |
|---|---|---|---|---|---|
| `/app/integrations` | 연결 상태 | 행: 제공자, 종류(crm·erp·automation·file), 상태(pending·active·error·revoked), 방향(pull·push·both), 마지막 동기화, 마지막 오류. 잠긴 제공자는 "Team에서 사용" | `docs.integration_connections` | 연결, 해지(`docs.revoke_integration`, owner/admin) | 없음 |
| CSV 가져오기 마법사 `/csv` | 거래처·단가표 일괄 입력 | 1 대상 선택(거래처 / 비용 단가표) → 2 파일 선택(csv, xlsx) → 3 열 매핑(자동 추정 + 수정, 미리보기 5행) → 4 검사 결과(오류 행 번호와 이유, 중복 처리: 건너뛰기/덮어쓰기) → 5 가져오기 결과 | `docs.parties`, `docs.line_items` 단가 카탈로그, `docs.sync_runs`(provider csv) | 다음, 이전, 오류 행 CSV 받기 | 없음 |
| 연결 `/connect/[provider]` (Phase 2) | HubSpot·admin-suite ERP·n8n | 설명, 필요한 권한, [연결]. ERP는 같은 조직 + 두 앱 엔타이틀먼트 조건 안내 | `core.oauth_states`, `docs.integration_connections` | 연결 | 없음 |
| 필드 매핑 `/[cid]/mappings` (Phase 2) | 외부 필드 → 내부 경로 | 표: 엔티티, 외부 필드, 내부 경로, 변환(none·date·money·enum_map), 사용 여부. enum_map 편집기 | `docs.field_mappings` | 추가, 수정, 테스트 변환 | 없음 |
| 동기화 기록 `/[cid]/sync` (Phase 2) | 실패와 충돌 확인 | 실행 표(방향, 상태, 시작·종료, 통계), 충돌 목록("외부 변경 있음": 내부 값, 외부 값, 선택) | `docs.sync_runs`, `docs.external_refs` | 다시 실행, 충돌 해결 | 없음 |
| 발신 웹훅 `/webhooks` (Phase 2) | 이벤트 알림 | 엔드포인트 목록(URL, 이벤트: `project.created`, `document.generated`, `document.finalized`, `document.exported`, `package.completed`, 상태 active·disabled·failing, 실패 수), 서명 비밀 1회 표시, 전송 기록 20건 | `docs.webhook_endpoints`, `docs.webhook_deliveries` | 추가(URL 검증), 비활성, 테스트 전송 | 없음 |

### 3.20 설정

| 화면 | 구성 | 데이터 | 비고 |
|---|---|---|---|
| 워크스페이스 | 이름, 기본 일단가(원), VAT 기본(%, `vat_rate_bp` 표시 변환), 견적 유효기간 기본(defaults) | `docs.workspace_settings`(owner/admin만 쓰기) | member는 읽기 전용 표시 |
| 자사 정보 | 회사명, 사업자등록번호, 대표자, 주소, 연락처. "문서의 발신·공급자 정보로 쓰입니다" | `docs.parties` kind `self` | 바꾸면 미확정 문서에 재생성 필요 표시 |
| 직인 | PNG(투명 배경 권장) 올리기, 문서 위 미리보기(견적서 발신란), 삭제. 최대 크기 1MB(제안) | `docs.workspace_settings.seal_image_path`, Storage(조직 폴더) | 확정 문서 내보내기에서만 직인이 들어간다(제안) |
| 문서번호 | 형식 입력(예 `{type}-{yyyy}-{nnn}`, 제안 문법) + 미리보기, 유형·연도별 마지막 번호(읽기 전용) | `docs.workspace_settings.doc_number_format`, `docs.doc_counters` | 형식 변경은 다음 확정부터 적용 |
| AI 처리 방식 | 라디오 2개(상용 함께 / 오픈소스만), 고지문, 제공자·국가 표, 변경 이력 | 코어 `ai_org_settings`, 감사 기록 | owner만. 철회 직후 다음 요청부터 상용 호출 없음 |
| 구성원(Phase 2) | 초대, 역할(admin·member·viewer), 상태 | 코어 `org_members` | `members_max`. Free·Pro는 1명이라 잠금 |

### 3.21 결제와 크레딧 `/app/billing`

| 영역 | 내용 |
|---|---|
| 잔액 | plan / pack 구분, 다음 월 지급일 |
| 플랜 | Free(월 30), Pro(19,900원 VAT 포함, 월 400, DOCX·ZIP·워터마크 없음·웹훅), Team(Phase 2, "준비 중", 프로젝트 300). 가격표에 "VAT 포함"을 표기하고 "무제한" 문구를 쓰지 않는다 |
| 크레딧팩 | `pack_100`, `pack_300`, `pack_1000` |
| 작업별 크레딧 표 | template 2, hybrid 6, ai 12, 패키지 28, 다시 쓰기 1, RFP 추출 10~, 회의록 분당 1 + 5, 내보내기 1, 채팅 1, 색인 1MB당 1, 음성 단가(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104`) |
| 사용 내역 | 원장 표(시각, 작업, 문서, 차감, 환불, 잔액). 환불 행은 "환불" 텍스트 |
| 결제 내역 | 주문, 금액, 상태, 영수증 |

### 3.22 고위험 문서 고지 모달

| 항목 | 내용 |
|---|---|
| 띄우는 때 | `dev_contract`(MVP), Phase 2 `nda`·`maint_contract` 등 `risk_level='high'` 유형을 조직에서 처음 생성할 때, 또는 고지 버전이 바뀐 뒤 처음 생성할 때(`DC007` 428 응답 또는 생성 전 사전 확인) |
| 본문 | 1) 이 문서는 표준 조항을 바탕으로 만든 초안이며 법률 자문이 아닙니다 2) 서명 전 변호사 검토를 권합니다 3) AI는 계약 조항을 만들거나 고치지 않습니다(조항은 운영자가 게시한 표준 조항과 입력값으로만 채웁니다) 4) 표준계약서 원문 출처와 이용 조건(D-8) 5) 고지문 버전과 날짜 |
| 행동 | [동의하고 계속] → `docs.ack_risk_notice(p_doc_type_code, p_notice_version)`, [취소] |
| 기록 | `docs.risk_acknowledgements`(조직, 유형, 버전, 동의자, 시각) + 감사 |
| 쓰지 않는 말 | "법적 효력 보장", "변호사 검토 불필요", "분쟁 방지 보장" |

### 3.23 계정, 데이터 내보내기, 삭제 `/app/account`

| 영역 | 내용 |
|---|---|
| 계정 | 표시 이름, 이메일, 비밀번호 변경, 로그아웃 |
| 데이터 내보내기 | [전체 내보내기] → ZIP(프로젝트·정본 JSON, 문서 최신 버전 HTML, 확정 PDF 링크 목록) 잡, 완료 시 서명 URL 7일(제안). 크레딧 없음(제안) |
| 계정 삭제 | owner면 워크스페이스 삭제 포함 경고, 확인 문구 입력, 유예 30일(제안, 재로그인 시 취소). 연동 연결은 즉시 해지 |

### 3.24 운영자 카탈로그 관리 `/admin/catalog`

목적: 문서 유형 버전·체크리스트·조항을 게시한다(DC-F-040). 서버가 service_role로 쓰며 브라우저에 키가 가지 않는다. 데이터: `docs.doc_types`, `docs.doc_type_versions`(structure, required_fields, lint_rules, template_ref, checksum, published_at), `docs.checklist_items`(effects 포함), `docs.clauses`(status draft·published·retired).

| 화면 | 구성 | 규칙 |
|---|---|---|
| 유형 목록 | 코드, 이름, 분류, 위험도, 생성 방식, 단계(MVP/Phase), 최신 게시 버전, 활성 | 비활성화는 새 생성만 막는다 |
| 유형 버전 | 섹션 구조 표(key, title, kind), 필수 입력, lint 규칙 JSON 편집기(스키마 검사), 템플릿 경로, checksum. [미리보기 생성] (샘플 프로젝트) → [게시] | 게시 후 불변(`DC003`). 고치려면 새 버전 |
| 체크리스트 항목 | key, group, label, help, input_type, options, applies_to, is_required, version, is_active, effects JSON 편집기 + "샘플 프로젝트에 적용하면" 결과 미리보기(효과 미리보기 패널과 같은 표시) | effects 스키마 검사 실패 시 저장 불가 |
| 조항 | code, 유형, 제목, 본문 템플릿(변수 `{{var}}` 강조), 변수 목록, 필수 여부, 출처 메모, 상태 전이(draft → published → retired) | 출처 메모 없으면 게시 불가(D-8) |
| 운영 상한 `/admin/ops` | 조직 동시 생성 수, 일일 플랫폼 크레딧 상한, 실패 잡 목록 | `docs.runtime_config` |

### 3.25 디자인 시스템

`docs/products/_design-guide/DESIGN_SYSTEM.md`를 따른다(9장 제품 문서 반영 규칙, `:96-99`). 이 절은 NOMAD Docs의 선택만 적는다.

| 항목 | 내용 | 근거 |
|---|---|---|
| 주 레퍼런스 | 앱 화면(체크리스트 마법사 3단계, 요구사항 보드, 패키지 진행, 확정 게이트, 모달·사이드바 중첩, 상태 배지): **Atlassian**. 보조: **Primer**(비용 항목 표, 추적표, 버전 이력, 내보내기 기록의 정보 밀도, 숫자 열 정렬, 컴팩트/기본 두 밀도). AI 채팅·음성·위키 화면: Astryx 패턴(존재·라이선스 미확인, 확인 전에는 패턴 이름으로만) + Primer 밀도. 랜딩: `DESIGN_PRINCIPLES.md` + `HERO_3D.md` + `REFERENCES.md`(4.1절) | `docs/products/_design-guide/DESIGN_SYSTEM.md:51-61`(협업·워크플로·보드 행 `:56`, B2B 밀도 행 `:55`, AI 채팅 행 `:57`) |
| 가져올 것 | Atlassian: 단계형 폼과 진행 표시, 칸반 열과 드래그의 키보드 대안, 상태 lozenge(아이콘 + 텍스트), 모달 중첩 최소화, 포커스 링 기준. Primer: 고밀도 표, tabular 숫자, 상태 라벨, `kbd` 단축키 표시 | 같은 곳 |
| 가져오지 않을 것 | 라이브러리 설치(`@atlaskit/*`, `@primer/react`, Astryx 패키지), 두 시스템의 색·아이콘(Lucide 사용), StyleX(Tailwind CSS v4로 재현), 마케팅 랜딩에 B2B 레퍼런스 적용 | `docs/products/_design-guide/DESIGN_SYSTEM.md:14`, `:61` |
| 스택 | Next.js·React 버전은 02장 1절 스택 표를 따른다. **Tailwind CSS v4**(4.x 고정, `latest` 금지), shadcn/ui(Tailwind CSS v4 지원 버전, 구현 시 확인), Lucide, Tiptap(버전은 02장). `tailwind.config.js`와 v3 문법 금지 | `docs/products/_design-guide/DESIGN_SYSTEM.md:63-73` |
| 토큰 파일(정답) | `apps/nomad-docs/src/styles/tokens.css`의 `@theme` 블록과 라이트/다크 변수(디렉토리는 02장 2절과 맞춘다). 의미 기반 이름: `--color-canvas`(서류철), `--color-surface`(용지), `--color-text`(먹회), `--color-text-muted`, `--color-rule`(괘선), `--color-accent`(결재청), `--color-seal`(인주: 직인·확정 표시와 3D 히어로에만), `--color-success`·`--color-warning`·`--color-danger`, `--color-diff-add`·`--color-diff-remove`, `--radius-control`, `--radius-sheet`, `--space-row-compact`/`--space-row-default`. 다크 전환은 `data-theme` 하나(`@custom-variant dark`). 값은 4.3절 | `docs/products/_design-guide/DESIGN_SYSTEM.md:26-37` |
| 컴포넌트(정답) | `apps/nomad-docs/src/components/ui/`(shadcn/ui를 토큰으로 재스타일). hex 직접 사용 금지(린트로 `bg-[#...]` 차단, 제안), 이모지 아이콘 금지 | `docs/products/_design-guide/DESIGN_SYSTEM.md:31` |
| 문서 | `docs/file/03-설계/디자인/DESIGN.md`(1절 레퍼런스와 방향, 토큰 표), `COMPONENTS.md`(배리언트 표). 코드에서 갱신하고 다르면 코드가 이긴다. UUPM이 만든 `design-system/nomad-docs/MASTER.md`는 초안이며 정답이 아니다 | `docs/products/_design-guide/DESIGN_SYSTEM.md:32`, `docs/products/_design-guide/DESIGN_PRINCIPLES.md:68-81` |
| 시각 확인 | `/dev/components` 라이트/다크 스크린샷 | `docs/products/_design-guide/DESIGN_SYSTEM.md:33` |
| 작업 순서 | `DESIGN_SYSTEM.md` 4장 1~4단계를 06장 W0~W1에 둔다. 3단계(비주얼 검토)는 사람이 수행한다. 화면 작업은 4단계 뒤 | `docs/products/_design-guide/DESIGN_SYSTEM.md:39-49` |
| 작업 지시 | 컴포넌트 1개 단위로 8장 템플릿(대상, 근거, 스택 버전, 배리언트, 수치, 금지, 검증) | `docs/products/_design-guide/DESIGN_SYSTEM.md:84-94` |

기본 컴포넌트와 배리언트(수치는 제안, 3단계 사람 검토에서 확정):

| 컴포넌트 | 배리언트 | 크기 | 상태 |
|---|---|---|---|
| Button | primary(결재청 바탕), secondary, ghost, danger | sm 32 / md 36 / lg 40px | 기본, 호버, 포커스, 비활성, 로딩 |
| Input, Textarea, Select, Combobox, DateField, MoneyInput(천 단위 구분, 원) | default, error | md 36 / lg 44px | 기본, 포커스, 비활성, 오류 |
| Checkbox, Switch, RadioGroup, SegmentedRadio | - | md | 기본, 포커스, 비활성, 오류 |
| Dialog, Sheet(채팅 패널 400px, 상세 패널 480px, 모바일 전체 화면), Toast | - | Sheet 400/480px / 전체 | 열림, 닫힘 |
| Table | compact(행 32px), default(행 40px), 숫자 열 오른쪽 정렬 | - | 빈 상태, 로딩 스켈레톤, 행 선택 |
| StatusLozenge | 프로젝트(draft, active, delivered, archived), 문서(draft, generating, review, final, archived), 요구사항(proposed, accepted, rejected, changed), 생성 실행(queued, running, succeeded, failed, canceled), 내보내기(queued, rendering, ready, failed, expired), 연동(pending, active, error, revoked), compliance(pass, warn, fail, skipped) | sm | 아이콘 + 텍스트(색만으로 구분하지 않음) |
| Board(열 + 카드, 드래그) | 키보드 대안 이동 포함 | - | 기본, 드래그 중, 드롭 가능, 비활성 |
| Tabs, Tooltip, Popover, Progress, Skeleton, Kbd, Stepper(3단계) | - | - | - |
| Tag(출처 칩, 변수 칩) | 자료 출처, 위키 출처, 요구사항 코드, 변수 | sm | 기본, 호버, 포커스 |

제품 고유 컴포넌트(기본 세트 뒤): ChecklistStep, EffectsPreviewPanel, RequirementBoard, LineItemTable, PackageRunTable, DocEditor(Tiptap 섹션 노드, LockedSection, VariableChip), DiffCard, LintPanel, FinalizeDialog, VersionDiffView, TraceMatrix, ExtractReviewList, MeetingRecorder, RiskNoticeDialog, ChatPanel, MessageBubble, CitationChip, VoiceButton, WikiArticle, CsvImportWizard, Hero3D, 그리고 2026-10-14 추가분 AppShell(왼쪽 내비 + 상단 명령 막대), CommandPalette, PipelineBoard·PipelineCard·StageColumn, RecordHeader·RecordSidebar(거래처 360), ActivityTimeline, SavedViewBar(필터 칩, URL 동기화), GenerationProgress(StageRail·SectionLane·SheetAssembler), HeroVideo.

모션 토큰(2026-10-14 추가, 제안): `--motion-fast` 120ms(호버·포커스), `--motion-base` 200ms(패널·시트 열기), `--motion-slow` 360ms(보드 카드 이동), `--motion-stage` 600ms(생성 단계 전환), 이징 `--ease-standard` cubic-bezier(0.2, 0, 0, 1), `--ease-emphasized` cubic-bezier(0.3, 0, 0, 1). 모든 모션은 `prefers-reduced-motion: reduce`에서 0ms(상태 변화는 즉시 반영). 애니메이션 라이브러리는 `motion`(구 framer-motion, React 19 지원 버전, 제안·구현 시 확인)을 `features/progress/`와 `features/pipeline/`에서만 쓴다. 나머지는 CSS 전환.

#### 3.25.1 DESIGN.md 초기값 (개발 폴더 `docs/file/03-설계/디자인/DESIGN.md`로 복사된다)

| 항목 | 값 |
|---|---|
| 주 레퍼런스 | 앱: Atlassian(단계형 폼·보드·상태 lozenge) + Primer(표 밀도). 로그인 후 셸: Attio·HubSpot·Pipedrive·Linear 패턴(3.26절). 랜딩: `HERO_3D.md` + 4장 |
| 가져올 패턴 | 단계형 진행, 칸반 열과 키보드 대안, 고밀도 표, 레코드 페이지(헤더 + 탭 + 오른쪽 속성 사이드바), 활동 타임라인, ⌘K 팔레트, 필터 칩 + 저장된 뷰 |
| 가져오지 않을 것 | 라이브러리 설치(`@atlaskit/*`, `@primer/react`), 각 서비스의 색·로고·아이콘·일러스트, 끌어 놓기로 데이터 상태 바꾸기, 무한 커스텀 필드 |

| 토큰 | 라이트 | 다크(제안, 3단계 사람 검토에서 확정) | 용도 |
|---|---|---|---|
| `--color-canvas` | #E6EBE7 | #141A17 | 페이지 배경(서류철) |
| `--color-surface` | #FBFCFA | #1B2320 | 문서 지면·카드·표 바탕(용지) |
| `--color-text` | #1D2421 | #E3E8E4 | 본문(먹회) |
| `--color-text-muted` | #4F5A55 | #A7B0AB | 보조 글자(대비 4.5:1 이상, 구현 시 측정) |
| `--color-rule` | #8A948F | #3A4440 | 괘선·구분선(글자에 쓰지 않음) |
| `--color-accent` | #1F4E8C | #7FA8E0 | 주 행동·링크·포커스 링(결재청) |
| `--color-seal` | #B3262E | #D0464E | 직인·확정 표시·3D 히어로 직인에만(인주) |
| `--color-success` | #1F7A45 | #4CB97A | 확정 완료, compliance pass |
| `--color-warning` | #8F5B00 | #D9A23B | WARN, 재생성 필요 |
| `--color-danger` | #A3361A | #E07A5F | 오류(인주와 구분) |
| `--color-diff-add` / `--color-diff-remove` | #DCEFE2 / #F6DEDA | #1F3A2A / #3E2523 | Diff 바탕(밑줄·취소선·텍스트 병기) |

| 토큰 | 값 | 용도 |
|---|---|---|
| `--font-display`, `--font-body` | Spoqa Han Sans Neo | UI·제목. 본문 15/24px 400 |
| `--font-doc` | Noto Serif KR | 문서 지면 15/26px |
| `--radius-control` / `--radius-sheet` | 6px / 10px | 입력·버튼 / 카드·시트 |
| `--space-row-compact` / `--space-row-default` | 32px / 40px | 표 행 높이 |
| `--shadow-sheet` | 0 1px 2px 먹회 8%, 0 8px 24px 먹회 6% | 시트·팔레트(다크는 그림자 대신 테두리) |
| 모션 | 위 모션 토큰 | 3.25절 |

밀도: 표·보드는 컴팩트/기본 두 단계(사용자 설정, 기본 = 기본). 다크 전환: `data-theme` 하나(`@custom-variant dark`). 다크는 앱 화면만, 랜딩은 라이트.

#### 3.25.2 COMPONENTS.md 초기값 (개발 폴더 `docs/file/03-설계/디자인/COMPONENTS.md`로 복사된다)

| 컴포넌트 | 배리언트 | 크기 | 상태 | 작업 |
|---|---|---|---|---|
| Button | primary, secondary, ghost, danger | sm 32 / md 36 / lg 40px | 기본, 호버, 포커스, 비활성, 로딩 | DC-06-009 |
| Input·Textarea·Select·Combobox·DateField·MoneyInput | default, error | md 36 / lg 44px | 기본, 포커스, 비활성, 오류 | DC-06-009 |
| Checkbox·Switch·RadioGroup·SegmentedRadio | - | md | 기본, 포커스, 비활성, 오류 | DC-06-009 |
| Dialog·Sheet(400/480px)·Toast | - | - | 열림, 닫힘 | DC-06-009 |
| Table | compact 32px, default 40px, 숫자 오른쪽 정렬 | - | 빈 상태, 스켈레톤, 행 선택 | DC-06-009 |
| StatusLozenge | 프로젝트·문서·요구사항·생성 실행·내보내기·연동·compliance·파이프라인 단계 | sm | 아이콘 + 텍스트 | DC-06-009 |
| Tabs·Tooltip·Popover·Progress·Skeleton·Kbd·Stepper·Tag | - | - | - | DC-06-009 |
| AppShell | 내비 펼침 240px / 접힘 56px, 상단 명령 막대 48px | - | 모바일은 하단 탭 4개 + 햄버거 | DC-06-011 |
| CommandPalette | 검색, 명령, 최근 | 640px 폭 | 열림, 결과 없음, 로딩 | DC-06-061 |
| PipelineBoard·StageColumn·PipelineCard | board, table | 열 280px, 카드 높이 자동 | 기본, 포커스, 단계 이동 애니메이션, 재생성 필요 배지 | DC-06-061 |
| RecordHeader·RecordSidebar·ActivityTimeline | 거래처, 프로젝트 | 사이드바 320px | 기본, 접힘, 빈 타임라인 | DC-06-061 |
| SavedViewBar | 필터 칩, 정렬, 열 선택 | - | 기본, 변경됨(저장 안 됨) | DC-06-061 |
| GenerationProgress(StageRail·SectionLane·SheetAssembler) | 단일, 패키지 | 오버레이 560px / 패키지 전체 폭 | 대기, 진행, 완료, 실패, 취소, reduced-motion | DC-06-062 |
| Hero3D·HeroVideo | 실시간 3D, 영상, 정지 이미지 | 전체 폭 | 로딩, 재생, 일시정지, 강등 | DC-06-045 |

### 3.26 로그인 후 CRM형 워크스페이스 (DC-F-047)

목적: 로그인 후 화면을 "문서 도구"가 아니라 "고객·프로젝트·문서를 한곳에서 굴리는 작업 공간"으로 만든다. 벤치마킹(2026-10-14, 화면 패턴만 참고하고 코드·자산·색은 가져오지 않는다. URL은 `docs/products/_design-guide/REFERENCES.md` nomad-docs 절, C-4 반영):

| 서비스 | 가져올 패턴 | 이 제품에서의 모습 | 가져오지 않을 것 |
|---|---|---|---|
| Attio | 레코드 페이지(헤더 + 탭 + 속성 사이드바), 같은 데이터를 표·보드로 바꿔 보는 뷰 | 거래처 360, 프로젝트 표/보드 전환 | 임의 객체·커스텀 필드 빌더 |
| HubSpot | 레코드 왼쪽 속성, 가운데 활동 타임라인, 오른쪽 연결 카드(Associations) | 거래처 상세: 왼쪽 회사 정보, 가운데 활동, 오른쪽 프로젝트·문서 카드 | 이메일·전화 기록, 마케팅 기능 |
| Pipedrive | 딜 파이프라인 보드, 열마다 합계, 오래 멈춘 카드 표시(rotting) | 파이프라인 보드: 열 합계(VAT 포함), 14일 넘게 변화 없는 카드 흐림 + "14일째 변화 없음" | 끌어 놓기로 단계 변경(이 제품은 문서가 단계를 정한다) |
| Linear | 키보드 우선, ⌘K 팔레트, 빠른 전환 | 팔레트, `g p`(파이프라인)·`g c`(거래처) 이동, `n q`(새 견적서) | 이슈 트래커 개념 |

앱 셸(모든 `/app` 화면):

```
+--------+-------------------------------------------------------------------+
| NOMAD  | [⌘K 검색·명령]                     잔액 42cr  [결제] [알림] [계정] |
| Docs   +-------------------------------------------------------------------+
|        |                                                                   |
| 홈     |                         (화면 본문)                                |
| 파이프 |                                                                   |
| 라인   |                                                                   |
| 거래처 |                                                                   |
| 프로젝트|                                                                   |
| 문서   |                                                                   |
| ─────  |                                                                   |
| 연동   |                                                                   |
| 설정   |                                                       [채팅 열기] |
+--------+-------------------------------------------------------------------+
```

파이프라인 보드 `/app/pipeline`:

```
+------------------------------------------------------------------------------------------+
| 파이프라인   [보드|표]   필터: [거래처 ▾] [유형 ▾] [담당 ▾] [재생성 필요만]   [+ 프로젝트] |
+--------------+--------------+--------------+--------------+--------------+---------------+
| 리드 3        | 작성 중 4    | 견적 확정 2   | 계약 확정 1   | 검수 완료 1   | 종료 5        |
| 0원           | 12,400,000   | 8,800,000    | 22,000,000   | 5,500,000    |               |
| +----------+ | +----------+ | +----------+ | +----------+ |              |               |
| |쇼핑몰 리뉴|| |사내 ERP   | | |홈페이지   | | |앱 MVP    | |              |               |
| |(주)한빛   || |(주)누리   | | |○○상사     | | |△△랩      | |              |               |
| |문서 0     || |3,575,000 | | |4,400,000 | | |22,000,000| |              |               |
| +----------+ | |열린 문서 2| | |다음: 계약서| | |다음: 검수 | |              |               |
|              | |재생성 필요1| | +----------+ | +----------+ |              |               |
|              | +----------+ |              |              |              |               |
+--------------+--------------+--------------+--------------+--------------+---------------+
```

| 요소 | 동작 |
|---|---|
| 단계 | 뷰 `docs.project_pipeline.stage`(01장 DC-F-047). 저장 값이 아니라 문서 상태에서 계산하므로 문서를 확정하면 카드가 스스로 옮겨진다(Realtime `documents` 이벤트 → 보드 재조회, 카드 이동 `--motion-slow`) |
| 카드 | 프로젝트명, 거래처, 합계(`project_totals.total_krw`, tabular 숫자), 열린 문서 수, 재생성 필요 배지(경고색 + 아이콘 + 텍스트), "다음 할 일" 한 줄(예: 다음 = 계약서 생성). 클릭 → 프로젝트 홈 |
| 열 머리 | 단계명, 카드 수, 합계. 종료 열은 접힘이 기본 |
| 끌어 놓기 | 하지 않는다. 카드를 끌면 "이 단계는 문서가 정합니다: 견적서를 확정하면 이동합니다" 툴팁. 키보드 사용자는 Enter로 카드 열기 |
| 표 보기 | 같은 데이터를 Table(compact)로. 열: 이름, 거래처, 단계, 합계, 열린 문서, 재생성 필요, 수정일. 정렬·필터는 URL 쿼리(`?stage=quoted&party=...`)에 남아 링크로 공유된다 |
| 빈 상태 | "아직 프로젝트가 없습니다. 거래처를 고르고 체크리스트로 시작하세요" + [첫 프로젝트 만들기] |

거래처 360 `/app/parties/[id]`(HubSpot식 3단):

```
+--------------------+-----------------------------------------+---------------------+
| (주)한빛            | 활동                                    | 프로젝트 2           |
| 사업자 123-45-67890 | 10/14 견적서 QT-2026-0003 확정           | 쇼핑몰 리뉴얼 견적확정|
| 대표 김○○           | 10/13 과업지시서 v2 생성                 | 앱 MVP     리드       |
| 담당 이○○ 메일·전화  | 10/12 RFP 업로드 → 후보 14개             |---------------------|
| 메모               | 10/10 프로젝트 생성                      | 문서 5 (확정 2)      |
| [편집]             | [더 보기]                                | 합계 7,975,000원     |
+--------------------+-----------------------------------------+---------------------+
```

| 요소 | 동작 |
|---|---|
| 활동 | 뷰 `docs.project_activity`를 거래처의 프로젝트로 모아 최근 순 20건, 무한 스크롤 없음([더 보기]) |
| 오른쪽 카드 | 프로젝트(단계 lozenge), 문서 수, 합계. 연동 시(Phase 2) HubSpot 회사 링크 |
| 개인정보 | 담당자 연락처는 member 이상만 원문, viewer는 가림(제안) |

커맨드 팔레트(⌘K / Ctrl+K, 상단 검색 칸 클릭도 같음):

| 구역 | 내용 |
|---|---|
| 검색 | 프로젝트·거래처·문서(제목, 문서번호, 요구사항 코드 `FR-003`). 조직 안에서만, 서버 검색 API(레이트 리밋) |
| 명령 | 새 프로젝트, 새 견적서(현재 프로젝트), 문서 묶음 만들기, 체크리스트 이어서, 파이프라인 열기, 채팅 열기. viewer에게 쓰기 명령은 보이지 않는다 |
| 최근 | 최근 연 5개 |
| 키보드 | ↑↓ 이동, Enter 실행, Esc 닫기, `g p`/`g c`/`g d` 이동 단축키(설정에서 끌 수 있음) |

프로젝트 홈 상단에는 파이프라인 단계 진행 막대(리드 → 작성 중 → 견적 확정 → 계약 확정 → 검수 완료)를 두고, 지금 단계와 "다음 할 일"을 같은 규칙으로 보여 준다.

### 3.27 문서 생성 단계별 진행 애니메이션 (DC-F-048)

목적: 생성이 진행되는 동안 무엇이 실제로 일어나는지 보여 줘 기다림을 신뢰로 바꾼다. 데이터: Realtime `docs.generation_runs`(status, `progress` = `{stage, section_key, step, total, at}`), `core.jobs`(대기 순번). 진행 값은 ai-service가 그래프 노드 경계에서 `docs.report_generation_progress`로만 쓴다. 화면은 시간으로 가짜 진행률을 만들지 않는다.

단일 문서 오버레이:

```
+---------------------------------------------------------+
| 과업지시서를 만들고 있습니다                    [닫기] |
|                                                         |
|  ● 대기열        ✓                                      |
|  ● 자료 모으기   ✓  요구사항 14 · 비용 9 · 일정 3        |
|  ● 섹션 작성     …  [개요 ✓][과업 범위 ▓▓░][요구사항 ][일정 ][산출물 ][금액 ] |
|  ○ 문서 조립                                            |
|  ○ 검사(lint)                                           |
|                                                         |
|   +-----------------+   ← 용지 위에 섹션 줄이 차례로    |
|   | ▬▬▬▬▬▬         |      채워지고(작성 중 섹션은 줄이   |
|   | ▬▬▬▬           |      왼쪽에서 오른쪽으로 그려짐),   |
|   | ▬▬▬░░░         |      검사 단계에서 괘선이 훑고      |
|   |                 |      지나간다                      |
|   +-----------------+                                   |
|  대기 중일 때만 [취소]          예상 차감 6크레딧        |
+---------------------------------------------------------+
```

| 단계(stage) | 화면 표현 | 서버 근거 |
|---|---|---|
| queued | "대기열 n번째"(같은 큐 앞 잡 수), 용지 흐림. [취소] 보임 | `generation_runs.status='queued'` |
| collecting | 정본 요약 숫자(요구사항·비용·일정 개수)가 한 줄씩 나타남 | `progress.stage='collecting'` |
| drafting | 섹션 칩이 차례로 켜지고 `section_key` 칩이 진행 중. 용지에 해당 섹션 줄 막대가 그려짐. template 섹션은 즉시 채움, ai 섹션은 줄이 천천히 | `progress.section_key`, `step/total` |
| assembling | 섹션 막대가 한 장으로 모여 정렬 | `progress.stage='assembling'` |
| linting | 괘선 색 선이 위에서 아래로 한 번 훑음, 오류·경고 개수 배지 | `progress.stage='linting'` |
| done | 용지가 편집기로 전환(`--motion-stage`), "버전 n 저장됨" 토스트. 직인은 쓰지 않는다(확정 때만) | `status='succeeded'` |
| failed | 실패 단계에서 멈추고 경고색 테두리, "원인 · 환불 n크레딧 · [다시 시도]" | `status='failed'`, `error` |
| canceled | "취소했습니다. n크레딧을 돌려드렸습니다" | `status='canceled'` |

패키지 진행(`/package`): 문서마다 가로 레인 1줄(SectionLane). 의존 순서 그룹(1 → 6)마다 레인이 차례로 켜지고 같은 그룹은 동시에 진행한다. 위쪽에 전체 단계 막대(문서 완료 수 / 전체)와 남은 예상 크레딧. 실패한 레인 아래 하류 레인은 "멈춤 · 환불됨"으로 흐려진다.

| 규칙 | 내용 |
|---|---|
| 연결 | Realtime 구독(`generation_runs` 행 id). 끊기면 3초 간격 폴링으로 대체, 다시 연결되면 폴링 중지 |
| 재진입 | 오버레이를 닫아도 생성은 계속된다. 상단 명령 막대에 진행 칩(“생성 2건”)을 두고, 다시 열면 현재 단계부터 보인다 |
| reduced-motion | 애니메이션 없이 단계 목록의 체크만 바뀐다. 섹션 칩은 텍스트 상태(완료/진행 중/대기) |
| 접근성 | 단계 변화는 `aria-live="polite"` 한 줄 요약("섹션 작성 중: 과업 범위, 2/6"), 포커스는 이동하지 않는다 |
| 성능 | 애니메이션은 transform·opacity만, 60fps 목표, 진행 이벤트는 200ms 단위로 묶어 렌더 |
| 금지 | 시간 기반 가짜 퍼센트, "AI가 생각 중" 같은 의인화 문구, 실제 단계와 다른 순서 |

## 4. 메인페이지(랜딩) 디자인 방향

`docs/products/_design-guide/DESIGN_PRINCIPLES.md` 1~5단계(`:27-131`)를 따른다.

### 4.1 레퍼런스 (URL은 `docs/products/_design-guide/REFERENCES.md`에 있는 것만)

`REFERENCES.md`에 nomad-docs 절이 있다(`docs/products/_design-guide/REFERENCES.md:309`, 2026-10-14 C-4 반영). 아래 표는 그 절과 같다. 항목은 같은 파일의 다른 제품 절에서 확인된 URL 중 문서·생산성 도구에 맞는 것을 골랐고, 원래 제품과 다른 참고 포인트로 쓴다(`docs/products/_design-guide/REFERENCES.md:23`). 마지막 열은 원래 제품 절의 위치다. 로그인 후 CRM 패턴(3.26절)의 서비스 URL도 같은 절에 있고, `HERO_3D.md` 5장 소재 행과 6장 영상 단계도 반영됐다(06장 6절 C-4).

| 구분 | 제목 | 출처 | URL | 참고 포인트(가져올 것) | 가져오지 않을 것 | 적용 화면 | REFERENCES.md 위치 |
|---|---|---|---|---|---|---|---|
| 랜딩 | Superlist (SOTD) | Awwwards | https://www.awwwards.com/sites/superlist | 생산성 도구의 실제 제품 화면을 첫 화면 주인공으로 두는 구성. 여기서는 체크리스트 화면 한 장 | 할 일 관리 카피, 브랜드 색 | 히어로 오버레이 옆 체크리스트 실제 화면 | study-note 절 `:258` |
| 랜딩 | Codapress Publishing (Honorable Mention) | Awwwards | https://www.awwwards.com/sites/codapress-publishing | 결과물을 히어로의 주인공으로 두는 방식. 여기서는 책 대신 문서 묶음(8장 서류) | 원형 캐러셀과 GSAP 스크롤 연출 반복 | 히어로 마지막 프레임, "만들어지는 문서" 섹션 | flora-publishing 절 `:51` |
| 앱 | Lexi - AI Writer Assistant Web App Saas Platform | Dribbble | https://dribbble.com/shots/22398012-Lexi-AI-Writer-Assistant-Web-App-Saas-Platform | 좌측 사이드바 + 본문 편집 영역의 작업 공간 구조 | 모든 패널을 같은 둥근 카드로 나누는 SaaS 카드 키트 | 프로젝트 셸, 문서 편집기 | flora-publishing 절 `:55` |
| 앱 | Scribbler - Writing App | Dribbble | https://dribbble.com/shots/15364448-Scribbler-Writing-App | 본문 폭과 도구 노출을 최소화한 편집 화면 | 종이 질감 배경, 크림 배경 | 문서 편집기 본문 영역 | flora-publishing 절 `:53` |
| 앱 | Table data view for admin dashboard | Dribbble | https://dribbble.com/shots/22988094-Table-data-view-for-admin-dashboard | 행 선택 상태, 페이지네이션, 페이지당 행 수 | 행 호버 전환 효과 | 비용 항목, 요구사항 표, 버전 이력, 내보내기 기록 | admin-suite 절 `:176` |

Dribbble 링크는 인용 전에 브라우저에서 한 번 열어 본다(`docs/products/_design-guide/REFERENCES.md:30`).

### 4.2 브리프 (DP 2단계, 제안: 사용자 확인 필요)

| 항목 | 내용 |
|---|---|
| 주제 | 외주 개발 실무 서류: 견적서, 과업지시서, 요구사항정의서, WBS, 화면목록, 개발용역계약서, 검수확인서, 회의록, 추적표. 결재 서류철, 문서번호, 직인, 간인, 괘선 표 |
| 대상 | 1인 개발자·프리랜서, 5~30인 외주 개발사의 PM. 계약 전후로 같은 숫자를 여러 문서에 손으로 옮겨 적는 사람 |
| 주된 일 | "체크 하나가 여러 문서의 같은 자리를 함께 채운다"를 첫 화면에서 보여 주고 무료 가입으로 이끈다 |
| 고유 어휘 | 체크박스, 서류 낱장이 쌓이는 묶음, 문서번호(QT-2026-013), 인주색 직인, 괘선 표의 합계 행 |
| 피할 인상 | 법률 서비스처럼 보이는 저울·법봉 그림, 보라 그라디언트 AI 툴(UUPM 안티패턴 `docs/products/_design-guide/DESIGN_PRINCIPLES.md:133`), 계약서 "보장" 문구, 크림색 + 세리프 + 테라코타(기본값 1) |

### 4.3 토큰 플랜 (DP 4단계, 제안)

| 이름 | hex | 역할 |
|---|---|---|
| 서류철 | #E6EBE7 | 페이지 배경(라이트). 회녹색 서류철 판지. 크림 계열 아님 |
| 용지 | #FBFCFA | 문서 지면, 입력 영역, 표 바탕 |
| 먹회 | #1D2421 | 본문 글자(순수 검정 대신 의도한 회녹 먹색) |
| 괘선 | #8A948F | 표 괘선, 구분선, 메타 정보(본문 글자에 쓰지 않음) |
| 결재청 | #1F4E8C | 주 행동(버튼, 링크, 포커스 링). 용지 대비 4.5:1 이상(구현 시 측정) |
| 인주 | #B3262E | 직인·확정 표시와 3D 히어로의 도장 한 곳에만(대담함의 위치). 앱 UI 오류 표시에 쓰지 않는다 |

| 상태 | hex | 비고 |
|---|---|---|
| 성공 | #1F7A45 | 확정 완료, compliance pass |
| 경고 | #8F5B00 | WARN, 재생성 필요 |
| 오류 | #A3361A | 인주와 구분되도록 갈색 쪽으로 옮김. 항상 아이콘 + 텍스트 |
| Diff 추가 / 삭제 | #DCEFE2 / #F6DEDA(바탕) | 밑줄·취소선과 "추가/삭제" 텍스트를 함께 |

다크 모드는 앱 화면만(배경 #141A17, 글자 #E3E8E4로 파생, 3단계 사람 검토에서 확정). 랜딩 기본은 라이트.

| 역할 | 서체 | 크기/굵기(제안) |
|---|---|---|
| 디스플레이·UI | Spoqa Han Sans Neo(OFL, 라이선스 원문 구현 시 확인) | 히어로 44/54px 700, 자간 -1%. 섹션 제목 28px 700. UI 본문 15/24px 400 |
| 문서 지면(편집기 본문, 랜딩 문서 미리보기) | Noto Serif KR | 15/26px 400. PDF 렌더(WeasyPrint, Noto CJK)와 같은 계열로 맞춰 화면과 출력의 차이를 줄인다 |
| 숫자(금액, 문서번호) | UI 서체의 tabular-nums. 지원하지 않으면 IBM Plex Sans KR 500으로 대체(미확인) | 모노스페이스 라벨을 쓰지 않는다(기본값 5) |

| 원칙 | 내용 |
|---|---|
| 1 | 히어로의 주인공은 실제 결과물(문서 묶음)이다. 마지막 프레임은 실제 템플릿으로 렌더한 견적서 첫 쪽 |
| 2 | 대담함은 인주 직인 한 곳에만. 나머지는 서류철·용지·먹의 조용한 대비 |
| 3 | 숫자 통계·후기·보장 문구 없이 무엇을 만드는지만 말한다 |
| 4 | 기능 카드 격자 대신 "체크 하나 → 바뀌는 자리" 표 하나 |
| 5 | 한 화면에 CTA 하나 |

### 4.4 레이아웃 안 비교 (DP 4단계)

A안: 체크리스트 → 문서 묶음 좌우 연결형(채택)

```
+------------------------------------------------------------------+
| NOMAD Docs                        요금   만들어지는 문서   로그인  |
+------------------------------------------------------------------+
| [3D 장면: 왼쪽 체크리스트 판, 오른쪽에 서류 낱장이 쌓이는 묶음]      |
|                                                                  |
| 체크리스트에 답하면                     +--------------------+      |
| 견적서부터 검수확인서까지                | 견적서  QT-2026-013 |      |
| 같은 숫자로 채워집니다.                  | 합계 41,800,000원   |      |
| (좌측 정렬, HTML 오버레이)               |        [인주 직인]  |      |
| [무료로 문서 묶음 만들기]  샘플 PDF 보기  +--------------------+      |
+------------------------------------------------------------------+
| 체크 하나가 바뀌면 (표: 체크 항목 | 요구사항 | 화면 | 비용 | 조항)   |
+------------------------------------------------------------------+
| 만드는 순서: 정보 입력 > 체크리스트 > 문서 묶음 > 확인·확정 > PDF    |
| (실제 순서라 번호 허용)                                            |
+------------------------------------------------------------------+
| 계약서 초안 안내(법률 자문 아님) . 요금(Free / Pro / 크레딧팩)        |
+------------------------------------------------------------------+
```

B안: 중앙 헤드라인 + 앱 스크린샷 + 기능 카드 6개(기각)

```
+------------------------------------------------------------------+
| NOMAD Docs                                             로그인      |
+------------------------------------------------------------------+
|                 큰 중앙 헤드라인 2줄                                |
|                 [시작하기]                                         |
|          [대시보드 스크린샷 기울인 목업]                             |
+------------------------------------------------------------------+
| 기능 카드 6개(같은 크기, 같은 반경, 같은 그림자)                     |
+------------------------------------------------------------------+
```

B안 기각 이유: 중앙 헤드라인 + 기울인 목업 + 같은 카드 6개는 어느 SaaS에나 나오는 구성(기본값 4)이고, "체크가 문서로 이어진다"는 주제를 보여 주지 못한다.

### 4.5 생성형 기본값 회피 검토 (DP 5단계, `docs/products/_design-guide/DESIGN_PRINCIPLES.md:116-131`)

| # | 기본값 | 이 계획의 상태 |
|---|---|---|
| 1 | 크림 배경 + 고대비 세리프 + 테라코타 | 배경은 회녹 서류철, 강조는 결재청. 세리프는 문서 지면에만(디스플레이 아님). 인주는 붉지만 직인 한 곳에만 쓰고 넓은 강조색이 아니다 |
| 2 | 거의 검정 + 애시드 그린/버밀리언 | 사용 안 함. 랜딩은 라이트 |
| 3 | 헤어라인 브로드시트 | 괘선은 문서 표 안에만, 다단 신문 구성 없음 |
| 4 | SaaS 카드 키트 | 기능 카드 없음. 변경 영향 표 하나. 앱도 표·패널 중심, 반경은 위계별(`--radius-control`, `--radius-sheet`) |
| 5 | 대문자 아이브로, 가운데 점 메타, `→` 버튼, 모노 라벨 | 사용 안 함. 버튼은 동작을 말함("문서 묶음 만들기") |
| 6 | 큰 숫자 히어로 | 사용 안 함. 히어로의 금액은 예시 견적서 안의 값이며 성과 통계가 아니다("예시 문서" 표시) |
| 7 | 헤드라인 한 단어 강조 | 사용 안 함 |
| 8~9 | 대문자 라벨, 불필요한 라벨 | 사용 안 함 |
| 10 | 의미 없는 번호 | "만드는 순서"만 실제 순서라 번호 사용 |
| 11 | 섹션 페이드인, 모든 카드 호버 전환 | 없음. 모션은 히어로 3D 연출 하나 |
| 12 | 습관적 기본 서체 | Spoqa Han Sans Neo + Noto Serif KR(문서 지면, PDF와 일치시키려는 이유) |

### 4.6 3D 히어로 (체크가 접혀 서류 묶음이 되고 직인이 찍힌다)

정본은 `docs/products/_design-guide/HERO_3D.md`(기기 구성 `:5-15`, 저사양 판정 `:17-30`, 성능 예산 `:32-41`, 구현 규칙 `:43-54`, 공용 키트 `:56-68`, 수용 기준 `:70-75`)이고, 이 절은 제품 소재와 장면만 정한다. `HERO_3D.md` 5장 표(`:77-92`)에 nomad-docs 행이 없으므로 아래 소재를 C-4로 추가 요청한다.

| 항목 | 내용 |
|---|---|
| 소재 | 체크리스트 판의 체크 표시가 하나씩 접혀 서류 낱장이 되고, 낱장이 의존 순서대로 묶음으로 쌓인 뒤 맨 위 견적서에 인주 직인이 찍힌다 |
| 드러내는 의미 | 입력 한 번(체크)이 여러 문서가 되고, 마지막에 사람이 확정한다 |
| 모바일 절충안 | 체크 3개 → 낱장 3장 쌓임, 직인은 2D(SVG) 오버레이 |

| 기기 | 구성(HERO_3D 1절) | nomad-docs 장면 |
|---|---|---|
| PC(1280px 이상) | 풀 3D. 제목·CTA·샘플 PDF 링크는 HTML 오버레이 | 체크 8개 → 낱장 8장(7종 + 추적표) |
| 태블릿(768~1279px) | 풀 3D, DPR 상한 1.5, 터치 드래그 시점 이동 | PC와 같음 |
| 모바일(767px 이하) | HTML 즉시 표시 + 가벼운 3D를 첫 화면 뒤 자동 로드(로딩 전 저사양 판정) | 체크 3 → 낱장 3, 직인 SVG |
| 대체 | WebGL 미지원, 저사양(로딩 전 판정), `prefers-reduced-motion`, 데이터 절약 모드, `NEXT_PUBLIC_HERO3D_ENABLED=false`(킬 스위치), 로딩 뒤 30fps 미만 지속(런타임 강등) | 같은 구도의 정지 렌더 이미지(`apps/nomad-docs/public/hero/checklist-to-docs.avif`, WebP 대체, 크기 지정으로 레이아웃 이동 없음) + HTML 견적서 첫 쪽 |

장면 연출(PC·태블릿):

| 단계 | 계기 | 3D | HTML |
|---|---|---|---|
| 0 첫 화면 | 페이지 로드 | 없음. 정지 이미지 자리 | 헤드라인(LCP 요소), CTA |
| 1 대기 | 동적 import 완료 | 왼쪽 체크리스트 판(용지 #FBFCFA, 괘선 줄)에 빈 체크박스 8개. 아주 느린 기울기 흔들림(약 60초 주기, 제안). [움직임 멈춤] 토글 | 변화 없음 |
| 2 체크 | [체크해 보기] 버튼 또는 스크롤 진입 | 체크 표시가 위에서부터 0.15초 간격으로 들어간다(제안) | 변화 없음 |
| 3 접힘 | 각 체크 직후 | 체크된 줄이 판에서 떨어져 접히며 A4 비율(210:297) 낱장으로 펼쳐진다 | 변화 없음 |
| 4 쌓임 | 3단계 직후 | 낱장이 오른쪽으로 날아가 묶음으로 쌓인다. 쌓이는 순서는 패키지 의존 순서(요구사항정의서 → ... → 추적표) | 변화 없음 |
| 5 직인 | 4단계 끝 | 맨 위 낱장에 인주 #B3262E 원형 직인이 한 번 찍힌다(유일한 대담한 순간), 이후 렌더 중단(`frameloop="demand"`) | 맨 위 낱장 위치에 실제 템플릿으로 렌더한 견적서 첫 쪽 이미지 + "예시 문서" 표시 |

reduced-motion이면 0~5단계 없이 정지 이미지와 HTML 견적서만 보인다.

| 요소 | 토큰(4.3절) | 비고 |
|---|---|---|
| 장면 배경 | 서류철 #E6EBE7 | 그라디언트 없음 |
| 체크리스트 판, 낱장 | 용지 #FBFCFA | 얇은 박스. 글자 대신 먹회 낮은 불투명도 줄 막대 |
| 체크박스 테두리, 표 괘선 | 괘선 #8A948F | 선 지오메트리 |
| 체크 표시 | 결재청 #1F4E8C | 체크 표시에만 |
| 직인 | 인주 #B3262E | 3D에서 인주를 쓰는 유일한 요소. 직인 안 글자 없음(실존 회사 직인처럼 보이지 않게) |

| 항목 | nomad-docs 결정 |
|---|---|
| 위치 | `apps/nomad-docs/src/components/hero3d/`(`ChecklistBoard`, `SheetFold`, `DocStack`, `SealStamp`, `MobileStack`, `StaticFallback`, `useHeroTier`), 정지 이미지 `apps/nomad-docs/public/hero/`. 디렉토리는 02장 2절과 맞춘다 |
| 형상 | 코드 생성 도형(Box, Plane, Line, Cylinder). 외부 glTF·텍스처·3D 글자 없음 |
| 로딩·렌더 | `next/dynamic`(`ssr: false`), 화면 밖·탭 숨김이면 정지(HERO_3D 3절) |
| 저사양 판정 | 로딩 전에 `saveData`, reduced-motion, WebGL 시험 생성, GPU 등급(렌더러 문자열), `deviceMemory`·`hardwareConcurrency`(4 이하 낮음)를 조합. `deviceMemory`가 없는 Safari·Firefox에서 undefined를 고사양으로 보지 않는다(`docs/products/_design-guide/HERO_3D.md:17-30`) |
| 태블릿 기울기 | iOS Safari는 [기울여 보기] 버튼 탭으로 권한 요청, 거부·미지원이면 터치 드래그만 |
| 예산 | 3D 번들+에셋 PC·태블릿 1MB, 모바일 300KB 이하, 60fps / 30fps 이상, LCP 2.5초, 첫 화면 전 3D 초기화 0ms(HERO_3D 2절). 모바일 장면은 three.js 코어 + 박스 3개 |
| 공용 키트 | `packages/ui-3d`(제안) 위에 소재만 얹는다. 키트가 없으면 같은 인터페이스로 `hero3d/` 안에 두고 키트가 생기면 옮긴다 |
| 피할 인상 | 저울·법봉, 보라/핑크 그라디언트, 별 파티클, 네온 그리드, 지구본(`docs/products/_design-guide/HERO_3D.md:53`) |
| 접근성 | 캔버스 `aria-hidden`, 견적서 예시는 HTML(이미지에는 대체 텍스트), [움직임 멈춤] 키보드 조작 |
| 검증 | PC·태블릿·모바일 스크린샷 3종, Lighthouse 모바일·데스크톱, 프레임 측정, 고문(Fable) 디자인 검토(`docs/products/_design-guide/HERO_3D.md:70-75`) |

#### 4.6.1 3D 영상 레이어 (DC-F-049, 2026-10-14 추가)

메인 페이지는 "동적 3D 장면 + 3D 영상" 두 겹이다. 실시간 장면(위 4.6)과 같은 소재·토큰 색을 쓴 미리 렌더한 시네마틱 영상을 함께 두어, 실시간 3D를 못 돌리는 기기에서도 움직이는 3D를 보여 준다. `HERO_3D.md` 6장 "선택 단계: 3D 영상"이 이 구성의 공통 기준이다(C-4 반영 2026-10-14).

| 단계(위에서부터 시도) | 조건 | 보여 주는 것 |
|---|---|---|
| 1 실시간 3D | PC·태블릿, 저사양 아님, WebGL 정상, reduced-motion 아님, 킬 스위치 켜짐 | 4.6 장면(인터랙티브: 포인터에 따라 묶음 시점이 조금 돈다, 스크롤 진입 시 체크 시작) |
| 2 3D 영상 | 모바일, 저사양, WebGL 실패, 런타임 30fps 미만 강등 | `hero-loop` 영상(장면 0~5단계를 카메라가 한 바퀴 돌며 보여 주는 8~12초 무음 루프) |
| 3 정지 이미지 | reduced-motion, 데이터 절약 모드, 영상 로드 실패, `NEXT_PUBLIC_HERO_VIDEO_ENABLED=false` | 4.6 정지 렌더 이미지 + HTML 견적서 첫 쪽 |

| 항목 | 결정 |
|---|---|
| 파일 | `apps/nomad-docs/public/hero/hero-loop.mp4`(H.264, 1920x1080, 2MB 이하), `hero-loop.webm`(VP9), 모바일 `hero-loop-m.mp4`(1080x1350 세로, 1MB 이하), 포스터 `hero-loop-poster.avif`(첫 프레임, LCP 요소) |
| 재생 | `<video autoplay muted loop playsinline preload="metadata" poster>`. 화면 밖·탭 숨김이면 일시정지(IntersectionObserver, visibilitychange). 재생/일시정지 버튼(키보드 조작) 제공 |
| 제작 | 실시간 장면(R3F)을 같은 코드로 오프라인 렌더해 프레임을 뽑고 ffmpeg로 인코딩한다(`scripts/nomad-docs/hero-record/`, DC-06-045). 장면이 바뀌면 영상도 다시 만든다. 생성형 영상 도구는 D-17 확인 전에는 쓰지 않는다 |
| 내용 규칙 | 실존 인물·실존 회사 직인·가상 후기·숫자 통계 없음. 마지막 프레임은 "예시 문서" 표시가 있는 견적서 첫 쪽. 자막·소리 없음 |
| 두 번째 영상 | 4.4 A안의 "체크 하나 → 바뀌는 자리" 표 옆에 6초 짧은 영상(체크 → 요구사항·견적·계약서 칸이 동시에 바뀜). 스크롤로 화면에 들어올 때 한 번 재생, reduced-motion이면 정지 프레임 |
| 예산 | 첫 화면 JS에 영상·3D 코드 0(동적 import), LCP 2.5초(포스터), CLS 0(크기 고정), 영상은 첫 화면 뒤 로드 |
| 검증 | 3기기 스크린샷 + 영상 재생 확인, Lighthouse 모바일, 자동재생 차단 브라우저(저전력 모드 iOS)에서 포스터 + 재생 버튼 표시 확인 |

### 4.7 카피 (금지 문구 통과)

금지 목록은 `docs/products/_platform-core/DOC_TEMPLATE.md:98`과 01장 6절이다. 랜딩·앱 문구 모두 아래를 통과해야 한다.

| 위치 | 문구(제안) | 점검 |
|---|---|---|
| 헤드라인 | 체크리스트에 답하면 견적서부터 검수확인서까지 같은 숫자로 채워집니다 | 기능 설명. 수치·보장 없음 |
| 보조 문장 | 회사와 거래처 정보를 한 번 넣고 체크하면 요구사항, 화면 목록, 비용, 계약 조항이 함께 정리되고 문서 묶음과 PDF로 나옵니다 | 설명 우선(`docs/products/_design-guide/DESIGN_PRINCIPLES.md:198`) |
| CTA | 무료로 문서 묶음 만들기 / 샘플 PDF 보기 | 누르면 일어나는 일 |
| 변경 영향 표 제목 | 체크 하나가 바뀌면 이 자리들이 함께 바뀝니다 | - |
| 계약서 안내(필수) | 개발용역계약서는 표준 조항으로 만든 초안이며 법률 자문이 아닙니다. 서명 전 변호사 검토를 권합니다. AI는 계약 조항을 만들거나 고치지 않습니다 | 법적 고지 |
| AI 안내 | 서술 문단 일부는 AI가 초안을 씁니다. 금액, 합계, 기간, 요구사항 번호는 서버가 계산합니다 | 사실 설명 |
| 요금 | Free 가입 시 50크레딧, 매월 30크레딧. 문서 묶음 한 번에 약 28크레딧(01장 단가, 제안) | 정책값이며 성과 수치 아님. 단가 확정(D-4) 후 갱신 |

| 쓰지 않는 표현 | 이유 |
|---|---|
| 가상 후기, 고객사 로고, 별점 | 가상 후기 금지 |
| "N개 회사가 사용", "문서 N만 건 생성", "작성 시간 90% 단축", "30분 만에" | 검증되지 않은 수치(30분은 내부 KPI 목표일 뿐 광고 문구로 쓰지 않는다) |
| "법적 효력 보장", "분쟁 걱정 없는 계약서", "변호사 검토 필요 없음", "100% 정확" | 보장 표현, 법률 단정 |
| 타사 상표를 우리 기능처럼 쓰는 것(HubSpot 연동은 Phase 2 출시 전 랜딩에 쓰지 않음) | 상표 오용, 미출시 기능 |

## 5. 상태, 오류, 빈 화면

HTTP 매핑은 설계 기준서 7장과 `docs/products/_platform-core/CORE_SPEC.md:424`를 따른다.

| 상황 | 표시 | 문구 예 |
|---|---|---|
| 생성 잡 진행(Realtime) | 문서별 상태 칩 + 진행 메시지(`core.jobs` progress). 구독이 끊기면 10초 폴링(제안) | "과업지시서 서술 섹션 작성 중(3/5)" |
| 패키지 진행 | 표 행마다 칩, 상단 "4/8 완료" | "견적서 완료. 과업지시서를 만드는 중입니다" |
| RFP 추출·회의록 진행 | 그래프 단계 표시 | "요구사항 후보를 찾는 중입니다" |
| 크레딧 부족(402 `CR001`) | 모달: 필요량, 잔액, 팩 3종, Pro | "크레딧이 6 부족합니다. 크레딧팩을 구매하면 바로 이어서 만듭니다" |
| 플랜 한도(`DC006`) | 잠금 아이콘 + 인라인 안내 + 요금 링크 | "Free는 프로젝트 2개까지입니다. 쓰지 않는 프로젝트를 보관하거나 Pro로 바꾸세요" / "DOCX는 Pro에서 받을 수 있습니다" / "이 문서 유형은 Phase 2에 열립니다" |
| 이미 생성 중(`DC002`) | 버튼 비활성 + 띠 | "이 문서는 지금 만드는 중입니다. 끝나면 다시 요청하세요" |
| 상태 전이 위반(`DC001`) | 토스트 + 새로고침 | "프로젝트 상태가 이미 바뀌었습니다. 화면을 새로 불러왔습니다" |
| 확정 문서 수정 시도(`DC003`) | 읽기 전용 전환 | "확정된 문서는 고칠 수 없습니다. 개정본을 만들어 고치세요" |
| 필수 입력 누락(`DC004`) | 누락 목록 + 이동 링크 | "WBS를 만들려면 프로젝트 종료일이 필요합니다 [기간 입력]" |
| compliance FAIL·lint 오류(`DC005`) | 확정 비활성 + 패널 강조 | "검사 오류 1건을 고쳐야 확정할 수 있습니다: 견적 합계와 계약 금액이 다릅니다" |
| compliance WARN(`DC008`) | 확정 대화 상자 체크박스 | "경고 2건을 확인했다고 체크해야 확정할 수 있습니다" |
| lint 오류(편집 중) | 패널 목록, 섹션 옆 아이콘 | "3장 합계 41,800,000원이 계약서 제4조 금액 38,000,000원과 다릅니다 [비용 항목 열기]" |
| 고위험 고지 미동의(`DC007` 428) | 고지 모달(3.22절) | "개발용역계약서를 처음 만들기 전에 안내를 확인해 주세요" |
| 연동 상태 불가(`DC009`) | 연동 행 오류 + 다시 연결 | "HubSpot 연결이 끊겼습니다. 다시 연결하면 밀린 전송을 이어서 합니다" |
| 버전 충돌(`DC010`) | 대화 상자: [최신 버전 보기], [내 변경을 새 버전으로 저장] (최신 위에 다시 저장, 비교 화면 경유) | "다른 곳에서 v4가 먼저 저장되었습니다. 달라진 점을 확인한 뒤 저장하세요" |
| 생성 실패 + 환불 | 문서 칩 오류 + 툴팁 | "과업지시서를 만들지 못했습니다. 6크레딧을 돌려드렸습니다. 다시 만들 수 있습니다" |
| AI 제공자 장애 → 대체 발생 | 메시지·문서 버전 정보에 작은 표시 | "다른 AI 모델로 작성했습니다" |
| AI 실패(모든 제공자) | 오류 띠 + 환불 | "답변을 만들지 못해 1크레딧을 돌려드렸습니다. 잠시 뒤 다시 물어보세요" |
| 국외 이전 미동의 | 채팅·생성 확인 모달 한 줄 | "국내 오픈소스 AI로 처리합니다. 설정에서 바꿀 수 있습니다" |
| 근거 없음 답변 | 안내 + 자료 올리기 링크 | "이 프로젝트 자료에서 근거를 찾지 못했습니다. 아래는 자료 밖 일반 설명입니다" |
| 마이크 권한 거부·미지원 | 마이크 버튼 비활성 + 안내, 텍스트 경로 유지 | "마이크를 사용할 수 없습니다. 텍스트로 입력하거나 녹음 파일을 올리세요" |
| 음성 변환 실패 | 환불 + 다시 말하기 | "말씀을 글로 바꾸지 못했습니다. 크레딧은 돌려드렸습니다. 다시 말해 주세요" |
| 회의 녹음 조각 실패 | 조각별 [다시 시도], 올라간 조각 보존 | "조각 5를 올리지 못했습니다. 연결되면 이어서 올립니다" |
| 파일 업로드 오류 | 파일 행 오류 | "20MB보다 큰 파일은 올릴 수 없습니다" / "파일 형식이 확장자와 다릅니다" |
| 레이트 리밋(429) | 버튼 비활성 + 재시도 시각 | "요청이 많습니다. 14:32 이후 다시 시도하세요" |
| 네트워크 오류 | 토스트, 버전 저장은 재시도 3회(제안), 브라우저 초안 유지 | "저장하지 못했습니다. 작성한 내용은 이 브라우저에 남아 있습니다" |
| 3D 로딩 실패 | 정지 이미지로 조용히 교체 | - |
| 빈 프로젝트 목록 | 버튼 2개 | "아직 프로젝트가 없습니다. 체크리스트로 시작하거나 RFP를 올려 시작하세요" |
| 빈 거래처 | 만들기 + CSV 링크 | "거래처가 없습니다. 직접 추가하거나 CSV로 한 번에 가져오세요" |
| 빈 요구사항 | 체크리스트 링크 | "요구사항이 없습니다. 체크리스트 2단계에서 기능을 체크하면 자동으로 만들어집니다" |
| 빈 비용 항목 | 같음 | "비용 항목이 없습니다. 체크리스트를 적용하거나 단가표를 가져오세요" |
| 빈 문서 목록 | 패키지 링크 | "아직 문서가 없습니다. 문서 묶음을 한 번에 만들어 보세요" |
| 빈 내보내기 | - | "내보낸 파일이 없습니다. 문서 편집기에서 PDF를 만들 수 있습니다" |
| 빈 위키 | 자료 링크 | "용어 페이지가 없습니다. 자료나 회의록을 올리면 당사자와 용어가 정리됩니다" |
| 빈 회의 | 녹음 시작 | "회의 기록이 없습니다. 회의를 녹음하거나 메모를 붙여넣어 회의록을 만드세요" |
| 빈 추적표 | 요구사항 링크 | "연결할 요구사항이 없습니다" |
| DOCX 준비 전(C-1) | DOCX 버튼 비활성 | "DOCX 내보내기는 준비 중입니다. PDF를 이용하세요" |
| 계약서 게이트(D-3) | 계약서 행 비활성 | "개발용역계약서는 법무 검토를 마친 뒤 열립니다" |

## 6. 접근성과 반응형

| 항목 | 기준 |
|---|---|
| 키보드: 마법사 | Tab으로 질문 이동, Space로 체크, 방향키로 라디오·체크 그룹 안 이동, Ctrl+Enter로 [적용], Alt+방향키로 이전/다음 단계(제안). 단계 탭은 `aria-current="step"` |
| 키보드: 편집기 | Ctrl+S 버전 저장, Ctrl+K 선택영역 툴바 열기(제안), Diff 카드는 Tab으로 이동 후 Enter 수락 / Esc 거절, 잠긴 섹션은 Tab 순서에서 읽기 전용으로 안내("표준 서식, 고칠 수 없음") |
| 키보드: 보드·표 | 요구사항 보드와 화면 정렬은 드래그의 키보드 대안(선택 후 방향키 이동, Atlassian식). 표 행 선택은 Space |
| 포커스 | `:focus-visible` 결재청 포커스 링 토큰, 모달·시트 포커스 트랩과 Esc 닫기, 닫으면 여는 버튼으로 복귀 |
| 대비 | 본문 4.5:1 이상(라이트·다크). 괘선 색은 글자에 쓰지 않음. 인주는 장식·직인에만 |
| 색만으로 구분 금지 | 상태 lozenge, Diff(밑줄·취소선 + 텍스트), 추적표 빈칸, 필수 표시 모두 아이콘·텍스트 병기 |
| 스크린 리더 | 생성 진행·패키지 표·RFP 추출 단계는 `aria-live="polite"`, 채팅 스트리밍은 완료 때 한 번 읽음, 녹음 중 상태 알림 |
| 모션 | `prefers-reduced-motion`이면 3D 대신 정지 이미지, 앱 안 전환 모션 제거 |
| 음성 | 음성은 텍스트 입력의 대안이다. 모든 기능은 음성 없이 쓸 수 있다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:110`). 회의 녹음도 파일 올리기·텍스트 붙여넣기 경로가 있다 |
| 폭 | 375/768/1024/1440px 확인, 가로 스크롤 없음(넓은 표는 표 영역 안에서만 가로 스크롤) |
| 데스크톱 우선 | 문서 편집기, 버전 비교 나란히 보기, 추적표, 운영자 카탈로그, 필드 매핑은 1024px 이상 기준으로 설계 |
| 모바일 지원 범위 | 767px 이하에서 지원: 대시보드, 체크리스트 마법사(효과 미리보기는 하단 시트로), 문서 읽기·검토(편집기는 읽기 전용 + "편집은 넓은 화면에서 할 수 있습니다", 제안), RFP 추출 검토(원문은 탭 전환), 회의 녹음, 채팅·음성, 확정 대화 상자, 내보내기 받기 |
| 모바일 레이아웃 | 사이드바는 드로어, 채팅·상세 패널은 전체 화면 시트, 마법사 단계 표시는 "2/3" |
| 3D 히어로 | 캔버스 `aria-hidden`, CTA·견적서 예시는 3D 로딩 전에 HTML로 사용 가능, [움직임 멈춤] 토글 |

## 7. 로그인 화면의 인증 단계 (2026-10-14 추가, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2.1, 5.2, 7.1, 7.2, 7.3절이다. 화면은 서버 컴포넌트가 `listLoginOptions('docs')`(02장 9.2절) 결과로만 그리며, 다른 화면은 단계를 모른다.

### 7.1 단계별 로그인 화면 구성

| 단계 | `/login` | `/signup`, `/reset-password` | 공통 표시 |
|---|---|---|---|
| A(Mock, 로컬 전용) | "개발용 로그인" 패널: 페르소나 버튼(owner, admin, member, viewer, outsider, no_app, suspended, ops, Pro 구독자 `pro`, 05장 10절), 현재 로그인 페르소나, 로그아웃. 버튼은 `POST /api/dev/login { persona, next }` 후 응답 경로로 이동. 제공자 버튼·이메일 폼 없음 | 렌더하지 않는다(404) | 모든 화면 상단 고정 배지 `MOCK AUTH · 로컬 전용`(대비 4.5:1, 닫기 없음). `isMockAuthAllowed()`가 거짓이면 패널·배지 코드를 렌더하지 않는다 |
| B(Google + 이메일) | "Google로 계속하기" 버튼(위) + 구분선 + 이메일·비밀번호 폼(01장 DC-F-001, D-20) + "비밀번호를 잊으셨나요" 링크 | 이메일 가입(약관 동의 체크, 메일 인증 안내), 재설정 메일 요청·새 비밀번호 입력 | 배지 없음. OAuth는 가입과 로그인이 같은 버튼이라 `/signup`에도 같은 Google 버튼을 둔다 |
| C1·C2(카카오·네이버) | B 구성 위에 "카카오로 계속하기"(C1), "네이버로 계속하기"(C2) 버튼을 더한다. 버튼은 `listLoginOptions`의 `oauth` 항목을 순서대로 그리는 같은 컴포넌트라 C 작업이 로그인 화면 파일을 고치지 않는다. 색·문구는 각 사의 디자인 가이드를 따른다(미확인: 최신판 확인 후 반영, C1-5). 운영에서 `AUTH_PROVIDERS`에 없는 제공자는 버튼을 숨긴다 | 같음 | 같음 |

버튼 순서는 Google → 카카오 → 네이버 → 이메일 폼이다(제안: 공개 베타 사용자는 Google로 시작했으므로 위치를 바꾸지 않는다). 모든 버튼은 Lucide 아이콘이 아니라 제공자 로고 SVG를 쓰며 이모지는 쓰지 않는다(6절). 로그인 화면 레이아웃·토큰은 3.25절 디자인 시스템을 따르고 `--color-seal`(인주)은 쓰지 않는다.

### 7.2 오류 상태

| 쿼리·상황 | 단계 | 표시 위치 | 문구 |
|---|---|---|---|
| `/login?error=callback` | B·C | 로그인 폼 위 오류 띠 | 로그인을 끝내지 못했습니다. 다시 시도해 주세요 |
| `/login?error=state` | C2 브리지 | 같음 | 로그인 요청이 만료되었거나 올바르지 않습니다. 처음부터 다시 시도해 주세요 |
| `/login?error=email_in_use` | C2 브리지(C1 비즈 앱 자동 연결이 안 될 때도 같은 문구) | 같음 | 이미 다른 방법으로 가입한 이메일입니다. 그 방법으로 로그인한 뒤 설정에서 네이버를 연결하세요 |
| 프로필 없음 | 전 단계 | 로그아웃 후 `/login` | 계정 정보를 불러오지 못했습니다. 다시 로그인해 주세요 |
| `status=suspended` | 전 단계 | `/suspended` | 이용이 정지된 계정입니다. 문의처로 연락해 주세요 |
| 이메일 인증 전 실행(403 `email_not_verified`) | B·C(이메일 가입자) | 실행 버튼 옆 띠 + [인증 메일 다시 보내기] | 메일 인증을 마치면 문서를 만들 수 있습니다 |
| `/api/dev/login`이 404(배포 환경, 판정 거짓) | A 코드가 남은 B·C 배포 | 패널 자체가 없음 | - |
| invite 앱 `/no-access` 안내 | 해당 없음 | - | docs는 open 앱이라 초대 메일·`/no-access`가 없다. 첫 OAuth 로그인은 `finishLogin`이 바로 엔타이틀먼트를 만든다. Phase 2 team 구성원 초대(`/app/settings/members`)는 이미 로그인한 사용자를 조직에 더하는 것이라 로그인 단계와 별개다 |

### 7.3 첫 OAuth 로그인 뒤 약관 동의 위치

OAuth는 가입 폼이 없으므로 약관 동의를 온보딩 첫 단계 `/onboarding/terms`에서 받는다. 온보딩 순서와 판정은 02장 9.6절이다.

| 순서 | 화면 | 내용 | 누가 보는가 |
|---|---|---|---|
| 1 | `/onboarding/terms`(B부터) | 이용약관·개인정보처리방침(국외 이전 표 포함)·AI 생성물 안내 필수 동의, 만 14세 이상 확인(제안), 마케팅 수신 선택. 동의 기록은 감사 로그(제안: 행동 이름 `terms.accept`, 약관 버전 `DOCS_TERMS_VERSION` 포함). 계약서 초안 고지(3.22절)는 여기서 받지 않고 첫 계약서 생성 때 받는다 | 현재 약관 버전의 동의 기록이 없는 사용자. 이메일 가입자는 `/signup`에서 이미 동의했으므로 건너뛴다 |
| 2 | `/onboarding/ai` | 2.1절 3단계 그대로 | 첫 로그인한 owner |
| 3 | `/onboarding/company` | 2.1절 4단계 그대로 | 자사 정보가 빈 조직의 owner/admin |

Stage A에는 1단계 화면이 없다. 시드 페르소나도 첫 로그인 때 02장 9.6절 판정을 그대로 따른다: 자기 조직 owner인 `owner`, `no_app`, `outsider`, `pro`는 `/onboarding/ai`부터 본다. 시드 훅은 `no_app`을 뺀 페르소나의 약관 동의 기록(B 이후 1단계를 건너뛰게)과 `outsider`·`pro` 조직의 자사 정보를 만들고, `owner` 조직의 자사 정보는 비워 둔다(05장 10.2절). 온보딩 E2E(DC-06-057 (a))는 `no_app`의 첫 로그인으로 돌리고, Playwright `globalSetup`은 `no_app`을 빼고 storageState를 만든다(globalSetup 로그인이 첫 로그인을 소비하기 때문이다).

### 7.4 설정 → 로그인 방법 (C단계, P1)

| 항목 | 내용 |
|---|---|
| 위치 | `/app/settings/login-methods`(설정 사이드 메뉴의 한 항목). 조직 설정이 아니라 본인 계정 설정이라 역할과 무관하게 본인만 본다 |
| 구성 | 연결된 제공자 목록(Google, 카카오, 네이버, 이메일)과 연결 시각, 연결·해제 버튼 |
| 연결 | 로그인 상태에서 `linkIdentity({ provider })`(Supabase 수동 연결, `[auth] enable_manual_linking = true`). 네이버 브리지는 `/auth/naver/start?link=1` 경로로 같은 사용자에 링크 행을 만든다(이미 다른 사용자에 연결된 네이버 id면 거부) |
| 해제 | 남는 로그인 수단이 1개 이상일 때만 버튼 활성. 마지막 수단은 "다른 로그인 방법을 먼저 연결하세요" |
| 감사 | `auth.identity_link`, `auth.identity_unlink` |
| 단계 | C1 작업(DC-06-064)이 만들고 C2 작업(DC-06-065)이 네이버 행을 더한다. A·B 단계에서는 이 메뉴를 렌더하지 않는다 |
