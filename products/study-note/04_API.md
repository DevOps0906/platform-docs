# 04 API: Study Note

작성일 2026-10-12. TypeScript 블록은 계약 예시다. 구현 파일이 아니다.

2026-10-13: AI·음성 Route Handler(2.1절), 노트 정리 그래프 잡 계약(4.1절), 이 제품이 쓰는 FastAPI 엔드포인트와 Dify Chatflow 계약(6.1, 6.2절), AI 오류 코드(7절)를 추가했다. 기존 일지 정리 API(2절 표)는 바꾸지 않았다.

## 1. 원칙

| 항목 | 내용 |
|---|---|
| 인증 | 모든 `/api/notes/*`는 `requireSession('notes')`로 시작한다(`SHARED_MODULES.md` 2장). 미로그인 401, `pending`/`suspended` 403, `entitled=false` 402. 정리 실행 계열은 추가로 이메일 인증 필수(미인증 403 `email_not_verified`). 세션은 모든 인증 단계(A Mock, B Google·이메일, C 카카오·네이버)에서 실제 Supabase JWT이고 `requireSession`은 같다(확정 결정 22, 8절) |
| 멱등 | 클라이언트가 실행마다 UUID `request_id`를 보낸다. 서버는 `consume:notes:<request_id>`, `job:notes:<request_id>`로 쓴다(`DB_CONVENTIONS.md:215`). 같은 `request_id`는 같은 실행을 돌려준다 |
| 크레딧 선차감 위치 | Route Handler가 아니라 DB 함수 `notes.start_run` 안(service_role 호출). 차감, 실행 생성, 잡 생성이 한 트랜잭션 |
| 응답 봉투 | 성공 `{ "ok": true, "data": ... }`, 실패 `{ "ok": false, "error": { "code": "...", "message": "한국어 문장", "retryable": bool } }` |
| 레이트 리밋 | `core.rate_limit_hit('notes:<route>:<org_id>', limit, window)`. 초과는 429 + `Retry-After` |
| 서비스 키 | `createAdminClient`는 서버 파일에서만 import. 브라우저에서 `OPENROUTER_API_KEY`나 service_role에 닿는 경로가 없다 |
| 직접 조회 | 목록/상세/설정 읽기와 일지 입력 저장은 브라우저가 Supabase로 직접 한다(RLS가 정본). Route Handler는 과금, 상태 전이, 외부 호출, 감사가 필요한 것만 |
| AI·음성 크레딧 선차감 위치 | 일지 정리는 위 규칙대로 DB 함수 `notes.start_run`이 차감한다. AI·음성은 `POST /api/ai/organize`, `/api/ai/chat`, `/api/ai/wiki/lint`, `/api/ai/quizzes/grade`, `/api/voice/stt`·`tts`·`lectures/[id]/chunks`의 Route Handler와 정산 크론(`/api/internal/ai-settle`)만 `consume_credits`/`refund_credits`를 부른다. 사용자 RPC 안에서는 차감하지 않는다 |
| AI 경계 | 브라우저는 `/api/ai/*`, `/api/voice/*`, `/api/notes/*`만 부른다. Dify, FastAPI, LLM·음성 제공자, 오픈소스 서버는 Route Handler가 부른다(`docs/products/_platform-core/SECURITY_BASELINE.md:299`) |
| 서명 토큰 | `src/server/ai/token.ts`가 EdDSA JWT를 발급: `iss=notes`, `aud=platform-ai:notes`, `org`, `app=notes`, `sub`(사용자 id), `conv`, `feat`, `scope`(`chat`, `rag`, `wiki`, `graph:notes.organize`, `voice`), `jti`, `iat`, `exp`(10분). org는 세션에서만 가져오고 요청 본문의 org는 무시한다. 개인키는 Next.js 서버에만 둔다(`docs/products/_platform-core/AI_ARCHITECTURE.md:33-42`) |
| AI 멱등 키 | 채팅 `conv:<id>:turn:<n>`(n은 서버가 센 턴 번호. 같은 `request_id` 재전송은 `notes:ai-req:<request_id>` 버킷 1회로 막는다), 그래프 `consume:notes:<request_id>`·`job:notes:<request_id>`, 음성 `voice:<voice_job_id>`(클라이언트 `request_id`를 `voice_jobs.id`로 쓴다), 퀴즈 채점 `run:<quiz_session_id>` |
| AI 선차감·정산 | 선차감은 제공자 호출 전 Route Handler에서, 정산은 응답 종료 직후 같은 Route Handler에서. 연결이 끊기면 `/api/internal/ai-settle`(워커가 5분마다 호출)이 처리. 결과가 전달되지 않은 실패는 선차감 전액 환불 |
| 스트리밍 | 채팅은 SSE(`text/event-stream`), 강의 조각 처리 진행은 JSON 응답(조각 단위) |
| 입력 마스킹 | 채팅 메시지와 문서 본문은 서버가 주민등록번호·전화번호·이메일·계좌번호 형식을 마스킹한 뒤 FastAPI·Dify로 보낸다 |
| AI 레이트 리밋 | `notes:ai-chat:<user>` 20회/60초, `notes:ai-chat-day:<user>` 하루 `ai_chat_turns_per_day`, `notes:ai-organize:<org>` 6회/3600초, `notes:voice-stt:<user>` 10회/60초, `notes:lecture-chunk:<user>` 30회/60초, `notes:upload-url:<org>` 20회/3600초, `notes:ai-token:worker` 120회/60초(01장 5절) |

## 2. Route Handler

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 호출하는 RPC | 오류 |
|---|---|---|---|---|---|---|
| POST `/api/notes/runs` | owner/admin/member, 엔타이틀먼트 | `request_id: uuid`, `entry: { id?: uuid, entry_date: 'YYYY-MM-DD', input_text: 1..20000 }`, `models?: { base1, base2, merge }`(없으면 사용자 설정, 그것도 없으면 프리셋) | `{ run, steps[], estimated_credits }` | 선차감(등급 합) | 일지 upsert(사용자 세션, RLS) → `notes.start_run`(service) | 400 입력, 402 `CR001`, 403, 409 `NT002`, 422 `NT004`, 429 한도/`NT006`, 503 `NT005` |
| POST `/api/notes/runs/{id}/retry` | 같음 | `request_id`, `roles: ['base1'\|'base2'][]` | `{ run, steps[] }` | 실행 대상 단계 + 통합 | `notes.start_run(parent, retry_roles)` | 404, 409, 422 `22023`(재사용할 결과 없음) |
| POST `/api/notes/runs/{id}/cancel` | 같음 | 없음 | `{ run }` | queued는 전액 환불, running은 미실행분 환불 | `notes.request_run_cancel`(사용자 세션) | 404, 409 `NT003` |
| GET `/api/notes/runs/{id}` | 같음 | | `{ run, steps[] }` (Realtime 불가 시 폴링용, 2초 간격) | | RLS 조회 | 404 |
| GET `/api/notes/models` | 로그인 | | `{ models[], allowed_tiers, defaults }` | | `model_catalog` + `org_features` | |
| PUT `/api/notes/settings` | 로그인 | `base_model_1`, `base_model_2`, `merge_model`, `theme` | `{ settings }` | | `user_settings` upsert(RLS) | 422 등급/비활성 모델 |
| POST `/api/notes/consent` | 로그인 | `kind: 'llm'`, `version: string` | `{ ok }` | | `write_audit('notes_consent.llm')` | |
| POST `/api/notes/export` | 로그인 | 없음 | JSON 파일(전체 일지 + 카드) | | `write_audit('notes_export')` | 429(하루 3회, 제안) |
| POST `/api/notes/account/delete` | owner | `confirm: 'DELETE'` | `{ scheduled_for }` | | 조직 soft delete(service_role, 코어 요청 C-3) + 감사 | |
| POST `/api/billing/orders`, `/api/billing/confirm` (Phase 2) | owner | `core-billing` 계약(`SHARED_MODULES.md` 5장) | | | `payment_orders` INSERT, `confirm_payment_order` | 409 `PM001`: 지급 없음 + 운영 알림 |
| POST `/api/webhooks/toss` (Phase 2) | 서명 | 코어 webhooks | 200 | | `webhook_events` | 401 서명 실패 |

실행 요청 처리 순서(`POST /api/notes/runs`):

| 순서 | 동작 |
|---|---|
| 1 | 세션, 이메일 인증, zod 검증 |
| 2 | `rate_limit_hit('notes:run:<org>', 6, 60)` |
| 3 | 사용자 세션으로 일지 insert/update(RLS, 컬럼 GRANT) |
| 4 | service_role로 `notes.start_run(...)` 호출(모델 미지정 시 `user_settings` → 프리셋) |
| 5 | SQLSTATE를 7장 표대로 HTTP로 매핑 |

### 2.1 AI·음성 Route Handler (2026-10-13)

서명 토큰 scope와 호출 대상은 `docs/products/_platform-core/AI_ARCHITECTURE.md:149-158`, `docs/products/_platform-core/VOICE_ARCHITECTURE.md:22-38`을 따른다. 모든 핸들러는 `requireSession('notes')`로 시작하고 이메일 인증을 요구한다(AI 설정·읽기 제외).

| 메서드 경로 | 역할/플랜 | 입력(zod 요약) | 출력 | 크레딧 | 서명 토큰 scope / 호출 대상 | 코어 RPC·테이블 | 오류 |
|---|---|---|---|---|---|---|---|
| `POST /api/onboarding/ai-consent` | owner | `{ granted: boolean, notice_version }`(서버 상수와 같아야 함) | 204 | 0 | 없음 | 사용자 세션 `rpc('set_ai_cross_border_ack', { p_org_id, p_ack, p_notice_version })`, `write_audit('notes_consent.ai_cross_border')` | 409 `CONSENT_VERSION_MISMATCH`, 403 |
| `POST /api/notes/subjects` | owner/admin/member | `{ name(1..40) }` | `{ subject_id(8자리 16진수) }` | 0 | scope `wiki` / FastAPI 위키 저장(`subjects/s-<id>/index`, 제목 = 과목 이름) | `rate_limit_hit`, 감사 `subject.create` | 422 `AI_PLAN_LIMIT`(`ai_subjects_max`), 409 같은 이름 |
| `PATCH /api/notes/subjects/[sid]` | 같음 | `{ name }` | 204 | 0 | scope `wiki` / 위키 저장(`expected_version`) | 감사 `subject.rename` | 404, 409 `WIKI_VERSION_CONFLICT` |
| `DELETE /api/notes/subjects/[sid]` | owner | `{ confirm: 'DELETE' }` | 204 | 0 | scope `rag wiki` / FastAPI 제품 확장 `POST /products/notes/subjects/{sid}/purge`(C-7) | 감사 `subject.delete`, Storage 파일 24시간 내 삭제 | 404 |
| `POST /api/notes/documents/upload-url` | 같음 | `{ filename, mime(md/txt/pdf), byte_size(20MB 이하) }` | `{ path, upload_url, token, expires_at }`. 경로는 서버가 `<org_id>/notes/<uuid>/<안전한 파일명>`으로 정한다 | 0 | 없음 | Storage `createSignedUploadUrl`(service_role, 버킷 `org-files`), `rate_limit_hit('notes:upload-url:<org>', 20, 3600)` | 400 형식, 413, 429 |
| `POST /api/notes/documents` | 같음 | `{ subject_id, source: 'upload'\|'text', path?, text?(20,000자), title, rights_confirmed: true, contains_pii?: boolean, lecture_id? }` | `{ document_id, status: 'pending' }` | 0(색인 과금 없음) | scope `rag` / FastAPI `POST /rag/ingest`(컬렉션 `rag:s-<sid>`, 임베딩 `notes.knowledge`) | `write_audit('notes_upload_rights')`, `ai_documents` 조회로 한도 확인 | 403 `UPLOAD_RIGHTS_REQUIRED`, 409 `DOC_CONTENT_DUPLICATE`, 422 `AI_PLAN_LIMIT`, 404 과목 |
| `DELETE /api/notes/documents/[id]` | owner/admin/member | - | 204 | 0 | scope `rag` / FastAPI 제품 확장 `DELETE /products/notes/documents/{id}`(청크 삭제, C-7) | 감사 `document.delete` | 404 |
| `POST /api/ai/organize` | owner/admin/member, `ai_chat` 무관 | `{ request_id, subject_id, document_ids(1..5, 모두 ready), quiz_count?(5..20, 기본 10) }` | `{ run_id, estimated_credits, route: 'open_source'\|'commercial' }` | 선차감(4.6절) | scope `graph:notes.organize`, `jti` 1회 / FastAPI `POST /graphs/notes.organize/runs` | `consume_credits(consume:notes:<request_id>)`, `rate_limit_hit` | 402 `CR001`, 404, 409 같은 문서에 활성 실행, 422 `AI_PLAN_LIMIT`, 429 `AI_BUSY`/`RATE_LIMITED`, 503 `AI_UNAVAILABLE`(환불됨) |
| `GET /api/ai/runs/[id]` | 실행 주인 조직 | - | `{ run{ status, progress, credits, output? }, steps[] }`(2초 폴링) | 0 | 없음 | RLS로 `core.ai_runs`, `core.ai_run_steps` 조회 | 404 |
| `POST /api/ai/runs/[id]/cancel` | 같음 | - | `{ run }` | queued는 전액 환불 | 없음 | `core.cancel_job`(사용자 세션 호출 가능) | 404, 409 `JB002`(이미 실행 중) |
| `POST /api/ai/conversations` | owner/admin/member, `ai_chat` | `{ subject_id?: string, channel: 'text'\|'voice' }` | `{ conversation_id }` | 0 | 없음 | `ai_conversations` INSERT(service_role, `dify_user` = HMAC(org:user)) | 402, 403 |
| `POST /api/ai/chat` | 대화 주인 | `{ conversation_id, request_id, message(1..1000), subject_id? }` | SSE `delta`, `citations`, `fallback`, `usage{credits}`, `done` / `error` | 선차감 2(오픈소스) 또는 5(상용), 정산 1~선차감값 | Dify Chat API(`user=dify_user`, 입력 `platform_conversation_id`, `subject_id`). Dify 장애 시 FastAPI `/tools/answer-direct`(scope `chat rag wiki`, `conv`=대화 id, `feat=chat`) | `rate_limit_hit` 3종, `consume_credits(conv:<id>:turn:<n>)`, 사용자 `ai_messages` INSERT, 정산 + `ai_usage.settled_at` | 402 `CR001`, 404 대화, 409 `AI_CONVERSATION_CLOSED`, 429 `AI_DAILY_LIMIT`/`RATE_LIMITED`, 503 `AI_UNAVAILABLE`(환불됨) |
| `POST /api/ai/conversations/[id]/close` | 대화 주인 | - | 204 | 0 | - | `ai_conversations.status='closed'` | 404 |
| `DELETE /api/ai/conversations/[id]` | 대화 주인 | - | 204 | 0 | Dify 대화 삭제 API(구현 시 확인) | 대화·메시지 삭제(service_role), 감사 `ai.conversation.delete` | 404 |
| `PUT /api/ai/wiki/pages/[...slug]` | owner/admin/member | `{ expected_version, body_md, reason? }` | 페이지 | 0 | scope `wiki` / FastAPI 위키 저장(`editor_kind='user'`, 고친 블록에 `<!-- owner:user -->`, C-7) | 감사 `wiki.edit` | 404, 409 `WIKI_VERSION_CONFLICT`, 422 slug가 자기 조직·과목 범위 밖 |
| `POST /api/ai/wiki/lint` | 같음 | `{ subject_id, request_id }` | `{ run_id, estimated_credits }` | 선차감(4.6절) | scope `wiki` / FastAPI `POST /wiki/lint` | `consume_credits(run:<id>)` | 402, 404, 429 |
| `GET /api/ai/quizzes/[run_id]` | 실행 주인 조직 | - | `{ questions[{ id, type, question, choices[] }] }`. `answer`, `explanation`, `evidence_chunk_ids`는 제거 | 0 | 없음 | RLS로 `core.ai_runs.output` 조회 후 서버에서 제거 | 404 `QUIZ_NOT_FOUND` |
| `POST /api/ai/quizzes/sessions` | 실행 주인 조직 | `{ quiz_run_id, request_id, voice?: boolean }` | `{ quiz_session_id, estimated_credits }` | 단답 채점 예상(문항 수 × 0.5 / × 2, 올림)만. `voice=true`면 문제 읽어 주기 TTS(문항 글자 합) + 답 STT(문항 수 × 30초)를 더해 한 번에 선차감. 10문항 음성 오픈소스 약 7. 단답이 없고 `voice=false`면 0 | `voice=true`일 때만 음성 처리 고지(`notes_consent.voice`) 확인 | `consume_credits(run:<quiz_session_id>)` | 403 `VOICE_CONSENT_REQUIRED`, 404 `QUIZ_NOT_FOUND`, 402 |
| `POST /api/ai/quizzes/grade` | 같음 | `{ quiz_run_id, question_id, answer, request_id, quiz_session_id }` | `{ correct, score, explanation, evidence[] }` | 추가 차감 없음(`quiz_session_id`의 세션 선차감에서 소진. 크레딧은 정수라 건별이 아니라 세션 단위로 올림) | 단답만 scope `chat` / FastAPI 제품 확장 `POST /products/notes/quiz/grade`(`notes.quiz`) | `consume_credits(run:<quiz_session_id>)`, 정답은 DB 저장본에서만 읽음 | 404, 402, 503(환불됨) |
| `POST /api/voice/consent` | owner | `{ notice_version }` | 204 | 0 | - | `write_audit('notes_consent.voice')` | 409 `CONSENT_VERSION_MISMATCH` |
| `POST /api/voice/sessions` | owner, `voice_chat` | `{ conversation_id? }` | `{ session_id }` | 0 | - | `voice_sessions` INSERT | 403 `VOICE_CONSENT_REQUIRED` |
| `POST /api/voice/stt` | 세션 주인 | multipart `{ audio(webm/ogg/mp4, 5MB 이하, 60초 이하), session_id, request_id, feature: 'voice_chat'\|'quiz_voice', quiz_session_id? }` | `{ text, duration_seconds, provider }` | 녹음 길이 기준 선차감, 실제 정산. `quiz_session_id`가 있으면 `POST /api/ai/quizzes/sessions` 선차감에서 소진(추가 차감 없음) | `resolve_ai_route(org,'notes',feature,'stt')` → 오픈소스 `/stt`(scope `voice`) 또는 ElevenLabs SDK | `consume_credits(voice:<request_id>)`, `voice_jobs`(`store_audio=false`), `ai_usage` | 403 `VOICE_CONSENT_REQUIRED`, 413 `VOICE_TOO_LONG`, 402, 429, 503(환불됨) |
| `POST /api/voice/tts` | 메시지·퀴즈 주인 | `{ message_id }` 또는 `{ quiz_run_id, question_id }`, `request_id`, `feature: 'voice_chat'\|'quiz_voice'`, `quiz_session_id?`(텍스트는 DB의 assistant 메시지와 퀴즈 JSON에서만 읽는다. 임의 텍스트 낭독 금지) | `audio/mpeg` 스트림 | 글자 수 기준 선차감·정산 | `voice_chat`/`quiz_voice` tts 체인(대체 허용) | `voice_jobs`, `consume_credits(voice:<request_id>)` | 404, 402, 503(환불됨) |
| `POST /api/voice/lectures` | owner/admin/member, `lecture_note` | `{ subject_id, title, notice_version, keep_audio: boolean }` | `{ lecture_id(= voice_sessions.id), max_minutes, chunk_seconds: 300 }` | 0 | - | `write_audit('notes_consent.lecture_notice')`(고지문 버전), `voice_sessions` INSERT | 403 `LECTURE_NOTICE_REQUIRED`(버전 불일치), 409 `CONSENT_VERSION_MISMATCH`, 402 |
| `POST /api/voice/lectures/[id]/chunks` | 세션 주인 | multipart `{ audio(조각, 50MB 이하, 10분 이하), seq(0부터), duration_seconds, request_id }` | `{ seq, status: 'done', text_chars }` | 조각 길이 기준 선차감(오픈소스 0.5/분 올림) | `resolve_ai_route(org,'notes','lecture_note','stt')`(강제 오픈소스) → 오픈소스 `/stt`(scope `voice`). 상용으로 대체하지 않는다 | `consume_credits(voice:<voice_job_id>)`, `voice_jobs`(feature `lecture_note`, `store_audio` = `keep_audio`; 보관이면 `consent_at`, `consent_kind='third_party_notice'`, `notice_version`, `expires_at`, `storage_path`), Storage `org-files/<org_id>/notes/lectures/<id>/<seq>.json`(전사), 보관이면 `voice-audio` | 403 `LECTURE_NOTICE_REQUIRED`, 413 `VOICE_TOO_LONG`(허용 시간 초과), 402, 429, 502 `LECTURE_CHUNK_FAILED`(그 조각 환불됨, 재시도 가능) |
| `POST /api/voice/lectures/[id]/finish` | 세션 주인 | `{}` | `{ transcript, total_seconds, chunk_count, missing_seqs[] }` | 정산(차액 환불) | - | 전사 조각 병합(`seq` 순), `voice_sessions.status='ended'`, 정산 | 404, 409 조각 누락(`missing_seqs` 안내) |
| `GET /api/voice/lectures/[id]` | 세션 주인 | - | `{ status, received_seqs[], elapsed_seconds, max_minutes }`(재개용) | 0 | - | Storage 목록, `voice_jobs` 조회 | 404 |
| `GET /api/voice/lectures/[id]/audio` | 세션 주인 | - | `{ url, expires_at }`(보관을 선택한 경우만, 1시간 서명 URL) | 0 | - | `voice-audio` 서명 URL(본인만) | 404 |
| `POST /api/internal/ai-settle` | 워커(`X-Worker-Key`, 5분 주기) | - | `{ settled, refunded }` | 정산 | - | `ai_usage`(`settled_at is null`, 10분 경과), `consume_credits`/`refund_credits` | 401 `INTERNAL_KEY_INVALID` |

읽기는 Route Handler 없이 RLS로 직접 한다: `core.ai_conversations`, `core.ai_messages`, `core.voice_jobs`(본인 행만, `docs/products/_supabase-modular/migrations/0008_core_ai.sql:635-642`, `0009_core_voice.sql:81-87`), `core.ai_documents`, `core.wiki_pages`, `core.wiki_links`, `core.wiki_revisions`(조직 멤버, 같은 파일 `:630`). 청크 테이블 `ai_chunks`는 사용자에게 열지 않는다(`docs/products/_platform-core/SECURITY_BASELINE.md:294`).

## 3. RPC (SECURITY DEFINER)

정본은 `docs/products/_supabase-modular/migrations/2100_notes.sql`. 모놀리스는 `public.` 접두사.

| 시그니처 | 호출자 | 검사 | 반환 | SQLSTATE |
|---|---|---|---|---|
| `notes.start_run(p_org_id, p_user_id, p_entry_id, p_request_id, p_base_model_1, p_base_model_2, p_merge_model, p_parent_run_id default null, p_retry_roles default null)` | service_role | 활성 멤버(owner/admin/member, NULL-safe), 엔타이틀먼트, 일지 소유, 활성 실행 없음, 입력 길이, 모델 활성/등급, 조직 동시 실행, 일일 예산, 크레딧(`CR001`) | `notes.runs` | `42501`, `P0002`, `22023`, `NT002`, `NT004`, `NT005`, `NT006`, `CR001` |
| `notes.record_step(p_run_id, p_role, p_status, p_content, p_latency_ms, p_prompt_tokens, p_completion_tokens, p_ai_usage_id, p_error_code, p_error_message, p_model_id)` | service_role | 실행이 queued/running, 단계 전이 pending→running→succeeded/failed 등 | `notes.run_steps` | `42501`, `P0002`, `22023`, `NT003` |
| `notes.finish_run(p_run_id, p_final_text, p_keywords)` | service_role | 실행이 종료 전. 상태 계산(succeeded/partial/failed/canceled), 미성공 단계 환불, 일지 갱신, 보존 정책 실행 | `notes.runs` | `42501`, `P0002`, `22023`, `NT003` |
| `notes.request_run_cancel(p_run_id)` | authenticated | `is_service_caller()` 또는 owner/admin/member(NULL-safe `has_org_role`). queued는 `core.cancel_job` 호출 | `notes.runs` | `42501`, `P0002`, `NT003` |
| `notes.enforce_retention(p_org_id)` | service_role | `features.history_max_entries/bytes` 초과분 soft delete | 삭제 건수 | `42501` |
| `notes.purge_deleted(p_grace default '30 days')` | service_role(스케줄) | 유예 지난 휴지통 영구 삭제, 오래된 `cost_guard` 정리 | 삭제 건수 | `42501` |
| `notes.org_features(p_org_id)` | service_role(내부) | | jsonb | |

코어 RPC는 `CORE_SPEC.md`를 인용만 한다: `consume_credits`, `refund_credits`, `enqueue_job`, `claim_jobs`, `heartbeat_job`, `complete_job`, `fail_job`, `cancel_job`, `write_audit`, `rate_limit_hit`. AI·음성 코어 RPC: `resolve_ai_route`, `match_ai_chunks`(service_role 전용, FastAPI만), `set_ai_cross_border_ack`(사용자 세션, owner), `expire_voice_audio`(워커). 이 제품은 AI용 제품 RPC를 새로 만들지 않는다.

## 4. 잡 페이로드 계약

`job_type = 'notes.organize'`, 큐 `notes.organize`. 원문과 비밀값은 payload에 넣지 않는다.

```json
{
  "payload": { "run_id": "uuid", "entry_id": "uuid", "exec_roles": ["base1", "base2", "merge"] },
  "progress": [
    { "pct": 0,   "message": "queued" },
    { "pct": 10,  "message": "base_running" },
    { "pct": 60,  "message": "base_done" },
    { "pct": 70,  "message": "merge_running" },
    { "pct": 100, "message": "done" }
  ],
  "result": { "status": "succeeded|partial|failed|canceled", "credits_refunded": 0 }
}
```

`exec_roles`는 재요청이면 `["base2","merge"]`처럼 실행 대상만 담는다. 재사용 단계는 이미 `run_steps`에 `reused`로 있다.

### 4.1 노트 정리 그래프 잡 페이로드

`job_type = 'notes.ai.organize'`, 큐 `notes.ai`. 문서 본문과 비밀값은 payload에 넣지 않는다.

```json
{
  "payload": { "run_id": "uuid", "subject_id": "1a2b3c4d", "document_ids": ["uuid"], "quiz_count": 10, "request_id": "uuid" },
  "progress": [
    { "pct": 0,   "message": "queued" },
    { "pct": 15,  "message": "upload" },
    { "pct": 45,  "message": "summary" },
    { "pct": 70,  "message": "link" },
    { "pct": 85,  "message": "quiz" },
    { "pct": 95,  "message": "compliance" },
    { "pct": 100, "message": "done" }
  ],
  "result": { "status": "succeeded|failed|canceled", "excluded": { "quiz": 0, "wiki_pages": 0 }, "credits_refunded": 0 }
}
```

`core.ai_runs.output` 형식(그래프 결과, 사용자는 RLS로 읽는다):

```json
{
  "summary_page_slugs": ["subjects/s-1a2b3c4d/sources/d-5e6f7a8b"],
  "concept_page_slugs": ["subjects/s-1a2b3c4d/concepts/c-9f8e7d6c"],
  "quiz": [ { "id": "q1", "type": "mcq", "question": "...", "choices": ["..."], "answer": "...", "explanation": "...", "evidence_chunk_ids": [123] } ],
  "excluded": { "quiz": 0, "wiki_pages": 0 },
  "suggestions": [ { "slug": "...", "reason": "사용자 소유 블록이라 제안으로만 남김" } ]
}
```

## 5. 웹훅

| 구분 | 내용 |
|---|---|
| 수신 | Toss(Phase 2): 코어 webhooks 모듈의 서명 검증과 `(provider, event_id)` 멱등. 지급은 confirm 경로가 정본이고 웹훅은 상태 동기화만 |
| 발신 | 없음 |

## 6. 외부 API 어댑터

| 외부 | 호출 위치 | 실패 처리 |
|---|---|---|
| OpenRouter Chat Completions | 워커, 코어 LLM 게이트웨이 경유 | 5절/02장 5절 매핑. 폴백 1회, 단계 단위 실패 → 환불 |
| OpenRouter 모델 목록(동기화, Phase 2) | 워커 크론 `notes.models.sync` | 엔드포인트와 응답 형식은 미확인(구현 시 문서 확인). 목록에 없는 모델만 `is_active=false`. 신규 모델 자동 추가는 하지 않는다(등급/단가는 사람이 정함) |
| Toss Payments (Phase 2) | 코어 toss 모듈 | `SHARED_MODULES.md` 5장 |

쿼터: 공급사별 레이트 리밋은 OpenRouter 키 단위로 공유되므로 워커 동시성(기본 4잡)으로 제어한다.

| 외부 API(AI·음성, 2026-10-13) | 호출 위치 | 실패 처리 | 쿼터/비용 |
|---|---|---|---|
| FastAPI AI 서비스(그래프, RAG, 위키, 도구) | Next.js Route Handler(서명 토큰) | 체인 대체(라우터) → 항목 재작성 1회(그래프) → `failed` → `fail_job` 자동 환불. 10분 안에 끝나지 않으면 실패 처리 | 문서 10,000자 정리당 LLM 호출 수십 회. 원가는 `ai_usage`(run_id) |
| Dify Chat API | `src/app/api/ai/chat` | 5xx·10초 무응답 → FastAPI `/tools/answer-direct` + 운영 알림 | 공용 인스턴스 |
| ElevenLabs(TS SDK) | `src/app/api/voice/*`(음성 대화·퀴즈 음성만) | 체인 다음으로 대체(`voice_jobs.fallback_from`). 강의 녹음에는 쓰지 않는다 | 요금·상업 이용 조건·보관 정책 구현 시 확인(D-18) |
| 오픈소스 음성 서버 | `src/app/api/voice/*`(서명 토큰 scope `voice`) | STT 실패 → 그 요청 환불, 조각 단위 재시도 | 요청당 STT 10분·TTS 5,000자 상한(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:61`). 이 제품은 음성 질문 60초·강의 조각 5분 |
| Supabase Storage | 업로드 서명 URL, 강의 전사 조각, 녹음 보관 | 업로드 실패 → 클라이언트 재시도 | 버킷 `org-files` 50MB, `voice-audio` 50MB |

### 6.1 이 제품이 쓰는 FastAPI 엔드포인트

`docs/products/_platform-core/AI_ARCHITECTURE.md:149-158` 중 study-note가 쓰는 것과 제품 전용 그래프·확장이다.

| 엔드포인트 | 호출자 | 인증 | study-note 사용 |
|---|---|---|---|
| `POST /v1/chat/completions` | Dify 질문 분류 LLM 노드 | 내부 키 | `model` 값을 기능 키(`dify.aux`)로 받아 라우팅(제안, 공용 ai-service 확인 필요, 06장 C-7). 조직 데이터 금지 |
| `POST /tools/answer` | Dify HTTP 노드 | 내부 키 + 대화 매핑 | 모드 `notes`: 매핑된 org의 과목(`subject_id`)인지 확인 → 컬렉션 `rag:s-<sid>`와 `wiki:s-<sid>` 검색(`match_ai_chunks`) → `chat` 모델 → compliance 후처리. assistant `ai_messages` 행(본문, citations, 제공자, 토큰)을 FastAPI가 쓴다 |
| `POST /tools/answer-direct` | Next.js(Dify 장애) | 서명 토큰 scope `chat rag wiki` | `/tools/answer`와 같은 처리 |
| `POST /graphs/notes.organize/runs`, `GET /graphs/runs/{id}` | Next.js | 서명 토큰 scope `graph:notes.organize`, `jti` 1회 | 노트 정리 시작(4.1절 계약), 상태 조회(Next.js는 RLS로 직접 읽으므로 `GET`은 점검용) |
| `POST /rag/ingest` | Next.js | 서명 토큰 scope `rag` | 노트·교재 색인(컬렉션 `rag:s-<sid>`, 임베딩 `notes.knowledge`) |
| `POST /wiki/lint`, `GET /wiki/pages/{slug}`, 페이지 저장 | Next.js | 서명 토큰 scope `wiki` | 위키 점검, 읽기, 사용자 편집 저장(저장 엔드포인트는 코어 목록에 없어 C-7로 요청) |
| `DELETE /products/notes/documents/{id}`, `POST /products/notes/subjects/{sid}/purge`, `POST /products/notes/quiz/grade` | Next.js | 서명 토큰 scope `rag` / `rag wiki` / `chat` | 제품 확장(공용 ai-service의 `app/ai/products/notes/`). 문서 삭제(청크 삭제), 과목 purge, 단답 채점 |

쓰지 않는 것: `POST /tools/graph/{name}`(Dify에서 그래프를 실행하지 않는다), `POST /rag/search`(Next.js가 직접 검색하지 않는다), `POST /dify/retrieval`(제품 공통 지식이 없고 모든 지식이 사용자 조직 데이터라서 Dify 외부 지식 API를 쓰지 않는다), `POST /wiki/ingest`(위키 갱신은 그래프 `link` 노드가 한다).

### 6.2 Dify Chatflow 계약 (`notes-chat`)

| 항목 | 값 |
|---|---|
| 앱 | `notes-chat`(Chatflow) 1개, 앱 키 `DIFY_APP_KEY_NOTES`(Next.js 서버 전용). 정의는 `infra/dify/notes-chat.yml`(키 없음) |
| 호출 | Next.js `POST {DIFY_API_URL}/chat-messages`(스트리밍), `user`=`dify_user`, 두 번째 턴부터 `conversation_id`=`dify_conversation_id`, `query`=마스킹된 메시지 |
| 입력 변수 | `platform_conversation_id`(필수, 플랫폼 대화 UUID), `subject_id`(선택, 8자리 16진수). 서명 토큰, org, 표시 이름은 넣지 않는다(`docs/products/_platform-core/SECURITY_BASELINE.md:285`). DOC_TEMPLATE의 `platform_token` 입력은 코어 결정(대화 매핑)으로 대체됐다 |
| 노드 | 시작 → 질문 분류(LLM 노드, 모델 공급자 = FastAPI OpenAI 호환, model `dify.aux`: `notes`/`quiz`/`other`) → 분기 `notes`: HTTP 요청 노드 → 답변 / 분기 `quiz`: 고정 답변("퀴즈는 노트 상세의 [퀴즈 풀기]에서 풀 수 있습니다") / 분기 `other`: 고정 답변("공부한 내용에 대해 질문해 주세요") |
| HTTP 요청 노드 | `POST {AI_SERVICE_URL}/tools/answer`, 헤더 `X-Internal-Key`(Dify 환경 변수의 비밀 `DIFY_INTERNAL_API_KEY`), 본문 `{ platform_conversation_id, dify_user: sys.user, query: sys.query, subject_id, mode: "notes" }`, 타임아웃 30초 |
| HTTP 응답 | `{ answer, citations: [{ type, id or slug, title }], no_source: boolean, general_explanation: boolean, fallback: boolean, usage: { provider, model, input_tokens, output_tokens } }` |
| 출처 | FastAPI가 `ai_messages.citations`를 기록한다 |
| 첫 표시 지연 | HTTP 노드가 전체 답을 돌려준 뒤 표시되므로 그동안 "근거를 찾는 중" 상태를 보인다 |
| 대화 이력 | Dify 보관 30일, 플랫폼 정본은 `core.ai_messages` |
| 장애 | Dify 5xx·10초 무응답 → `/tools/answer-direct`. Dify 복구 후 새 대화로 시작 |
| 확인 | 노드 이름과 입력 변수 동작은 설치한 Dify 버전 문서로 구현 시 확인(`docs/products/_platform-core/AI_ARCHITECTURE.md:71`) |

## 7. 오류 코드

| SQLSTATE | 의미 | HTTP | 사용자 문구 |
|---|---|---|---|
| `NT001` | 상태 전이 위반(정리 중 원문 수정 포함) | 409 | 정리 중에는 원문을 바꿀 수 없습니다 |
| `NT002` | 일지에 이미 활성 실행 | 409 | 이 일지는 정리 중입니다 |
| `NT003` | 종료된 실행/단계에 쓰기 | 409 | 이미 끝난 정리입니다 |
| `NT004` | 플랜 한도 초과(입력 길이, 모델 등급) | 422 | 선택한 모델/길이는 현재 플랜에서 사용할 수 없습니다 |
| `NT005` | 일일 전체 예산 소진 | 503 + `Retry-After` | 오늘 사용량이 가득 찼습니다 |
| `NT006` | 조직 동시 실행 한도 | 429 | 동시에 정리할 수 있는 개수를 넘었습니다 |
| `CR001` | 크레딧 부족 | 402 | 크레딧이 N 부족합니다 |
| `42501` | 권한 없음 | 403 | |
| `P0002` | 대상 없음 | 404 | |
| `22023` | 인자 오류(비활성 모델 등) | 422 | |
| `PM001`/`PM409` | 결제 금액 불일치(Phase 2) | 409 + 운영 알림 | 결제를 확인하지 못했습니다 |
| 단계 error_code | `rate_limited`, `model_unavailable`, `provider_error`, `network`, `empty_response`, `bad_format`, `timeout`, `aborted` | 단계 상태로 전달 | 02장 5절, 03장 5절 |
| `AI001` | 플랫폼이 강제한 오픈소스 범위를 해제하려 함(운영 도구에서만 발생. 강의 STT `lecture_note` 포함) | 403 | |
| `AI002` | 국외 이전 동의 없이 국외 제공자를 체인에 넣으려 함(운영 도구에서만 발생. 제품 화면은 `set_ai_routing`을 부르지 않는다) | 403 | "AI 처리 방식에서 국외 이전 동의가 필요합니다" |
| 앱 코드 `AI_UNAVAILABLE` | 체인의 모든 제공자 실패(선차감 환불 완료) | 503 | "AI가 응답하지 못했습니다. 크레딧은 환불되었습니다" |
| 앱 코드 `AI_PLAN_LIMIT` | 과목·문서·글자 수·강의 시간 등 플랜 한도 초과 | 422 | "현재 플랜의 한도를 넘었습니다" |
| 앱 코드 `AI_BUSY` | 조직당 활성 그래프 2건 초과 | 429 | "정리 중인 작업이 끝난 뒤 다시 시도하세요" |
| 앱 코드 `AI_CONVERSATION_CLOSED` | 닫힌 대화 또는 대화당 50턴 초과 | 409 | |
| 앱 코드 `AI_DAILY_LIMIT` | 하루 채팅 턴 상한 | 429 | "오늘 질문 횟수를 모두 사용했습니다" |
| 앱 코드 `UPLOAD_RIGHTS_REQUIRED` | 자료 사용 권한 확인 누락 | 403 | |
| 앱 코드 `DOC_CONTENT_DUPLICATE` | 같은 내용(`content_hash`) 문서 | 409 | |
| 앱 코드 `QUIZ_NOT_FOUND` | 퀴즈가 없거나 다른 조직의 실행 | 404 | |
| 앱 코드 `VOICE_CONSENT_REQUIRED` | 음성 처리 고지 미확인 | 403 | |
| 앱 코드 `LECTURE_NOTICE_REQUIRED` | 강의 녹음 고지 미확인 또는 고지문 버전 불일치 | 403 | "녹음 고지를 확인해 주세요" |
| 앱 코드 `VOICE_TOO_LONG` | 60초(음성 질문) 또는 허용 강의 시간·5MB(음성 질문)·50MB(조각) 초과 | 413 | |
| 앱 코드 `LECTURE_CHUNK_FAILED` | 강의 조각 STT 실패(그 조각 환불 완료) | 502 | "이 구간을 변환하지 못했습니다. 다시 시도하세요" |
| 앱 코드 `CONSENT_VERSION_MISMATCH` | 고지문 버전이 서버 값과 다름 | 409 | |
| 앱 코드 `INTERNAL_KEY_INVALID` | 워커 키 또는 Dify 내부 키 불일치 | 401 | |
| FastAPI `AI_TOKEN_INVALID` | 서명, `aud`, scope, 만료, `jti` 재사용 | 401 | |
| 앱 코드 `WIKI_VERSION_CONFLICT` | 위키 저장 시 `expected_version`이 현재 버전과 다름(`docs/products/_platform-core/LLM_WIKI.md:31`) | 409 | "다른 곳에서 먼저 수정되었습니다" |
| `JB002` | 이미 실행 중인 잡 취소 | 409 | "이미 정리를 시작해 취소할 수 없습니다" |

## 8. 인증 단계 Route Handler (2026-10-14 추가, 확정 결정 22)

정본은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2장, 3.2절, 7.2.3절이다. 아래 경로는 `/api/notes/*`가 아니므로 1절의 `requireSession('notes')` 규칙 대상이 아니다(로그인 전 경로). 단계 분기(`AUTH_MODE`, 제공자 목록)를 읽는 Route Handler는 이 절의 경로뿐이다.

| 메서드 경로 | 단계 | 입력 | 처리 | 출력 | 오류 | 작업 |
|---|---|---|---|---|---|---|
| POST `/api/dev/login` | A(로컬 전용) | `{ persona: 'owner' \| 'admin' \| 'member' \| 'viewer' \| 'outsider' \| 'no_app' \| 'suspended' \| 'ops' \| 'unverified' \| 'low_credit', next?: string }`(zod, 05장 10절 키만) | `isMockAuthAllowed()` 확인 → 쿠키 세션 서버 클라이언트로 `signInWithPassword(<페르소나 이메일>, DEV_SEED_PASSWORD)` → `finishLogin('notes', next)` | 303 → 반환 경로 | 판정 거짓이면 404(존재 자체를 숨긴다). 시드 안 된 페르소나 400 "시드 스크립트를 먼저 실행하세요". 레이트 리밋 대상 아님(로컬 전용) | NT-06-006 |
| POST `/api/dev/logout` | A(로컬 전용) | 없음 | `signOut` | 303 → `/login` | 판정 거짓이면 404 | NT-06-006 |
| GET `/auth/callback` | B·C | `code`, `next?`, `error?` | `finishLogin` 앞에 코드 교환: (1) `exchangeCodeForSession`(PKCE, `@supabase/ssr`) (2) `session_context('notes')` 1회 (3) `entitled=false`이고 앱 `signup_policy`가 open이므로 `rpc('bootstrap_app_for_org', { p_app_id: 'notes' })` 1회 후 재조회(모놀리스는 가입 트리거가 자동 부트스트랩해 아무 일 없음) (4) `status` 분기(suspended 403) (5) 약관 동의 기록이 없으면 `/onboarding/terms`(03장 7.3절) (6) `next`가 `/`로 시작하고 `//`·`@`·`\`가 없을 때만, 아니면 `/app`. origin은 `NEXT_PUBLIC_APP_URL` 고정 (7) 감사 `auth.login`(provider, 첫 로그인 여부, 토큰·코드 없음) | 302 | `/login?error=callback`(코드 없음·재사용·만료·교환 실패), 프로필 없음 → 로그아웃 후 `/login` | NT-06-053 |
| POST `/api/onboarding/terms` | B·C(A 시드 페르소나는 동의 기록이 있어 거치지 않는다, 03장 7.3절) | `{ terms_version, privacy_version, age_over_14: true }` | `requireSession('notes')`(이메일 인증 불필요) → `write_audit('notes_consent.terms')`(제안) | `{ ok }` → 클라이언트가 `/onboarding/ai`로 | 400 `age_over_14` 누락, 409 `CONSENT_VERSION_MISMATCH` | NT-06-053 |
| GET `/auth/naver/start` | C2 브리지 경로만 | `next?` | 32바이트 state를 HMAC(`AUTH_BRIDGE_SECRET`) HttpOnly·Secure·SameSite=Lax 쿠키(10분)에 넣고 네이버 authorize로 302. 레이트 리밋 `auth:naver:<ip 해시>` 10회/10분 | 302 | 429 | NT-06-055 |
| GET `/auth/naver/callback` | C2 브리지 경로만 | `code`, `state` | 쿠키 state 상수 시간 비교·삭제 → 토큰 교환 → `/v1/nid/me`(`resultcode='00'`) → `core.auth_identity_links` 조회 → 연결 있으면 매직링크 `verifyOtp`로 세션, 없으면 새 사용자 생성 + 링크 행, 같은 이메일 다른 사용자면 거부 → `finishLogin` | 302 | `/login?error=state`, `/login?error=email_in_use`, `/login?error=callback` | NT-06-055 |

`/auth/naver/*`는 C2 스파이크(`AUTH_ROADMAP.md` 7.2.2절)가 `custom:naver`를 택하면 만들지 않는다(그때는 `/auth/callback` 하나로 끝난다). 네이버 토큰은 저장하지 않는다.

### 8.1 인증 오류 코드

| 코드 | 위치 | HTTP/동작 | 사용자 문구 |
|---|---|---|---|
| (없음, 404) | `/api/dev/*`에서 `isMockAuthAllowed()` 거짓 | 404 | - |
| `DEV_PERSONA_NOT_SEEDED` | `/api/dev/login` | 400 | "시드 스크립트를 먼저 실행하세요"(로컬 전용) |
| `error=callback` | `/auth/callback`, `/auth/naver/callback` | 302 → `/login?error=callback` | 03장 7.2절 |
| `error=state` | `/auth/naver/callback`(브리지) | 302 → `/login?error=state` | 03장 7.2절 |
| `error=email_in_use` | `/auth/naver/callback`(브리지) | 302 → `/login?error=email_in_use` | 03장 7.2절 |
| `email_not_verified` | 기존 1절(정리 실행 계열) | 403 | 단계와 무관하게 같다 |
