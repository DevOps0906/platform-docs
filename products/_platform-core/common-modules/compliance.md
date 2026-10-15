# compliance: 법정 표기·동의 기록·표시 라벨 (공용모듈 기획서)

작성일 2026-10-15. 상태: 제안. 패키지 `@nomad/compliance`, 스키마 `compliance`(0150~0199), 오류 코드 `CP###`. 출처: local-news M7(`docs/products/local-news/modules/M7_compliance-desk.md`)의 제품 무관 부분. 개발서 `docs/develop/_shared/modules/compliance.md`.

## 1. 문제

15개 제품이 모두 약관·개인정보처리방침·마케팅 수신 동의를 받고, 사업자 정보를 푸터에 표시하고, 광고·AI 생성물에 표시를 붙여야 한다. 제품마다 따로 만들면 (1) 어떤 버전에 누가 동의했는지 증빙이 제품마다 다르고 (2) 법이 바뀌면 15곳을 고쳐야 하며 (3) 표시 누락이 제품마다 다른 방식으로 생긴다. local-news는 이 문제를 신문법 기준으로 가장 엄격하게 풀었고(필요적 게재사항 미완성 시 공개 차단, 광고·AI 라벨 CHECK), 그 틀을 일반화한다.

## 2. 범위

| 구분 | 내용 |
|---|---|
| MVP | (1) 정책 문서 버전(약관, 개인정보처리방침, 마케팅 수신, 위치정보, 청소년보호정책, AI 이용 안내) (2) 동의 기록(추가만, 수정·삭제 불가) (3) 법정 표기 프로필(사업자·통신판매업·신문 등 종류별 필수 필드와 완성 판정) (4) 표시 라벨 사전과 판정 함수(광고, 기사형 광고, 대가성, AI 생성, AI 보조) (5) 공용 푸터 컴포넌트 |
| 확장 | 개인정보 열람·정정·삭제·처리정지 요청함(기한 관리), 보존 기간 규칙과 자동 파기 잡, 쿠키 동의 배너, 국외 이전 고지 표 |
| 제품에 남김 | 신문법 자체기사 비율, 정정·반론보도 청구(언론중재법), 선거 모드(공직선거법) → local-news. 의료정보 → admin-suite hms. 투자 권유 고지 → stock-dashboard |
| 코어에 이미 있음(재정의 금지) | 제휴 대가성 표기 `core.effective_disclosure`, `core.upsert_affiliate_disclosure`(코어 0006). compliance 라벨 판정은 대가성일 때 이 함수를 호출만 한다 |

## 3. 데이터 모델

| 표 | 주요 컬럼 | RLS·쓰기 |
|---|---|---|
| `compliance.policy_documents` | `id`, `org_id`(null = 플랫폼 공통), `app_id`, `kind`(`terms`, `privacy`, `marketing`, `location`, `youth`, `ai_notice`, `refund`), `version`(정수), `title`, `body_md`, `summary_md`(변경 요약), `status`(`draft`→`published`→`retired`), `effective_at`, `published_at`, `published_by` | 읽기: 게시본은 공개(anon), 초안은 org admin. 쓰기: `compliance.publish_policy` RPC(org admin 또는 플랫폼 운영자) |
| `compliance.consents` | `id`, `org_id`, `app_id`, `subject_kind`(`member`, `end_user`, `email`), `subject_id`(uuid 또는 이메일 해시), `purpose`(정책 kind 또는 `marketing_email`, `marketing_sms`, `marketing_push`, `night_ads`, `cross_border_ai`), `policy_id`, `granted`(bool), `method`(`signup_form`, `settings`, `double_opt_in`, `import`), `evidence`(jsonb: 화면 id, 체크박스 문구 해시), `ip_hash`, `ua_hash`, `created_at` | 추가만(UPDATE·DELETE 트리거로 거부 `CP001`). 본인은 자기 행 읽기, org admin은 자기 org 읽기. 쓰기는 `compliance.record_consent`(service 또는 본인 세션) |
| `compliance.legal_profiles` | `org_id`, `app_id`, `profile_kind`(`kr_business`, `kr_ecommerce`, `kr_newspaper`, `kr_education`), `fields`(jsonb), `updated_by`, `updated_at` | 읽기: 공개용 필드만 뷰 `compliance.public_legal_footer`(anon). 쓰기: `compliance.set_legal_profile`(org admin), 허용 키 밖은 `CP002` |
| `compliance.profile_rules` | `profile_kind`, `field_key`, `label_ko`, `required`, `public`, `pattern`(정규식), `source_url`(법령 근거) | 플랫폼 운영자만 쓰기, 모두 읽기. seed로 배포 |
| `compliance.label_definitions` | `code`(`ad`, `sponsored`, `affiliate`, `ai_generated`, `ai_assisted`, `ai_voice`), `text_ko`(예: "광고", "AI 생성 이미지"), `placement`(`before_title`, `badge`, `caption`, `footer`), `required_when`(jsonb 조건 설명), `source_url` | 플랫폼 운영자만 쓰기. 제품은 문구를 바꾸지 못하고 위치만 고른다 |
| `compliance.data_requests`(확장) | `org_id`, `app_id`, `subject_kind`, `subject_id`, `kind`(`access`, `correct`, `delete`, `suspend`), `status`(`received`→`in_progress`→`done`/`rejected`), `due_at`, `handled_by`, `result_note` | 본인 생성(`compliance.create_data_request`), org admin 처리. 기한 임박은 잡이 notify로 알림 |

함수:

| 함수 | 반환 | 용도 |
|---|---|---|
| `compliance.is_profile_complete(org, app, profile_kind)` | bool | 필수 필드가 모두 있는가. 게시·사이트 공개 가드로 쓴다(local-news `news.is_profile_complete`의 일반화) |
| `compliance.missing_fields(org, app, profile_kind)` | text[] | 화면에 "무엇이 빠졌는가" 표시 |
| `compliance.current_policy(org, app, kind)` | row | 현재 효력 버전(org 버전이 없으면 플랫폼 공통) |
| `compliance.needs_reconsent(org, app, subject)` | text[] | 필수 정책의 새 버전에 아직 동의하지 않은 kind 목록. 로그인 후 재동의 화면 |
| `compliance.has_consent(org, app, subject, purpose)` | bool | 마지막 기록 기준. notify가 광고성 발송 전에 부른다 |
| `compliance.labels_ok(labels text[], context jsonb)` | bool | 붙은 라벨이 필요한 라벨을 모두 포함하는가. editorial·ads 게시 가드 |
| `compliance.required_labels(context jsonb)` | text[] | 콘텐츠 성격(`{is_paid:true, ai:'generated', affiliate:true}`)으로 필요한 라벨 코드. 제품 표의 CHECK 또는 게시 RPC에서 검사 |

오류 코드: `CP001` 동의 기록 변경 시도, `CP002` 허용 밖 프로필 필드, `CP003` 필수 프로필 미완성으로 공개 거부, `CP004` 필수 라벨 누락, `CP005` 효력일이 과거인 정책 게시 시도.

## 4. 공개 API (TS 계약 예시)

```ts
// @nomad/compliance/server
recordConsent(input: { appId: string; orgId: string; subject: Subject; purpose: Purpose; policyId?: string; granted: boolean; method: ConsentMethod; evidence?: Record<string, string> }): Promise<void>
hasConsent(appId: string, orgId: string, subject: Subject, purpose: Purpose): Promise<boolean>
needsReconsent(appId: string, orgId: string, subject: Subject): Promise<PolicyKind[]>
assertProfileComplete(appId: string, orgId: string, kind: ProfileKind): Promise<void>   // 미완성이면 CP003
requiredLabels(ctx: LabelContext): LabelCode[]          // 서버·클라이언트 공용 순수 함수, SQL 함수와 같은 표
// @nomad/compliance/ui
<LegalFooter appId orgId />   <ConsentCheckboxes kinds={['terms','privacy','marketing']} />   <ContentLabel code="ad" />
```

## 5. 이벤트

`compliance.policy.published`(구독: notify가 변경 고지 메일, 30일 전 고지 등은 제품 정책), `compliance.consent.recorded`, `compliance.profile.completed`, `compliance.data_request.received`·`.due_soon`.

## 6. 제품별 설정

| 설정 | 예 |
|---|---|
| 필요한 프로필 종류 | website-floria `kr_business`, nomad-commerce·microweb `kr_ecommerce`, study-note·lms 사용 제품 `kr_education`, local-news `kr_newspaper` |
| 공개 차단 가드 | local-news만 "프로필 미완성이면 독자 사이트 비공개", 나머지는 경고 배너 |
| 가입 시 동의 항목 | 필수(약관·개인정보) / 선택(마케팅 채널별, 야간 광고, AI 국외 이전) |
| 라벨 위치 | 제품 디자인에 맞춰 `placement`만 선택 |

## 7. 법규 근거와 확인 필요

| 항목 | 내용 | 상태 |
|---|---|---|
| 개인정보 수집 동의·처리방침 공개 | 개인정보 보호법 제15·22·30조 | 조문 원문 확인 필요(https://www.law.go.kr) |
| 광고성 정보 수신 동의, 야간(21~08시) 별도 동의, 2년마다 수신 동의 확인 | 정보통신망법 제50조 | 시행령 세부 확인 필요 |
| 기사형 광고 구분 | 신문법 제6조 3항(local-news) | local-news 01장 6절 |
| 추천·보증 광고 대가성 표시 | 공정위 「추천·보증 등에 관한 표시·광고 심사지침」 | 코어 `effective_disclosure`가 이미 처리 |
| AI 생성물 표시 | 인공지능 기본법 및 하위 규정 | 표시 대상·방식은 시행령·고시 확인 전 "미확인". 1차는 모든 AI 생성 이미지·음성·초안에 라벨 |
| 통신판매업 표시 | 전자상거래법 제10조 | 확인 필요 |
| 열람 요구 처리 기한 | 개인정보 보호법 시행령(열람 10일 이내로 알려짐) | 미확인, 법무 확인 후 `due_at` 계산식 확정 |

법무 확인 전까지 조문 번호·기한은 문서에 "미확인"으로 두고 코드 상수에 넣지 않는다(`profile_rules`·`label_definitions` seed 값으로만 관리해 배포 없이 바꾼다).

## 8. 실패 동작

| 상황 | 동작 |
|---|---|
| 동의 기록 저장 실패 | 가입·설정 저장 자체를 실패로 돌린다(동의 없이 진행 금지) |
| 정책 조회 실패 | 플랫폼 공통 버전으로 대체하지 않고 오류 화면(잘못된 약관 노출 방지) |
| 라벨 판정 불일치(클라이언트 vs SQL) | SQL 판정이 정본, 게시 RPC가 `CP004`로 거부 |

## 9. local-news에서 옮기는 것

| local-news(1차) | 공용 | 비고 |
|---|---|---|
| `news.newspapers`의 법정 표기 필드, `news.is_profile_complete` | `compliance.legal_profiles`(`kr_newspaper`), `compliance.is_profile_complete` | 필요적 게재사항 10개는 `profile_rules` seed |
| 광고·AI 표시 CHECK(`sponsored` 라벨, `ai_disclosure`) | `compliance.required_labels`, `label_definitions` | 제품 표 CHECK는 함수 호출로 바꿈 |
| 독자 가입 동의, 뉴스레터 수신 동의 | `compliance.consents` | 뉴스레터 이중 동의 증빙은 notify가 기록 |
| `correction_requests`, `election_periods`, 자체기사 비율 | 남김 | 언론 전용 |

## 10. 결정 필요

| ID | 결정 | 권고 |
|---|---|---|
| CP-D1 | 정책 문서를 org별로 쓰게 할지 | 플랫폼 공통 + org 덮어쓰기(멀티테넌트 제품만 org 버전 허용) |
| CP-D2 | 재동의 강제 방식 | 필수 정책 새 버전은 로그인 후 동의 화면 차단, 선택 정책은 배너 |
| CP-D3 | 데이터 요청함 1차 포함 | 확장(1차는 문의함 support로 접수 후 수동 처리) |
