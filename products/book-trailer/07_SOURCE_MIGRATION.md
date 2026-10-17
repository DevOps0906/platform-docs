# 07 원본 이식과 폐기: NOMAD Book Trailer

작성일 2026-10-15. NOMAD Book Trailer는 신규 제품이라 전용 원본 저장소가 없다(`README.md` 2장). 이 장의 "원본"은 `README.md` 3장의 이식 원천 6개다: sceneflow(설계), toon-factory(설계·SQL), flora-publishing(설계, 연동 대상), nomad-docs(설계), NOMAD Shorts Maker(코드, 리뷰로만 참조), Toon-Factory(기획, 리뷰로만 참조). 이식은 개발 단계에서 새 앱 저장소에 "새로 작성하며 패턴을 참고"하거나 "데이터·규칙을 복사 후 수정"하는 두 방식뿐이고, 원천 폴더와 원천 제품 문서는 수정하지 않는다(5절).

근거 표기: 분석 = `docs/products/00_MERGE_ANALYSIS.md`(아래 "분석:줄"), 리뷰 = `docs/reviews/<이름>.md:줄`, 이 폴더 문서는 파일 이름만 쓴다. 대상 위치의 `web/`, `api/`, `orch/`, `rend/`, `comp/` 약어는 `06_AGENT_PLAN.md` 머리말과 같다.

AI 관련 원천 자산 점검: 원천의 AI 사용은 sceneflow 설계의 이미지(fal)·TTS(ElevenLabs·오픈소스) 경로와 LangGraph 그래프(`docs/products/sceneflow/02_ARCHITECTURE.md:176`, `:210-238`), NOMAD Shorts Maker 원본의 AI 클라이언트 산재(`docs/reviews/NOMAD_Shorts_Maker.md` 5장 #10)다. 원본 코드 호출 경로는 하나도 옮기지 않고 ai-service 라우터(확정 결정 17)와 오케스트레이터 단계로 새로 작성한다. 원고 분석, 브리프·인용 원고 대조, 장르 트레일러 문법, 표지 팔레트 추출, 구매 링크 추적, Remotion 컴포지션은 원천에 없어 모두 신규다.

## 1. 원본별 자산 분류

상태는 원천 자산의 구현 상태(동작/부분/목업/기획만), 처리는 이식(복사 후 수정)/참고(패턴만, 새로 작성)/폐기다(`docs/products/_platform-core/DOC_TEMPLATE.md` 2.8절).

### 1.1 sceneflow (설계, 미디어 파이프라인 패턴 베이스)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| 이미지 경로(fal Flux, 안전 검사, 모델 id 서버 상수, 코어 라우팅 밖) | 기획만 | 참고 | `orch/src/steps/image/` | `docs/products/sceneflow/02_ARCHITECTURE.md:22`, `:176` |
| 같은 목소리 규칙(첫 결과로 제공자·보이스 고정, 같은 엔진 재시도만, 샘플 대체 없음) | 기획만 | 이식(규칙 문장 그대로, 대상 테이블만 `trailers`) | `orch/src/steps/tts/`, `trailer.trailers.voice`(jsonb) | `docs/products/sceneflow/02_ARCHITECTURE.md:227-238` |
| compliance 노드(그래프 마지막, FAIL 차단·WARN 확인) | 기획만 | 참고(규칙 사전은 출판 도메인으로 새로 작성) | `api/app/ai/compliance/trailer.py`, `packages/trailer-rules/` | `docs/products/sceneflow/02_ARCHITECTURE.md:214` |
| 고객 승인 링크(토큰 sha256, 만료, 로그인 없는 재생·결정) | 기획만 | 참고 | `trailer.reviews`, `web/src/app/review/` | `docs/products/sceneflow/01_PRD.md` 3.1절 VD-F-123 |
| 오케스트레이터 잡 토큰(running 잡에 묶인 토큰을 내부 경로에서 발급) | 기획만 | 참고(`AI_ARCHITECTURE.md` 1장 잡 토큰 규칙, `parse` scope는 R-T4로 추가) | `orch/src/core/token.ts` | `docs/products/sceneflow/02_ARCHITECTURE.md:58-80` |
| 크레딧 단가 구조(서버 상수가 정본, DB는 받은 값만 차감), 이미지 3·업로드 1 | 기획만 | 참고 | `web/src/server/pricing.ts` | `docs/products/sceneflow/01_PRD.md:175`, `:184`, `:189` |
| sns-uploader(YouTube 업로드) | 기획만 | 참고(소비자로 호출만, 소유는 sceneflow) | `orch/src/steps/upload/` | `docs/products/_platform-core/SHARED_MODULES.md` 11장 |
| BullMQ FlowProducer 단계 체인, Python 미디어 워커 | 기획만 | 폐기 | - | TS-01 |
| FFmpeg 단일 합성 엔진 결정과 "Remotion 제외" | 기획만 | 폐기(이 제품은 반대 결정) | - | TS-02 |
| Track A~D, 다채널 예약·분석, 레이더 | 기획만 | 폐기(범위 밖, Phase 2 "sceneflow로 보내기") | - | TS-03 |

### 1.2 toon-factory (설계, SQL 검증 완료)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| 컷 저장 방식(낙관적 동시성 `revision`, 충돌 시 최신본 재조회) | 기획만(SQL 검증) | 참고 | `trailer.save_scene`(`TR409`) | `docs/products/_supabase-modular/migrations/2000_toon.sql:476-497` |
| 음악·에셋 카탈로그 라이선스 근거 CHECK(근거 없으면 공개 불가) | 기획만(SQL 검증) | 이식(컬럼 구조와 CHECK 방식) | `trailer.music_tracks`(`music_tracks_publish_license_check`) | `2000_toon.sql:94-115` |
| 비공개 원본 버킷 + 공개 미리보기 버킷 분리 | 기획만 | 참고 | `trailer-catalog`, `trailer-previews` 버킷 | `docs/reviews/Toon-Factory.md:46` 차단 설계 |
| 서버 렌더 + 플랜으로 워터마크 결정(요청 입력 무시) | 기획만 | 참고 | `trailer.start_render`, `rend/src/handlers/render/` | `docs/reviews/Toon-Factory.md:45` 차단 설계 |
| 컷 단위 재생성(이전 에셋 보존) | 기획만 | 참고 | `trailer.scene_assets.status='superseded'` | `docs/products/toon-factory/01_PRD.md` |
| Fabric.js 캔버스·레이어 편집기, 말풍선, 표정 교체 | 기획만 | 폐기 | - | TS-04 |
| LoRA 화풍 학습 | 기획만 | 폐기 | - | TS-05 |
| 캐릭터 엔진 | 기획만 | 보류(Phase 2 연계, TR-F-131) | - | `01_PRD.md` 2장 |

### 1.3 flora-publishing (설계, 업로드·그래프 패턴과 연동 대상)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| 업로드 계약(서명 URL → 완료 검증, 20MB, 매직바이트, 서버 생성 경로) | 기획만 | 참고(형식에 epub 추가) | `web/src/server/uploads/`, `web/src/app/api/uploads/` | `docs/products/flora-publishing/01_PRD.md:96` |
| LangGraph 그래프 패턴(노드 마지막 compliance, 결과는 service RPC 1회 저장) | 기획만 | 참고 | `api/app/ai/graphs/trailer_*.py` | `docs/products/flora-publishing/02_ARCHITECTURE.md:302-321` |
| 탈퇴·삭제(30일 유예 → purge) | 기획만 | 참고 | `orch/src/steps/purge/` | `docs/products/flora-publishing/01_PRD.md:107` |
| FLORA 원고 md 내보내기 | 기획만 | 연동(소비만, P1) | `web/src/server/import/` | TR-F-015, `05_DATA_MODEL.md` 6절 |
| 판형·표지 디자인·페르소나 60종·ePub 생성·TTS 낭독·3D 책 소재 | 기획만 | 폐기 | - | TS-06 |

### 1.4 nomad-docs (설계, 교훈)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| "결정적 값은 서버가 계산하고 LLM은 해석만" 원칙 | 기획만 | 참고(팔레트 추출·글자 노출 시간·장면 길이 합계·인용 대조에 적용) | `rend/src/handlers/kit/`, `comp/src/tokens/`, `api/app/ai/products/trailer/quotes.py` | `docs/products/nomad-docs/07_SOURCE_MIGRATION.md` 1.4절 |
| RFC 5987 한글 파일명 | 동작(flora v1에서 이식된 설계) | 이식 | `web/src/app/api/renders/[id]/download/` | `docs/products/nomad-docs/07_SOURCE_MIGRATION.md` 1.2절 |
| 파서 라이브러리 선택 교훈(pdf, docx, md, txt) | 기획만 | 참고(epub 추가) | `api/app/ai/products/trailer/parsers/` | 같은 문서 1.2절 |
| 진행 표시는 서버 보고 값만(시간 기반 가짜 진행률 금지) | 기획만 | 참고 | `RenderMonitorRow`, 실행 진행 | `docs/products/nomad-docs/CLAUDE.md` 2장 |
| 오케스트레이터를 `core.jobs` 단일 큐로 두는 단순 구조 | 기획만 | 참고 | `orch/` | `02_ARCHITECTURE.md` 1절 |

### 1.5 NOMAD Shorts Maker (코드, 약 35%, 리뷰로만 참조)

코드는 sceneflow가 소유한다(`docs/products/sceneflow/README.md:32`). 이 제품은 그 코드를 직접 복사하지 않고 리뷰가 지적한 결함만 차단 설계로 가져온다(`README.md` 2.1절).

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `lib/media/*`(켄번스, 레이어 합성, 워터마크) | 동작 | 참고(움직임 파라미터 교훈만. 구현은 Remotion 모션 프리셋으로 새로 작성) | `comp/src/motion/` | `docs/reviews/NOMAD_Shorts_Maker.md:21`, `docs/reviews/Toon-Factory.md` 5장 #10 |
| `lib/platforms/youtube.ts` 업로드 | 부분(메모리 버퍼) | 폐기(sns-uploader 소비) | - | TS-07 |
| Mock 로그인(localStorage), `x-internal-call`, user 기반 마이그레이션, 플랜 정의 3벌 | 동작(결함) | 폐기 | - | TS-08, 4절 |

### 1.6 Toon-Factory (기획만, 리뷰로만 참조)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| "첫 진입 5분 완성 경험" 목표 | 기획만 | 참고(KPI "첫 트레일러 20분", 마법사·샘플 책) | `01_PRD.md` 7장, TR-06-034 | `docs/reviews/Toon-Factory.md` 5장 #13 |
| 공개 작품 페이지 + JSON-LD | 기획만 | 참고(샘플 페이지 VideoObject) | TR-06-044 | 같은 리뷰 5장 #14 |
| 브라우저 FFmpeg.wasm 렌더 | 기획만 | 폐기 | - | TS-09 |

## 2. 이식 자산 상세

"참고" 자산은 코드를 복사하지 않고 새로 작성하므로 아래에는 실제로 규칙·데이터를 옮기는 자산과, 참고하되 원천과 반드시 달라야 하는 점이 있는 자산을 적는다.

| 자산 | 수정할 점 |
|---|---|
| sceneflow 같은 목소리 규칙 | 고정 시점이 "첫 내레이션 성공"이고 고정 값은 `trailers.voice`(`provider`, `voice_id`, `fixed_at`, 서버만 쓴다). 장면 재생성·전체 다시 녹음도 같은 값. 다른 목소리 결과는 `finish_run`이 22023으로 거부. 작가 목소리 클론은 Phase 2(D-9, 동의 녹음) |
| sceneflow 이미지 경로 | 스타일 고정이 추가된다: 브랜드 키트 팔레트 → 프롬프트 색 지시, 문법별 스타일 프리셋 접미어, 트레일러 고정 seed(`02_ARCHITECTURE.md` 5.4절). 실존 인물·특정 작가 화풍 금지어를 compliance가 막고 인물은 실루엣·소품 중심(08장 8장) |
| sceneflow compliance | 규칙 사전을 출판 도메인으로: 근거 없는 판매·순위·수상, 보장, 가상 독자 후기, 의료·투자 효능 단정, 도서정가제 위반 할인(정가 대비 15% 초과), 실존 인물 이름 이미지 프롬프트, 스포일러 수준 위반(`01_PRD.md` 6.5절). 한글 경계 `\b` 금지(4절) |
| sceneflow 고객 승인 | 승인 대상이 렌더(1~5개)이고 결정은 승인·수정 요청(1,000자). 승인되면 `trailers.status=approved`. publisher 플랜만 |
| toon-factory 컷 저장 | 컷 대신 장면. `scenes.revision` 낙관적 동시성(`save_scene`의 `p_expected_revision`), 엔드카드 보호(`TR007`), 위치 재정렬은 `reorder_scenes` 한 번에 |
| toon-factory 라이선스 CHECK | 음악은 `license_verified_at`, `license_verified_by`, `commercial_use_allowed`가 없으면 `status='published'` 불가(`license_source`, `license_ref` 필수). 서체는 OFL 8종만(08장 4.2절), 템플릿 그래픽은 자체 코드라 라이선스 행이 없다 |
| flora-publishing 업로드 계약 | 형식 5종(pdf, epub, docx, md, txt), 붙여넣기 600,000자, 권리 확인(감사) 없으면 분석 불가(`TR003`), 원문은 Storage에만 두고 DB에는 해시·글자 수 |
| flora-publishing 그래프 패턴 | 그래프 4종(`trailer.digest`, `brief`, `storyboard`, `meta`), 결과 저장은 오케스트레이터가 아니라 ai-service가 `finish_run`으로 1회, 사람 승인 interrupt 없음(사용자 행동마다 별도 실행) |
| nomad-docs 결정성 원칙 | 팔레트는 CIELAB k-means(k=8, seed 7, 08장 4.1절), 글자 노출 시간은 공식(08장 7.3절), 장면 길이 합계는 그래프가 아니라 서버 검증(±10%), 인용은 원고 문자열 대조 통과만 저장 |
| RFC 5987 파일명 | 파일명은 `<책 제목>_<포맷>_<렌더 번호>.<ext>`(제안), 제목은 서버가 정규화(경로 문자 제거) |

## 3. 폐기 목록과 사유

`README.md` 3장 "버리는 것" 열을 빠짐없이 옮기고, 이식 원천에서 이 제품과 관련된 폐기 항목을 더했다. ID는 이 제품 고유(`TS-##`)다.

| ID | 항목 | 원천 | 출처 | 사유 | 대체 |
|---|---|---|---|---|---|
| TS-01 | BullMQ FlowProducer 단계 체인, Redis, Python 미디어 워커 | sceneflow | `docs/reviews/NOMAD_Shorts_Maker.md:133`, `docs/products/sceneflow/02_ARCHITECTURE.md` 4장 | 이 제품은 단계가 사용자 행동마다 끊기고 동시 잡이 적다. 큐 인프라를 하나 더 운영할 이유가 없다 | `core.jobs` + 오케스트레이터 1개 + 렌더러 1개(02장 4절) |
| TS-02 | FFmpeg 단일 합성 엔진, "Remotion 제외" 결정 | sceneflow | `docs/products/sceneflow/07_SOURCE_MIGRATION.md:91`, `docs/products/sceneflow/01_PRD.md:91` | sceneflow는 원본 영상 편집이 중심이라 FFmpeg가 맞다. 이 제품은 텍스트·한글 조판·브랜드 토큰이 중심이라 React 컴포지션이 맞다(D-2). 두 결정은 서로 모순이 아니라 제품별 선택이다 | Remotion 4.0.x 렌더러(라이선스: 직원 3명 이하 무료, 그 밖은 Company License) |
| TS-03 | Track A~D, 다채널 예약·분석, 레이더 | sceneflow | `docs/products/sceneflow/01_PRD.md` 2장 | 범위 밖 | YouTube 직접 업로드만(P1), 다채널은 Phase 2 "sceneflow로 보내기"(D-10) |
| TS-04 | Fabric.js 자유 캔버스·레이어 편집, 말풍선, 표정 교체 | toon-factory, Toon-Factory | `docs/reviews/Toon-Factory.md` 5장 #5, #7 | 트레일러는 자유 배치보다 문법·템플릿 일관성이 품질을 결정한다. 자유 편집은 이중 상태 원천 문제를 다시 만든다 | 장면 컴포넌트 8종 + 속성 편집(08장 9장) |
| TS-05 | LoRA 화풍 학습 | Toon-Factory | `docs/reviews/Toon-Factory.md:49` | 학습 데이터·GPU·검수 기준이 없고 일정 위험이 가장 크다 | 프롬프트 프리셋 + 팔레트 + 고정 seed(02장 5.4절) |
| TS-06 | 판형·표지 디자인·페르소나 60종·ePub 생성·TTS 낭독·3D 책 소재 | flora-publishing | `docs/products/flora-publishing/01_PRD.md` 2장 | 책을 만드는 기능은 flora-publishing 소유. 이 제품은 이미 나온 책을 홍보한다 | FLORA 가져오기(P1) |
| TS-07 | 메모리 버퍼 YouTube 업로드 | NOMAD Shorts Maker | `docs/reviews/NOMAD_Shorts_Maker.md` 5장 #12 | 큰 파일에서 메모리 초과 | 공용 sns-uploader(스트리밍 resumable) |
| TS-08 | localStorage Mock 로그인, `x-internal-call` 우회, user 기반 스키마, 플랜 정의 3벌 | NOMAD Shorts Maker | `docs/reviews/NOMAD_Shorts_Maker.md:81`, `:83`, 5장 #6 | 인증 우회, 권한 위조, 플랜 불일치 | `AUTH_ROADMAP.md` 2장 Mock 로그인, 함수 직접 호출, org 기준 스키마, 플랜은 코어 엔타이틀먼트 + `web/src/server/pricing.ts` 하나 |
| TS-09 | 브라우저 FFmpeg.wasm 렌더 | Toon-Factory | `docs/reviews/Toon-Factory.md:45` | 워터마크 제거, 무료 MP4 생성을 서버가 막을 수 없다 | 서버 렌더러만 파일 생성, 브라우저는 Remotion Player 미리보기(다운로드 경로 없음) |
| TS-10 | 사용자 모델 선택, LLM SDK 직접 연동 | NOMAD Shorts Maker | `docs/reviews/NOMAD_Shorts_Maker.md` 5장 #10 | 키 분산, 단가 설명 불가 | ai-service 라우터 기능별 체인(02장 5.1절), 기능별 정액 단가 |
| TS-11 | 대시보드 더미 배열, 난수 성장률 | NOMAD Shorts Maker | `docs/reviews/NOMAD_Shorts_Maker.md` 5장 #9 | 허위 수치 | 구매 링크 클릭 실집계(`link_clicks`), 랜딩 수치 표시 금지 |
| TS-12 | Suno 음악 생성 | sceneflow | `docs/products/sceneflow/01_PRD.md` D-8 | 공식 API 미확인, 저작권 불명확 | 라이선스 검증 카탈로그 곡, 사용자 업로드(권리 확인), Phase 2 재검토(TR-F-135) |

## 4. 복사 금지 결함

`docs/products/_platform-core/SECURITY_BASELINE.md` 14장 중 이 제품에 해당하는 항목(앞 13행)과 이식 원천 리뷰·이 제품 설계에서 찾은 고유 결함(뒤 행). 14장 항목 중 해당 없음: "OVERRIDE 비밀번호·verify-admin API"(의료 데이터 없음), "프로필 없으면 admin·클라이언트 PageGuard"(Hospital 원천 없음), "전역 n8n API 키 프록시"(n8n 연동 없음).

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 크레딧 RPC EXECUTE 미회수 | `SECURITY_BASELINE.md` 14장, `docs/reviews/NOMAD_Shorts_Maker.md:78` | 브라우저에서 크레딧 지급 | 코어 RPC와 이 스키마 서버 RPC는 service_role만. 스모크가 사용자 호출 42501 확인(TR-06-002) |
| 비원자 크레딧 차감 | `SECURITY_BASELINE.md` 14장 | 동시 요청으로 음수 잔액 | `start_run`·`start_render` 한 트랜잭션 안 `consume_credits` |
| 웹훅 서명 미검증·선택적 검증 | `SECURITY_BASELINE.md` 14장, `docs/reviews/NOMAD_Shorts_Maker.md:79` | 위조 결제 | Toss 원시 본문 서명 검증 + `core.webhook_events` 멱등 |
| `customerKey = Date.now()`, orderId 파싱 | `SECURITY_BASELINE.md` 14장, `docs/reviews/NOMAD_Shorts_Maker.md:80` | 금액·대상 위조, 정상 결제 누락 | 코어 `payment_orders` 서버 생성, confirm 정본 |
| OAuth state 위조, 콜백 인증 결함 | `SECURITY_BASELINE.md` 14장, `docs/reviews/NOMAD_Shorts_Maker.md:82` | 타인 조직에 채널 연결 | `core.oauth_states` 서버 발급·1회 소비 |
| 토큰 평문 저장, 0키 폴백 | `SECURITY_BASELINE.md` 14장, `docs/reviews/NOMAD_Shorts_Maker.md:84` | 채널 계정 탈취 | `core.encrypted_credentials`, 키 없으면 기동 실패 |
| 세션 없는 백그라운드 작업이 RLS에 막혀 무동작 | `SECURITY_BASELINE.md` 14장, `docs/reviews/NOMAD_Shorts_Maker.md:85` | 장애 은폐 | 오케스트레이터·렌더러는 service_role, 서버 RPC는 anon 호출 시 42501 |
| `FOR ALL` 정책(셀프 업그레이드) | `SECURITY_BASELINE.md` 14장 | 자기 플랜 변경 | `FOR ALL` 0, 컬럼 단위 GRANT(05장 4절) |
| Pro 잠금해제, localStorage 플래그 | `SECURITY_BASELINE.md` 14장 | 유료 기능 무료 사용 | 서버 플랜 판정, 워터마크는 `start_render`가 결정 |
| RLS 정책 안 자기참조 재귀 | `SECURITY_BASELINE.md` 14장 | 전체 거부 또는 우회 | 정책은 코어 헬퍼(`is_org_member`, `has_org_role`, `has_entitlement`)만 |
| 인증 없는 공개 AI 프록시, CORS `*` | `SECURITY_BASELINE.md` 14장 | 키 도용, 비용 폭증 | `/api/ai/*`는 세션 + 서명 토큰 |
| 라우터 무인증, `dev-user` 우회 | `SECURITY_BASELINE.md` 14장 | 데이터 접근 | 모든 Route Handler 래퍼, 허용되는 Mock은 `AUTH_ROADMAP.md` 2장뿐(6절) |
| 실키 `.env` 커밋 | `SECURITY_BASELINE.md` 14장 | 키 유출 | CI 비밀 검사, 원천 `.env` 복사 금지(5절) |
| 한글 `\b` 경계 금지어 매칭 | `SECURITY_BASELINE.md` 14장 | 필터 무효 | 사전 매칭 + 단위 테스트(TR-06-023) |
| `x-internal-call` 같은 헤더 신뢰 | `docs/reviews/NOMAD_Shorts_Maker.md:81` | 인증 우회 | 내부 호출은 함수 직접 호출 또는 서명 토큰 |
| 브라우저 렌더·브라우저 다운로드 경로 | `docs/reviews/Toon-Factory.md:45` | 워터마크 제거 | 서버 렌더만, 미리보기 Player에 다운로드·우클릭 저장 경로 없음 |
| 공개 버킷에 유료 에셋 원본 | `docs/reviews/Toon-Factory.md:46` | URL 수집 | 원본 비공개 버킷, 미리듣기만 공개 |
| 라이선스 근거 없는 음악·서체·스톡 변형 재배포 | `docs/reviews/Toon-Factory.md:50` | 저작권 분쟁 | DB CHECK, OFL 서체만, 스톡 변형 없음 |
| 렌더 요청 입력으로 워터마크·AI 표시 결정 | 05장 7절 | 무료 사용자 워터마크 제거, AI 표시 누락 | `start_render`가 플랜·에셋 출처로 결정, `renders` 사용자 쓰기 불가 |
| 원고에 없는 문장을 인용으로 표시 | `01_PRD.md` 6.3절 | 저자·독자 기만, 저작권 | 인용은 원고 문자열 대조 통과만 저장, 80자·전체 300자 상한 |
| 원고 전문을 LLM에 매번 전송, 원고를 DB 컬럼에 저장 | `01_PRD.md` 6.1절 | 비용, 유출 범위 확대 | 원고는 Storage, 분석 1회 → 요약·청크(RAG), 이후 그래프는 요약과 검색 결과만 |
| 근거 없는 판매·순위·수상 문구, 정가 15% 초과 할인 표현 | `01_PRD.md` 6.5절 | 표시광고법, 도서정가제 | `trailer-rules` FAIL, 근거 입력 필드 |
| 실존 인물·특정 작가 화풍 이미지 프롬프트 | `01_PRD.md` 6.3절 | 초상권, 화풍 모방 분쟁 | compliance 차단, 인물은 실루엣·소품 |
| 같은 템플릿 반복 업로드(양산형) | `01_PRD.md` 6.6절 | YouTube 비진정성 콘텐츠 정책 위반 | 변주 규칙(08장 10장), 7일 3편 경고 |
| 다른 목소리로 장면 섞기 | `02_ARCHITECTURE.md` 5.3절 | 품질 붕괴 | 같은 목소리 규칙, 저장 거부 |
| 사용자 입력 파일명을 Storage 경로에 사용 | `docs/reviews/flora.md:71` | 경로 조작 | 서버 생성 `<org_id>/trailer/<purpose>/<uuid>.<ext>`, 원본 이름은 표시용만 |
| 렌더러의 무제한 외부 fetch | `docs/reviews/flora.md:72` | SSRF | 렌더 입력은 스냅샷의 Storage 경로만, 렌더러 네트워크는 Storage·Supabase만 허용 |
| 시스템 폰트·Windows 폰트 경로 의존 | `docs/reviews/flora.md:75` | 컨테이너에서 한글 두부 | OFL 8종을 이미지에 포함, 렌더 회귀 테스트(TR-06-047) |
| 시간 기반 가짜 진행률 | `docs/products/nomad-docs/CLAUDE.md` 2장 | 사용자 기만 | 렌더러가 보고한 프레임 진행률만 |
| 단계 동시 enqueue, placeholder 값, 즉시 done | `docs/reviews/NOMAD_Shorts_Maker.md:86` | 결과 없는 성공 | 실행 상태는 `finish_run`/`fail_run`만, 전이 트리거 |

## 5. 아카이브 절차

이 제품은 전용 원본 저장소가 없으므로 `archive/<원본>` 이동 대상이 없다. 이식 원천은 다른 제품의 소유이거나 공용 문서이므로 이 제품 작업이 옮기거나 지우지 않는다.

| 순서 | 작업 | 담당 |
|---|---|---|
| 1 | 아카이브 대상 없음을 확인한다. NOMAD Shorts Maker·Toon-Factory 원본 폴더의 아카이브는 각 소유 제품(sceneflow, toon-factory)의 07장 5절이 맡는다 | 해당 없음 |
| 2 | 원천 폴더·원천 제품 문서(`sceneflow/`, `toon-factory/`, `flora-publishing/`, `nomad-docs/`, `_platform-core/`, `_design-guide/`, `docs/reviews/`)를 읽기 전용으로 둔다. 필요한 변경은 06장 6절 공용 모듈 요청 또는 해당 제품 담당에게 요청한다. git으로 원천을 바꾸는 명령(checkout, reset, stash, add, commit)을 쓰지 않는다(`docs/products/_PRODUCT_AGENT_BRIEF.md`) | 모든 개발 에이전트 |
| 3 | 코드를 옮기는 자산은 2절의 규칙 문장, 라이선스 CHECK 구조, RFC 5987 파일명뿐이다. 원천의 `.env*`, `node_modules`, venv, 잡파일을 새 저장소로 복사하지 않는다 | TR-06-001, 029 |
| 4 | 키 재발급은 필요 없다. 모든 키를 새로 발급해 배포 플랫폼 비밀로만 둔다. 개발 중 원천 `.env` 값을 실수로 복사·커밋했다면 즉시 재발급하고 원천 소유 제품의 재발급 기록에 함께 남긴다 | TR-06-049(CI 비밀 검사), 사람 |
| 5 | zip 중복 정리 대상 없음 | 해당 없음 |
| 6 | 공용 ai-service·Dify·sns-uploader는 소비만 한다. Remotion 렌더러를 공용으로 승격할지는 R-T8 | 사람(운영) |

## 6. 인증 단계 관련 복사 금지 (확정 결정 22)

4절 표에 이어서 본다. 허용되는 Mock은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2장(로컬 Supabase 시드 계정으로 실제 JWT, `isMockAuthAllowed()` 가드, 배포 환경 404)뿐이다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| localStorage·쿠키 역할 Mock(`mock-auth.ts`, `nomad_role`, `nomad_plan`) | `docs/reviews/NOMAD_Shorts_Maker.md:83` | 권한 위조, 프로덕션 노출 | `AUTH_ROADMAP.md` 2장 Mock 로그인(TR-06-004), CI 금지 문자열(TR-06-049) |
| 콜백 `next` 무검증 연결 | `docs/reviews/Flora-v2.md:71` | 외부 리다이렉트 | `finishLogin` 화이트리스트(`AUTH_ROADMAP.md` 3.2절) |
| `SUPABASE_URL` 미설정 시 `dev-user` 반환 | `docs/reviews/flora.md:80` | env 누락이 인증 우회 | 기동 시 env 검증, `AUTH_MODE=mock`인데 판정이 거짓이면 기동 실패 |
| 기능 코드의 `if (mock)`·페르소나 이메일 분기 | `AUTH_ROADMAP.md` 0장, 2.5절 | 단계 전환 때 권한 경로가 달라짐 | 단계 분기는 `web/src/lib/auth/`·로그인 화면·콜백·`/api/dev/login`에만(02장 9절) |
| YouTube 채널 연결 OAuth를 로그인에 재사용, 같은 Google 클라이언트 공유 | `01_PRD.md` D-17 | 검토 실패·유출이 서로 번진다 | 로그인용·채널용 Google Cloud 클라이언트 분리, 서로 import 금지 |
| 외부 승인 링크 화면에 로그인 버튼·세션 생성 | `01_PRD.md` TR-F-071 | 링크 하나로 계정 접근 오해 | `/review/[token]`은 토큰 해시만 service RPC로 확인, 세션을 만들지 않는다 |
