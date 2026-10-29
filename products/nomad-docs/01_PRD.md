# 01 PRD: NOMAD Docs

작성일 2026-10-13. 신규 제품이라 원본 PRD와 리뷰가 없다. 근거 표기: 분석 = `docs/products/00_MERGE_ANALYSIS.md`, 코어 = `docs/products/_platform-core/`, 이식 원천 = `docs/products/flora-publishing/`, `docs/reviews/SellingDocs.md`, `docs/reviews/flora.md`, `docs/reviews/FortuneDocs.md`. 기능 범위와 식별자는 설계 기준서(작성 에이전트 공통 기준, 산출물 아님)를 따르며 표에서는 "기준서 n장"으로 적는다. 원천 근거가 없는 수치와 정책은 "제안"으로 표시하고 이유를 적는다. 외부 사실(법령 해석, 외부 API, 표준계약서 이용 조건)은 확인하지 않았으면 "미확인"이다.

AI 설계 정본은 `docs/products/_platform-core/AI_ARCHITECTURE.md`, `LLM_WIKI.md`, `VOICE_ARCHITECTURE.md`다. 이 문서는 그 규칙을 인용만 하고 재정의하지 않는다.

2026-10-13 추가(확정 결정 21, `docs/products/00_MERGE_ANALYSIS.md`): 숏폼 제작·채널 운영 대행 문서 패키지 `shorts_agency`(DC-F-046, Phase 2)를 더했다. 대행 운영 자체(고객사, 고객 승인, 성과 수집)는 sceneflow의 에이전시 운영 기능이 맡고, 이 제품은 영업·계약·검수·보고 문서만 만든다. 새 내용은 3.1.1절, 3.3.1절, 3.5.1절, 6.4절, D-13~D-16이다.

## 1. 페르소나와 핵심 과제

| 페르소나 | 상황 | 목표 | 좌절 |
|---|---|---|---|
| 준호(34, 1인 풀스택 프리랜서) | 한 달에 외주 상담 4~6건. 상담마다 견적서·과업 범위·계약서를 워드 파일을 복사해 고친다 | 상담 당일 저녁에 견적서와 과업지시서를 보내고, 수주하면 계약서와 요구사항정의서를 같은 숫자로 바로 만든다 | 견적서와 계약서 금액·기간이 서로 달라 고객이 지적한다. "결제 기능"을 견적에 넣고 요구사항정의서에서 빠뜨려 검수 때 분쟁이 난다 |
| 서연(39, 12인 에이전시 PM) | 동시에 프로젝트 5개. 고객 RFP(PDF 40~80쪽)를 읽고 요구사항을 뽑아 내부 개발팀과 고객에게 각각 문서를 준다 | RFP를 올리면 요구사항 후보와 체크리스트가 채워지고, 회의가 끝나면 회의록과 변경된 요구사항이 정리된다. 문서마다 버전이 남는다 | RFP 정리에 하루가 걸리고, 회의에서 바뀐 범위가 견적·WBS에 반영되지 않는다. 최종본이 어느 파일인지 모른다 |
| 민재(31, 예비창업자, 정부지원사업 준비) | 지원사업 신청서와 외주 개발 견적·과업지시서를 함께 제출해야 한다 | 서비스 개요를 한 번 쓰면 개발 외주 문서와 사업계획서(Phase 2)가 같은 내용으로 나온다 | 개발 용어를 몰라 외주사 견적을 비교하지 못한다. 신청서 양식과 외주 문서 내용이 어긋난다 |
| 지현(36, 사내 서비스 기획 PM) | 사내 개발 요청을 받아 요구사항정의서·WBS·화면목록을 만들고 회의록을 남긴다 | 요구사항 ID가 화면·일정·검수 항목까지 이어지는 추적표를 보고서로 바로 낸다 | 요구사항이 바뀔 때마다 엑셀 추적표 4개를 손으로 고친다 |
| 태윤(33, 숏폼 대행 1인 사업자, Phase 2) | 브랜드 고객 3곳의 쇼츠·릴스·네이버 클립을 월 리테이너로 대행한다. 상담마다 견적서, 계약서, 채널 위임 동의서를 따로 만들고 매달 성과 리포트를 손으로 쓴다 | 상담 당일 견적서와 콘텐츠 기획안을 보내고, 수주하면 계약서·위임 동의서를 같은 편수·금액으로 만든다. 매달 리포트를 같은 양식으로 낸다 | 수정 횟수·2차 사용 범위·광고 표시 책임이 계약서에 없어 분쟁이 난다. 고객이 조회수 보장을 요구한다 |

핵심 과제:

| # | 과제 | 이 제품의 답 |
|---|---|---|
| 1 | 같은 정보를 문서마다 다시 입력하지 않는다 | 정본 데이터(프로필·체크리스트 답·요구사항·산출물·비용 항목)를 한 번 입력하고 문서는 그 투영으로 만든다. 정본이 바뀌면 영향받는 문서에 "재생성 필요" 표시(DC-F-006, DC-F-011) |
| 2 | 문서끼리 숫자와 범위가 어긋나지 않는다 | 금액·VAT·기간·요구사항 번호는 서버가 계산하고 LLM은 읽기만 한다. 확정 전 일관성 검사와 lint(DC-F-009, DC-F-016) |
| 3 | 체크 하나로 범위 변경이 모든 문서에 반영된다 | 결정적 체크리스트 효과 엔진: 체크 → 요구사항·화면·비용·조항(DC-F-006) |
| 4 | 어떤 버전을 누가 확정했는지 남는다 | 불변 버전, 문서번호, 개정본, 추적표(DC-F-014, DC-F-015, DC-F-017) |
| 5 | 계약서를 만들되 법적 위험을 사용자가 알고 쓴다 | 고위험 문서는 템플릿만, 고지와 동의, 변호사 검토 권고(DC-F-020, 6장) |
| 6 | RFP와 회의에서 나온 요구사항을 놓치지 않는다 | RFP 추출, 회의 녹음 → 회의록 + 요구사항 후보, 사용자 확인 후 반영(DC-F-022, DC-F-026) |

## 2. 범위: MVP와 Phase

확정 결정 7·8은 이 제품을 다루지 않는다(`docs/products/00_MERGE_ANALYSIS.md:15-16`). 범위는 기준서 4장이 정본이고, 확정 결정 13~17(AI·Dify·3D·음성·LLM 이원화)은 MVP 필수다(`docs/products/00_MERGE_ANALYSIS.md:21-25`).

| ID | 기능 | MVP | Phase 2 | Phase 3 | 근거 |
|---|---|---|---|---|---|
| DC-F-001 | 가입·로그인·워크스페이스 부트스트랩. 로그인은 단계로 켠다(2026-10-14): MVP 개발은 Mock(Stage A, 로컬 시드 계정), 공개 베타 전 Google + 이메일(Stage B, P0), 카카오·네이버는 G2 후(Stage C, C1 카카오 P1, C2 네이버 P1) | O(Stage A·B) | Stage C(G2 후, 8.1절) | | 기준서 4장, `docs/products/_platform-core/CORE_SPEC.md:83`, 확정 결정 22(`docs/products/00_MERGE_ANALYSIS.md:30`), `docs/products/_platform-core/AUTH_ROADMAP.md` 0장, 8장 |
| DC-F-002 | 워크스페이스 설정 | O | | | 기준서 4장, 6장 `workspace_settings` |
| DC-F-003 | 거래처(당사자) 관리 | O | | | 기준서 4장 |
| DC-F-004 | 프로젝트 생성 | O | | | 기준서 4장 |
| DC-F-005 | 체크리스트 마법사 | O | | | 기준서 4장, 원칙 1 |
| DC-F-006 | 체크리스트 효과 엔진 | O | | | 기준서 2장 원칙 2 |
| DC-F-007 | 요구사항 관리 | O | | | 기준서 4장 |
| DC-F-008 | 산출물 항목 관리(화면, 마일스톤, 산출물) | O | 테스트케이스 | | 기준서 4장 |
| DC-F-009 | 비용 항목과 금액 계산 | O | | | 기준서 2장 원칙 4, `docs/reviews/FortuneDocs.md:47` |
| DC-F-010 | 문서 유형 카탈로그 | O | | | 기준서 3장 |
| DC-F-011 | 단일 문서 생성 | O | | | 기준서 8장 `docs.generate` |
| DC-F-012 | 패키지 생성 `outsourcing_basic` | O | | | 기준서 3장, `docs/reviews/SellingDocs.md:51` 교훈(분리 생성) |
| DC-F-013 | 문서 편집기 | O | | | `docs/products/flora-publishing/01_PRD.md:78` 패턴 |
| DC-F-014 | 버전 이력과 비교 | O | | | 기준서 2장 원칙 5 |
| DC-F-015 | 문서 확정과 개정본 | O | | | 기준서 2장 원칙 5 |
| DC-F-016 | 일관성 검사와 lint | O | | | 기준서 2장 원칙 4, 5장 문서 표준 |
| DC-F-017 | 요구사항 추적표 | O | | | 기준서 2장 원칙 6 |
| DC-F-018 | 내보내기 PDF, DOCX, ZIP | O(DOCX는 코어 요청 C-1 선행) | | HWPX | 기준서 4장, `docs/products/_platform-core/SHARED_MODULES.md:264-290` |
| DC-F-019 | 조항 라이브러리 | O(플랫폼 표준) | 조직 맞춤 조항 | | 기준서 6장 `clauses` |
| DC-F-020 | 고위험 문서 고지와 동의 | O | | | 기준서 2장 원칙 9 |
| DC-F-021 | RFP·자료 업로드와 색인 | O | | | 확정 결정 13, `docs/products/_platform-core/AI_ARCHITECTURE.md:94-107` |
| DC-F-022 | RFP → 체크리스트·요구사항 후보 추출 | O | | | 기준서 9장 `docs.extract` |
| DC-F-023 | 프로젝트 Q&A 채팅 | O | | | 확정 결정 13, 14 |
| DC-F-024 | 프로젝트 용어 위키 | O | | | 확정 결정 13, `docs/products/_platform-core/LLM_WIKI.md:37-47` |
| DC-F-025 | AI 처리 방식 온보딩·국외 이전 동의 | O | | | 확정 결정 17, `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| DC-F-026 | 회의 녹음 → 회의록 + 요구사항 후보 | O | | | 확정 결정 16, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:95` |
| DC-F-027 | 음성 대화 | O | | | 확정 결정 16 |
| DC-F-028 | CSV/Excel 가져오기 | O | | | 기준서 4장 |
| DC-F-029 | 발신 웹훅 | | O | | 기준서 4장, 11장 |
| DC-F-030 | HubSpot CRM 연동 | | O(D-6) | | 기준서 4장, 11장. HubSpot API 약관 미확인 |
| DC-F-031 | admin-suite ERP 연동 | | O(품목, 판매) | 직원 → 인사 문서 | 기준서 11장, `docs/products/_supabase-modular/migrations/1600_erp.sql:113`, `:154` |
| DC-F-032 | n8n 연동 | | O | | 기준서 11장 |
| DC-F-033 | 공개 REST API | | | O(코어 요청 C-2) | 기준서 11장 |
| DC-F-034 | Salesforce, 이카운트, 더존 어댑터 | | | O(외부 API 미확인) | 기준서 4장 |
| DC-F-035 | 검토·승인 흐름 | | O | | 기준서 4장, 6장 `approval_steps` |
| DC-F-036 | 전자서명 연동 | | | O(제공자 미확인, D-7) | 기준서 4장 |
| DC-F-037 | 외부 공유 링크 | | O | | 기준서 4장 |
| DC-F-038 | 요금·크레딧 | O | | | 확정 결정 4, `docs/products/_platform-core/CORE_SPEC.md:177-188` |
| DC-F-039 | 비용 보호 | O | | | `docs/products/_platform-core/SECURITY_BASELINE.md:143-155` |
| DC-F-040 | 운영자 카탈로그 관리 | O | | | 기준서 4장 |
| DC-F-041 | 랜딩(3D 히어로), 약관·방침 페이지 | O | | | 확정 결정 15, `docs/nomad-design-modules/_design-guide/HERO_3D.md:70-75` |
| DC-F-042 | 데이터 내보내기·계정 삭제 | O | | | `docs/products/_platform-core/SECURITY_BASELINE.md:197` |
| DC-F-043 | 문서 유형 2차 확장 | | O | | 기준서 3장 Phase 2 유형 |
| DC-F-044 | 문서 유형 3차 확장(인사·노무, 약관·방침, HWPX) | | | O | 기준서 3장 Phase 3 유형, D-5 |
| DC-F-045 | 조직 맞춤 서식(DOCX 업로드 → 변수 매핑) | | O | | 기준서 4장 |
| DC-F-046 | 숏폼 제작·채널 운영 대행 패키지 `shorts_agency` | | O(D-13) | | 확정 결정 21, 3.1.1절, 6.4절 |
| DC-F-047 | 로그인 후 CRM형 워크스페이스(파이프라인 보드, 거래처 360, 활동 타임라인, 커맨드 팔레트) | O | 저장된 뷰 공유 | | 2026-10-14 사용자 요청, `03_SCREENS_UX.md` 3.26절 |
| DC-F-048 | 문서 생성 단계별 진행 애니메이션 | O | | | 2026-10-14 사용자 요청, `03_SCREENS_UX.md` 3.27절 |
| DC-F-049 | 랜딩 동적 3D + 3D 영상 히어로 | O | | | 2026-10-14 사용자 요청, 확정 결정 15, `03_SCREENS_UX.md` 4.6.1절 |

## 3. 기능 요구사항과 수용 기준

처리 분류: 이 제품은 원본 코드가 없으므로 대부분 "신규"다. 이식 원천의 설계 패턴을 고쳐 쓰는 기능은 "디벨롭", 공용 모듈을 그대로 쓰는 기능은 "통합"으로 적는다(`docs/products/_platform-core/DOC_TEMPLATE.md:15`).

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| DC-F-001 | 가입·로그인·워크스페이스 부트스트랩 | 통합 | 단계로 켠다(확정 결정 22, `docs/products/_platform-core/AUTH_ROADMAP.md`). Stage A(MVP 개발): 로컬 Supabase 시드 페르소나로 실제 JWT를 받는 Mock 로그인만(AUTH_ROADMAP 2장, `/login` 개발용 패널, 배포 환경에서 `/api/dev/login` 404). 쿠키 역할 Mock 금지, 개발용 로그인은 AUTH_ROADMAP 2장의 로컬 시드 계정만. Stage B(공개 베타 전, P0): Google OAuth + 이메일+비밀번호(가입 폼은 `options.data.signup_app='docs'`, 이메일 인증 필수, 8.1절 D-20). OAuth 첫 로그인과 기존 다른 앱 사용자는 콜백 `finishLogin`이 `bootstrap_app_for_org('docs')`를 1회 부른다. Stage C(G2 후): 카카오(C1, P1), 네이버(C2, P1). 단계와 무관하게: 이메일 인증 전에는 생성·추출·채팅·녹음 불가(`email_confirmed_at` 기준 서버 가드, 시드 계정은 인증 완료 상태). 첫 진입 시 `workspace_settings` 1행과 `parties.kind='self'` 빈 행 1개를 서버가 만든다. 콜백·Mock 로그인의 `next`는 `/`로 시작하고 `//`, `@`, `\`가 없는 경로만 허용(검증은 `finishLogin` 한 곳, AUTH_ROADMAP 3.2절 5번) | Stage A: `owner` 페르소나 로그인 직후 `core.session_context('docs')`가 `entitled=true`, `plan_code='free'`, 잔액 = 가입 50(pack) + 월 30(plan) = 80. 같은 조직에 `workspace_settings` 1행, self 당사자 1행(재로그인 10회에도 1행). 미인증 계정(테스트가 만든 `email_confirmed_at` 없는 사용자)의 생성 요청은 403 `email_not_verified`. `next=//evil.com`, `next=https://evil.com`, `next=/\evil.com`, `next=@evil.com`은 `/app`으로. Stage B: 이메일 가입 직후와 새 Google 계정 첫 로그인 모두 같은 결과(재로그인 3회 뒤에도 가입 크레딧 1회)와 AUTH_ROADMAP 5.3절 B-1~B-6. Stage C: 7.1.3절 C1-1~C1-5, 7.2.4절 C2-1~C2-6 | `docs/products/_platform-core/CORE_SPEC.md:83-84`, `:121`, 기준서 10장, 확정 결정 22 |
| DC-F-002 | 워크스페이스 설정 | 신규 | 자사 정보(self 당사자: 상호, 사업자등록번호, 대표자, 주소, 담당자), 문서번호 형식(`doc_number_format`, 기본 `{TYPE}-{YYYY}-{SEQ:4}`. 토큰 `{TYPE}`(=`{PREFIX}`, 유형 접두사), `{YYYY}`, `{YY}`, `{SEQ:n}`), 기본 일단가(`default_day_rate_krw`), VAT 비율(`vat_rate_bp`, 기본 1000 = 10%), 직인 이미지(PNG/WebP, 2MB, 비공개 Storage). owner/admin만 수정 | member가 저장하면 403. 직인 2MB 초과 413, PNG/WebP 매직바이트가 아니면 415. `vat_rate_bp=1000`이면 공급가 1,000,000원의 VAT가 100,000원으로 표시된다. 문서번호 형식에 `{SEQ`가 없으면 422 | 기준서 6장, 3.6절 |
| DC-F-003 | 거래처(당사자) 관리 | 신규 | kind(self·client·vendor·freelancer), 상호/이름, 사업자등록번호(10자리, 체크섬 검사), 대표자, 주소, 담당자 이름·이메일·전화, 메모. 소프트 삭제(휴지통 30일). 주민등록번호 입력란 없음, 모든 텍스트 필드에 주민등록번호 패턴 lint(6장) | 사업자등록번호 체크섬 오류는 422. 메모에 `900101-1234567` 형식을 넣으면 저장이 422 `pii_detected`로 거부된다. 삭제한 거래처는 목록에서 즉시 빠지고 30일 안에 복원된다. 확정 문서에 쓰인 거래처는 삭제해도 그 문서 버전의 `variables_snapshot`이 그대로 남는다 | 기준서 2장 원칙 9, 6장 `parties` |
| DC-F-004 | 프로젝트 생성 | 신규 | 이름, 코드(조직 내 유니크, 자동 제안 `P-YYYY-NNN`), 거래처, `project_type`(web·app·ai·mixed·other, Phase 2 content), 시작일·종료일, 예산(선택), 통화 KRW 고정. 상태 draft → active → delivered → archived(`docs.set_project_status`). 생성 시점의 체크리스트 버전을 `checklist_version`에 고정 | 플랜 `projects_max` 초과 생성은 403 `DC006`. 종료일 < 시작일은 422. delivered → draft 전이는 409 `DC001`. archived 프로젝트에서 생성 요청은 409 `DC001`. 삭제한 프로젝트를 복구해 Free 한도(2개)를 넘길 수 없다(409 `DC006`). 소프트 삭제·복구는 owner/admin만(403) | 기준서 6장, 7장 |
| DC-F-005 | 체크리스트 마법사 | 신규 | 3단계: (1) 공통 프로필(`profile`, `project_type`) (2) 프로젝트 체크(`feature`, `nfr`, `delivery`) (3) 문서별 옵션(`contract_terms` 등 문서 유형의 `required_fields`). 그룹별 진행률, 필수 누락 배지, 항목마다 도움말과 "이 체크가 만드는 것" 미리보기(효과 요약). 답은 입력 즉시 자동 저장(디바운스 800ms, 제안) | 필수 항목 12개 중 9개를 답하면 진행률 75%와 누락 3개 링크가 보인다. 새로고침 후에도 답이 그대로다. "결제" 항목 미리보기에 "요구사항 2, 화면 2, 비용 1, 조항 1"이 보인다 | 기준서 4장, 3.2~3.3절 |
| DC-F-006 | 체크리스트 효과 엔진 | 신규 | 3.2절 명세. 서버 코드(TS 순수 함수 + DB 트랜잭션)가 `checklist_items.effects`를 적용한다. LLM을 쓰지 않는다. 사용자가 고친 행(`is_user_modified=true`)은 수정·삭제하지 않는다. 정본이 바뀌면 영향받는 문서의 `needs_regeneration=true` | `feat.payment`를 체크하면 FR 2개, 화면 SCR 2개, 비용 항목 1개가 3초 안에(p95) 생성된다. 체크 해제 시 그 체크가 만든 행 중 사용자 미수정 행만 제거되고, 사용자가 이름을 고친 SCR 1개는 남아 "출처 체크 해제됨" 경고가 붙는다. 같은 답 집합을 빈 프로젝트 2개에 적용하면 두 프로젝트의 요구사항(code, title, priority)·산출물·비용 항목 목록이 완전히 같다. 같은 답을 두 번 저장해도 행 수가 변하지 않는다(멱등). 이미 `req_spec` 초안이 있으면 그 문서에 "재생성 필요"가 1초 안에 표시된다 | 기준서 2장 원칙 1·2 |
| DC-F-007 | 요구사항 관리 | 신규 | kind(functional·nonfunctional·constraint) → 코드 FR-001/NFR-001/CON-001(트리거 자동, 프로젝트 내 유니크, 재사용 안 함). 제목, 설명, 우선순위 MoSCoW(must·should·could·wont), 수용 기준, 상태(proposed·accepted·rejected·changed), 출처(checklist·extract·manual·integration·minutes). 수동 추가·편집·정렬·필터 | 수동 추가 2건이 FR-004, FR-005로 번호가 붙는다. FR-004를 삭제하고 새로 추가하면 FR-006이다(번호 재사용 없음). 사용자가 `req_code`를 바꾸려 하면 403. 효과 엔진이 만든 요구사항을 편집하면 `is_user_modified=true`가 된다 | 기준서 6장 `requirements` |
| DC-F-008 | 산출물 항목 관리 | 신규 | kind screen(SCR-001), milestone(MS-001), deliverable(DLV-001) 코드 자동. 화면: 메뉴 경로, 역할, 연결 요구사항. 마일스톤: 시작·종료일, 선행. 산출물: 인도 형태. 정렬 순서. test_case·api·table은 Phase 2 | 화면 3개 추가 시 SCR-001~003. 마일스톤 종료일이 프로젝트 종료일보다 늦으면 lint 경고 1건. Phase 2 kind로 생성 요청은 403 `DC006` | 기준서 6장 `artifacts`. 코드 접두 MS·DLV는 제안 |
| DC-F-009 | 비용 항목과 금액 계산 | 신규 | 분류(dev·design·pm·qa·infra·license·etc, content용 production·channel_ops·media), 단위(man_day·man_month·ea·lump, content용 per_video·per_month·per_channel), 수량(소수 2자리), 단가(원, 정수). 금액 = 수량 × 단가(DB 생성 컬럼, 원 단위 반올림), 공급가 합계, VAT(`round(합계 × vat_rate_bp / 10000)`), 총액은 서버가 계산. 일단가 미입력 시 `default_day_rate_krw` 적용. LLM은 금액을 쓰지 않고 서버가 넣은 값을 읽기만 | 수량 2.5 × 단가 400,000 = 1,000,000원. 항목 3개 합계 3,250,000원이면 VAT 325,000원, 총액 3,575,000원이 견적서·과업지시서·계약서에 같은 값으로 들어간다. 클라이언트가 `amount_krw`를 보내면 무시된다 | 기준서 2장 원칙 4, `docs/reviews/FortuneDocs.md:47` |
| DC-F-010 | 문서 유형 카탈로그 | 신규 | 3.1절 유형. 유형마다 위험도, 생성 방식, 필수 입력, 현재 게시 버전, 플랜 단계. 게시된 `doc_type_versions`는 불변(`checksum`) | Free에서 Phase 2 유형은 "준비 중"으로 보이고 생성 요청은 403 `DC006`. 게시된 버전 행 UPDATE는 409 `DC003` | 기준서 3장, 6장 |
| DC-F-011 | 단일 문서 생성 | 신규 | `docs.generate` 잡. 필수 입력 검사 → 크레딧 선차감 → 그래프 `docs.generate`(load_context → plan_sections → fill_template → draft_ai_sections → consistency_check → lint → compliance → output). template은 LLM 0회. hybrid는 서술 섹션만 LLM. 고위험 유형은 draft_ai_sections를 건너뛴다. 결과는 새 `document_versions`(created_kind=generated). 문서당 활성 생성 1건. 대기 중(queued) 생성은 `docs.cancel_generation`으로 취소(환불, 문서 원래 상태 복구). 진행 단계는 `generation_runs.progress`(DC-F-048) | template 문서(견적서) p95 5초, hybrid 문서(과업지시서) p95 60초 안에 버전이 생긴다. 필수 입력 누락은 422 `DC004`와 누락 필드 목록(잔액 변화 없음). 같은 문서 생성 중 재요청은 409 `DC002`. LLM 제공자 오류로 버전이 전달되지 않으면 선차감 전액 환불 행 1개. 버전이 전달된 뒤 잡이 실패해도 환불 행 0개(이중 혜택 방지). 대기 중 취소 후 같은 문서를 바로 다시 생성할 수 있다(DC002 없음). `dev_contract` 생성 1건의 `core.ai_usage` LLM 행 0개. 서술 섹션마다 근거(요구사항 ID 또는 업로드 청크) 표시 1개 이상 | 기준서 8장, 9장, `docs/products/_platform-core/AI_ARCHITECTURE.md:117`, `:129` |
| DC-F-012 | 패키지 생성 | 디벨롭 | `outsourcing_basic` = quote, sow, req_spec, wbs, screen_list, dev_contract, acceptance + trace_matrix(부록). 부모 잡 `docs.package`가 의존 순서(3.5절)로 자식 `docs.generate` 잡을 만든다. 예상 크레딧(28)을 실행 전에 보여 주고 자식 단위로 선차감한다. 자식이 실패하면 그 자식과 하류 자식만 canceled + 환불하고 나머지는 남긴다 | 8종 패키지가 p95 4분 안에 끝난다. 진행률이 자식 완료마다 Realtime으로 1초 안에 갱신된다. `req_spec` 실패 시 하류(sow, acceptance, trace_matrix)가 canceled이고 환불 합계 = 실패·취소 자식 단가 합. `dev_contract`의 고지 동의가 없으면 패키지 시작 전에 428 `DC007`(잔액 변화 없음) | 기준서 3장, 8장, `docs/reviews/SellingDocs.md:51` |
| DC-F-013 | 문서 편집기 | 디벨롭 | Tiptap. 섹션 단위 편집, fixed 섹션(표, 금액, 당사자, 조항 본문)은 잠금. 선택영역 툴바 "다시 쓰기·요약·표로 바꾸기"(`docs.assist`, 1크레딧) → Diff 카드(적용/취소). 저장은 서버가 sanitize 후 새 버전(created_kind=edited). 고위험 문서는 AI 툴바 비활성 | 잠긴 금액 셀은 편집 불가하고 "비용 항목에서 수정" 링크가 보인다. `<script>`, `onerror=` 속성을 붙여 저장하면 저장된 `body_html`에 0건. `dev_contract`에서 AI 다시 쓰기 API를 직접 호출하면 403 `assist_disabled_high_risk`. 다시 쓰기 실패 시 1크레딧 환불. body_html 2MB 초과 저장은 413 | `docs/products/flora-publishing/01_PRD.md:78`, `docs/products/_platform-core/SECURITY_BASELINE.md:172` |
| DC-F-014 | 버전 이력과 비교 | 신규 | `document_versions`는 append-only. 목록(버전, 종류, 작성자, 시각, lint·compliance 결과). 두 버전 선택 → 섹션 단위 diff(추가/삭제 강조). 이전 버전 복원 = 그 내용으로 새 버전 생성 | 버전 행 UPDATE·DELETE는 409 `DC003`. v2와 v5 비교에서 바뀐 섹션만 강조된다. v2 복원 후 최신 버전 번호가 v6이다 | 기준서 2장 원칙 5 |
| DC-F-015 | 문서 확정과 개정본 | 신규 | `docs.finalize_document(p_document_id, p_expected_version, p_ack_warn)`. 게이트: 정본 최신성(`needs_regeneration=false`, 생성 버전의 `inputs_hash` = 현재 체크리스트 해시, 아니면 `DC010` "다시 생성 필요"), 필수 입력(`DC004`), lint 실행 기록(`lint_result.ran_at`)·lint 오류 0건·compliance FAIL 아님(`DC005`), WARN이면 `p_ack_warn=true`(`DC008`), 버전 일치(`DC010`), 고위험이면 고지 동의(`DC007`). 통과 시 `docs.next_doc_number`로 문서번호 부여, status final, 이후 수정 불가. 고치려면 `docs.create_revision` → 새 문서(`supersedes_document_id`) | 확정 후 편집 저장은 409 `DC003`. 단가를 바꿔 `needs_regeneration=true`가 된 견적서는 확정되지 않는다(409 `DC010`). lint를 돌리지 않은 편집 버전은 422 `DC005`. 같은 해 견적서 3건 확정 시 번호가 QT-2026-0001~0003으로 빈틈없이 증가한다(동시 확정 10건에도 중복 0). WARN 확인 확정은 감사 기록 1행. 개정본은 원문서 번호를 참조하고 확정 시 새 번호를 받는다 | 기준서 6장 RPC, 7장 |
| DC-F-016 | 일관성 검사와 lint | 신규 | 3.4절 규칙. 코드 검사(금액·기간·당사자명·요구사항 ID 교차 검증, 유형별 필수 섹션·조항) + 경량 LLM 검사(서술 섹션이 정본과 모순되는지, hybrid·ai만). 결과는 `lint_result`(error·warn 목록, 위치) | 견적서 총액 3,575,000원과 계약서 금액 3,500,000원이 다르면 error 1건과 두 문서 링크. 존재하지 않는 FR-099를 본문에 쓰면 error 1건. 지급 비율 합이 100%가 아니면 error. lint 실행 p95 3초(코드 검사) | 기준서 2장 원칙 4, 5장(문서 표준 → lint) |
| DC-F-017 | 요구사항 추적표 | 신규 | `trace_links`(요구사항 → 화면·문서 절·조항·비용 항목·검수 항목)로 표 생성: 행 = 요구사항, 열 = 화면, 요구사항정의서 절, WBS 마일스톤, 검수 항목. 빈칸(연결 없음) 강조. 패키지에 부록으로 자동 포함 | FR 10개 중 화면 연결이 없는 2개가 빨간 빈칸으로 보인다. 추적표 생성(template) p95 5초. 요구사항 추가 후 추적표에 "재생성 필요" 표시 | 기준서 2장 원칙 6 |
| DC-F-018 | 내보내기 | 통합 | PDF: 공용 WeasyPrint 렌더(`render.pdf`), A4 공문서 프리셋(머리말·꼬리말, 쪽번호 "n / N", 코어 요청 C-1). DOCX: `render.docx`(C-1 선행). ZIP: 패키지 문서 PDF(와 DOCX) 묶음(`docs.export_zip`). Free는 워터마크 강제·PDF만. 같은 버전·형식 재요청은 기존 파일 재사용(재과금 없음) | A4 20쪽 PDF p95 30초, DOCX p95 30초, 한글 두부 문자 0개. Free에서 DOCX 요청은 403 `DC006`. 렌더 실패 시 1크레딧 환불. 같은 버전 PDF 재요청은 크레딧 0, 같은 파일. 서명 URL 7일 | `docs/products/_platform-core/SHARED_MODULES.md:269-274`, `docs/reviews/flora.md:75` 교훈 |
| DC-F-019 | 조항 라이브러리 | 신규 | 플랫폼 표준 조항(`clauses.org_id is null`, status published). 조항 = code, 유형, 제목, `{{var}}` 본문, 변수 목록, 필수/선택, 출처 메모(`source_note`). 체크리스트 효과가 선택 조항을 켜고, 필수 조항은 항상 포함. 변수는 서버가 정본에서 치환. MVP는 조직이 조항 본문을 바꾸지 못한다(편집기에서 조항 섹션 잠금) | `contract_terms.warranty_months=6`이면 하자보수 조항에 "6개월"이 들어간다. 필수 조항(목적, 대금, 지식재산, 비밀유지, 해지, 분쟁 해결 등)이 빠진 계약서는 lint error. 조직이 `clauses`에 INSERT하면 42501 | 기준서 6장 `clauses` |
| DC-F-020 | 고위험 문서 고지와 동의 | 신규 | `risk_level='high'` 유형을 처음 생성하기 전에 6.2절 고지문(버전 표시)을 보여 주고 확인받는다(`docs.ack_risk_notice`, 조직·유형·고지문 버전당 1회, 감사 기록). 고지문 버전이 바뀌면 다시 받는다. 문서 PDF 마지막 쪽에 고지 요약 1문단 | 동의 없이 `dev_contract` 생성은 428 `DC007`. 동의 후 두 번째 생성부터 고지 화면 0회. 고지문 버전 변경 후 첫 생성에서 다시 428 | 기준서 2장 원칙 9, 7장 |
| DC-F-021 | RFP·자료 업로드와 색인 | 디벨롭 | 프로젝트에 RFP·참고 자료 업로드(txt, md, docx, pdf, 20MB·300쪽). 서명 업로드 URL → 서버가 크기·MIME·매직바이트 재검사 → 파싱 → `rag.index`로 `docs.knowledge` 컬렉션(프로젝트별, 오픈소스 임베딩) 색인. 업로드 때 "사용 권한이 있습니다" 확인(필수)과 "개인정보 포함" 표시(선택, `contains_pii`). 경로는 서버 생성 | 40쪽 PDF가 p95 90초 안에 `ready`. 21MB는 413, 301쪽은 422. 확장자만 pdf인 실행 파일은 415. 권한 확인 없이 등록하면 403. 색인 실패 시 색인 크레딧 환불. 삭제한 자료는 채팅·추출 근거에서 즉시 빠진다 | `docs/products/flora-publishing/01_PRD.md:87`, `:105`, `docs/products/_platform-core/SECURITY_BASELINE.md:174` |
| DC-F-022 | RFP → 체크리스트·요구사항 후보 | 신규 | `docs.extract` 그래프: parse → index → extract_checklist(구조화 출력, 체크리스트 key만) → extract_requirements → dedupe(기존 정본 비교) → compliance → output. 결과는 `checklist_answers(source='extract', is_confirmed=false)`와 `requirements(status='proposed', source='extract')` 후보. 후보마다 근거 쪽·문단. 사용자가 고른 것만 `docs.confirm_checklist_suggestions`로 반영되고 그때 효과 엔진이 돈다 | 40쪽 RFP 추출 p95 3분. 후보마다 근거(쪽 번호와 인용 200자 이하) 1개 이상. 확인 전에는 효과 엔진 산출물 0행. 카탈로그에 없는 key 후보는 저장되지 않는다. 그래프가 실패하면 10크레딧 전액 환불. 같은 요구사항이 이미 있으면 후보에 "중복" 표시 | 기준서 9장, `docs/products/_platform-core/AI_ARCHITECTURE.md:106` |
| DC-F-023 | 프로젝트 Q&A 채팅 | 신규 | 프로젝트 화면 옆 채팅 패널(Dify `docs-chat`). 근거 = 프로젝트 업로드 자료(RAG) + 용어 위키 + 정본 요약(요구사항·비용·일정). 스트리밍, 답변마다 출처 칩, "AI가 생성한 답변" 표시. 근거가 없으면 "프로젝트 자료에서 근거를 찾지 못했습니다"를 먼저 쓴다. 법률 판단 질문(조항 유효성, 분쟁 승패)에는 판단하지 않고 전문가 상담을 안내. 메시지 1,000자, 대화당 50턴(제안) | 답변 100%에 출처 1개 이상 또는 "근거 없음" 표시. 응답이 전달되지 않은 턴은 1크레딧 환불. 잔액 부족 402 `CR001`. Dify 장애 시 FastAPI `/tools/answer` 대체 경로로 답한다. 다른 조직 프로젝트 id로 질문하면 404. 텍스트만으로 모든 기능 사용 가능 | `docs/products/_platform-core/AI_ARCHITECTURE.md:58-71`, `:105`, `:121-130` |
| DC-F-024 | 프로젝트 용어 위키 | 신규 | 프로젝트마다 위키: 당사자, 정의 용어, 약어, 결정 사항. 업로드 색인 직후와 회의록 생성 직후 `wiki.ingest`. 계약서·요구사항정의서의 "용어 정의" 절은 위키의 확정 용어를 읽는다. 사용자가 고친 블록은 에이전트가 덮어쓰지 않는다. 저장은 `expected_version` | RFP 1건 색인 후 갱신 페이지 5개 이하. 사용자 소유 블록의 에이전트 수정 0건. 오래된 version 저장은 409. 위키 페이지 종류 매핑: 당사자 → `entity`, 용어·약어 → `concept`, 결정 → `topic`(slug `decisions/...`), 목차 → `index` | `docs/products/_platform-core/LLM_WIKI.md:25`, `:30-31`, `:47` |
| DC-F-025 | AI 처리 방식 온보딩·국외 이전 동의 | 디벨롭 | 이메일 인증 직후(OAuth는 첫 로그인 직후 `/onboarding/terms` 약관 동의 다음, Stage A는 페르소나 첫 로그인 직후, 03장 7.3절) `/onboarding/ai`에서 "상용 AI 사용(국외 이전 동의)" 또는 "국내 오픈소스만" 선택. 동의는 `core.set_ai_cross_border_ack`(owner, 고지문 버전) + 감사 기록. 설정에서 철회 | 미동의 조직의 `core.ai_usage` 상용 제공자 행 0건. 철회 직후 다음 요청부터 상용 0건. 온보딩을 건너뛰면 미동의 | `docs/products/flora-publishing/01_PRD.md:104`, `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| DC-F-026 | 회의 녹음 → 회의록 + 요구사항 후보 | 신규 | 프로젝트에서 "회의 녹음" 또는 녹음 파일(mp3, m4a, wav, webm, 200MB, 길이는 플랜 `minutes_max_minutes`: free 30분, pro 120분, team 180분) 업로드 또는 회의 텍스트 붙여넣기. 녹음 전 제3자 고지(참석자 목소리, 동의 책임 안내, 고지문 버전) 확인. STT는 `meeting_minutes`(오픈소스 강제) → 그래프 `docs.minutes`(minutes_draft → decisions_actions → requirement_candidates → compliance) → `minutes` 문서 버전 + 요구사항 후보(`source='minutes'`, proposed). 원본 오디오는 처리 완료 24시간 뒤 삭제(D-11) | 60분 녹음 회의록 p95 10분(제안). 고지 확인 없이 업로드하면 422 `recording_notice_required`. `feature='meeting_minutes'` 상용 제공자 행 0건. 결정 사항·할 일(담당, 기한) 표가 있다. 후보는 확인 전 정본 0행. STT 또는 그래프 실패 시 선차감 전액 환불. 마이크가 없어도 텍스트 붙여넣기로 회의록 생성 가능. 오디오 파일이 완료 24시간 뒤 Storage에 0개 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:89-95`, `docs/products/_platform-core/SECURITY_BASELINE.md:297` |
| DC-F-027 | 음성 대화 | 신규 | 채팅 패널 마이크 버튼(누르고 말하기 60초). STT(`voice_chat`, 오픈소스 우선) → 변환 텍스트 확인·수정 → 전송 → "읽어 주기"(TTS, 자동 재생 기본 꺼짐). 녹음 원본 저장 안 함. 첫 사용 때 음성 처리 고지 | 60초에서 자동 중지. `store_audio=false` 100%. 마이크 거부 시 텍스트 채팅 정상. TTS 입력은 DB의 assistant 메시지만(임의 텍스트 403). STT 실패 시 환불과 "다시 말하기" | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:90`, `:110` |
| DC-F-028 | CSV/Excel 가져오기 | 신규 | 거래처, 비용 항목 단가표(조직 단가 카탈로그: 이름, 분류, 단위, 단가) CSV(UTF-8, CP949 자동 감지)·xlsx. 미리보기 → 열 매핑 → 검증 오류 행 표시 → 가져오기. 5MB·5,000행 | 5,000행 거래처 파일이 30초 안에 반영된다. 사업자번호 체크섬 오류 12행은 건너뛰고 오류 목록 CSV로 내려받는다. 주민등록번호 패턴 셀이 있는 파일은 해당 행 거부. 5,001행은 422 | 기준서 4장. 단가 카탈로그는 `workspace_settings.defaults` jsonb에 둔다(제안, 새 테이블 없이) |
| DC-F-029 | 발신 웹훅(Phase 2) | 디벨롭 | HTTPS URL(조직당 5개, 제안) 등록, 이벤트 `project.created`, `document.generated`, `document.finalized`, `document.exported`, `package.completed`. HMAC-SHA256 `X-Signature`, `X-Timestamp`. 재시도 5회 | 사설 IP·localhost URL 등록은 422. 수신 측이 서명으로 검증 가능. 5회 실패 후 `failing` | 기준서 11장, `docs/products/_platform-core/SHARED_MODULES.md:172`, `docs/products/flora-publishing/01_PRD.md:96` |
| DC-F-030 | HubSpot CRM 연동(Phase 2) | 신규 | OAuth(`core.oauth_states`), 토큰은 `core.encrypted_credentials`. Pull: 딜·회사·연락처 → 프로젝트·거래처. Push: 확정 문서 PDF 링크 → 딜 노트. 딜 단계 변경 수신 → "문서 생성 제안" 알림(자동 생성 없음) | 연동 해지(`docs.revoke_integration`) 후 동기화 요청 409 `DC009`. 같은 딜 2회 pull에도 프로젝트 1개(`external_refs` 유니크). API 한도·약관 미확인(D-6) | 기준서 11장 |
| DC-F-031 | admin-suite ERP 연동(Phase 2) | 신규 | 같은 org + 두 앱 엔타이틀먼트일 때만. service_role 함수가 `erp.products`(sku, name, price) → 단가 카탈로그, `erp.sales` → 거래명세서(`invoice`) 입력. 사용자 세션에 `erp` GRANT 없음 | docs만 쓰는 조직은 연동 메뉴가 비활성. 사용자 세션으로 `erp.products` SELECT는 42501 또는 0행 | 기준서 11장, `docs/products/_supabase-modular/migrations/1600_erp.sql:113`, `:154` |
| DC-F-032 | n8n 연동(Phase 2) | 신규 | 수신 `/api/integrations/inbound/[endpointToken]`(프로젝트 생성, 체크리스트 답 입력) + 발신 웹훅 | 잘못된 토큰 401. 같은 이벤트 id 재전송은 1회만 반영 | 기준서 11장 |
| DC-F-033 | 공개 REST API(Phase 3) | 신규 | 조직 API 키(코어 요청 C-2)로 프로젝트·문서 조회와 생성 요청 | Phase 3. 결정 전 구현하지 않는다 | 기준서 11장 |
| DC-F-034 | Salesforce·이카운트·더존(Phase 3) | 신규 | 같은 어댑터 인터페이스 | 외부 API 존재·약관 미확인. 확인 전 구현하지 않는다 | 기준서 4장 |
| DC-F-035 | 검토·승인 흐름(Phase 2) | 신규 | 문서 버전마다 검토자·승인자 단계, 코멘트, 승인 후에만 확정 | 승인 전 확정 요청 409 `DC001`. 승인자가 아닌 멤버의 승인은 42501 | 기준서 6장 `approval_steps` |
| DC-F-036 | 전자서명(Phase 3) | 신규 | 외부 제공자로 서명 요청, 서명본 PDF와 sha256 보관 | 제공자 미확인(D-7) | 기준서 6장 `signature_requests` |
| DC-F-037 | 외부 공유 링크(Phase 2) | 신규 | 확정 문서 읽기 전용 링크, 만료 1~30일, 회수 | 만료 후 404. 회수 즉시 404 | 기준서 4장 |
| DC-F-038 | 요금·크레딧 | 통합 | 4장 플랜·팩·단가. Toss 일반결제(팩, 첫 구독)와 빌링키. 모든 유료 작업 전에 예상 크레딧 표시, 서버 선차감, 실패 환불 | 테스트 키로 `pack_100` 결제 → 잔액 +100. 금액 변조 주문은 지급 0(`PM001`). 브라우저에서 `rpc('grant_credits')`는 42501. 패키지 실행 버튼 옆에 "28 크레딧"이 보이고 잔액 20이면 실행 전에 "8 크레딧 부족" 안내 | `docs/products/_platform-core/CORE_SPEC.md:177-188`, 확정 결정 4 |
| DC-F-039 | 비용 보호 | 신규 | 조직 동시 생성 3건(`runtime_config`, 패키지 1건 = 1건), 레이트 리밋(5장), 플랫폼 일일 크레딧 상한(제안 20,000/일, KST 자정. 생성은 `docs.start_generation`, 추출·회의록·다시 쓰기·채팅·음성·색인·내보내기는 `docs.reserve_credits`를 거쳐 같은 상한을 쓴다), 이메일 인증 필수 | 4번째 동시 생성은 429 `DC006`(대기 안내). 같은 문서의 중복 생성은 409 `DC002`. 1분 안 21번째 생성 요청은 429. 일일 상한 소진 시 503 `DC006` "오늘 생성량이 가득 찼습니다"(추출·채팅 등 생성 밖 차감도 같은 상한에 막힌다) | `docs/products/_platform-core/SECURITY_BASELINE.md:148` |
| DC-F-040 | 운영자 카탈로그 관리 | 신규 | platform_admin 화면: 문서 유형 버전·체크리스트 항목·조항 초안 작성 → 미리보기(샘플 프로젝트로 생성) → 게시(service_role). 게시 후 불변, 수정은 새 버전. effects JSON 스키마 검증 | effects 스키마 위반은 게시 422. 게시 버전 수정 409 `DC003`. 일반 사용자의 `/admin` 접근 403. 게시·폐기는 감사 기록 | 기준서 4장 |
| DC-F-041 | 랜딩, 약관·방침 페이지 | 신규 | 3D 히어로(제품 소재는 03장 4절: 체크박스 → 문서 묶음), 이용약관·개인정보처리방침·AI 생성물 안내·계약서 고지 페이지 | `HERO_3D.md` 4절 수용 기준 전부. 6.1절 금지 문구 점검 위반 0건 | `docs/nomad-design-modules/_design-guide/HERO_3D.md:70-75` |
| DC-F-042 | 데이터 내보내기·계정 삭제 | 디벨롭 | 조직 데이터 JSON 내보내기(프로젝트, 정본, 문서 버전 메타), 확정 문서 PDF ZIP. 계정 삭제 = 확인 문구 → 조직 soft delete → 30일 유예 → `purge_organization`, Storage 파일 삭제 | 삭제 요청 30일 뒤 조직의 `docs` 행 0개, Storage 객체 0개. 유예 중 로그인하면 복구 가능. 요청은 감사 기록 1행 | `docs/products/flora-publishing/01_PRD.md:98`, `docs/products/_platform-core/SECURITY_BASELINE.md:197` |
| DC-F-043 | 문서 유형 2차 확장(Phase 2) | 신규 | nda, maint_contract, proposal, change_request, test_cases, api_spec, db_design, invoice, biz_plan | 유형마다 3.1절 형식의 필수 입력·lint 규칙 게시 후 활성 | 기준서 3장 |
| DC-F-044 | 문서 유형 3차 확장(Phase 3) | 신규 | 인사·노무 계약서, 개인정보처리방침·이용약관, HWPX 내보내기 | 법무 검토(6장 규제 특례)와 D-5 이후 | 기준서 3장 |
| DC-F-045 | 조직 맞춤 서식(Phase 2) | 신규 | 자사 DOCX 업로드 → `{{var}}` 자리 표시 감지 → 정본 변수 매핑 → 그 서식으로 DOCX 생성. 조직 맞춤 조항(`clauses.org_id` 값 있음) 편집 | 매핑되지 않은 자리 표시가 있으면 생성 전 422와 목록 | 기준서 4장 |
| DC-F-046 | 숏폼 제작·채널 운영 대행 패키지(Phase 2) | 신규 | `project_type=content` 프로젝트에 3.3.1절 체크리스트(채널, 월 편수, 촬영·출연·음원, 업로드 대행, 네이버 클립, 광고·제휴, 수정 횟수, 2차 사용 기간)를 적용하고 `shorts_agency` = content_brief, quote, sow, video_service_contract, channel_access_mandate, acceptance(3.5.1절)를 만든다. brand_guide_ack, ad_disclosure_checklist, monthly_report, service_intro는 단독 생성. 계약서·위임 동의서는 고위험(템플릿만, 고지 동의, D-3·D-15 게이트). 월간 리포트 KPI는 사용자가 입력하거나 CSV로 넣는다(sceneflow 연동은 D-16) | content 프로젝트의 체크리스트에 dev 전용 항목(플랫폼, 로그인, 결제, 소스코드 인도, 하자보수)이 0개 보인다. 월 12편·단가 130,000원이면 비용 항목 "숏폼 영상 제작" 12 × 130,000 = 1,560,000원이 견적서·과업지시서·계약서에 같은 값으로 들어간다. `delivery.naver_clip_upload`를 켜면 계약서에 `vsc.automation_risk` 조항과 제약 요구사항 1개가 생긴다. 계약서에 "조회수 보장" 류 문구가 있으면 `L-NO-GUARANTEE` error. 광고·제휴를 켠 프로젝트의 계약서에 `vsc.ad_disclosure`가 빠지면 `L-REQUIRED-CLAUSE` error. 비활성 유형 생성 요청은 22023 | 확정 결정 21, 6.4절 근거 |
| DC-F-047 | 로그인 후 CRM형 워크스페이스 | 신규 | 로그인 후 앱 셸을 CRM 방식으로 구성(Attio·HubSpot·Pipedrive 벤치마킹, `03_SCREENS_UX.md` 3.26절). (1) 파이프라인 보드: 프로젝트를 단계 열(lead → drafting → quoted → contracted → accepted → closed)로 보여 준다. 단계는 저장하지 않고 문서 상태에서 계산한다(뷰 `docs.project_pipeline`, 견적서 확정 = quoted, 계약서 확정 = contracted, 검수확인서 확정 = accepted, 프로젝트 delivered·archived = closed). 카드 = 프로젝트명, 거래처, 합계(VAT 포함), 열린 문서 수, "다시 생성 필요" 배지. (2) 거래처 360: 거래처 상세에 프로젝트·문서·금액 합계·최근 활동. (3) 활동 타임라인: 생성·버전 저장·확정·업로드(뷰 `docs.project_activity`). (4) 커맨드 팔레트(⌘K/Ctrl+K): 프로젝트·거래처·문서 검색과 "새 견적서" 같은 명령. (5) 표 보기: 프로젝트·거래처 목록을 정렬·필터 가능한 표로, 필터는 URL 쿼리에 남는다(저장된 뷰 공유는 Phase 2) | 견적서를 확정하면 새로고침 없이(Realtime `documents`) 카드가 quoted 열로 옮겨진다. 다른 조직 프로젝트는 보드·타임라인·검색에 0건. 보드 50카드 첫 렌더 p95 1.5초. 키보드만으로 팔레트 열기 → 프로젝트 이동 → 문서 생성 시작이 된다. 카드 끌어 놓기로 단계를 바꾸지 않는다(단계는 문서가 정한다. 끌어 놓으면 "견적서를 확정하면 이동합니다" 안내) | 2026-10-14 사용자 요청 |
| DC-F-048 | 문서 생성 단계별 진행 애니메이션 | 신규 | 생성 중 화면(단일·패키지)이 실제 진행 단계를 따라 움직인다. ai-service가 그래프 노드 경계마다 `docs.report_generation_progress`로 `{stage, section_key, step, total}`을 쓰고 화면은 Realtime `generation_runs`로 받는다. 단계: queued(대기열) → collecting(정본·자료 모으기) → drafting(섹션 작성, section_key 별) → assembling(문서 조립) → linting(검사) → rendering(PDF, 내보내기 때) → done. 패키지는 자식 문서별 레인(견적서·과업지시서·…)이 의존 순서대로 차례로 켜진다. 가짜 진행률(시간 기반 증가)을 쓰지 않는다. `prefers-reduced-motion`이면 애니메이션 없이 단계 목록만 갱신 | 단계 표시는 서버 progress와 다르지 않다(E2E에서 stage 5종 순서 확인). 대기 중에는 [취소] 버튼(DC-F-011), 실행 중에는 숨긴다. 실패 시 실패한 단계에서 멈추고 환불 여부를 보여 준다. 탭을 닫았다 열어도 현재 단계에서 이어진다. 애니메이션 프레임 60fps 목표, 메인 스레드 긴 작업 50ms 초과 0건 | 2026-10-14 사용자 요청 |
| DC-F-049 | 랜딩 동적 3D + 3D 영상 히어로 | 신규 | 메인 페이지 첫 화면을 두 겹으로 만든다: (1) 실시간 3D 장면(three.js·R3F): 체크리스트 카드가 체크되면 문서 묶음이 쌓이고 직인이 찍히는 인터랙티브 장면(스크롤·포인터 반응) (2) 3D 영상: 같은 장면을 미리 렌더한 짧은 시네마틱 루프(8~12초, H.264 MP4 + WebM, 무음, 자동재생 muted·playsinline, 포스터 이미지). 데스크톱 고성능 기기는 (1), 모바일·저성능·`prefers-reduced-motion`·WebGL 실패는 (2), 영상도 못 쓰면 정지 이미지(`HERO_3D.md` 정지 이미지 규칙). 아래 섹션 "체크 → 문서" 설명 영상은 스크롤로 재생 | LCP 2.5초 이내(모바일 4G, 히어로 영상은 포스터가 LCP), 3D 번들은 첫 화면 JS와 분리(동적 import), 영상 파일 2MB 이하(모바일 1MB), 영상에 실제 사람·가상 후기·허위 수치 0건, 자동재생 영상에 소리 0. 3기기(데스크톱·태블릿·모바일) 렌더 스모크(DC-06-057) 통과 | 2026-10-14 사용자 요청, `docs/nomad-design-modules/_design-guide/HERO_3D.md` |

### 3.1 문서 유형과 필수 입력

`required_fields`는 `doc_type_versions`에 저장되는 정본 경로 목록이다. 아래 경로 표기는 제안이며 05장에서 확정한다.

| code | 이름 | 위험 | 생성 방식 | 단계 | 패키지 | 필수 입력(`required_fields`) | 섹션 구성 요약(`structure`) |
|---|---|---|---|---|---|---|---|
| `quote` | 견적서 | low | template | MVP | O | `client_party`, `self_party.biz_reg_no`, `line_items>=1`, `quote.valid_until`, `vat_rate_bp` | 머리(fixed), 수신·발신(table), 비용 내역(table), 합계·VAT(table), 조건·유효기간(variable) |
| `sow` | 과업지시서(SOW) | low | hybrid | MVP | O | `project.name`, `project.start_date`, `project.end_date`, `requirements(accepted\|proposed)>=1`, `artifacts(milestone)>=1`, `artifacts(deliverable)>=1` | 개요(ai), 범위(ai, 요구사항 요약), 제외 범위(ai), 일정(table), 산출물(table), 역할(variable) |
| `req_spec` | 요구사항정의서 | low | hybrid | MVP | O | `profile.service_summary`, `requirements>=1`, `nfr` 그룹 필수 항목 | 개요(ai), 용어 정의(variable, 위키), 기능 요구사항(table), 비기능(table), 제약(table), 수용 기준(table) |
| `wbs` | WBS·일정표 | low | template | MVP | O | `artifacts(milestone)>=1`, 각 마일스톤 시작·종료일 | 단계별 작업(table), 일정(table), 산출물 연결(table) |
| `screen_list` | 화면목록·메뉴구조도 | low | hybrid | MVP | O | `artifacts(screen)>=1` | 메뉴 트리(table), 화면 목록(table), 화면 설명(ai) |
| `dev_contract` | 소프트웨어 개발 용역계약서 | high | template | MVP(출시 게이트 D-3) | O | `client_party`(상호, 대표자, 주소, 사업자번호), `self_party`(같음), `total_krw`, `contract_terms.payment_schedule`, `project.start_date`, `project.end_date`, `contract_terms.warranty_months`, `contract_terms.ip_ownership`, 고지 동의 | 전문(fixed), 조항 1~n(clause, 라이브러리), 대금 지급표(table), 서명란(fixed), 별첨 목록(variable) |
| `acceptance` | 검수확인서 | low | template | MVP | O | `requirements(accepted)>=1`, `acceptance.date`, `contract_terms.acceptance_days` | 대상(variable), 검수 항목(table, 요구사항별 합격/불합격), 서명란(fixed) |
| `minutes` | 회의록 | low | ai | MVP | X | 전사본 또는 텍스트, `minutes.attendees>=1`, `minutes.date` | 개요(ai), 논의(ai), 결정 사항(table), 할 일(table), 요구사항 후보(table) |
| `trace_matrix` | 요구사항 추적표 | low | template | MVP | O(부록) | `requirements>=1` | 추적표(table), 빈칸 요약(variable) |
| Phase 2·3 유형 | `nda`, `maint_contract`, `proposal`, `change_request`, `test_cases`, `api_spec`, `db_design`, `invoice`, `biz_plan`, shorts_agency 7종(3.1.1절) / 인사·노무, `privacy_policy`, `terms` | 기준서 3장 | 기준서 3장 | Phase 2 / 3 | X | DC-F-043·044 착수 때 정의 | 같음 |

### 3.1.1 shorts_agency 문서 유형 (DC-F-046, Phase 2)

전부 `phase='phase2'`, `is_active=false`로 카탈로그에 넣고, 게시 전 초안 버전(`published_at` null)만 둔다(`docs/products/_supabase-modular/migrations/2300_docs.sql` 25절). quote·sow·acceptance는 `outsourcing_basic`과 같은 유형을 `in_package`로 함께 쓴다.

| code | 이름 | 위험 | 생성 방식 | 패키지 | 필수 입력(`required_fields`) | 섹션 구성 요약(`structure`) |
|---|---|---|---|---|---|---|
| `content_brief` | 콘텐츠 브리프·기획안 | low | hybrid | O(1) | `client_party`, `content.channels`, `content.monthly_videos`, `profile.service_summary` | 목표·타깃(ai), 채널·규격(table), 편수·일정(table), 훅·스크립트 초안(ai), 참고 영상(variable), 광고 표시 방식(variable) |
| `quote` | 견적서(공유) | low | template | O(2) | 3.1절과 같음. 단위 per_video·per_month·per_channel 표시 | 3.1절과 같음 |
| `sow` | 과업지시서(공유) | low | hybrid | O(3) | 3.1절과 같음. 마일스톤·산출물은 `content.monthly_videos` 효과가 만든다 | 3.1절과 같음 |
| `video_service_contract` | 영상 제작·채널 운영 대행 계약서 | high | template | O(4) | `client_party`, `self_party`, `total_krw`, `contract_terms.payment_schedule`, 기간, `contract_terms.ip_ownership`, `contract_terms.revision_rounds`, `contract_terms.secondary_use_months`, `contract_terms.acceptance_days`, 고지 동의 | 전문(fixed), 조항(clause `vsc.*`), 납품 사양(table), 대금 지급표(table), 서명란(fixed), 별첨(variable) |
| `channel_access_mandate` | 채널 계정 접근·운영 위임 동의서 | high | template | O(4) | `client_party`, `self_party`, `content.channels`, 기간, 고지 동의(`notice-channel-mandate-2026-10-13`) | 전문, 위임 채널(table), 위임 범위·책임(clause `cam.*`), 자동화 위험 고지(fixed), 서명란 |
| `acceptance` | 검수확인서(공유) | low | template | O(5) | 3.1절과 같음(검수 항목 = 월 납품 요구사항) | 3.1절과 같음 |
| `brand_guide_ack` | 브랜드 가이드 확인서 | low | template | X | `client_party`, `self_party` | 브랜드 정보(variable), 써야 할 표현·톤(table), 금지 표현·경쟁사(table), 제공 소재·사용 범위(table), 확인(fixed) |
| `ad_disclosure_checklist` | 광고 표시 준수 체크리스트 | low | template | X | `content.channels`, `feat.content_affiliate` | 캠페인·대가 관계, 채널별 표시 위치(table), 표시 문구(table), AI 가상인물 표시(variable), 게시 전 확인(table) |
| `monthly_report` | 월간 성과 리포트 | low | hybrid | X | `client_party`, `report.period`, `report.kpis`(사용자 입력 또는 CSV, D-16) | 핵심 지표 요약(table), 상위·하위 영상(table), 분석(ai), 다음 달 계획(ai), 고객 요청 처리(table) |
| `service_intro` | 서비스 소개서 | low | ai | X | `self_party`, `profile.service_summary` | 회사·서비스 소개(ai), 서비스 패키지(table), 진행 절차(table), 포트폴리오(variable), 문의(fixed) |

`report.kpis` 표준 열(제안): 기간, 채널, 업로드 수, 조회수, 평균 시청 지속률, 구독 순증, 제휴 클릭. 서술 섹션(ai)은 입력된 숫자만 인용하고 새 수치를 만들지 않는다(`L-AI-CLAIM`).

### 3.2 체크리스트 효과 엔진 명세 (DC-F-006)

정본 규칙:

| 항목 | 규칙 |
|---|---|
| 실행 주체 | Next.js Route Handler(서버)가 TS 순수 함수 `computeEffects(items, answers)`로 목표 상태를 계산하고, service_role 트랜잭션 1개로 diff를 적용한다. LLM 호출 0회 |
| 입력 | 프로젝트에 고정된 `checklist_version`의 `checklist_items`(정렬: group 순서 profile → project_type → feature → nfr → delivery → contract_terms, 그다음 key 사전순)와 `checklist_answers`(`is_confirmed=true`만) |
| 출력 단위 | effects 배열의 원소 1개 = 정본 행 1개. 행의 `source='checklist'`, `source_key='<item_key>#<effect_id>'`(제안: 한 항목이 여러 행을 만들 수 있어 효과 id로 구분) |
| 조건 | 원소의 `when`이 답과 맞을 때만 목표 상태에 넣는다. boolean은 `{"eq": true}`, single은 `{"eq": "<option>"}`, multi는 `{"has": "<option>"}`, number는 `{"gte": n}` / `{"lt": n}`. `when`이 없으면 boolean `true`와 같다 |
| 값 치환 | 문자열의 `{{answer}}`, `{{answer.label}}`, `{{item:<key>}}`는 답 값으로 치환. 수량은 숫자 또는 `{"from": "<item_key>", "factor": x, "min": a, "max": b}`(제안)로 계산하고 소수 2자리 반올림 |
| 적용(diff) | 목표 집합 T와 현재 행 집합 C(`source='checklist'`인 행)를 `source_key`로 비교한다. T에만 있음 → INSERT. 둘 다 있고 `is_user_modified=false` → 엔진 값으로 UPDATE. 둘 다 있고 `is_user_modified=true` → 손대지 않음. C에만 있고 `is_user_modified=false` → DELETE(요구사항은 문서가 참조 중이면 DELETE 대신 `status='rejected'`). C에만 있고 `is_user_modified=true` → 남기고 화면에 "출처 체크 해제됨" 경고(파생 판정, 새 컬럼 없음) |
| 사용자 수정 판정 | 사용자가 엔진이 만든 행의 내용 컬럼(title, description, priority, acceptance_criteria, name, attributes, quantity, unit_price_krw)을 바꾸면 Route Handler가 `is_user_modified=true`로 저장한다. "엔진 값으로 되돌리기"를 누르면 false로 되돌리고 다음 적용에서 덮어쓴다 |
| 결정성 | 같은 (checklist_version, 확정 답 집합)이면 T가 바이트 단위로 같다. 시각, 난수, 외부 호출을 쓰지 않는다. 새 행의 코드(FR-001 등)는 T의 정렬 순서대로 INSERT해 빈 프로젝트에서는 항상 같은 번호를 받는다. 기존 프로젝트에 나중에 추가되는 행은 다음 번호(번호 재사용 없음) |
| 멱등·동시성 | 프로젝트 단위 advisory lock 안에서 적용한다. 같은 답을 다시 저장하면 diff 0 |
| 조항 효과 | `clauses` 원소는 정본 행을 만들지 않는다. 조항 라이브러리는 플랫폼 카탈로그이므로, 계약서 생성 때 엔진이 같은 규칙으로 "포함할 조항 code와 변수"를 계산하고 결과를 `document_versions.variables_snapshot`과 `trace_links(to_kind='clause')`에 남긴다(제안: 기준서 6장에 프로젝트별 조항 표가 없어서) |
| 재생성 표시 | 적용 결과 행이 1개 이상 바뀌면 그 행을 참조하는 문서 유형(요구사항 → req_spec, sow, acceptance, trace_matrix / 화면 → screen_list, trace_matrix / 마일스톤·산출물 → wbs, sow / 비용 → quote, sow, dev_contract / 조항 답 → dev_contract)의 draft·review 문서에 `needs_regeneration=true` |
| 성능 | 항목 200개·답 200개 기준 계산 50ms 이하, 적용 트랜잭션 p95 3초 이하(제안) |
| 버전 업그레이드 | 운영자가 새 체크리스트 버전을 게시해도 기존 프로젝트는 고정 버전을 유지한다. 사용자가 "새 체크리스트로 업그레이드"를 누르면 미리보기(diff) 후 적용(제안) |

effects jsonb 예(`feat.payment`, input_type boolean). 정본 형식은 **효과 원소의 평평한 배열**이고 원소마다 `target`(requirements, artifacts, line_items, clauses)을 가진다. DB CHECK가 배열만 허용한다(`docs/products/_supabase-modular/migrations/2300_docs.sql:154`), seed도 이 형식이다(`2300_docs.sql:3005`).

```json
[
  { "id": "fr_pg", "target": "requirements", "kind": "functional", "title": "카드·간편결제 결제", "description": "사용자는 {{item:profile.platforms}}에서 PG를 통해 결제한다", "priority": "must", "acceptance_criteria": "결제 성공 시 주문 상태가 paid로 바뀌고 영수증이 발송된다" },
  { "id": "fr_refund", "target": "requirements", "kind": "functional", "title": "결제 취소·환불", "priority": "should" },
  { "id": "nfr_pg_sec", "target": "requirements", "kind": "nonfunctional", "title": "카드정보 미저장", "description": "카드번호를 서버에 저장하지 않고 PG 토큰만 보관한다", "priority": "must", "when": { "eq": true } },
  { "id": "scr_checkout", "target": "artifacts", "kind": "screen", "name": "결제", "attributes": { "menu": "주문 > 결제", "roles": ["user"] }, "links": ["fr_pg"] },
  { "id": "scr_paid", "target": "artifacts", "kind": "screen", "name": "결제 완료", "attributes": { "menu": "주문 > 결제 완료" }, "links": ["fr_pg"] },
  { "id": "li_pg", "target": "line_items", "category": "dev", "name": "PG 결제 연동", "unit": "man_day", "quantity": 5, "unit_price": "default_day_rate" },
  { "id": "cl_pg", "target": "clauses", "code": "dev.pg_responsibility", "vars": { "pg_contract_party": "client" } }
]
```

`links`는 같은 항목 안 효과 id를 가리키고 엔진이 `trace_links(requirement → artifact)`로 바꾼다. `unit_price: "default_day_rate"`는 `workspace_settings.default_day_rate_krw`를 적용 시점에 읽는다(같은 설정이면 같은 결과). 비교 기준: `nfr_pg_sec`는 보안 등급 답과 무관하게 결제에 붙는 예다.

### 3.3 MVP 체크리스트 항목 (예시 30개, 운영자가 게시하는 seed 초안)

| key | group | input_type | 필수 | 효과 요약 |
|---|---|---|---|---|
| `profile.service_summary` | profile | text | O | 요구사항정의서·과업지시서 개요 변수. 정본 행 없음 |
| `profile.platforms` | profile | multi(web, android, ios, desktop, admin_web) | O | 플랫폼마다 NFR 호환성 1개, android·ios 선택 시 비용 "앱 빌드·스토어 등록" 1개씩 |
| `profile.target_users` | profile | multi(b2c, b2b, internal) | | b2c면 NFR "개인정보 처리방침 화면" 1개 + 화면 1개 |
| `project_type.build_kind` | project_type | single(new, renewal, maintenance) | O | renewal이면 CON "기존 데이터 이관 범위 합의" 1개 + 비용 "데이터 이관" 1개 |
| `project_type.design_scope` | project_type | single(none, provided, full) | O | full이면 비용 design 화면 수 × 0.5MD, 산출물 "디자인 시안" 1개 |
| `feat.login` | feature | boolean | | FR 회원가입·로그인·비밀번호 재설정 3개, 화면 3개, 비용 3MD |
| `feat.social_login` | feature | multi(kakao, naver, google, apple) | | 제공자마다 FR 1개, 비용 1MD. apple은 ios 선택 시 필수 경고 |
| `feat.payment` | feature | boolean | | 3.2절 예: FR 2 + NFR 1, 화면 2, 비용 5MD, 조항 `dev.pg_responsibility` |
| `feat.subscription_billing` | feature | boolean | | FR 정기결제·해지 2개, 화면 1개, 비용 4MD |
| `feat.admin` | feature | boolean | | FR 관리자 로그인·회원 관리·콘텐츠 관리 3개, 화면 4개, 비용 6MD |
| `feat.push` | feature | boolean | | FR 푸시 발송·수신 설정 2개, 화면 1개, 비용 2MD |
| `feat.email_notify` | feature | boolean | | FR 1개, 비용 1MD, 비용 infra "메일 발송 서비스" 1개(lump) |
| `feat.file_upload` | feature | boolean | | FR 1개, NFR 업로드 용량·형식 1개, 비용 2MD |
| `feat.search` | feature | single(basic, fulltext) | | basic FR 1 + 1MD, fulltext FR 1 + NFR 응답 시간 1 + 4MD |
| `feat.chat` | feature | boolean | | FR 실시간 채팅·읽음 표시 2개, 화면 2개, 비용 8MD, NFR 동시 접속 1개 |
| `feat.i18n` | feature | multi(en, ja, zh, vi) | | 언어마다 비용 "번역·현지화" 1개(ea), NFR 다국어 1개 |
| `feat.map_location` | feature | boolean | | FR 1개, 화면 1개, 비용 3MD, CON "지도 API 사용료는 발주자 부담" 1개 |
| `feat.ai_feature` | feature | boolean | | FR 1개, CON "AI 결과 정확도 비보장" 1개, 비용 5MD |
| `nfr.concurrent_users` | nfr | number | O | NFR "동시 사용자 {{answer}}명" 1개. 1,000 이상이면 비용 qa "부하 테스트" 1개 |
| `nfr.response_time_ms` | nfr | number | | NFR "주요 화면 응답 p95 {{answer}}ms" 1개 |
| `nfr.security_level` | nfr | single(basic, standard, high) | O | standard 이상 NFR 2개(암호화, 접근 로그), high면 비용 qa "모의해킹" 1개(lump) |
| `nfr.browser_support` | nfr | multi(chrome, edge, safari, firefox, ie_mode) | | NFR 호환 1개. ie_mode면 CON 경고 1개 |
| `delivery.source_code` | delivery | boolean | O | 산출물 "소스코드" 1개, 조항 `dev.source_delivery` |
| `delivery.manual` | delivery | multi(user, admin, ops) | | 매뉴얼 종류마다 산출물 1개 + 비용 pm 1MD |
| `delivery.design_files` | delivery | boolean | | 산출물 "디자인 원본 파일" 1개 |
| `delivery.deploy` | delivery | single(client_server, our_cloud, none) | O | client_server면 CON "서버 환경은 발주자 제공" 1개, our_cloud면 비용 infra 월 운영비 1개 |
| `contract_terms.payment_schedule` | contract_terms | single(advance_balance_50_50, advance_mid_balance_30_40_30, monthly) | O(계약서) | 조항 `dev.payment`(선금/중도금/잔금 비율 변수), 마일스톤 "중도금 검수" 1개(30/40/30일 때) |
| `contract_terms.warranty_months` | contract_terms | number | O(계약서) | 조항 `dev.warranty`(기간 변수). 0이면 조항 대신 "하자보수 없음" 문구 + lint warn |
| `contract_terms.ip_ownership` | contract_terms | single(client, developer, shared) | O(계약서) | 조항 `dev.ip` 변형 3종 중 1개 |
| `contract_terms.acceptance_days` | contract_terms | number | O(계약서) | 조항 `dev.acceptance`(검수 기간), 검수확인서 변수 |
| `contract_terms.delay_penalty` | contract_terms | boolean | | 조항 `dev.delay_penalty`(지체상금 비율 변수, 기본 1/1000 제안) |
| `contract_terms.confidentiality` | contract_terms | boolean | | 조항 `dev.confidentiality`. false여도 필수 비밀유지 조항 최소본은 포함 |

수량과 MD 값은 seed 초안(제안)이며 운영자 화면(DC-F-040)에서 버전으로 관리한다. 조항 code(`dev.*`)는 제안 식별자다.

### 3.3.1 content 체크리스트 (shorts_agency, `applies_to = {content}`)

dev 전용 항목(`profile.platforms`, `project_type.build_kind`, `feat.*` 개발 기능, `nfr.*`, `delivery.source_code`, `contract_terms.warranty_months`)은 `applies_to`를 web·app·ai·mixed·other로 좁혔다. `profile.service_summary`, `contract_terms.payment_schedule`(monthly 포함), `contract_terms.ip_ownership`, `contract_terms.acceptance_days`는 모든 유형에 나온다. 견적 항목은 크몽 숏폼 견적 체크리스트(촬영 포함 여부, 수정 횟수, 납기, 플랫폼별 재가공, 편수)를 참고했다([출처](https://kmong.com/prices/%EC%88%8F%ED%8F%BC-%EC%98%81%EC%83%81-%EC%A0%9C%EC%9E%91), 확인일 2026-10-13).

| key | group | input_type | 필수 | 효과 요약 |
|---|---|---|---|---|
| `content.channels` | profile | multi(youtube_shorts, instagram_reels, tiktok, naver_clip, threads) | O | 채널마다 NFR "업로드 규격(9:16, 길이, 자막 안전영역)" 1개 |
| `content.monthly_videos` | profile | number | O | FR "월 n편 제작·납품", 산출물 "숏폼 영상 월 n편", 마일스톤 "월간 납품·검수", 비용 production "숏폼 영상 제작" n × `catalog:short_video`(per_video) |
| `content.channel_count` | profile | number | | 업로드 대행 비용의 수량 |
| `feat.content_shooting` | feature | boolean | | CON "촬영 일정·장소 사전 합의", 비용 production "촬영"(ea), 조항 `vsc.shooting` |
| `feat.content_talent` | feature | boolean | | CON "출연자 초상권·출연 동의서 확보", 비용 media "출연료", 조항 `vsc.publicity_rights` |
| `feat.content_music_license` | feature | single(free_library, licensed_paid, client_provided) | O | licensed_paid면 비용 license(per_month), 조항 `vsc.license`(항상) |
| `feat.content_multilingual` | feature | multi(en, ja, zh, vi) | | 언어마다 비용 production "자막·더빙" n편(per_video) |
| `feat.content_affiliate` | feature | multi(brandconnect, shopping_connect, coupang, direct_sponsor) | | NFR "경제적 이해관계 표시(제목·영상 안·첫 해시태그)", 조항 `vsc.ad_disclosure`, `ad_disclosure_checklist` 생성 권장 |
| `delivery.upload_service` | delivery | boolean | | FR "채널 업로드·제목·해시태그·고정 댓글 관리", 비용 channel_ops 채널 수 × `catalog:channel_ops_month`(per_channel), 조항 `vsc.channel_ops`. 켜면 패키지에 `channel_access_mandate` 포함 |
| `delivery.naver_clip_upload` | delivery | boolean | | CON "네이버 클립 자동 업로드 위험 고지·동의", 조항 `vsc.automation_risk`(위임 동의서에는 `cam.automation_risk`) |
| `delivery.monthly_report` | delivery | boolean | | 산출물 "월간 성과 리포트", 비용 channel_ops(per_month) |
| `contract_terms.revision_rounds` | contract_terms | number | O(계약서) | 조항 `vsc.revision` |
| `contract_terms.secondary_use_months` | contract_terms | number | O(계약서) | 조항 `vsc.secondary_use` |
| `contract_terms.retainer_months` | contract_terms | number | | 조항 `vsc.term` |

단가 토큰 `catalog:<key>`(short_video, shooting_day, talent_fee, music_license, localize_video, channel_ops_month, monthly_report)는 조직 단가 카탈로그(`workspace_settings.defaults`, DC-F-028)에서 읽는다. 키가 없으면 단가 0으로 넣고 견적서 lint warn "단가 미입력"을 낸다(D-14). 효과 엔진 결정성(3.2절)은 그대로다: 같은 설정·답이면 같은 결과다.

### 3.4 lint 규칙 (DC-F-016, 문서 유형 버전의 `lint_rules`)

| 코드(제안) | 수준 | 규칙 | 적용 유형 |
|---|---|---|---|
| `L-AMOUNT-MATCH` | error | 공급가·VAT·총액이 정본 계산값과 같고, quote·sow·dev_contract 사이에서 같다 | quote, sow, dev_contract, video_service_contract |
| `L-PAY-100` | error | 지급 비율 합 = 100%, 지급 금액 합 = 총액 | dev_contract, video_service_contract |
| `L-PERIOD` | error | 기간이 프로젝트 시작·종료일과 같고 마일스톤이 기간 안에 있다 | sow, wbs, dev_contract, video_service_contract, channel_access_mandate |
| `L-PARTY` | error | 당사자 상호·대표자가 `parties`와 같고 문서 전체에서 같다 | quote, sow, dev_contract, acceptance, shorts_agency 계약·확인 문서 |
| `L-REQ-REF` | error | 본문의 FR/NFR/CON 코드가 실제 요구사항이다 | 전체 |
| `L-REQUIRED-CLAUSE` | error | 필수 조항이 모두 있다 | dev_contract, video_service_contract, channel_access_mandate. content 프로젝트에서 광고·제휴(`feat.content_affiliate`)를 켰으면 `vsc.ad_disclosure` 필수 |
| `L-RRN` | error | 13자리 주민등록번호 패턴(`\d{6}-?[1-8]\d{6}`, 외국인등록번호 `[5-8]` 포함)이 없다 | 전체 |
| `L-UNTRACED` | warn | 화면 연결 없는 FR, 검수 항목 없는 must 요구사항 | req_spec, trace_matrix |
| `L-AI-CLAIM` | warn | 서술 섹션이 정본에 없는 기능·수치를 언급(경량 LLM 판정) | hybrid, ai 유형 |
| `L-BANNED` | error/warn | 6.1절 금지 문구(compliance 규칙 사전) | 전체 |
| `L-NO-GUARANTEE` | error | 조회수·구독자·매출 등 성과 보장 표현("조회수 100만 보장", "구독자 보장")이 없다. 계약서에는 `vsc.no_guarantee` 조항이 있다 | content_brief, video_service_contract, monthly_report, service_intro |
| `L-AD-DISCLOSURE` | error | 광고·제휴 채널마다 표시 위치(제목, 영상 안, 첫 해시태그 중 하나 이상)와 표시 문구가 있고, "소정의 수수료를 받을 수 있음" 같은 조건부 표현만 쓰지 않는다(6.4절) | ad_disclosure_checklist |

### 3.5 패키지 생성 순서와 크레딧

| 순서 | 문서 | 선행 | 크레딧 |
|---|---|---|---|
| 0 | 효과 엔진 적용(체크리스트 → 정본) | 없음 | 0 |
| 1 | `req_spec`, `screen_list`, `wbs`(병렬, 조직 동시 한도 안에서) | 0 | 6, 6, 2 |
| 2 | `quote` | 0 | 2 |
| 3 | `sow` | 1, 2 | 6 |
| 4 | `dev_contract` | 2, 3, 고지 동의 | 2 |
| 5 | `acceptance` | 1 | 2 |
| 6 | `trace_matrix` | 1, 5 | 2 |
| 합계 | 8종 | | 28 |

### 3.5.1 shorts_agency 생성 순서와 크레딧

| 순서 | 문서 | 선행 | 크레딧 |
|---|---|---|---|
| 0 | 효과 엔진 적용(content 체크리스트 → 정본) | 없음 | 0 |
| 1 | `content_brief` | 0 | 6 |
| 2 | `quote` | 0 | 2 |
| 3 | `sow` | 1, 2 | 6 |
| 4 | `video_service_contract`, `channel_access_mandate`(업로드 대행을 켠 경우만) | 2, 3, 유형별 고지 동의 | 2, 2 |
| 5 | `acceptance` | 1 | 2 |
| 합계 | 6종(업로드 대행 없으면 5종) | | 20(18) |

`package_order`는 유형마다 한 값이라 두 패키지가 같은 순서 체계(1 기획 → 2 견적 → 3 과업 → 4 계약 → 5 검수)를 쓴다. 추적표는 shorts_agency에 넣지 않는다(요구사항 수가 적다).

### 3.6 문서번호

| 항목 | 값 |
|---|---|
| 기본 형식 | `{TYPE}-{YYYY}-{SEQ:4}`(제안, DB 기본값과 같음). 토큰 `{TYPE}`/`{PREFIX}`, `{YYYY}`, `{YY}`, `{SEQ:n}`. `doc_counters`(org, 유형, 연도)로 연도별 일련번호, 확정 때만 증가 |
| 유형 접두(제안) | quote `QT`, sow `SOW`, req_spec `REQ`, wbs `WBS`, screen_list `SL`, dev_contract `CT`, acceptance `AC`, minutes `MN`, trace_matrix `TM`. Phase 2 shorts_agency: content_brief `CB`, video_service_contract `VC`, channel_access_mandate `CAM`, brand_guide_ack `BG`, ad_disclosure_checklist `ADC`, monthly_report `MR`, service_intro `SI` |
| 연도 기준 | KST 확정 일자 |

## 4. 요금과 크레딧

모든 가격은 원화, VAT 포함이다(B2C SaaS 기본, `docs/Price_Plans/_common/PRICING_PRINCIPLES.md` 7장, 2026-10-14 결정). 단계별 인상 계획은 `docs/Price_Plans/nomad-docs/PRICE_PLAN.md` 6장. 모든 금액·크레딧은 제안이다(D-4). 이유: 신규 제품이라 원가 측정 전이고 확정 결정 8이 이 제품의 플랜 정본을 지정하지 않았다(`docs/products/00_MERGE_ANALYSIS.md:16`). 플랜·팩 정본은 이 절이고 모듈러 `seed.sql` 반영은 코어 요청 C-3이다(`docs/products/_platform-core/DB_CONVENTIONS.md:235`).

### 4.1 플랜

| 코드 | 가격(월, VAT 포함) | 가입 크레딧(pack 버킷) | 월 크레딧(plan 버킷) | 이월 | 상태 | 가격 이유(제안) |
|---|---|---|---|---|---|---|
| `free` (기본) | 0원 | 50 | 30 | 없음 | 베타 활성 | 첫 달 80 크레딧 = 패키지 1회(28) + PDF 8건(8) + RFP 추출 1회(10) + 채팅 약 30턴. 체험 1회로 가치를 보게 한다 |
| `pro` | 19,900원 | 0 | 400 | 없음 | MVP | 월 패키지 약 10회 + 내보내기·채팅. 프리랜서 월 수주 상담 4~6건 기준으로 여유 2배 |
| `team` | 59,000원 | 0 | 1,500 | 없음 | Phase 2(팀 조직 생성 코어 요청 C-5 선행) | 5인 에이전시 기준 프로젝트 5개 × 패키지·개정 반복 |

### 4.2 `core.plans.features` 키 해석 (서버만 읽는다, `docs/products/_platform-core/DB_CONVENTIONS.md:240`)

| 키 | 의미 | free | pro | team | 키가 없을 때 | 사용 위치 |
|---|---|---|---|---|---|---|
| `projects_max` | 활성(archived 제외) 프로젝트 수 | 2 | 50 | 300(2026-10-14 결정: 판매 문구 "무제한" 금지, `docs/Price_Plans/_common/PRICING_PRINCIPLES.md` 6장. null은 운영 조직 수동 부여용으로만 트리거가 계속 처리) | 2 | 프로젝트 생성 API, `DC006` |
| `formats` | 허용 내보내기 형식 | ["pdf"] | ["pdf","docx","zip"] | ["pdf","docx","zip"] | ["pdf"] | 내보내기 API |
| `watermark` | PDF 워터마크 강제 | true | false | false | true | 렌더 옵션(서버가 결정) |
| `doc_phase` | 허용 문서 유형 단계 | "mvp" | "mvp" | "phase2" | "mvp" | 생성 API, 카탈로그 표시 |
| `members_max` | 조직 멤버 수 | 1 | 1 | 5 | 1 | 초대 API(Phase 2) |
| `integrations` | 허용 연동 provider | ["csv"] | ["csv","webhook"] | ["csv","webhook","hubspot","admin_suite_erp","n8n"] | ["csv"] | 연동 API |
| `approvals` | 검토·승인 흐름 | false | false | true | false | DC-F-035 |
| `share_links` | 외부 공유 링크 | false | false | true | false | DC-F-037 |
| `ai_chat_turns_per_day` | 하루 채팅 턴 상한(제안 키) | 30 | 200 | 500 | 30 | `/api/ai/chat`, 초과 429 |
| `minutes_max_minutes` | 회의 녹음 1회 최대 분(제안 키) | 30 | 120 | 180 | 30 | 회의록 업로드, 초과 413 |
| `storage_mb` | 업로드 자료 총용량(제안 키) | 200 | 5,000 | 20,000 | 200 | 업로드 URL 발급, 초과 413 |

### 4.3 크레딧 단가

| 작업 | 크레딧 | 근거 |
|---|---|---|
| template 문서 생성 | 2 | 기준서 10장(제안). LLM 0회지만 렌더 전 단계 처리와 남용 방지 |
| hybrid 문서 생성 | 6 | 기준서 10장(제안). 서술 섹션 3~5개 LLM |
| ai 문서 생성(회의록 제외) | 12 | 기준서 10장(제안). Phase 2 proposal, biz_plan |
| 패키지 `outsourcing_basic` | 28(구성 합계) | 3.5절 |
| 패키지 `shorts_agency`(Phase 2) | 20(구성 합계, 업로드 대행 없으면 18) | 3.5.1절 |
| 다시 쓰기 제안 1회 | 1 | 기준서 10장(제안) |
| RFP 추출 | 10(50쪽까지), 이후 50쪽당 +5 | 기준서 10장(제안). 300쪽 = 35 |
| 회의록 | STT 분당 1 + 그래프 5 | 기준서 10장(제안). 60분 = 65 |
| PDF/DOCX 내보내기 | 1(같은 버전·형식 재요청 0) | 기준서 10장(제안) |
| ZIP | 0(구성 렌더에서 차감) | 기준서 8장 |
| 채팅 1턴 | 1 | 기준서 10장(제안) |
| 자료 색인 | 1MB당 1(올림) | 기준서 10장(제안) |
| 체크리스트 효과 엔진, lint, 버전 비교, 확정, 추적표 화면 | 0 | 결정적 서버 계산 |

### 4.4 크레딧팩 (pack 버킷, 소멸 없음)

| 코드 | 크레딧 | 가격(VAT 포함) | 크레딧당 |
|---|---|---|---|
| `pack_100` | 100 | 4,900원 | 49원 |
| `pack_300` | 300 | 12,900원 | 43원 |
| `pack_1000` | 1,000 | 39,000원 | 39원 |

### 4.5 AI·음성 크레딧과 경로별 차이

제공자 원가 단가는 코어 seed `core.ai_model_prices`(`docs/products/_supabase-modular/seed.sql:243-262`: LLM 상용 1k 입력 1·출력 4, 오픈소스 0.2·0.5, 임베딩 오픈소스 0.01/1k, STT ElevenLabs 3/분·오픈소스 0.5/분, TTS ElevenLabs 5/1천 자·오픈소스 1/1천 자, 모두 제안)다. 선차감·정산·실패 환불 규칙은 `docs/products/_platform-core/AI_ARCHITECTURE.md:121-130`, 음성 단가는 `docs/products/_platform-core/VOICE_ARCHITECTURE.md:97-104`를 따른다.

| 작업 | 선차감 | 정산 | 멱등 키 |
|---|---|---|---|
| 채팅 1턴(텍스트) | 1 | 정액 확정(차액 0). 응답이 전달되지 않으면 전액 환불 | `conv:<id>:turn:<n>` |
| 문서 생성 그래프(hybrid·ai) | 유형 단가(6, 12) | 정액 확정. 버전이 전달되지 않으면 전액 환불 | `consume:docs:gen:<request_id>`, `run:<ai_run_id>` |
| RFP 추출 그래프 | 쪽수 기준 단가 | 정액 확정. 실패 전액 환불 | `run:<ai_run_id>` |
| 자료 색인(임베딩, 오픈소스 고정) | 1MB당 1 | 정액 확정 | `consume:docs:index:<request_id>` |
| 회의록 STT(`meeting_minutes`, 오픈소스 강제) | 분당 1(올림) | 실제 `audio_seconds`로 다시 계산해 남는 분 환불 | `voice:<voice_job_id>` |
| 음성 질문 STT(60초 이하) | 오픈소스 1 / ElevenLabs 3 | 실제 경로 단가로 정산 | `voice:<voice_job_id>` |
| 읽어 주기 TTS | 1천 자당 오픈소스 1 / ElevenLabs 5(올림) | 실제 `characters`로 정산 | `voice:<voice_job_id>` |
| 위키 갱신(`wiki.ingest`) | 0(색인 단가에 포함, 제안) | `ai_usage` 기록만 | - |

| 규칙 | 내용 | 근거 |
|---|---|---|
| 경로별 차이 | 문서 생성·추출·채팅·색인은 오픈소스/상용 경로와 무관한 정액이다(제안: 사용자가 "문서 1건 = n 크레딧"으로 이해하고, 견적처럼 실행 전에 확정 금액을 보여 주기 위해). 원가 차이는 `core.ai_usage.cost_usd_micros`로 기록해 베타 2주 후 단가를 보정한다(D-4). 음성(STT 질문, TTS)은 경로별 원가 차이가 3~5배라 경로별 단가를 쓴다 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:101-102` |
| 국외 이전 미동의 | 체인에 오픈소스만 남는다. 정액 작업은 가격이 같고, 음성은 오픈소스 단가가 적용된다 | `docs/products/_platform-core/AI_ARCHITECTURE.md:86` |
| 폴백 비용 | 오픈소스 실패 → 상용 대체 시 원가가 선차감보다 커도 추가 청구하지 않고 `ai_usage.status='fallback'`으로 집계 | `docs/products/_platform-core/AI_ARCHITECTURE.md:88` |
| 차감 위치 | `docs.start_generation`(service_role)이 run 생성 + 잡 enqueue + `core.consume_credits`를 한 트랜잭션에서. 사용자용 RPC 안에서 차감하지 않는다 | `docs/products/_platform-core/DB_CONVENTIONS.md:239`, 기준서 6장 |
| 성공 후 저장 실패 | 환불하지 않고 `ai_usage.status='error'` | `docs/products/_platform-core/CORE_SPEC.md:188` |

## 5. 비기능 요구사항

근거가 표시되지 않은 수치는 제안이다. 이유: 신규 제품이라 측정 기준이 없다.

| 항목 | 값 | 비고 |
|---|---|---|
| template 문서 생성(요청 → 버전 표시) | p95 5초 이하 | LLM 0회 |
| hybrid 문서 생성 | p95 60초 이하. 5분 초과 시 실패 처리와 환불 | 서술 섹션 병렬 LLM |
| 패키지 `outsourcing_basic` | p95 4분 이하 | 3.5절 순서 |
| PDF 렌더(A4 20쪽) | p95 30초 이하. 렌더 타임아웃 120초 | `docs/products/_platform-core/SHARED_MODULES.md:274` |
| DOCX 렌더(A4 20쪽) | p95 30초 이하 | 코어 요청 C-1 |
| 효과 엔진 적용 | p95 3초 이하(항목 200개) | 3.2절 |
| 체크리스트 답 저장 API | p95 300ms 이하(효과 적용 제외) | |
| RFP 추출(40쪽) | p95 3분 이하 | DC-F-022 |
| 색인(40쪽 PDF) | p95 90초 이하 | DC-F-021 |
| 채팅 첫 토큰 | p95 6초 이하 | Dify 경유 |
| 회의록(60분 녹음) | p95 10분 이하 | STT 요청당 10분 조각(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:61`) |
| 업로드 상한 | 자료 20MB·300쪽, 녹음 200MB·플랜 `minutes_max_minutes`(30/120/180분), CSV 5MB·5,000행, 직인 2MB | 자료 20MB는 `docs/products/flora-publishing/01_PRD.md:87` |
| 본문 크기 | `body_html` 2MB 이하(DB CHECK), 버전당 섹션 200개 이하 | 기준서 6장 |
| 동시 생성 | 조직당 3건(`runtime_config.max_active_generations_per_org`, 패키지 1건 = 1건), 문서당 1건 | 기준서 4장 DC-F-039 |
| 레이트 리밋 | 로그인·가입 IP당 10회/10분, 생성 API 조직당 20회/분(코어 기준 60회/분보다 낮춤: 고비용), `docs:ai-chat:<user>` 20회/60초, `docs:extract:<org>` 10회/시간, `docs:upload-url:<org>` 30회/시간, `docs:voice-stt:<user>` 10회/60초, 수신 웹훅 제공자당 600회/분 | `docs/products/_platform-core/SECURITY_BASELINE.md:147-149` |
| 일일 플랫폼 상한 | 20,000 크레딧/일(`runtime_config.daily_credit_cap`), KST 자정 | 베타 비용 서킷 브레이커 |
| 보존: 문서 버전 | 계정이 있는 동안(append-only). 프로젝트 삭제 시 휴지통 30일 후 purge | 기준서 2장 원칙 5 |
| 보존: 내보내기 | 서명 URL 7일, 파일 30일 후 삭제(`doc_exports.status='expired'`), 재요청 시 다시 렌더(같은 버전 7일 안은 재과금 없음) | `docs/products/_platform-core/SHARED_MODULES.md:271` |
| 보존: 업로드 자료 | 원본 파일 90일 후 삭제, 파싱 텍스트·청크는 프로젝트 삭제 시까지(D-10) | 제안 |
| 보존: 회의 녹음 원본 | 처리 완료 24시간 후 삭제(D-11). 전사본은 회의록 버전과 함께 보존 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:90-91` |
| 보존: Dify 대화 로그 | 30일 | `docs/products/_platform-core/AI_ARCHITECTURE.md:69` |
| 계정 삭제 유예 | 30일 후 `purge_organization` | `docs/products/_platform-core/SECURITY_BASELINE.md:197` |
| 가용성 | 월 99.5%(제안. 업무 문서 도구라 study-note 베타 99%보다 높게) | 업타임 모니터링 |
| 접근성·반응형 | 375/768/1024/1440px, 키보드 조작, 대비 4.5:1. 편집기와 추적표는 1024px 이상 권장, 모바일은 열람·체크리스트 입력 중심 | |
| 로그 | 문서 본문, 업로드 원문, 프롬프트 전문, 전사본을 애플리케이션 로그에 남기지 않는다. 잡 payload는 id만 | `docs/products/_platform-core/SECURITY_BASELINE.md:199`, `:304` |

## 6. 법, 개인정보, 금지 문구

이 절의 판단은 모두 제안이며 법무 확인이 필요하다. 법령 해석은 확인하지 않았다(미확인).

| 항목 | 내용 |
|---|---|
| 개인정보: 수집 항목 | 회원: 이메일, 표시 이름, 비밀번호 해시(Supabase Auth, 이메일 가입자), 로그인 제공자 식별자(단계별: Stage B부터 Google 계정 식별자·이름·프로필 이미지 URL, C1부터 카카오 사용자 식별자·닉네임·프로필 이미지·비즈 앱이면 이메일, C2부터 네이버 고유 id·이메일·이름. AUTH_ROADMAP 5.2, 7.1.1, 7.2.3절. Stage A 시드 계정은 로컬 DB에만 있고 `.test` 도메인이라 개인정보가 아니다). 당사자(`parties`): 상호, 대표자 이름, 주소, 담당자 이름·이메일·전화, 사업자등록번호(개인사업자·프리랜서는 개인정보에 해당할 수 있음). 업무 데이터: 프로젝트 정보, 업로드 자료(RFP에 제3자 정보가 들어 있을 수 있음), 회의 녹음과 전사본(참석자 음성·발언). **주민등록번호·외국인등록번호·여권번호 등 고유식별정보는 수집하지 않는다**: 입력란을 두지 않고, 모든 텍스트 입력·CSV 가져오기·문서 편집 저장에서 13자리 패턴(`\d{6}-?[1-8]\d{6}`)을 서버 lint로 차단한다(422 `pii_detected`, 확정 lint `L-RRN`). 업로드 자료에서 발견되면 차단하지 않고 LLM 전송 전 마스킹한다 |
| 개인정보: 목적 | 계정 인증, 문서 생성 서비스 제공, 결제, 연동(사용자가 켠 경우), 부정 사용 방지 |
| 개인정보: 보존 | 5장 보존 행. 결제 기록은 관련 법령상 보존 기간(미확인, 법무 확인). IP는 해시만 |
| 암호화 대상 | 연동 토큰·웹훅 비밀은 `core.encrypted_credentials`에만. `parties` 연락처는 앱 계층 컬럼 암호화 대상에 넣지 않는다(제안: 민감정보가 아니고 문서 렌더·검색에 평문이 필요. `SECURITY_BASELINE.md` 12장 대상은 astro 생년월일시, `docs/products/_platform-core/SECURITY_BASELINE.md:194`). 직인 이미지는 비공개 버킷, 서명 URL로만 렌더 서비스에 전달 |
| 삭제 절차 | 거래처·프로젝트: soft delete(`deleted_at`) → 휴지통 30일 → purge. 확정 문서 버전은 프로젝트 purge 때 함께 삭제. 계정: soft delete → 30일 → `purge_organization` + Storage 삭제 |
| 제3자 제공·국외 이전 | 상용 LLM(Anthropic, OpenAI, Google)·음성(ElevenLabs)은 국외 이전에 동의한 조직의 요청에만 쓴다(`docs/products/_platform-core/SECURITY_BASELINE.md:293`). 보내는 범위: hybrid 서술 섹션 입력(정본 요약, 마스킹된 자료 조각), 다시 쓰기 선택 영역, 채팅 질문과 근거 조각, 음성 질문 오디오, 읽어 줄 답변. 보내지 않는 것: 회의 녹음 오디오(오픈소스 강제), 고위험 문서 본문(AI 미사용), `contains_pii=true` 자료(오픈소스 강제), 직인 이미지. RFP 추출은 오픈소스 우선(고객 기밀). 처리방침에 제공자와 이전 국가를 적는다 |
| 오픈소스 강제 범위 | `meeting_minutes` STT(제3자 음성), `dify.aux`, `contains_pii` 자료의 임베딩·LLM. 회의 전사본을 `docs.minutes` 그래프가 상용 LLM으로 대체 처리할 수 있는지(기준서 9장 체인 oss-llm → anthropic)는 제3자 발언이 담기므로 D-11에서 함께 결정한다(권고: 강제 오픈소스) |
| 약관/고지 | 이용약관, 개인정보처리방침, AI 생성물 안내, 계약서 고지(6.2절)를 가입 화면과 푸터에 링크. 약관 포함: 서비스는 문서 작성 도구이며 법률·세무 자문이 아님, 크레딧 정책(이월 없음, 실패 환불), 사용자 책임(입력 정보의 정확성, 업로드 권한, 녹음 동의), 금지 행위(타인 고유식별정보 입력, 허위 문서 작성) |
| 생성물 저작권과 책임 | 생성 문서의 이용 권한은 사용자에게 있다. 정확성·적법성 검토 책임은 사용자에게 있다고 문서 화면과 PDF 꼬리말·메타데이터에 안내(D-9) |
| AI 생성 표시 | AI가 쓴 섹션은 편집기에서 "AI 초안" 배지, 채팅 답변·회의록·추출 후보에 "AI가 생성한 내용" 표시, 음성 답변 재생 전 표시. PDF는 메타데이터(`Producer`/`Keywords`)에 AI 생성 표시, 꼬리말 표기 여부는 D-9 |
| 녹음 동의와 제3자 음성 | 회의 녹음 전 매번 고지: "이 녹음에는 회의 참석자의 목소리와 발언이 담깁니다. 녹음 전에 참석자에게 알리고 동의를 받는 책임은 사용자에게 있습니다. 녹음은 회의록 작성에만 쓰고 처리 후 24시간 안에 삭제합니다." `consent_kind=third_party_notice`, 고지문 버전 기록(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:95`). 대화 당사자가 아닌 사람이 타인 간 대화를 녹음하는 용도로 쓰지 말라는 문구(통신비밀보호법 해석 미확인) |
| 계약서 법률 서비스 규제 | 문서 자동 작성이 변호사법상 비변호사의 법률사무 취급 금지 규정과 충돌하는지 미확인. 출시 게이트 D-3: 법무 검토 완료 전 `dev_contract`는 `doc_types.is_active=false`(패키지는 7종으로 축소 표시). 완화 설계: 템플릿만, AI 조항 생성·수정 없음, 개별 사안 판단 없음, 채팅의 법률 판단 거절 |
| 표준계약서 원문 | 조항 라이브러리의 기반으로 쓸 공공 표준계약서(후보: 과학기술정보통신부 소프트웨어사업 표준계약서, 공정거래위원회 표준하도급계약서 소프트웨어업종)의 존재·최신판·이용 조건 미확인(D-8). 확인 전에는 운영자가 직접 작성한 조항만 게시하고 `source_note`에 출처를 적는다 |
| 제휴/광고 | 제품 자체에는 제휴 링크와 광고가 없다(affiliate 모듈 미사용). 다만 shorts_agency 문서는 고객의 광고 영상 표시 의무를 다루므로 6.4절 근거로 `vsc.ad_disclosure` 조항과 `ad_disclosure_checklist`를 둔다 |
| 플랫폼 약관 | HubSpot(Phase 2), Salesforce·이카운트·더존(Phase 3) API 이용 약관·호출 한도·앱 등록 요건 미확인. 연동 시작 시 사용자가 외부 계정 연결과 데이터 이동 범위(필드 매핑)를 확인하는 동의 화면을 둔다 |
| 규제 특례 | 의료·금융·미성년자 데이터를 다루지 않는다. 만 14세 이상 가입 확인(제안). 인사·노무 문서(근로계약서 등, Phase 3)는 근로기준법상 필수 기재 사항과 최저임금 등 강행 규정 위반 위험이 있어 별도 법무 검토 후 연다(DC-F-044). 개인정보처리방침·이용약관 생성(Phase 3)도 같은 이유 |

### 6.1 금지 문구 점검표 (랜딩, 03장 카피, 생성 문서 공통)

| 금지 | 예 | 대체 |
|---|---|---|
| 가상 후기 | "프리랜서 김OO: 계약서 쓰는 시간이 10분으로 줄었어요" | 후기 섹션을 두지 않는다. 출시 후 동의받은 실제 후기만 |
| 허위 수치 | "1만 건 생성", "문서 작성 시간 90% 단축", "고객사 500곳" | 수치를 쓰지 않거나 측정값을 측정 기간과 함께 |
| 법적 효력 보장 | "법적 효력 보장", "분쟁 걱정 없는 계약서", "법적으로 완벽" | "표준 조항을 바탕으로 한 초안입니다. 서명 전에 전문가 검토를 권합니다" |
| 결과 보장 | "100% 승소", "지원사업 100% 통과", "검수 무조건 통과" | "필요한 항목을 빠짐없이 챙기도록 돕습니다" |
| 성과 보장(shorts_agency) | "조회수 100만 보장", "구독자 1만 명 보장", "알고리즘 노출 보장" | "목표 지표와 측정 방법을 합의하고 매달 보고합니다"(`L-NO-GUARANTEE`) |
| 전문가 대체 | "변호사 수준", "변호사 없이 계약 끝", "노무사가 필요 없습니다" | "법률 자문이 아닙니다" |
| 공공기관 보증 | "정부 인증 양식", "공정위 승인" | 표준계약서 출처 표기는 D-8 확인 후 "OO 표준계약서를 참고" 수준만 |
| 타사 상표 오용 | HubSpot·Salesforce 로고를 제휴·보증처럼 사용 | 연동 대상 이름은 텍스트로만 |
| 예시 문서 | 랜딩 예시를 실제 고객 문서처럼 표기 | "예시"로 명시하고 가상 회사명만 |

생성 문서 안에서는 compliance 규칙 사전이 "법적 효력 보장", "100%", "반드시 승소" 류를 FAIL로, 근거 없는 수치를 WARN으로 처리한다(`docs/products/_platform-core/SHARED_MODULES.md:359`).

### 6.2 고위험 문서 고지문 (DC-F-020, 버전 `notice-contract-2026-10-13`, 제안)

"이 계약서는 표준계약서와 일반적인 실무 관행을 바탕으로 만든 초안이며 법률 자문이 아닙니다. 계약 당사자의 구체적인 사정과 거래 조건에 맞는지 확인할 책임은 사용자에게 있습니다. 서명 전에 변호사 등 전문가의 검토를 받기를 권합니다. NOMAD Docs의 AI는 이 문서의 조항을 만들거나 고치지 않습니다."

| 고지·동의 | 시점 | 기록 |
|---|---|---|
| 상용 AI 국외 이전 | 이메일 인증 직후 온보딩, 설정에서 변경 | `core.set_ai_cross_border_ack` + 감사 `docs_consent.ai_cross_border`(고지문 버전) |
| 고위험 문서 | 유형별 첫 생성 전, 고지문 버전 변경 시 | `docs.risk_acknowledgements` + 감사 |
| 채널 위임 동의서(Phase 2) | `channel_access_mandate` 첫 생성 전, 고지문 `notice-channel-mandate-2026-10-13` | `docs.risk_acknowledgements` + 감사 |
| 회의 녹음(제3자) | 녹음·업로드마다 | `voice_jobs` 동의 컬럼 + 감사 `docs_consent.minutes_notice` |
| 음성 대화 | 첫 마이크 사용 | 감사 `docs_consent.voice` |
| 업로드 권한 | 업로드마다 | 감사 `docs_upload_rights` |
| 연동 데이터 이동 | 연동 연결 시(Phase 2) | 감사 `docs_consent.integration` |

채널 위임 동의서 고지문(버전 `notice-channel-mandate-2026-10-13`, 제안): "이 위임 동의서는 초안이며 법률 자문이 아닙니다. 공식 업로드 API가 확인되지 않은 채널(예: 네이버 클립)에 자동화 도구로 업로드하면 플랫폼 약관 위반으로 업로드 제한, 계정 정지, 수익 정산 보류가 생길 수 있습니다. 채널 소유자인 고객에게 이 위험을 알리고 서면 동의를 받을 책임은 사용자에게 있습니다. 계정 접근은 비밀번호 공유보다 플랫폼의 관리자 초대 기능을 먼저 쓰세요. NOMAD Docs의 AI는 이 문서의 조항을 만들거나 고치지 않습니다."

### 6.3 AI 대화 규칙 (채팅, 다시 쓰기, 회의록)

| 분류 | 금지 | 대신 |
|---|---|---|
| 법률 판단 | 조항 유효성·분쟁 승패·위법 여부 단정 | "법률 판단은 할 수 없습니다. 변호사 상담을 권합니다" |
| 계약 조항 작성 | 채팅에서 새 계약 조항 문안 작성 | 조항 라이브러리 안내 |
| 근거 없는 단정 | 자료에 없는 요구사항·금액을 사실처럼 서술 | "프로젝트 자료에서 근거를 찾지 못했습니다" |
| 금액 계산 | LLM이 합계·VAT 계산 | 서버 계산값 인용 |
| 개인정보 요구 | 주민등록번호, 계좌 비밀번호 요청 | 묻지 않는다 |

### 6.4 숏폼 제작·채널 운영 대행 문서의 근거 (DC-F-046, 확인일 2026-10-13)

| 주제 | 확인한 내용 | 반영 | 출처 |
|---|---|---|---|
| 광고 표시(추천보증 심사지침) | 2024년 개정으로 경제적 이해관계를 게시물 첫 부분에 표시하도록 했고, 영상은 제목·영상 안·첫 해시태그 등으로 알리도록 안내됐다. "소정의 수수료를 받을 수 있음" 같은 조건부 표현은 불명확한 표시로 제시됐다. 2025-12 Q&A 안내서 개정본이 배포됐다. 시행일은 보도마다 달라 원문 확인 필요(미확인) | `vsc.ad_disclosure`, `ad_disclosure_checklist`, `L-AD-DISCLOSURE` | [아주경제 2025-12-02](https://www.ajunews.com/view/20251202085042877), [법무법인 세종 뉴스레터](https://shinkim.com/kor/media/newsletter/2613) |
| AI 가상인물 광고 | 2026-04 AI 가상인물 추천·보증 시 '가상인물' 표시 의무화 개정안이 행정예고됐다는 보도가 있다. 최종 확정 여부는 미확인 | `ad_disclosure_checklist`의 "AI 가상인물 표시" 섹션(확정 전에는 권고 문구) | 위 보도 검색 결과. 원문 확인 필요 |
| 표준계약서 | 문체부 고시 중 영상 제작·MCN 전용 표준계약서를 찾지 못했다. 가까운 후보는 방송프로그램 제작 표준계약서, 디지털콘텐츠 공급 표준계약서다 | 조항은 자체 작성 초안(`status='draft'`, `source_note='미확인(D-8, D-15)'`), 법무 검토 전 비활성 | [문화체육관광부 훈령·고시](https://www.mcst.go.kr/site/s_data/ordinance/instruction/instructionView.jsp?pSeq=150) |
| 견적 관행 | 숏폼 견적은 촬영 포함 여부, 수정 횟수, 납기, 플랫폼별 재가공, 편수에 따라 달라진다 | 3.3.1절 체크리스트, 단위 per_video·per_channel·per_month | [크몽 숏폼 영상 제작 비용](https://kmong.com/prices/%EC%88%8F%ED%8F%BC-%EC%98%81%EC%83%81-%EC%A0%9C%EC%9E%91) |
| 성과 보장 | 조회수·구독자 보장이나 구매는 플랫폼 정책 위반 위험이 있다(일반 실무 판단, 법령 해석 아님) | `vsc.no_guarantee`, `L-NO-GUARANTEE`, 6.1절 금지 문구 | 제안 |
| 네이버 클립 업로드 | 공식 업로드 API를 찾지 못했다. 업로드 대행은 브라우저 자동화가 된다(sceneflow 기획) | `delivery.naver_clip_upload`, `vsc.automation_risk`, `cam.automation_risk`, 위임 동의서 고지문 | `docs/products/sceneflow/01_PRD.md`(클립 채널 기획) |

sceneflow와의 경계: 고객사·고객 승인·성과 수집 같은 대행 운영 데이터는 sceneflow의 에이전시 운영 기능(별도 작업)이 소유한다. 이 제품은 그 데이터를 DB로 참조하지 않는다(외래키·교차 스키마 조회 없음). `monthly_report`의 KPI는 사용자가 입력하거나 sceneflow에서 내려받은 CSV를 올린다. 자동 연동은 D-16에서 정한다.

## 7. KPI

목표값은 모두 제안이다. 이유: 출시 전이라 기준 데이터가 없다.

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| 활성화: 가입 후 30분 안에 첫 패키지(또는 문서 3종 이상) 생성 성공 | 40% 이상 | 가입 시각 대비 첫 `generation_runs.status='succeeded'`(package_code 또는 문서 3개) | 베타 첫 4주 |
| 확정률: 생성된 문서 중 30일 안에 final | 35% 이상 | `documents.finalized_at` / 생성 문서 | 월간 |
| 편집 거리: 생성 버전 대비 확정 버전의 변경 문자 비율(중앙값) | 20% 이하 | 버전 diff 문자 수 / 생성 버전 문자 수 | 월간 |
| 생성 성공률(succeeded / 종료) | 97% 이상(template), 92% 이상(hybrid) | `generation_runs` 집계 | 주간 |
| 확정 시 lint error 0 비율 | 100%(게이트) | `lint_result` | 주간 |
| 유료 전환: 가입 60일 안 첫 결제(구독 또는 팩) | 6% 이상 | Toss 결제 | 코호트 60일 |
| 재방문: 가입 코호트 중 30일 안 두 번째 프로젝트 생성 | 25% 이상 | `projects.created_at` | 코호트 |
| 체크리스트 완료율(필수 항목 100% 답한 프로젝트) | 60% 이상 | `checklist_answers` | 월간 |
| RFP 추출 후보 채택률 | 50% 이상 | 확정 후보 / 제안 후보 | 월간 |
| AI 출처 표시율(채팅 답변) | 100% | `ai_messages.citations` | 주간 |
| 연동 사용률(team 조직 중 연동 1개 이상 active) | 30% 이상 | `integration_connections.status='active'` | Phase 2 이후 월간 |
| 환불 비율(환불 크레딧 / 차감 크레딧) | 5% 이하 | 원장 집계 | 주간 |
| 크레딧당 원가 | 보정 기준 확보 | `ai_usage.cost_usd_micros` / 크레딧, 기능·경로별 | 베타 2주 후 |
| 미정산 `ai_usage`(1시간 초과) | 0행 | `settled_at is null` | 일간 |

## 8. 열린 결정

| ID | 결정 | 선택지 | 권고 |
|---|---|---|---|
| D-1 | 브랜드명 | (a) NOMAD Docs (b) 한글 브랜드(예: "노마드 문서함") (c) 기능형 이름 | (a)로 베타. 폴더·app id(`docs`)는 브랜드와 무관하게 유지 |
| D-2 | MVP 문서 범위 | (a) 8종 유지(계약서 포함) (b) 계약서 제외 6종 + 추적표 | (a) 설계·구현은 8종, 공개는 D-3 게이트로 계약서만 늦출 수 있게 한다 |
| D-3 | 계약서 출시 게이트 | (a) 법무 검토 완료 전 `dev_contract` 비활성 (b) 고지만으로 출시 | (a). 변호사법 관련 위험 미확인 |
| D-4 | 요금 확정 | (a) 4장 제안값 (b) 베타 2주 원가 측정 후 확정 | (b). 지금 값은 문서 단위 상대 비율만 의미 있다. 일부 결정됨(2026-10-14, Price_Plans 반영): VAT 포함 표기, `team` `projects_max` 300. 크레딧 단가 보정(RFP·채팅)은 (b) 그대로 베타 실측 후(`docs/Price_Plans/nomad-docs/PRICE_PLAN.md` 10장 DC-P-4) |
| D-5 | HWPX 시점 | (a) Phase 3 (b) Phase 2(공공·정부지원 수요) | (a). 렌더 엔진·양식 검증 비용이 크다. D-12를 당기면 (b) 재검토 |
| D-6 | 첫 CRM | (a) HubSpot (b) 국내 CRM | (a). 공개 API·OAuth 문서가 있다고 알려져 있으나 약관·한도 미확인. 국내 고객 인터뷰 후 (b) 추가 |
| D-7 | 전자서명 제공자 | 국내외 제공자 후보 비교 | Phase 3 착수 전 API·요금·법적 효력 확인(미확인) |
| D-8 | 표준계약서 원문 출처와 이용 조건 | (a) 공공 표준계약서 기반 (b) 자체 작성 조항만 | 확인 전까지 (b), 확인 후 (a)로 출처 표기(`clauses.source_note`) |
| D-9 | AI 생성 표시 방식 | (a) 문서 메타데이터만 (b) 꼬리말 표기 (c) 둘 다, 꼬리말은 확정 시 끌 수 있음 | (c). 확정 문서는 사용자가 책임지는 대외 문서라 꼬리말 강제는 사용성을 해친다 |
| D-10 | 업로드 자료 보존 | (a) 원본 90일 + 텍스트는 프로젝트 삭제 시까지 (b) 프로젝트 삭제 시까지 전부 (c) 색인 후 원본 즉시 삭제 | (a)(제안). 고객 기밀 RFP 보관 기간을 줄이되 재파싱 여지를 둔다 |
| D-11 | 회의 녹음 원본 보존, 전사본 처리 경로 | (a) 24시간 후 삭제 + 전사본 그래프 오픈소스 강제 (b) 24시간 후 삭제 + 기준서 체인(oss → anthropic) (c) 사용자 선택 30일 보관 | (a). 제3자 음성·발언을 국외로 보내지 않는다 |
| D-12 | 정부지원 신청서(`biz_plan`)를 Phase 2 맨 앞으로 | (a) 앞으로 (b) 순서대로 | 페르소나 3(민재) 인터뷰 후 결정. 앞당기면 HWPX(D-5)와 묶어 판단 |
| D-13 | shorts_agency 공개 시점 | (a) Phase 2(team 플랜 `doc_phase='phase2'`) (b) MVP로 당김 | (a). 카탈로그는 Phase 2로 두고, 직접 대행 사업(확정 결정 21)에 쓰는 운영 조직에만 team 플랜을 수동 부여해 먼저 쓴다. 계약서·위임 동의서는 D-3·D-15 게이트를 따른다 |
| D-14 | content 단가 토큰 `catalog:<key>` 저장 위치 | (a) `workspace_settings.defaults` jsonb(DC-F-028 단가 카탈로그) (b) 새 테이블 | (a). 새 테이블 없이 기존 단가 카탈로그를 쓴다. 키가 없으면 0 + lint warn |
| D-15 | 영상 제작 계약서·위임 동의서 조항의 원문 출처 | (a) 공공 표준계약서 기반(방송프로그램 제작, 디지털콘텐츠 공급 후보) (b) 자체 작성 + 법무 검토 | 확인 전까지 (b). 원문·이용 조건을 확인하면 (a)로 `source_note` 표기(D-8과 같은 절차) |
| D-16 | 월간 리포트 KPI 입력 | (a) 사용자 입력·CSV (b) sceneflow 읽기 연동(같은 org + 두 엔타이틀먼트, service_role 함수, DC-F-031 패턴) | (a)로 시작. sceneflow 에이전시 기능의 리포트 데이터 형식이 확정되면 (b)를 Phase 2 연동 작업으로 추가 |
| D-17 | 3D 영상 히어로 제작 방식(DC-F-049) | (a) 3D 장면(R3F)을 직접 렌더해 녹화 (b) 생성형 영상 도구로 제작 후 편집 (c) 외주 | (a). 실시간 장면과 같은 소재·토큰 색을 써서 일관되고, 재렌더가 쉽다. (b)는 상업 이용 조건·인물 등장 여부 확인 후 보조로만 |

### 8.1 인증 단계 결정 (2026-10-14, 확정 결정 22)

확정 결정 22(`docs/products/00_MERGE_ANALYSIS.md:30`)로 로그인은 Mock(A) → Google + 이메일(B) → 카카오(C1)·네이버(C2) 순서로 켠다. 단계 규격은 `docs/products/_platform-core/AUTH_ROADMAP.md`가 정본이고, 이 제품 행은 AUTH_ROADMAP 8장(`docs`: open, 프리랜서·에이전시, A 추가 페르소나 없음, B Google + 이메일, C1 P1, C2 P1)이다. 아래는 이 제품에서 닫아야 할 남은 결정이다. 이 제품에는 카카오에 관한 기존 열린 결정이 없어 닫는 결정은 없다.

| ID | 결정 | 선택지 | 권고 | 결정 시점 | 근거 |
|---|---|---|---|---|---|
| D-18 | 카카오 이메일 정책(C1) | (a) 비즈 앱 전환 후 `account_email` 필수 동의 (b) 이메일 없이 허용(온보딩에서 연락 이메일 별도 입력, 같은 사람이 Google로 오면 다른 사용자) | (a). 견적서·계약서 발신자 연락처, 결제 영수증, 알림 메일, 계정 연결이 Google과 같아진다. 운영 주체의 사업자 정보로 비즈 앱 전환을 할 수 있는지는 미확인 | G2 판정 전(DC-06-064 착수 전) | AUTH_ROADMAP 7.1.2절 |
| D-19 | 네이버 연동 경로(C2) | (a) Supabase 커스텀 OAuth2 `custom:naver` (b) 서버 브리지 + 코어 `staged/0010_core_auth_identity_links.sql` | 스파이크 결과로 결정(DC-06-065 첫 단계, 0.5일). 결과는 `NAVER_AUTH_PATH`와 task `log.md` `[DECISION]`에 기록. (b)면 06장 8.3절 코어 요청 C-13 | DC-06-065 스파이크 직후 | AUTH_ROADMAP 7.2.2, 7.2.3절 |
| D-20 | 이메일+비밀번호 가입 유지 여부(공개 가입 제품) | (a) 유지(Stage B에서 Google과 함께 켠다) (b) Google·카카오·네이버만 | (a). DC-F-001이 이메일 인증 필수 가입을 이미 정했고 이 결정은 그것을 바꾸지 않는다. 회사 메일만 쓰는 에이전시 PM도 가입할 수 있다(제안). 이메일 가입·메일 인증·비밀번호 재설정 화면은 Stage B 작업(DC-06-063)이 만든다 | G1 판정 전 | AUTH_ROADMAP 1장 "이메일+비밀번호" 행 |
| D-21 | Google 로그인 사용자의 "이메일 인증 전 실행 불가" 판정 기준 | (a) `auth.users.email_confirmed_at`만 본다 (b) 제공자별 예외를 둔다 | (a)(제안). 가드는 단계·제공자와 무관하게 한 곳(`requireSession('docs')` 래퍼, DC-06-012)에 둔다. Google 로그인 사용자의 `email_confirmed_at`이 채워지는지는 미확인이므로 Stage B 작업(DC-06-063) 수용 기준에서 확인하고 결과를 `[DECISION]`으로 남긴다. 비어 있으면 063이 콜백에서 임의로 채우지 않고 이 결정을 다시 연다. 카카오 D-18 (b) 사용자는 연락 이메일 인증 전까지 실행 불가 | DC-06-063 착수 전 | DC-F-001(`email_confirmed_at` 기준 서버 가드), 04장 `email_not_verified` |
| D-22 | 로그인용 Google OAuth 클라이언트와 다른 Google·OAuth 자격증명의 분리 | (a) 로그인 전용 Google Cloud 프로젝트·웹 클라이언트를 따로 만들고, AI 키(`GOOGLE_API_KEY`, ai-service 전용)와 연동 OAuth(HubSpot, Phase 2, `core.oauth_states`·`/api/integrations/[provider]/callback`)와 공유하지 않는다 (b) AI 키와 같은 Google Cloud 프로젝트에 로그인 클라이언트를 둔다 | (a)(제안). 동의 화면 검토·할당량·키 유출의 영향 범위를 나눈다. 로그인 OAuth는 Supabase Auth(`/auth/callback`)만, 연동 OAuth는 `core.oauth_states`만 쓰고 서로 코드를 import하지 않는다(07장 6절) | G1 판정 전(G1 외부 준비) | 02장 8절 `GOOGLE_API_KEY`·`HUBSPOT_CLIENT_ID` 행, 02장 3절 oauth 행 |

## 9. 설득형 랜딩과 플랫폼 필요성 검증 (2026-10-17, 검토용)

근거는 공용 규칙 `docs/nomad-design-modules/_design-guide/LANDING_PERSUASION.md`다. 요구사항·문서 관리 분야의 다른 회사 랜딩과 주제가 겹치기 쉬우므로, 그 주장 문장과 시리즈 구성을 쓰지 않도록 특히 주의한다(그 문서 1장 9~12번). 시각은 03장 4절(서류철 라이트, 카드 그리드·큰 숫자·페이드업 없음) 그대로다. 화면은 03장 8절, 작업은 06장 9절, 결정은 9.4절(D-23~D-27).

1~8장은 그대로 두고(다른 문서가 줄 번호로 인용한다) 이번 추가분을 이 장에 모았다. 각 절 제목에 어느 장의 추가분인지 적는다.

### 9.1 기능 요구사항과 수용 기준 (3장 추가분)

| ID | 기능 | 처리 | 요구사항 | 수용 기준 | 근거 |
|---|---|---|---|---|---|
| DC-F-050 | 랜딩 설득 칸 보강 | 디벨롭(P0) | 랜딩(03장 4.4절 A안)에 "막히는 지점과 원인" 섹션을 더한다. 페르소나 좌절 장면 3개 + "같은 숫자를 여러 문서에 손으로 옮기기 때문입니다" 한 문장 + 비교 1쌍(복사한 문서 파일 / 정본 데이터의 투영). 섹션 수 7개 이하 | 장부(03장 8.3절)에 없는 문장 0, 6.1절 금지 문구 0, 생성형 기본값 점검(4.5절) 통과, 다른 회사 랜딩 문구 0 | `LANDING_PERSUASION.md` 2장 |
| DC-F-051 | "왜 NOMAD Docs인가" 판정 칸 | 신규(P0) | 대안 범주 4개(그대로 둔다, 범용 AI 채팅, 사람에게 맡긴다, 전문 도구) × 기준 6개의 판정표, 우리 열 ○마다 증거 링크, "이런 경우엔 다른 방법이 낫습니다" 4행. 증거 중 하나는 가입 없이 체크를 바꿔 보는 데모로, 효과 엔진(DC-F-006, 순수 함수)을 예시 데이터로 브라우저에서 그대로 실행한다 | 우리 열 △ 1개 이상(계약서 위험 관리 행은 △ 고정: 템플릿 초안이며 법률 자문 아님), 데모 결과가 서버 효과 엔진과 같은 입력에서 같은 출력(골든 테스트), 데모 입력 수집 0, 특정 회사·서비스 이름과 로고 0(D-23) | `LANDING_PERSUASION.md` 3장 |
| DC-F-052 | 주장 장부와 필요성 검증 | 신규(P0, 문서 작업) | 장부 상태 "검증"인 문장만 게시. V0(인터뷰 5건: 외주 개발 PM·프리랜서, "칸 유무" 교대 실험)와 V1(5명이 같은 가상 프로젝트로 견적서·과업지시서·요구사항정의서 3종을 자기 방법과 제품으로 각각 작성) 결과를 `[DECISION]`으로 | 장부와 문구 상수 일치(CI 점검), V0 결과로 판정 기준 확정, 측정치는 조건과 함께 | `LANDING_PERSUASION.md` 3.4·3.6절 |
| DC-F-053 | 문서 작성 시간 비교 계산기 | 신규(P1) | `/tools/time-compare`: 월 프로젝트 수, 프로젝트당 문서 수, 문서당 작성 시간, 범위 변경 횟수와 1회 수정 시간, 시간 가치를 넣으면 직접 작성과 NOMAD Docs의 월 시간·비용을 표로. NOMAD Docs 쪽 비용은 4장 정본(플랜 월 요금, 패키지 크레딧)으로 계산하고 시간은 V1 측정 전에는 사용자가 넣은 검토 시간만 | 출처 없는 기본값 0, 입력값 수집 0, 결과 아래 추정치 고지, 요금 값 하드코딩 0, 계산 함수 단위 테스트 | `LANDING_PERSUASION.md` 6장 |
| DC-F-054 | 이중 타임라인 | 디벨롭(P1) | 랜딩 "만드는 순서"와 생성 진행(DC-F-048)의 단계 설명을 "사용자가 하는 일 / NOMAD Docs가 하는 일" 두 줄로. 확정(사용자)과 계산(서버)과 초안(AI)을 섞지 않는다 | 확정 단계가 사용자 줄에만, 금액·번호 계산이 "서버 계산"으로 표기되고 AI 줄에 숫자 작업 0 | `LANDING_PERSUASION.md` 4장 |
| DC-F-055 | 실무 문서 인사이트 3편 | 신규(P2, D-25) | `/insight/[slug]` 정적 글 3편: (1) 견적서와 계약서 숫자가 어긋나는 이유, (2) 요구사항 번호 하나로 화면·일정·검수를 잇는 추적표, (3) AI는 문장을 쓰고 숫자는 서버가 계산한다 | 외부 인용은 원문 확인분만, 메타 설명·OG 이미지·사이트맵, 다른 회사 랜딩의 주장 문장·시리즈 제목 0 | `LANDING_PERSUASION.md` 5장 |

### 9.2 금지 문구 (6.1절 점검표 추가분)

| 금지 | 예 | 대체 |
|---|---|---|
| 실명 비교 | 판정표·계산기에 다른 제안서·전자계약·법률문서 서비스 이름이나 로고를 넣어 비교 | 대안은 범주 이름만(D-23). 가격 비교는 `/pricing`에서 출처·확인일·VAT 포함 여부와 함께만. 실명 비교광고의 법적 요건은 미확인이며 법무 확인 전 쓰지 않는다 |

### 9.3 KPI (7장 추가분)

| 지표 | 목표 | 측정 방법 | 기간 |
|---|---|---|---|
| 체크 바꿔 보기 데모 사용률 | 랜딩 방문의 10% 이상(제안) | 분석 이벤트 `proof_click`(증거 ID만) / 랜딩 방문 | 월간 |
| 데모 → 가입 전환 | 데모 사용 세션의 8% 이상이 같은 세션에 가입(제안) | `proof_click`(데모) 세션 중 가입 비율. 데모 입력값은 수집하지 않는다 | 월간 |

### 9.4 설득형 랜딩 결정 (8장 추가분, 검토 대기)

9.1절(DC-F-050~055)과 03장 8절은 권고안을 가정하고 썼다.

| # | 항목 | 선택지 | 권고 | 닫는 시점 | 근거 |
|---|---|---|---|---|---|
| D-23 | 판정표의 대안 표기 | (a) 범주 이름만 (b) 실명 비교(`docs/Price_Plans/nomad-docs/PRICE_PLAN.md` 4장 서비스) | (a). 9.2절. 실명·가격은 가격 플랜 4장에만 | DC-06-066 착수 전 | `LANDING_PERSUASION.md` 3.5절 |
| D-24 | 계산기 리드 수집 | (a) 결과를 먼저 보이고 아래에 무료 가입 버튼만(DB 변경 없음) (b) 결과 메일 발송 | (a). 이 제품은 대기자 표가 없고 무료 가입이 곧 리드다 | DC-06-069 착수 전 | `LANDING_PERSUASION.md` 6장 |
| D-25 | 인사이트 3편 시점 | (a) 공개 베타 전 1편 (b) Phase 2 (c) 하지 않음 | (b). V0 인터뷰로 고객 표현을 확정한 뒤 쓴다 | V0 결과 기록 후 | `LANDING_PERSUASION.md` 5장 |
| D-26 | 판정표 우리 열의 약점 | (a) "계약서 위험 관리 △(템플릿 초안, 법률 자문 아님)", "시작 수고 △(체크리스트 항목을 처음 익혀야 함)" 유지 (b) 약점 칸 제외 | (a). 계약서 고지(DC-F-020)와 같은 선이고, 분쟁 가능성이 큰 고객을 미리 변호사에게 안내한다 | DC-06-066 착수 전 | `LANDING_PERSUASION.md` 3.2절 |
| D-27 | 문의 버튼 경로 | (a) 이메일 (b) 카카오톡 채널 (c) 두지 않음 | (a). B2B 고객(에이전시 PM)은 이메일 문의가 자연스럽고 1인 운영의 응답 시간을 지킬 수 있다 | DC-06-066 착수 전 | `LANDING_PERSUASION.md` 4장 |

## 10. 대시보드 셸·GNB 결정 대기 (2026-10-19 추가, 03장 9장)

03장 9장(헤더 + 좌측 GNB + 홈 구성)에서 사용자 결정이 필요한 항목이다. 결정 전에는 03장 9.1절 기본값으로 시안과 문서를 둔다. NOMAD Docs 전용이고 다른 제품에는 적용하지 않는다. 1~9장은 그대로 둔다(다른 문서가 줄 번호로 인용한다). 번호는 8장·8.1절·9.4절 열린 결정(D-1~D-27)에 이어 붙였다. 07장 3절 폐기 ID(DS-##)와는 다른 번호 체계다.

| # | 항목 | 선택지 | 기본값(제안) | 닫는 시점 | 근거 |
|---|---|---|---|---|---|
| D-28 | 조직 전체 문서 목록 메뉴 | (a) GNB "작업 공간"에 "전체 문서" 메뉴 + 새 경로 `/app/documents`(재생성 필요·확정 대기·생성 실패 필터, 03장 9.4절)와 API `GET /api/documents`(제안) (b) 전역 메뉴 없이 프로젝트 안 문서 목록 + ⌘K 문서 검색 + 홈 "오늘 처리할 일"만 | (a)(제안). 03장 3.26절 앱 셸이 "문서"를 전역 메뉴로 그렸고(:778) 이동 단축키 `g d`도 있다(:838). 홈 "이어서 할 일"은 최대 5행(:206)이라 재생성 필요 문서가 여러 프로젝트에 흩어지면 전체 목록이 필요하다. 1절 표와 04장에 경로가 없어 화면·API가 각각 1개 늘어난다 | DC-06-038 착수 전 | 03장 1절 :47, 3.1절 :206, 3.26절 :778, :838, 04장 2절(조직 전체 문서 목록 경로 없음) |
| D-29 | 프로젝트 안 메뉴 10개(개요~위키)의 자리 | (a) GNB 안 "현재 프로젝트" 묶음(프로젝트 화면에서만 보임, 03장 9.5절) (b) GNB는 전역 메뉴만, 프로젝트 홈 머리 아래 가로 탭 10개 (c) 프로젝트에 들어가면 GNB 전체를 프로젝트 메뉴로 바꾸고 맨 위 "← 모든 프로젝트" | (a)(제안). 1절 :84가 "사이드바(프로젝트 안)"로 적었고 3.26절 셸은 왼쪽 내비 하나다(:773-781). (b)는 10개 탭이 1024px 한 줄에 들어가지 않고, (c)는 프로젝트 안에서 파이프라인·거래처로 가려면 한 단계를 더 거친다 | DC-06-038 착수 전 | 03장 1절 :84, 3.26절 :773-781, :840 |
| D-30 | 모바일(1024px 미만) 내비 | (a) 햄버거 → 왼쪽 서랍만(6절) (b) 하단 탭 4개 + 햄버거(3.25.2절 AppShell) | (a)(제안). 767px 이하 지원 범위(6절 :1161)는 대시보드·체크리스트·문서 읽기·RFP 검토·회의 녹음·채팅·확정·내보내기 받기로 대부분 프로젝트 안 화면이라, 전역 하단 탭 4개가 가리킬 화면이 적다. (b)로 정하면 탭은 홈·프로젝트·프로젝트에 묻기·더 보기(서랍)로 둔다(제안) | DC-06-011 착수 전(AppShell 배리언트) | 03장 3.25.2절 :747, 6절 :1161, :1162 |
| D-31 | ⌘K/Ctrl+K 충돌(커맨드 팔레트와 편집기 선택영역 툴바) | (a) 팔레트가 모든 `/app` 화면에서 ⌘K/Ctrl+K를 갖고, 툴바는 선택하면 뜨며 키보드로는 다른 키(예: Ctrl+Shift+K, 제안) (b) 편집기 안에서는 Ctrl+K를 툴바에 주고, 팔레트는 검색 칸 클릭과 `/`로 연다 | (a)(제안). 팔레트는 P0 기능이고 수용 기준이 "키보드만으로 팔레트 열기"다(DC-F-047). 툴바 단축키는 6절에서 이미 "제안"이다. (b)는 화면마다 같은 키의 뜻이 달라진다 | DC-06-040 착수 전 | 03장 1절 :36, 3.26절 :831, 6절 :1151, 01장 DC-F-047 |

| 결정 | 기본값과 다르게 정하면 고칠 곳(영향) |
|---|---|
| D-28 (b) | 03장 9.3절 "전체 문서" 행 삭제, 9.4절 전체, 9.6절 1행(누르면 열을 프로젝트 문서로), 9.7절 단축키 `g d` 대상(3.26절 :838 다시 정의), 디자인 config의 `documents-all` 메뉴 |
| D-29 (b)·(c) | 03장 9.3절 "현재 프로젝트" 묶음, 9.5절 전체, 9.7절 현재 위치·현재 프로젝트 행, 디자인 config의 `project` 묶음 |
| D-30 (b) | 03장 9.7절 반응형 행, 9.9절 AppShell 행, 3.25.2절 :747은 그대로 |
| D-31 (b) | 03장 9.2절 검색 행, 9.7절 단축키 행, 6절 :1151은 그대로 |
