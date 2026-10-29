# 07 원본 이식과 폐기: Toon Factory

작성일 2026-10-12. 원본 `Toon-Factory/`에는 기획 문서 3개만 있고 코드가 없다(`docs/reviews/Toon-Factory.md:4`). 그래서 "이식"은 주로 기획 개념과, 다른 워크스페이스 프로젝트의 참고 코드다.

AI 관련 원본 자산(2026-10-13 점검): 원본 `Toon-Factory/`의 AI 언급은 "AI 이미지의 캐릭터 일관성 한계"라는 문제 정의(`Toon-Factory/PRD.md:15`)와 "AI 하이브리드 에셋 파이프라인"(LoRA 화풍 통일, `Toon-Factory/Design.md:5`)뿐이다. 앞의 것은 "AI는 캐릭터를 그리지 않고 조립한다"는 설계 원칙(01장 J1)으로 이식하고, 뒤의 것은 이미 3절에서 폐기했다. 참고 프로젝트의 LLM·음성 코드는 `Nomad-BlogStudio/src/lib/ai/*`(OpenAI, TTS, Whisper, ElevenLabs를 직접 호출하나 큐가 미연결, `docs/reviews/Nomad-BlogStudio.md:17`, `:21`)와 `sellingstudio/lib/llm/openrouter.ts`, `app/api/generate/voice/route.ts`(타임아웃 없음, 크레딧 확인 없음, `docs/reviews/sellingstudio.md:42`, `:58`, `:75`)가 있으나 모두 폐기한다(아래 AI 추가 폐기 표). RAG, 위키, Dify, 일관성 검사, 음성 대화, 대사 음성, 영상 음성, 3D 히어로는 원본에 없어 모두 신규다.

## 1. 원본별 자산 분류

### 1.1 `Toon-Factory/`

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `PRD.md` 비전·대상·문제 정의(7~17줄) | 기획만 | 이식 | 01장 1절 | `Toon-Factory/PRD.md:7-17` |
| `PRD.md` 모듈형 캔버스(21줄) | 기획만 | 이식(디벨롭) | 01장 3.2절, 02장 2절 | 분석 `docs/products/00_MERGE_ANALYSIS.md:1296` |
| `PRD.md` 에셋 라이브러리(23줄) | 기획만 | 이식(수작업 카탈로그) | 01장 3.2절, 05장 2.1절 | 분석 `:1297` |
| `PRD.md` 숏폼 변환(25줄) | 기획만 | 이식(서버 렌더) | 01장 TN-F-033 | 분석 `:1299` |
| `PRD.md` GEO(27줄) | 기획만 | 폐기 | 3절 | 분석 `:1302` |
| `PRD.md` Freemium(31줄) | 기획만 | 이식(수치화) | 01장 4절 | 분석 `:1303` |
| `PRD.md` B2B 마스코트(33줄) | 기획만 | 폐기(Phase 3) | 3절 | 분석 `:1301` |
| `Design.md` 에셋 파이프라인 LoRA/자동 누끼(5줄) | 기획만 | 폐기 | 3절 | 분석 `:1301` |
| `PRD.md` "캐릭터 일관성 부족(AI 이미지의 한계)"(15줄) | 기획만 | 이식(원칙) | 01장 J1, TN-F-053(설정 일관성 검사) | 그림 일관성은 카탈로그 조립, 설정 일관성은 위키 대조로 다룬다 |
| `Design.md` 모듈 구성(7줄) | 기획만 | 이식 | 05장 2.1절 `assets.kind` | 리뷰 `:28` |
| `Design.md` 기술 스택(11~15줄) | 기획만 | 이식(Tailwind는 v4로 고정) | 02장 1절 | `Design.md:11`은 버전 없이 "Tailwind CSS"만 적었다. 이 제품은 Tailwind CSS v4(`DESIGN_SYSTEM.md:67`) |
| `Design.md` FFmpeg.wasm(17줄) | 기획만 | 폐기 | 3절 | 분석 `:1300` |
| `Design.md` `editorStore`, 레이어 필드(21~23줄) | 기획만 | 디벨롭 | 02장 2.2절 | 분석 `:1298` |
| `Design.md` 다크 모드, 3단 레이아웃(27~29줄) | 기획만 | 이식(색은 주제색으로 교체) | 03장 3.1절, 4.4절 | |
| `Claude.md` 개발 규칙(13~21줄) | 기획만 | 이식(모순 수정) | `CLAUDE.md` | 리뷰 #14~#16 |

### 1.2 참고 코드 (다른 프로젝트)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `NOMAD Shorts Maker/src/lib/media/ken-burns.ts`(`animate`, `imageToVideo`) | 동작(리뷰 기준) | 이식(인자 구성만) | `services/toon-worker/src/media/` | 리뷰 `docs/reviews/Toon-Factory.md:87` |
| `NOMAD Shorts Maker/src/lib/media/layer-composite.ts`(`composite`, `addBgm`) | 동작 | 이식(BGM 합성) | 같음 | 같음 |
| `NOMAD Shorts Maker/src/lib/media/watermark.ts`(`addLogoOverlay`) | 동작 | 참고(워터마크는 렌더러에서 이미지 단계로 넣음) | `packages/toon-doc/src/render/` | 같음 |
| `NOMAD Shorts Maker/src/lib/media/watermark.ts`(`remove`, delogo) | 동작 | 폐기 | - | 타인 워터마크 제거 기능은 이 제품에 필요 없고 권리 침해 소지 |
| `Nomad-BlogStudio` Next 16 + Supabase SSR 골격, shadcn ui | 동작 | 참고 | `apps/toon/` | 리뷰 `:86` |
| `Nomad-BlogStudio/supabase/migrations/*` | 결함 | 폐기 | - | RLS 결함(리뷰 `:86`) |
| `Nomad-BlogStudio/src/lib/ai/fal-image.ts` | 부분 | 폐기(코어 fal client 사용) | - | 키 없을 때 placeholder 폴백(리뷰 `:90`) |
| `sellingstudio/lib/image/fal.ts` | 동작 | 코어 fal client 기준 구현으로만 소비 | `_platform-core` | `SHARED_MODULES.md:228-249` |
| Toss 승인 흐름(BlogStudio, Shorts Maker `api/billing`) | 결함 있음 | 폐기(코어 toss 모듈 사용) | - | 리뷰 `:88` |
| Hospital 다크 대시보드 셸 | 동작 | 참고 안 함 | - | 03장 4.4절에서 다크 기본값 재검토 |
| `Nomad-BlogStudio/src/lib/ai/*`(OpenAI gpt-4o, TTS, Whisper, ElevenLabs 직접 호출) | 부분(큐 미연결) | 폐기 | - | 브라우저·Vercel에서 LLM·음성 키 직접 사용 구조. 이 제품은 FastAPI 라우터 + `packages/core-voice`(`docs/reviews/Nomad-BlogStudio.md:17`, `:21`) |
| `sellingstudio/lib/llm/openrouter.ts`, `app/api/generate/voice/route.ts` | 동작(결함 있음) | 폐기 | - | 크레딧 확인 없는 생성 라우트, 타임아웃 없음(`docs/reviews/sellingstudio.md:58`, `:75`) |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| `ken-burns.ts` | `child_process.execFile` 인자 배열 방식은 유지(셸 주입 없음). 입력 경로는 워커 임시 디렉토리의 서버 생성 파일명만. 이미지당 시간 고정(`durationPerImage`)을 컷별 `duration_ms` 배열로 바꾸고, 4:5 컷은 흐림 배경 채움 필터를, 웹툰 컷은 세로 팬(crop y 이동)을 추가. `audioPath` 필수를 선택으로(무음 트랙 생성) |
| `layer-composite.ts` | BGM 볼륨, 끝 1초 페이드아웃, `-shortest` 대신 영상 길이 기준 자르기. 출력에 `-metadata comment=ai_generated=...` |
| 렌더 골격 | 모든 FFmpeg 호출에 타임아웃(120초)과 heartbeat. 실패 시 `fail_job` |
| Next 골격 | `lib/supabase/*` 직접 구현 대신 `packages/core-db` 사용. `middleware.ts`가 아니라 로드되는 `src/proxy.ts`(`SECURITY_BASELINE.md:186`) |
| `editorStore` 개념 | `layers[]` 단일 배열 → series/episodes/cuts + `CutDoc` 판별 유니온, 히스토리는 immer patch |
| `Claude.md` 규칙 | "모든 코드 및 문서는 한국어" → 주석·문서·UI 문구는 한국어, 식별자는 영어(리뷰 #15). `@DESIGN.md` → 이 폴더 문서 경로(리뷰 #16). "기존 아키텍처 준수"(리뷰 #14)는 02장 2절을 기존 패턴으로 지정 |

## 3. 폐기 목록과 사유

분석 "폐기" 행 3개(`docs/products/00_MERGE_ANALYSIS.md:1300-1302`)에 든 항목 5개 전부.

| 항목 | 분석 근거 | 사유 | 재검토 |
|---|---|---|---|
| FFmpeg.wasm 브라우저 렌더 | `:1300` | 결과물이 클라이언트에서 만들어지면 워터마크·플랜 제한을 서버가 강제할 수 없다(리뷰 #1). COOP/COEP 헤더, 모바일 메모리, 인코딩 시간 문제(리뷰 #7) | Phase 2에 저해상도 미리보기 용도로만 검토 |
| LoRA 화풍 통일 | `:1301` | 학습 데이터·GPU·검수 기준이 없고 MVP 최대 지연 요인(리뷰 #5). 스톡 변형 시 라이선스 충돌(리뷰 #6) | Phase 3 B2B 마스코트와 함께 |
| 자동 누끼 | `:1301` | 카탈로그는 디자이너가 투명 PNG로 납품하므로 불필요. 운영자/사용자 기능 구분도 불명확(리뷰 #5) | Phase 2 AI 소품·캐릭터 시트의 배경 제거로 재도입 |
| B2B 마스코트 모듈화 셋업 | `:1301` | 핵심 편집 경험과 무관, MVP 범위 과다(리뷰 #13) | Phase 3 |
| GEO(구조화 데이터) | `:1302` | 결과물이 인스타·쇼츠로 반출되어 붙일 공개 페이지가 없다(리뷰 #9) | Phase 3 공개 작품 페이지(TN-06-040) |

AI 계층 도입(2026-10-13)으로 생긴 추가 폐기. 분석 "폐기" 목록 밖이라 따로 적는다.

| 항목 | 근거 | 사유 | 재검토 |
|---|---|---|---|
| 브라우저·Vercel·워커에서 LLM·음성 제공자 직접 호출 | `docs/reviews/Nomad-BlogStudio.md:17`, `docs/products/_platform-core/SECURITY_BASELINE.md:299` | 인증·과금 우회, 키 유출 | 없음 |
| AI가 캐릭터 이미지를 생성해 일관성을 맞추는 접근(참조 이미지 생성, LoRA) | `Toon-Factory/PRD.md:15`, `Toon-Factory/Design.md:5` | 품질 검수 기준 없음, 학습 데이터·GPU 부담(리뷰 #5) | Phase 2 캐릭터 시트(셀 단위 승인) |
| 사용자 음성 업로드·복제 보이스, 유명인 목소리 모방 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:75-83` | 퍼블리시티권·부정경쟁 위험 | 본인 음성 한정 클로닝은 Phase 2 이후 신원 확인 절차가 있을 때만 |
| 비회원 AI 상담(랜딩 채팅) | `docs/products/_platform-core/AI_ARCHITECTURE.md:130` | 운영자 예산과 강한 레이트 리밋이 필요 | Phase 2 |

## 4. 복사 금지 결함

`SECURITY_BASELINE.md:213-236` 중 해당 항목 + 이 제품 고유 항목.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 클라이언트가 최종 결과물을 만들고 워터마크를 붙임 | `Toon-Factory/Design.md:17`, 리뷰 #1 | 워터마크 제거, 무료 MP4 | 서버 렌더 + `exports.watermark` 서버 기록 |
| 프리미엄 에셋 공개 버킷, 원본 경로 노출 | 리뷰 #2 | 라이브러리 전체 수집 | 비공개 버킷 + 컬럼 GRANT 제외 + 등급 검사 서명 URL |
| Fabric `toObject` 결과를 그대로 저장 | 리뷰 #3 `:67`, #8 | 엔진 교체 시 데이터 손실, 이중 상태 원천 | 자체 `CutDoc` 스키마 |
| 스톡 벡터를 AI로 변형해 카탈로그 등록 | 리뷰 #6 | 라이선스 위반 | 출처 3종 제한 + 검증 필수 CHECK |
| `enable_safety_checker: false` | `sellingstudio/lib/image/fal.ts:24`, `:81` | 유해 이미지 생성 | 안전 필터 ON |
| 키 없을 때 placeholder 이미지 반환 | 리뷰 `:90` | 장애가 숨겨짐(`SECURITY_BASELINE.md:188`) | 기동 실패 |
| 크레딧 RPC EXECUTE 미회수, 비원자 차감 | `SECURITY_BASELINE.md:219-220` | 무료 크레딧 | 코어 credits 모듈만 |
| 웹훅 서명 미검증, `customerKey = Date.now()`, orderId 파싱 | `:221-222` | 위조 결제 | 코어 toss·webhooks |
| `user_plans FOR ALL`(셀프 업그레이드), Pro 잠금해제 localStorage | `:226-227` | 유료 기능 무료 사용 | 엔타이틀먼트는 SELECT만, 게이팅은 서버 |
| 프로필 없으면 admin, 클라이언트 PageGuard | `:229` | 권한 상승 | `proxy.ts` + 서버 가드 |
| 세션 없는 백그라운드 작업이 RLS에 막혀 무동작 | `:225` | 장애 은폐 | 워커는 service_role |
| 실키 `.env` 커밋 | `:235` | 키 유출 | `.env.example`만 |
| 정책 안 `org_members` 직접 조회 | `:230` | 재귀 42P17 | 코어 헬퍼 |
| FK가 RLS를 우회해 다른 조직 부모를 참조 | 이 제품 설계 점검 | 테넌트 간 데이터 연결 | `(id, org_id)` 복합 FK |
| 사용자 입력 파일명을 Storage 경로에 사용 | `:233` | 경로 조작 | 서버 생성 `<org>/toon/<entity>/<uuid>` |
| LLM·음성 키를 브라우저·Vercel·워커에 두기 | `docs/reviews/Nomad-BlogStudio.md:17`, `docs/products/_platform-core/SECURITY_BASELINE.md:284` | 키 유출, 비용 남용 | LLM 키는 FastAPI 전용, ElevenLabs 키와 토큰 개인키는 Next.js 서버 전용 |
| 브라우저에서 Dify·FastAPI·AI 제공자 직접 호출 | `docs/products/_platform-core/SECURITY_BASELINE.md:299` | 인증·과금 우회 | `/api/ai/*`, `/api/voice/*` |
| Dify 입력에 토큰·org·개인정보 | `docs/products/_platform-core/SECURITY_BASELINE.md:285` | Dify 로그에 평문으로 남음 | 대화 매핑(`platform_conversation_id`, `dify_user`) |
| 크레딧 확인 없는 생성 라우트, 타임아웃 없는 외부 AI 호출 | `docs/reviews/sellingstudio.md:58`, `:75` | 무료 사용, 장애 전파 | 선차감 → 호출 → 정산, 타임아웃과 환불 |
| 국외 이전 동의 없이 상용 AI·fal 호출 | `docs/products/_platform-core/AI_ARCHITECTURE.md:86` | 개인정보 국외 이전 고지 의무 | `resolve_ai_route` 필터 + 배경 생성 `TN007` |
| AI가 컷 문서·위키를 직접 수정 | 제안 | 되돌릴 수 없는 데이터 손상, 사람 소유 블록 침해 | 초안만 돌려주고 사용자 동작이 커맨드로 반영(Undo 가능) |
| 작품 설정 컬렉션을 작품 간·조직 간에 섞기 | 제안 | 설정 유출, 엉뚱한 근거 답변 | 작품별 컬렉션 + `series_id` 서버 대조 |
| 클라이언트가 보낸 임의 텍스트를 TTS | 제안 | 음성 생성 남용, 과금 우회 | 저장된 컷 문서·DB 메시지의 텍스트만 낭독 |
| 영상 음성을 만드는 도중 다른 제공자로 대체 | `docs/products/_platform-core/VOICE_ARCHITECTURE.md:47` | 한 영상 안에서 목소리가 바뀜 | 대체 금지, 실패 + 환불 |
| AI 표시 회피 조장("AI 티 안 나게") | 01장 6.5절 | 표시 의무 회피 | 거절. 메타데이터 표시는 끌 수 없음 |
| 3D 재질에 토큰 밖 색, 만화 효과음·말풍선을 3D 장식으로 사용 | `docs/nomad-design-modules/_design-guide/HERO_3D.md:52-53`, 03장 4.2절 | 피할 인상 | 03장 4.5절 토큰 표 |
| `tailwind.config.js`, `@tailwind base`, 버전 없는 "Tailwind" 지시 | `Toon-Factory/Design.md:11`, `docs/nomad-design-modules/_design-guide/DESIGN_SYSTEM.md:67`, `:81` | v3로 만들어지는 사고 | Tailwind CSS v4(4.x 고정), CSS 우선 설정 |

## 5. 아카이브 절차

| 단계 | 내용 |
|---|---|
| 1 | 원본 `Toon-Factory/`(문서 3개)를 `archive/Toon-Factory/`로 옮긴다. 코드가 없으므로 키 재발급 대상 없음 |
| 2 | 원본 `Claude.md`는 이 폴더 `CLAUDE.md`로 대체되었다는 한 줄을 아카이브 README에 남긴다 |
| 3 | 참고 코드(Shorts Maker media)는 원본 위치에 둔다(video 소유). 이식 시 커밋 메시지에 원본 경로를 남긴다 |
| 4 | zip 중복 없음(워크스페이스 루트에 Toon-Factory zip 없음) |
| 5 | 이동은 사용자 승인 후 별도 작업으로 한다(이번 단계에서 원본을 바꾸지 않음) |

## 6. 인증 단계 복사 금지 결함 (2026-10-14 추가, 확정 결정 22)

이 제품의 원본(`Toon-Factory/`)에는 코드가 없어 아래 패턴의 직접 출처는 없다. 골격 참고(`Nomad-BlogStudio`)와 다른 제품 원본에서 확인된 결함이라 4절 표에 행을 넣지 않고 여기에 둔다. 허용되는 Mock은 `docs/products/_platform-core/AUTH_ROADMAP.md` 2장(로컬 Supabase 시드 계정으로 실제 로그인)뿐이다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 쿠키·localStorage에 역할·플랜을 적는 Mock 로그인(`lib/mock-auth.ts`, `mock-login`, `nomad_role`, `nomad_plan` 쿠키) | `docs/products/nomad-blog/07_SOURCE_MIGRATION.md:88`, `docs/products/nomad-commerce/07_SOURCE_MIGRATION.md:96` | 권한 위조, 프로덕션 노출 | AUTH_ROADMAP 2장: 로컬 시드 계정 + 실제 JWT, `isMockAuthAllowed()` 가드, 배포 환경 `/api/dev/login` 404, CI 금지 문자열(06장 TN-06-031) |
| 기능 코드의 `if (mock)`·`AUTH_MODE` 분기, 페르소나 이메일로 권한 분기 | AUTH_ROADMAP 0장 불변 조건, 2.5절 | Mock에서만 통과하는 권한 경로 | 단계 분기는 `src/lib/auth/`·로그인 화면·콜백·`/api/dev/login`만, 권한은 `session_context`로만 |
| OAuth 콜백 `next` 무검증 리다이렉트, 요청 Host로 origin 조립 | AUTH_ROADMAP 3.2절 5번, `docs/products/_platform-core/SECURITY_BASELINE.md` 17장(인증 단계 보안 규칙) | 오픈 리다이렉트, 피싱 | `next`는 `/`로 시작하고 `//`·`@`·`\` 없는 경로만, origin은 `NEXT_PUBLIC_APP_URL` 고정 |
| 서명 없는 base64 JSON OAuth state, state 안의 orgId 신뢰 | `docs/reviews/Nomad-BlogStudio.md:65`(YouTube 연동 콜백) | CSRF, 다른 조직 연결 | 로그인은 Supabase PKCE. 네이버 브리지는 HttpOnly 서명 쿠키 state + 상수 시간 비교 + 1회 사용(AUTH_ROADMAP 7.2.3절) |
| 이메일 일치만으로 외부 로그인 계정을 기존 사용자에 합치기, `listUsers` 전체 조회로 사용자 찾기 | AUTH_ROADMAP 7.2.3절 | 계정 탈취, 페이지 누락으로 중복 계정 | 제공자 고유 id(`auth_identity_links`)로 찾고, 같은 이메일이면 `email_in_use` 안내 후 로그인 상태 수동 연결 |
| 로그인 제공자 토큰 저장 | AUTH_ROADMAP 7.2.3절 3번 | 유출 시 외부 계정 접근 | 로그인에만 쓰고 버린다 |
