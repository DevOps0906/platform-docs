# 04 API: NOMAD Docs

작성일 2026-10-13. 약칭: SM = `docs/file/03-설계/공용코어/SHARED_MODULES.md`, CS = `docs/file/03-설계/공용코어/CORE_SPEC.md`, AA = `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md`. 코어 RPC는 CS를 인용만 한다. 코드 블록은 계약 예시다. 브라우저는 제품 Route Handler와 `/api/ai/*`, `/api/voice/*`만 부르고 Dify·FastAPI·AI 제공자·렌더 서비스는 서버가 부른다(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md:299`). 테이블·RPC·잡·오류 코드 이름은 05장과 같다.

## 1. 원칙

| 항목 | 규칙 | 근거 |
|---|---|---|
| 인증 | 모든 Route Handler 첫 줄 `const ctx = await requireSession('docs')`. 미로그인 401, pending/suspended 403, `entitled=false` 402. 공개 예외: `/api/webhooks/toss`, `/api/integrations/[provider]/webhook`, `/api/integrations/inbound/[endpointToken]`(서명·토큰 검증), `/api/integrations/[provider]/callback`(OAuth state 검증) | SM 2장, CS 2.2 |
| 순서 | 인증 → zod 검증 → 레이트 리밋 → 엔타이틀먼트·플랜 features 확인 → (고위험) 고지 동의 확인 → 크레딧 선차감 → 처리(동기 호출 또는 enqueue) → 실패 시 환불 | `docs/file/03-설계/공용코어/CORE_SPEC.md:177-188`, `docs/reference/reviews/SellingDocs.md:70` |
| 멱등 | 유료·비동기 요청은 본문 `request_id`(UUID v4) 필수. 차감 `consume:docs:<request_id>`, 잡 `job:docs:<request_id>`, 생성 run `generation_runs.idempotency_key = gen:docs:<request_id>`(제안) | `docs/file/03-설계/공용코어/CORE_SPEC.md:198`, SM 18장 |
| 패키지 자식 키 | 자식 차감 `consume:docs:<run_id>:<doc_type_code>`, 자식 잡 `job:docs:<run_id>:<doc_type_code>` | 제안(자식 단위 환불 추적) |
| 크레딧 선차감 위치 | 생성: `docs.start_generation`(service_role, 한 트랜잭션), 동기 AI(`assist`, 채팅): Route Handler `withCredits`, 렌더: 내보내기 Route Handler가 `consume_credits` 후 `enqueue_job(p_credit_ledger_id)`, extract·minutes·색인: Route Handler가 차감 후 enqueue | SM 4장, 02장 4절 |
| DB 접근 | 정본 테이블(`parties`, `projects`, `checklist_answers`(source='user'), `requirements`, `artifacts`, `line_items`, `documents.title`)은 세션 클라이언트(RLS, 컬럼 GRANT). 서버 전용 테이블과 RPC는 `createAdminClient`로, 호출 전 `ctx.org.id`와 대상 행 `org_id` 일치 확인 | `docs/file/03-설계/공용코어/SECURITY_BASELINE.md` 4장, 11장 |
| 응답 봉투 | 성공 `{ ok: true, data }`, 실패 `{ ok: false, error: { code, message, details? } }`. 402는 `details: { required, balance }`, DC004는 `details: { missing: string[] }`, DC005는 `details: { lint, compliance }` | 제안(`D:/WorkSpace/platform/docs/products/flora-publishing/04_API.md:15`와 같음) |
| 레이트 리밋 | `core.rate_limit_hit('docs:<route>:<org_id>', limit, window)`. 생성 API 조직당 20회/분(`01_PRD.md` 5장, 코어 기준 60회/분보다 낮춤), 조직 동시 생성 3(`runtime_config`), 일일 플랫폼 크레딧 상한(`runtime_config`) | DC-F-039 |
| sanitize | 편집 저장, AI 섹션, 업로드 텍스트 미리보기는 서버에서 허용 목록 sanitize(`packages/docs-templates/sanitize-allowlist.json`, TS·Python 공용). 클라이언트 HTML을 렌더 서비스로 보내지 않는다 | 02장 2.2절, `SECURITY_BASELINE.md:172` |
| 금액·번호 | 요청 본문의 합계·VAT·문서번호·`req_code`는 받지 않는다(zod에 없음). 서버가 계산 | 02장 2.3절 |
| 서명 토큰 | `src/lib/server/ai/token.ts`가 EdDSA JWT 발급: `iss=docs`, `aud=platform-ai:docs`, `org`, `app=docs`, `sub`, `conv`, `feat`, `scope`, `jti`, `iat`, `exp`(10분) | `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:33-42` |
| AI 멱등 키 | 채팅 `conv:<id>:turn:<n>`, 음성 `voice:<request_id>`, 그래프 `run:<ai_run_id>`, 색인 `rag:<document_id>` | `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:125` |

## 2. Route Handler

역할: `member+` = owner/admin/member, `oa` = owner/admin. 플랜: F = free 가능, P = pro 이상, T = team(Phase 2). features 키는 01장 4절(브리프 10장). 크레딧은 01장 4절 단가.

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 코어 RPC | 오류 |
|---|---|---|---|---|---|---|
| `GET /api/session` | 로그인 | - | `SessionContext` | 0 | `session_context` | 401 |
| `GET /api/workspace` | 멤버 / F | - | `{ settings, self_party }` | 0 | - | - |
| `PATCH /api/workspace` | oa / F | `{ doc_number_format? (토큰 {TYPE}·{PREFIX}, {YYYY}, {YY}, {SEQ:n}; {SEQ 필수), default_day_rate_krw? int ≥ 0, vat_rate_bp? 0..10000, defaults? }` | `{ settings }` | 0 | `write_audit` | 403, 422 |
| `POST /api/workspace/seal` | oa / F | `{ ext: png\|webp, bytes ≤ 2MB }` | `{ signed_upload_url, path }` | 0 | - | 413, 415 |
| `GET /api/parties` | 멤버 / F | `?kind&q&cursor` | `{ items, next }` | 0 | - | - |
| `POST /api/parties` | member+ / F | `{ kind: self\|client\|vendor\|freelancer, name 1..200, biz_reg_no? (^\d{3}-\d{2}-\d{5}$), representative?, address?, contact_name?, contact_email?, contact_phone?, notes? }`. 주민등록번호 패턴이 어느 필드에든 있으면 거부 | `{ party }` | 0 | - | 422 `pii_detected`, 409(`self` 중복) |
| `PATCH /api/parties/[id]` | member+ / F | 위 필드 부분집합 | `{ party, external_owned_fields? }`(CRM 소유 필드 수정 경고) | 0 | - | 404, 422 |
| `DELETE /api/parties/[id]` | member+ / F | - | `{ ok }`(soft delete) | 0 | - | 409(진행 중 프로젝트 거래처) |
| `POST /api/parties/import` | member+ / F | multipart CSV/XLSX ≤ 5MB + `{ mapping: Record<column, field>, dry_run: bool }` | `{ created, updated, skipped, errors: [{ row, message }] }` | 0 | - | 413, 415, 422 |
| `GET /api/projects` | 멤버 / F | `?status&cursor` | `{ items, next }` | 0 | - | - |
| `POST /api/projects` | member+ / F | `{ name 1..120, project_type: web\|app\|ai\|mixed\|other\|content(Phase 2, team 플랜), client_party_id?, start_date?, end_date? (≥ start), budget_krw? }` | `{ project }`(checklist_version = 현재 게시 버전) | 0 | - | 402/403 `DC006`(`projects_max`), 422 |
| `GET /api/projects/[id]` | 멤버 / F | - | `{ project, progress: { answered, required_missing[] }, totals }` | 0 | - | 404 |
| `PATCH /api/projects/[id]` | member+ / F | `{ name?, client_party_id?, start_date?, end_date?, profile? }`(status 제외) | `{ project, affected_doc_types[] }` | 0 | - | 404, 422 |
| `POST /api/projects/[id]/status` | oa / F | `{ to: active\|delivered\|archived }` | `{ project }` | 0 | 사용자 세션 `docs.set_project_status` | 409 `DC001` |
| `GET /api/projects/[id]/checklist` | 멤버 / F | `?group` | `{ items (카탈로그), answers, suggestions (is_confirmed=false) }` | 0 | - | 404 |
| `PUT /api/projects/[id]/checklist/answers` | member+ / F | `{ answers: [{ item_key, value }] ≤ 200 }`(item의 input_type에 맞는 zod 동적 검증, `source='user'` 고정) | `{ answers, effects_stale: true }` | 0 | - | 422, 404 `unknown_item` |
| `POST /api/projects/[id]/checklist/confirm` | member+ / F | `{ item_keys: string[] ≤ 200 }` | `{ confirmed }` | 0 | 사용자 세션 `docs.confirm_checklist_suggestions` | 404, 409 |
| `POST /api/projects/[id]/effects/preview` | member+ / F | `{}` | `EffectPlan`(add, update, remove, keepUserModified, clauses, affectedDocTypes, checklistHash) | 0 | - | 404 |
| `POST /api/projects/[id]/effects/apply` | member+ / F | `{ expected_hash }` | `{ applied: { added, updated, removed, kept }, needs_regeneration: document_id[] }` | 0 | service_role `docs.apply_checklist_effects`(제안), `write_audit` | 409 `DC010`(해시 불일치, 미리보기 후 답이 바뀜), 409 `DC001`(archived 프로젝트) |
| `GET /api/projects/[id]/requirements` | 멤버 / F | `?kind&status` | `{ items }` | 0 | - | - |
| `POST /api/projects/[id]/requirements` | member+ / F | `{ kind, title 1..200, description?, priority, acceptance_criteria? }`(req_code 없음, `source='manual'`) | `{ requirement }`(req_code는 트리거) | 0 | - | 422 |
| `PATCH /api/requirements/[id]` | member+ / F | `{ title?, description?, priority?, acceptance_criteria?, status?: accepted\|rejected\|changed }` | `{ requirement }`(`is_user_modified=true`) | 0 | - | 404, 422 |
| `DELETE /api/requirements/[id]` | member+ / F | - | `{ ok }`(trace_links 정리, 번호 재사용 안 함) | 0 | - | 404 |
| `GET/POST /api/projects/[id]/artifacts`, `PATCH/DELETE /api/artifacts/[id]` | member+ / F | `{ kind: screen\|milestone\|deliverable, name, attributes?, sort_order? }`(`test_case`·`api`·`table`은 Phase 2) | `{ artifact }` | 0 | - | 422 |
| `GET/POST /api/projects/[id]/line-items`, `PATCH/DELETE /api/line-items/[id]` | member+ / F | `{ category, name, unit, quantity numeric(10,2) ≥ 0, unit_price_krw int ≥ 0, sort_order? }`(amount 없음) | `{ line_item, totals: { subtotal, vat, total } }` | 0 | - | 422 |
| `POST /api/projects/[id]/line-items/import` | member+ / F | multipart CSV/XLSX(단가표) + `{ mapping, dry_run }` | 위 `import`와 같음 | 0 | - | 413, 415, 422 |
| `GET /api/doc-types` | 멤버 / F | - | `[{ code, name, category, risk_level, generation_mode, phase, credits, required_fields, current_version }]` | 0 | - | - |
| `POST /api/projects/[id]/documents` | member+ / F | `{ request_id, doc_type_code }`(문서가 없으면 만들고 생성 시작, 있으면 재생성) | `{ document, run, job_id, estimated_credits }` | template 2 / hybrid 6 / ai 12 | service_role `docs.start_generation`(내부 `enqueue_job`, `consume_credits`) | 402 `CR001`, 403 `DC006`(doc_phase), 409 `DC002`, 422 `DC004`, 428 `DC007`, 429 |
| `POST /api/projects/[id]/packages` | member+ / F | `{ request_id, package_code: 'outsourcing_basic' \| 'shorts_agency'(Phase 2, `project_type=content`만, 아니면 422), include?: doc_type_code[] }` | `{ run, parent_job_id, estimated_credits: 28(shorts_agency 20 또는 18) }` | 자식 합계(28) | `docs.start_generation`(부모 run), 자식은 워커가 같은 RPC | 402(합계 부족), 409 `DC002`, 422 `DC004`(`details.missing`를 유형별로), 428 `DC007`(`dev_contract` 포함 시) |
| `POST /api/generation-runs/[id]/cancel` | member+ / F | - | `{ run }`(대기 자식 환불) | 0 | `cancel_job` | 409 `JB002`, 404 |
| `GET /api/documents/[id]` | 멤버 / F | - | `{ document, version (current), lint_result, compliance_verdict, needs_regeneration }` | 0 | - | 404 |
| `PATCH /api/documents/[id]` | member+ / F | `{ title 1..200 }` | `{ document }` | 0 | - | 409 `DC003`(final) |
| `POST /api/documents/[id]/versions` | member+ / F | `{ expected_version, sections: [{ key, html ≤ 200KB }] ≤ 60 }`(잠금 섹션 key가 있으면 거부) | `{ version }`(sanitize 후 새 버전, `created_kind='edited'`) | 0 | service_role INSERT `document_versions` | 409 `DC010`, 409 `DC003`, 422 `locked_section`, 413(2MB 초과) |
| `GET /api/documents/[id]/versions` | 멤버 / F | `?cursor` | `[{ version, created_kind, created_by, created_at, compliance_verdict }]` | 0 | - | - |
| `GET /api/documents/[id]/versions/diff` | 멤버 / F | `?from=int&to=int` | `{ sections: [{ key, status: same\|changed\|added\|removed, ops }] }`(섹션 단위 텍스트 diff, 서버 계산) | 0 | - | 404, 422 |
| `POST /api/documents/[id]/finalize` | oa / F | `{ expected_version, ack_warn: bool }` | `{ document (status final, doc_number) }` | 0 | 사용자 세션 `docs.finalize_document` | 409 `DC001`, `DC008`, `DC010`, 422 `DC004`, `DC005`, 428 `DC007` |
| `POST /api/documents/[id]/archive` | oa / F | - | `{ document }` | 0 | `docs.archive_document` | 409 `DC001` |
| `POST /api/documents/[id]/revision` | oa / F | - | `{ document (새 draft, supersedes_document_id) }` | 0 | `docs.create_revision` | 409 `DC001`(final 아님) |
| `POST /api/documents/[id]/exports` | member+ / F(pdf) P(docx) | `{ request_id, format: pdf\|docx, version?: int }` | `{ export, job_id, reused: bool }`(같은 버전·형식 ready면 재사용 0크레딧) | 1(재사용 0) | `consume_credits`, `enqueue_job(p_credit_ledger_id)` | 402, 403 `DC006`(formats), 404 |
| `POST /api/projects/[id]/exports/zip` | member+ / P | `{ request_id, document_ids: uuid[] ≤ 20 }` | `{ export, job_id }`(없는 PDF는 자식 `render.pdf`로 생성, 각 1) | 구성 렌더 수 x 1 | `consume_credits`(자식), `enqueue_job` | 402, 403 `DC006` |
| `GET /api/exports/[id]/download` | 멤버 / F | - | 302 → 서명 URL(7일) | 0 | - | 404, 410 `expired` |
| `POST /api/risk-acks` | oa / F | `{ doc_type_code, notice_version }`(서버 상수 `DOCS_RISK_NOTICE_VERSION`와 같아야 함) | 204 | 0 | 사용자 세션 `docs.ack_risk_notice` | 409 `CONSENT_VERSION_MISMATCH`, 422 |
| `POST /api/projects/[id]/uploads` | member+ / F | `{ purpose: rfp\|minutes_audio\|minutes_text\|reference, file_name, ext (pdf\|docx\|txt\|md\|webm\|m4a\|mp3\|wav, hwpx는 Phase 3), bytes, rights_confirmed: true, recording_notice_version? (minutes_audio 필수) }`. 문서 20MB, 음성 200MB(제안) | `{ upload_id, signed_upload_url, token }`(경로 `<org>/docs/uploads/<uuid>.<ext>`, 서버 생성) | 0 | - | 413, 415, 422 `recording_notice_required` |
| `POST /api/uploads/[id]/complete` | member+ / F | `{ request_id, index: bool }` | `{ upload, rag_job_id? }` | 색인 1MB당 1(index=true) | 매직바이트·실제 크기 재검사 → `consume_credits('rag:<document_id>')`, `enqueue_job('rag.index')` | 413, 415, 402 |
| `POST /api/projects/[id]/extract` | member+ / F | `{ request_id, upload_id (purpose rfp, parse 완료) }` | `{ job_id, estimated_credits }` | 10 + 50쪽당 5 | `consume_credits`, `enqueue_job('docs.extract')` | 402, 409(같은 업로드 진행 중), 422 |
| `POST /api/projects/[id]/minutes` | member+ / F | `{ request_id, upload_id (minutes_audio\|minutes_text), attendees: [{ name, role? }] ≤ 30, meeting_at }` | `{ job_id, document_id, estimated_credits }` | STT 분당 1 + 5 | `consume_credits`, `enqueue_job('docs.minutes')` | 402, 413 `VOICE_TOO_LONG`(플랜 `minutes_max_minutes` 초과), 422 |
| `POST /api/projects/[id]/suggestions/requirements/accept` | member+ / F | `{ requirement_ids: uuid[] }`(extract·minutes가 만든 proposed 행) | `{ accepted }`(status accepted) | 0 | - | 404 |
| `GET /api/integrations` | oa / F | - | `[{ connection_id, provider, status, last_synced_at, last_error }]` | 0 | - | - |
| `POST /api/integrations/[provider]/connect` | oa / T(hubspot, admin_suite_erp, make, n8n), F(csv) | `{ sync_direction: pull\|push\|both, settings? }` | `{ authorize_url }`(OAuth) 또는 `{ connection }`(ERP: 엔타이틀먼트 확인, Make/n8n: inbound 토큰 1회 표시) | 0 | `create_oauth_state` | 403 `DC006`, 409(이미 연결), 422 `entitlement_missing`(ERP) |
| `GET /api/integrations/[provider]/callback` | 공개(state) | `?code&state` | 302 → 설정 화면 | 0 | `consume_oauth_state`, vault put | 400 `OA001` |
| `PUT /api/integrations/[id]/mappings` | oa / T | `{ mappings: [{ entity, external_field, internal_path, transform, enum_map? }] ≤ 100 }`(`internal_path`는 허용 목록) | `{ mappings }` | 0 | - | 409 `DC009`, 422 |
| `POST /api/integrations/[id]/sync` | oa / T | `{ request_id, entity: party\|project\|line_item, direction: pull\|push }` | `{ sync_run, job_id }` | 0 | `enqueue_job('integration.sync')` | 409 `DC009`, 409(진행 중), 429 |
| `POST /api/integrations/[id]/revoke` | oa / F | - | `{ connection (revoked) }` | 0 | 사용자 세션 `docs.revoke_integration`(내부 `revoke_credential`) | 404, 409 `DC009` |
| `GET/POST /api/webhook-endpoints`, `DELETE /api/webhook-endpoints/[id]` | oa / P | `{ url (https), events: ('project.created'\|'document.generated'\|'document.finalized'\|'document.exported'\|'package.completed')[] }` | `{ endpoint, secret }`(비밀은 생성 응답에서만) | 0 | vault put, `revoke_credential` | 422 `url_not_allowed`, 409(5개 초과, 제안), 403 `DC006` |
| `POST /api/webhook-endpoints/[id]/test` | oa / P | - | `{ delivery }` | 0 | `enqueue_job('webhook.deliver')` | 429 |
| `POST /api/integrations/[provider]/webhook` | 공개(제공자 서명) | raw body | 200 | - | `webhook_events` | 401 서명, 200 중복 |
| `POST /api/integrations/inbound/[endpointToken]` | 공개(토큰 + HMAC) | raw body `{ event_id, action: create_project\|answer_checklist, data }` | 202 `{ accepted }` | 0 | `webhook_events` | 401, 404(토큰), 409 `DC009`, 422 |
| `POST /api/billing/orders`, `POST /api/billing/confirm`, `POST /api/billing/billing-key`, `POST /api/billing/subscription/cancel` | oa | SM 5장 계약(`D:/WorkSpace/platform/docs/products/flora-publishing/04_API.md:59-62`와 같음) | 주문·결제·구독 | 지급 | `confirm_payment_order`, `apply_subscription_transition` | `PM001`, `PM409`, `PM410`, `SB001` |
| `POST /api/webhooks/toss` | 공개(서명) | raw body | 200 | - | `webhook_events` | 401, 200 중복 |
| `POST /api/account/export` | owner | `{ request_id }` | `{ job_id }`(제안: `docs.export_zip`에 계정 데이터 JSON 포함) | 0 | `enqueue_job` | 429 |
| `POST /api/account/delete` | owner | `{ confirm_text: '삭제합니다' }` | `{ purge_at }` | 0 | 서버 조직 soft delete + 감사 | 422 |
| `POST /api/admin/catalog/publish` | platform_admin | `{ kind: doc_type_version\|checklist_items\|clauses, payload, checksum }` | `{ published }` | 0 | service_role INSERT(게시 후 불변), `write_audit` | 403, 409 `DC003`, 422(체크섬 불일치) |

### 2.1 AI·음성 Route Handler

서명 토큰 scope와 호출 대상은 `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:149-158`, `docs/file/03-설계/공용코어/VOICE_ARCHITECTURE.md:22-38`을 따른다(ai-gateway, `SHARED_MODULES.md:498`).

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| `POST /api/onboarding/ai-consent` | owner | `{ granted: boolean, notice_version }` | 204 | 0 | 없음 | 사용자 세션 `set_ai_cross_border_ack`, `write_audit('ai.consent.cross_border')` | 409 `CONSENT_VERSION_MISMATCH` |
| `POST /api/ai/conversations` | 로그인 / F | `{ project_id: uuid, channel: text\|voice }` | `{ conversation_id }` | 0 | 없음 | `ai_conversations` INSERT(service_role, `dify_user`=HMAC(org:user)), 프로젝트 org 확인 | 404, 403 |
| `POST /api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message 1..1000 }` | SSE `delta`, `citations`, `fallback`, `usage`, `done` / `error` | 1(턴) | Dify `docs-chat`(입력 `platform_conversation_id`, `project_id`). 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki`) | `rate_limit_hit`, `consume_credits(conv:<id>:turn:<n>)`, 정산 `refund_credits` | 402 `CR001`, 409 `AI_CONVERSATION_CLOSED`, 429, 503 `AI_UNAVAILABLE`(환불됨) |
| `POST /api/ai/assist` | member+ / F | `{ request_id, document_id, section_key, action: rewrite\|summarize\|to_table, selection_text 1..4000, instruction? ≤ 300 }` | `{ suggestion_html }`(저장 안 함, Diff 카드. 수락은 `POST /api/documents/[id]/versions`) | 1 | FastAPI `POST /graphs/docs.assist/runs`(scope `graph:docs.assist`) | `withCredits` | 403 `assist_disabled_high_risk`, 422 `selection_too_long`, 402, 503(환불됨) |
| `GET /api/projects/[id]/wiki/pages` | 멤버 / F | `?type=party\|term\|acronym\|decision` | `[{ slug, title, page_type, version, stale_since }]` | 0 | 없음(RLS 읽기) | `core.wiki_pages` | 404 |
| `PATCH /api/projects/[id]/wiki/pages/[...slug]` | member+ / F | `{ expected_version, body_md, reason ≥ 5자 }` | 페이지 | 0 | FastAPI 위키 저장(scope `wiki`, `editor_kind='user'`) | `write_audit` | 409 `WIKI_VERSION_CONFLICT`(`LLM_WIKI.md:31`) |
| `POST /api/projects/[id]/wiki/lint` | member+ / F | `{ request_id }` | `{ run_id }` | 사용량(선차감 2, 제안) | FastAPI `/wiki/lint`(scope `wiki`) | `consume_credits('run:<ai_run_id>')` | 402, 409 진행 중 |
| `POST /api/voice/consent` | 로그인 | `{ notice_version }` | 204 | 0 | - | `write_audit('voice.notice_ack')` | 409 |
| `POST /api/voice/stt` | 로그인 / F | multipart `{ audio (webm/ogg/mp4 ≤ 5MB), request_id, conversation_id, segment_seconds ≤ 60 }` | `{ text, duration_seconds, provider }` | 오픈소스 0.5/분, ElevenLabs 3/분(`VOICE_ARCHITECTURE.md:101`) | `voice_chat`/`stt` 체인(scope `voice`) | `voice_jobs`(`store_audio=false`), `consume_credits(voice:<request_id>)` | 403 `VOICE_CONSENT_REQUIRED`, 413, 402, 503 |
| `POST /api/voice/tts` | 메시지 주인 | `{ message_id, request_id }`(assistant 메시지 텍스트만) | `audio/mpeg` 스트림 | 글자 수 기준(`VOICE_ARCHITECTURE.md:102`) | `voice_chat`/`tts` 체인 | `voice_jobs`, `consume_credits` | 404, 402, 503 |
| `POST /api/internal/ai-token` | 워커(`X-Worker-Key`) | `{ job_id }` | `{ token, expires_at }` | 0 | 잡 행의 `job_type` → scope: `docs.generate` → `graph:docs.generate`, `docs.extract` → `graph:docs.extract`, `docs.minutes` → `graph:docs.minutes voice`, `rag.index` → `rag` | `core.jobs`(`status='running'`, `app_id='docs'`) | 401 `INTERNAL_KEY_INVALID`, 409 |
| `POST /api/internal/ai-settle` | 워커(5분) | - | `{ settled, refunded }` | 정산 | - | `ai_usage.settled_at is null` | 401 |

회의 녹음(`minutes_audio`) STT는 Route Handler가 아니라 `docs.minutes` 잡 안에서 ai-service가 `oss-voice`로만 처리한다(`meeting_minutes` 강제 오픈소스, 02장 5.1절).

## 3. RPC (SECURITY DEFINER)

모두 `set search_path = ''`, `revoke execute ... from public, anon`, 사용자 RPC는 `is_service_caller()` 패턴으로 호출자를 판정한다(`docs/file/03-설계/공용코어/SECURITY_BASELINE.md:13-25`). 사용자 RPC 안에서 크레딧을 차감하지 않는다. 코어 RPC(`consume_credits`, `refund_credits`, `enqueue_job`, `claim_jobs`, `heartbeat_job`, `complete_job`, `fail_job`, `cancel_job`, `create_oauth_state`, `consume_oauth_state`, `revoke_credential`, `write_audit`, `rate_limit_hit`, `session_context`, `set_ai_cross_border_ack`)는 CS 4~12장, 17장 그대로(`CORE_SPEC.md:42-61`).

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `docs.finalize_document(p_document_id uuid, p_expected_version int, p_ack_warn boolean)` | authenticated(oa), service_role | 상태 `draft`·`review`, `current_version = p_expected_version`, 필수 입력, 최신 버전 `lint_result` 오류 0, `compliance_verdict <> 'fail'`, `warn`이면 `p_ack_warn`, 고위험이면 `risk_acknowledgements` 존재. 통과 시 `docs.next_doc_number` → `status='final'`, `finalized_at`, 감사(`warn` 확인 포함) | `docs.documents` | `DC001`, `DC010`, `DC004`, `DC005`, `DC008`, `DC007`, `42501`, `P0002` |
| `docs.archive_document(p_document_id uuid)` | authenticated(oa), service_role | `final`·`draft` → `archived`. 감사 | `docs.documents` | `DC001`, `42501` |
| `docs.create_revision(p_document_id uuid)` | authenticated(oa), service_role | 원본 `final`. 새 문서 `draft`, `supersedes_document_id`, 원본 최신 버전 content를 버전 1로 복사(`created_kind='imported'`). 감사 | 새 `docs.documents` | `DC001`, `DC002`(진행 중 개정본 있음), `42501` |
| `docs.set_project_status(p_project_id uuid, p_to text)` | authenticated(oa), service_role | draft→active→delivered→archived, active↔delivered(제안) | `docs.projects` | `DC001`, `42501` |
| `docs.confirm_checklist_suggestions(p_project_id uuid, p_item_keys text[])` | authenticated(member+), service_role | `is_confirmed=false` 행만 `true`(source 유지). 확정 문서 수정 없음 | int(확정 수) | `42501`, `P0002` |
| `docs.ack_risk_notice(p_doc_type_code text, p_notice_version text)` | authenticated(oa), service_role | 유형 `risk_level='high'`, 유니크(org, doc_type, notice_version) 멱등. 감사 `docs.risk_ack` | `docs.risk_acknowledgements` | `22023`, `42501` |
| `docs.revoke_integration(p_connection_id uuid)` | authenticated(oa), service_role | `status <> 'revoked'`. `revoked` + `core.revoke_credential` + 대기 `integration.sync` 잡 취소. 감사 | `docs.integration_connections` | `DC009`, `42501` |
| `docs.decide_approval(...)` | authenticated(Phase 2) | Phase 2 승인 흐름. 시그니처는 Phase 2 설계에서 확정 | - | - |
| `docs.start_generation(p_org_id uuid, p_project_id uuid, p_document_id uuid, p_doc_type_code text, p_package_code text, p_parent_job_id uuid, p_credits int, p_idempotency_key text, p_actor uuid)` | service_role | 문서·패키지 활성 run 없음(부분 유니크), 조직 동시 생성 상한, `generation_runs` INSERT + `core.enqueue_job` + `core.consume_credits`(패키지 부모는 `p_credits=0`) 한 트랜잭션, `documents.status='generating'` | `docs.generation_runs` | `DC002`, `CR001`, `DC006` |
| `docs.finish_generation(p_run_id uuid, p_content jsonb, p_body_html text, p_variables jsonb, p_inputs_hash text, p_lint jsonb, p_verdict text, p_ai_run_id uuid)` | service_role | run running, `body_html` ≤ 2MB, 버전 INSERT, `current_version+1`, `status='review'`, `needs_regeneration=false`, `credits_settled` | `docs.document_versions` | `DC001`, `22023` |
| `docs.fail_generation(p_run_id uuid, p_error text)` | service_role | run → failed, 문서 `generating` → 이전 상태(버전 없으면 `draft`). 환불은 `fail_job`이 함 | `docs.generation_runs` | `DC001` |
| `docs.next_doc_number(p_org_id uuid, p_doc_type_code text)` | service_role(및 `finalize_document` 내부) | `doc_counters` 행 잠금 + `last_no+1`, 연도 경계는 KST | text(형식 적용 결과) | - |
| `docs.upsert_external_ref(p_connection_id uuid, p_entity text, p_internal_id uuid, p_external_type text, p_external_id text, p_etag text)` | service_role | 연결 `active`, 같은 org | `docs.external_refs` | `DC009`, `23505` |
| `docs.apply_checklist_effects(p_project_id uuid, p_plan jsonb, p_expected_hash text)` | service_role | 제안(브리프 6장에 없는 이름). 현재 답 해시 재계산 = `p_expected_hash`, `is_user_modified` 행 불변, 한 트랜잭션 적용 + `needs_regeneration` + 감사 | jsonb(집계) | `DC010`, `42501` |

## 4. 잡 페이로드 계약

공통: 비밀값·HTML·금액을 payload에 넣지 않는다(서버가 DB에서 읽는다). 경로는 서버가 만든 Storage 경로만. `progress` 0~100, `progress_message`는 한국어 한 줄. 모든 payload는 zod(TS)·pydantic(Python) 스키마 1개에서 생성(제안).

| job_type | payload | result | progress 메시지 |
|---|---|---|---|
| `docs.generate` | `{ run_id, document_id, doc_type_code, doc_type_version, project_id, mode: 'template'\|'hybrid'\|'ai', parent_run_id?: uuid }` | `{ version: int, version_id: uuid, ai_run_id?: uuid, lint: { errors: int, warnings: int }, compliance_verdict, skipped_ai_sections: string[] }` | "자료 모으는 중" → "표·고정 섹션 채우는 중" → "서술 섹션 작성 중 2/4" → "일관성 검사 중" → "검사 중" → "저장 중" |
| `docs.package` | `{ run_id, project_id, package_code: 'outsourcing_basic', stages: [['req_spec','screen_list','wbs'],['quote'],['sow'],['dev_contract'],['acceptance'],['trace_matrix']] / shorts_agency: [['content_brief'],['quote'],['sow'],['video_service_contract','channel_access_mandate'],['acceptance']], include: string[] }` | `{ succeeded: string[], failed: string[], canceled: string[], credits_used: int, refunded: int }` | "3/8 문서 완료(견적서 작성 중)" |
| `docs.extract` | `{ project_id, upload_id, ai_document_id, pages: int }` | `{ ai_run_id, checklist_suggestions: int, requirement_candidates: int, duplicates_skipped: int }` | "문서 읽는 중" → "색인 중" → "체크리스트 후보 찾는 중" → "요구사항 후보 찾는 중" → "중복 정리 중" |
| `docs.minutes` | `{ project_id, document_id, upload_id, kind: 'audio'\|'text', attendees: [{ name, role? }], meeting_at, stt_feature: 'meeting_minutes' }` | `{ ai_run_id, version, duration_seconds?, decisions: int, action_items: int, requirement_candidates: int, audio_deleted_at? }` | "받아쓰는 중 12/40분" → "회의록 작성 중" → "결정·할 일 정리 중" → "요구사항 후보 찾는 중" |
| `render.pdf` | `{ export_id, document_version_id, preset: 'a4_official', options: { watermark: bool, page_numbers: 'n / N', header_title: bool, ganin: bool } }` | `{ storage_path, pages, bytes, duration_ms }` | "PDF 만드는 중" |
| `render.docx` | `{ export_id, document_version_id, preset: 'a4_official', options: { watermark: bool } }` | `{ storage_path, bytes, duration_ms }` | "DOCX 만드는 중" |
| `docs.export_zip` | `{ export_id, project_id, document_version_ids: uuid[], include_trace_matrix: bool, account_export?: bool }` | `{ storage_path, bytes, files: int }` | "묶는 중 3/8" |
| `integration.sync` | `{ sync_run_id, connection_id, entity: 'party'\|'project'\|'line_item'\|'document', direction: 'pull'\|'push', cursor?: string, document_id?: uuid }` | `{ created, updated, skipped, conflicts, next_cursor? }` | "가져오는 중 120건" |
| `webhook.deliver` | `{ delivery_id, endpoint_id, event_type, event_id }`(본문은 워커가 `webhook_deliveries`와 원본 행에서 다시 만든다) | `{ http_status, attempts, duration_ms }` | - |
| `rag.index` | `{ ai_document_id, upload_id, collection: 'docs.knowledge', project_id }` | `{ chunks, embedding_provider, embedding_model, wiki_pages_updated }` | `chunking`, `embedding:<n>/<total>`, `wiki`, `done` |

그래프 실행 계약(워커 ↔ FastAPI, 잡 토큰):

```
// POST /graphs/docs.generate/runs   (Authorization: Bearer <잡 토큰, scope graph:docs.generate>)
{ "run_id": "uuid", "document_id": "uuid", "doc_type_code": "sow", "doc_type_version": 3 }
// 202 { "ai_run_id": "uuid", "status": "queued" }
// GET /graphs/runs/{ai_run_id} 완료 시
{ "status": "succeeded",
  "output": { "version": 4, "version_id": "uuid",
              "lint": { "errors": 0, "warnings": 2, "items": [ { "rule": "sow.period_matches_project", "level": "warning", "section": "schedule" } ] },
              "compliance": { "verdict": "warn", "issues": [ { "code": "guarantee_phrase", "section": "scope", "message": "..." } ] },
              "citations": [ { "type": "chunk", "id": 123 } ] } }
// 실패 { "status": "failed", "error": "required_missing|template_checksum|compliance_failed|provider_unavailable|document_not_found|too_large" }
```

FastAPI는 `documents.org_id = token.org`와 `generation_runs.job_id = token.sub`의 잡을 다시 확인한다. 버전 저장은 FastAPI가 `docs.finish_generation`으로 하고, 워커는 `version_id` 존재만 확인한다(이중 저장 방지).

렌더 요청 계약(C-1 반영 전제, 제안):

```ts
// POST /render/pdf : SM 10장 RenderPdfRequest 그대로, app_id에 'docs' 추가(C-1)
// POST /render/docx (C-1 신규, 제안)
interface RenderDocxRequest {
  org_id: string; app_id: 'docs'; job_id: string
  html: string                                  // 워커가 document_versions.body_html(sanitize 완료)을 DB에서 읽어 전달
  sections?: Array<{ key: string; title: string; html: string }>   // 구조 보존용(제목 스타일 매핑)
  preset: { page: 'A4'; margins_mm: { top: number; right: number; bottom: number; left: number }; font: 'Noto Sans CJK KR'; header?: string; footer_page_numbers: boolean }
  options?: { watermark?: string }
}
interface RenderDocxResponse { storage_path: string; bytes: number; duration_ms: number }
```

## 5. 웹훅

| 방향 | 제공자/이벤트 | 서명 방식 | event_id 출처 | 처리 |
|---|---|---|---|---|
| 수신 | Toss 결제 상태 | Toss 검증 방식(미확인, `SHARED_MODULES.md:186`) | CS 6장 규약 | `webhook_events` INSERT → 상태 동기화만. 지급은 confirm 경로 |
| 수신 | HubSpot 딜 단계 변경(`/api/integrations/hubspot/webhook`) | HubSpot 서명 헤더(버전·알고리즘 미확인). 원시 본문으로 검증 | HubSpot 이벤트 id(필드명 미확인) | `webhook_events`(provider `hubspot`) 멱등 → 해당 딜의 `external_refs`로 프로젝트 찾기 → "문서 생성 제안" 알림만(자동 생성 안 함). 연결이 `active`가 아니면 200 + 무시 기록 |
| 수신 | Make/n8n(`/api/integrations/inbound/[endpointToken]`) | 경로 토큰(조회는 토큰 해시) + HMAC-SHA256(`X-Signature`, `X-Timestamp`, 비밀은 연결 생성 시 1회 표시, 5분 허용) | 본문 `event_id`(UUID, 필수) | `webhook_events`(provider `make`/`n8n`) 멱등 → `create_project` 또는 `answer_checklist`(`source='integration'`) → 202 |
| 발신 | `project.created` | HMAC-SHA256(`timestamp.rawBody`), `X-Signature`, `X-Timestamp`, 5분 허용(`SHARED_MODULES.md:181`) | `event_id` UUID | `{ project_id, name, client_party_id, created_at }` |
| 발신 | `document.generated` | 같음 | 같음 | `{ document_id, project_id, doc_type_code, version, compliance_verdict }` |
| 발신 | `document.finalized` | 같음 | 같음 | `{ document_id, doc_number, version, finalized_at, download_url? }`(PDF가 있으면 서명 URL 24시간, 제안) |
| 발신 | `document.exported` | 같음 | 같음 | `{ document_id, export_id, format, pages?, download_url }` |
| 발신 | `package.completed` | 같음 | 같음 | `{ run_id, project_id, succeeded[], failed[] }` |

발신 공통: 헤더 `X-Event-Type`, `X-Event-Id`, `User-Agent: NOMAD-Docs-Webhook/1`. 수신 측 2xx만 성공, 타임아웃 10초(제안). `webhook_deliveries`는 `(endpoint_id, event_id)` 유니크로 중복 발송을 막고, 재시도는 4장 `webhook.deliver`(5회). 본문에 개인 연락처·문서 본문을 넣지 않는다(id와 링크만, 제안).

## 6. 외부 API 어댑터

| 외부 API | 호출 위치 | 실패 처리 | 쿼터 |
|---|---|---|---|
| FastAPI AI 서비스(그래프) | 워커(`docs.generate`, 잡 토큰), web(`docs.assist`, 사용자 토큰), ai-service 잡(`docs.extract`, `docs.minutes`, `rag.index`) | 체인 대체(라우터) → 노드 재시도 → `failed` → 환불. mock 금지. 300초(generate)·20초 p95(assist) 초과 시 실패 + 환불 | 조직당 60회/분, 동시 생성 3 |
| Dify Chat API | `src/app/api/ai/chat` | 5xx·10초 무응답 → `/tools/answer-direct` + 운영 알림 | 공용 인스턴스 |
| 오픈소스 음성 서버 | web(`/api/voice/stt`), ai-service(`docs.minutes`, scope `voice`) | 회의록은 대체 없이 실패 + 환불(강제 오픈소스) | 요청당 STT 10분(`VOICE_ARCHITECTURE.md:61`) → 회의 녹음은 10분 구간으로 나눠 호출 |
| ElevenLabs(TS SDK) | web `/api/voice/*` | 체인 다음으로 대체(`voice_jobs.fallback_from`) | 요금·조건 미확인 |
| 렌더 서비스 `POST /render/pdf` | 워커 `render-pdf` | SM 10장: 렌더 예외 재시도 불가 → 환불, 타임아웃 120초, 429는 재큐잉 | 컨테이너당 4(소유자 값, `D:/WorkSpace/platform/docs/products/flora-publishing/04_API.md:176`) |
| 렌더 서비스 `POST /render/docx`(C-1) | 워커 `render-docx` | 같음. C-1 반영 전에는 DOCX 형식을 비활성(403 `format_unavailable`) | 같음 |
| HubSpot | 워커(`integration.sync`, push), web(OAuth) | 401 → 토큰 갱신 1회 → 실패면 연결 `error` + 알림. 429 → `Retry-After` 준수 후 잡 재시도. 5xx → 지수 백오프 3회 | 레이트 한도 미확인 |
| admin-suite ERP(내부) | 워커 서비스 함수(service_role, `erp.products`·`erp.sales` 읽기) | 엔타이틀먼트 없음 → 연결 `error`(DC009). 스키마 변경(컬럼 없음) → 동기화 실패 + 운영 알림 | DB 내부, 1회 1,000행 페이지(제안) |
| Make/n8n | 수신 라우트, 발신 웹훅 | 5절 | 수신 엔드포인트당 60회/분(제안) |
| Toss | 공용 toss 모듈 | CS 5장. `PM001`은 운영 알림 + 승인 취소 요청 | - |
| Supabase Storage | web(서명 URL), 워커·렌더(service_role) | 업로드 완료 검증 실패 시 객체 삭제 | 문서 20MB, 음성 200MB(제안) |

HubSpot 상세(전부 미확인, 구현 시 HubSpot 공식 문서로 확인):

| 항목 | 계획 | 상태 |
|---|---|---|
| 인증 | OAuth 2.0 authorization code. 토큰은 `encrypted_credentials` | 미확인(앱 등록 절차) |
| 스코프 | CRM 딜·회사·연락처 읽기, 노트(또는 engagement) 쓰기, 파일 업로드(첨부 선택 시) | 스코프 문자열 미확인 |
| pull 엔드포인트 | CRM objects API의 deals, companies, contacts 목록·검색(증분 커서) | 경로·버전 미확인 |
| push 엔드포인트 | 딜에 연결된 노트 생성(문서 링크) | 경로 미확인 |
| 웹훅 | 딜 속성 변경 구독, 서명 헤더 검증 | 서명 버전 미확인 |

admin-suite ERP 매핑(읽기 전용, `D:/WorkSpace/platform/docs/products/_supabase-modular/migrations/1600_erp.sql:113-176`):

| ERP 원본 | 정본 대상 | 변환 |
|---|---|---|
| `erp.products.sku`, `name`, `category`, `price`, `is_active` | `line_items` 단가 카탈로그(사용자 선택 후 추가, `source='integration'`) | `price numeric(12,2)` → `unit_price_krw` 원 단위 정수(반올림, 제안), `unit='ea'`, 비활성 제외 |
| `erp.sales.product_id`, `quantity`, `unit_price`, `total_price`, `status='completed'`, `completed_at` | `invoice` 문서 입력(Phase 2 유형) | 합계는 docs 서버가 다시 계산해 `total_price`와 대조, 다르면 경고 |
| `erp.employees`(`display_name`, `position`, `department_id`) | Phase 3 인사 문서 | MVP·Phase 2 미사용 |

FastAPI 엔드포인트(`AI_ARCHITECTURE.md:149-158` 중 docs가 쓰는 것): `POST /tools/answer`(Dify HTTP 노드, 내부 키 + 대화 매핑, 프로젝트 범위 확인), `POST /tools/answer-direct`(web, scope `chat rag wiki`), `POST /graphs/docs.generate/runs`, `/graphs/docs.extract/runs`, `/graphs/docs.minutes/runs`, `/graphs/docs.assist/runs`, `GET /graphs/runs/{id}`, `POST /rag/ingest`, `POST /wiki/ingest`, `POST /wiki/lint`, `POST /v1/chat/completions`(Dify 보조 노드, `dify.aux`). 쓰지 않음: `/dify/retrieval`, `/tools/graph/{name}`.

Dify `docs-chat` 계약: `user=dify_user`, 입력 변수 `platform_conversation_id`(필수), `project_id`(선택, 대화 시작 때만). 토큰·org·문서 본문은 넣지 않는다. HTTP 노드 `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`, 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, project_id }`, 응답 `{ answer, citations[], no_source, fallback, usage }`. 노드 이름과 입력 변수 동작은 설치 버전 문서로 확인(`AI_ARCHITECTURE.md:71`).

## 7. 오류 코드

| 코드 | 의미 | HTTP | 발생 위치 |
|---|---|---|---|
| `DC001` | 상태 전이 위반 | 409 | 상태 트리거, `finalize_document`, `archive_document`, `create_revision`, `set_project_status`, `finish_generation` |
| `DC002` | 같은 문서(또는 패키지) 생성 이미 진행 중 | 409 | `start_generation`(부분 유니크) |
| `DC003` | 확정·불변 데이터 수정 시도(확정 문서, 게시된 유형 버전, 버전 행) | 409 | 불변 트리거 |
| `DC004` | 필수 입력 누락으로 생성·확정 불가 | 422 | Route Handler 사전 검사, `finalize_document` |
| `DC005` | compliance FAIL 또는 lint 오류로 확정 불가 | 422 | `finalize_document` |
| `DC006` | 플랜 한도 초과(프로젝트 수, 문서 유형 단계, 형식) | 402 또는 403(제안: 업그레이드 안내는 403) | 한도 트리거, Route Handler |
| `DC007` | 고위험 문서 고지 미동의 | 428 | Route Handler, `finalize_document` |
| `DC008` | WARN 확인 없이 확정 시도 | 409 | `finalize_document` |
| `DC009` | 연동 연결 상태 불가(해지, 오류) | 409 | `revoke_integration`, `upsert_external_ref`, 동기화 |
| `DC010` | 버전 충돌(expected_version 불일치) | 409 | `finalize_document`, 편집 저장, `apply_checklist_effects`(해시) |
| 코어 코드 | `42501` 403, `22023` 409, `P0002` 404, `CR001` 402(`details: { required, balance }`), `JB002` 409, `OA001` 400, `PM001`/`PM409` 409 + 운영 알림, `PM404` 404, `SB001` 409, `AI001` 403, `AI002` 403 | - | `docs/file/03-설계/공용코어/CORE_SPEC.md:424` 매핑 |
| `23505` | 중복(활성 run, 외부 매핑, 유니크) | 409 | 유니크 인덱스 |
| `23503` | 다른 조직·프로젝트 행 참조 | 422 | 복합 FK |
| 앱 코드 | `pii_detected` 422(주민등록번호 등 패턴), `locked_section` 422, `selection_too_long` 422, `assist_disabled_high_risk` 403, `format_unavailable` 403(DOCX, C-1 전), `url_not_allowed` 422, `entitlement_missing` 422, `recording_notice_required` 422, `expired` 410, `render_failed` 502 | - | Route Handler |
| AI 앱 코드 | `AI_UNAVAILABLE` 503(체인 전부 실패, 환불 완료), `AI_CONVERSATION_CLOSED` 409, `AI_DAILY_LIMIT` 429, `CONSENT_VERSION_MISMATCH` 409, `INTERNAL_KEY_INVALID` 401, `VOICE_CONSENT_REQUIRED` 403, `VOICE_TOO_LONG` 413, `WIKI_VERSION_CONFLICT` 409 | - | Route Handler(flora-publishing과 같은 이름, `D:/WorkSpace/platform/docs/products/flora-publishing/04_API.md:255-257`) |
| FastAPI | `AI_TOKEN_INVALID` 401(서명, `aud`, scope, 만료, `jti` 재사용) | - | `apps/api` |
