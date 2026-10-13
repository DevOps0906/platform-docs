# Toon-Factory 기획 리뷰

> 리뷰 일자: 2026-10-12 / 대상 경로: `D:\WorkSpace\platform\Toon-Factory`
> 대상 문서: `Claude.md`(28줄), `Design.md`(28줄), `PRD.md`(32줄). 코드, package.json, 스키마, 시안 이미지는 없다. 폴더에는 이 3개 파일만 존재한다.
> 이 문서는 `docs/_tools/REVIEW_TEMPLATE.md` 의 구조를 "기획 문서만 있는 프로젝트"용으로 바꿔 적용했다.

## 1. 프로젝트 개요

- 기획 의도: "그림 실력이 없어도 5분 만에 모듈을 조립해 만드는 인스타툰 및 숏폼 제작 SaaS" (`PRD.md:7`). 캐릭터 본체/표정/배경/말풍선을 미리 만든 모듈로 제공하고, 사용자는 캔버스에서 드래그 앤 드롭으로 컷을 조립한 뒤 이미지(인스타툰)와 9:16 MP4(쇼츠)로 내보낸다. AI 이미지 생성의 약점인 "캐릭터 일관성"을 생성 대신 조립으로 해결하겠다는 것이 핵심 아이디어다 (`PRD.md:15-17`).
- 대상 사용자: 인스타툰 작가 지망생, SNS 마케터, 지식 크리에이터, 1인 창업자 (`PRD.md:9`, `PRD.md:13`). B2B로 기업 마스코트 모듈화 셋업 서비스 (`PRD.md:33`).

| 영역 | 제안된 기술 (`Design.md:9-17`) | 비고 |
|------|------|------|
| 프론트 | Next.js App Router, Tailwind CSS, Shadcn UI | 워크스페이스 표준과 동일 (Next 16, Tailwind v4) |
| 캔버스 | Fabric.js v6+, Zustand (`editorStore`) | 워크스페이스 내 사용 사례 없음 (신규 도입) |
| 백엔드/DB | Supabase (Auth, RLS, Storage) | 스키마/버킷/정책 정의 없음 |
| 영상 | FFmpeg.wasm (브라우저 렌더링) | 워크스페이스 내 사용 사례 없음. 서버 FFmpeg 래퍼는 존재 |
| AI | LoRA 학습/적용, 자동 누끼 (`Design.md:5`) | 모델/호스팅/실행 주체 미정 |
| 결제 | 언급 없음 (Freemium/구독만 기술) | Toss/Stripe 미정 |

- 기획 완성도: **약 20%**
  - 있는 것: 제품 비전, 타겟, MVP 기능 4개의 이름, 기술 스택, 3단 에디터 레이아웃, 다크 테마 색상 1개, 레이어 객체 필드 6개.
  - 없는 것: 화면 목록/사용자 플로우, 컷(페이지) 개념과 프로젝트 저장 구조, DB 스키마와 RLS, 에셋 카탈로그 명세(15개 행동 목록, 표정 수, 포맷), 영상 변환 규칙(컷당 시간, 전환, BGM/자막), 요금제 수치, 결제 수단, 비기능 요구사항(지원 브라우저/해상도/자동저장), 성공 지표.
  - 세 문서를 합쳐 90줄 수준으로, 같은 워크스페이스의 NOMAD Shorts Maker/Nomad-BlogStudio PRD(트랙별 파이프라인과 크레딧 단가까지 수치화)에 비해 구현 기준으로 쓰기에는 부족하다.

## 2. 기획 문서 분석

| 문서 | 역할 | 주요 내용 | 평가 |
|------|------|------|------|
| `PRD.md` | 제품 요구사항 | 비전, 타겟/문제/해결, MVP 기능 4개(모듈형 캔버스, 에셋 라이브러리, 숏폼 변환, GEO), Freemium + B2B | 기능 이름만 있고 수용 기준이 없음 |
| `Design.md` | 시스템 설계 | 에셋 파이프라인 4단계, 기술 스택, `editorStore` 구조, 레이어 필드, 다크 모드와 3단 레이아웃 | 데이터 구조가 기능 요구를 담지 못함 |
| `Claude.md` | AI 에이전트 작업 규칙 | PRD/Design 우선 참조, TS strict + any 금지, `src/components/canvas/` 격리, Zustand history 델타, rAF/디바운스, 한국어, Shadcn 일관성 | 존재하지 않는 "기존 아키텍처"를 전제 |

요구사항 구조 요약

1. 에셋 계층 (운영자 측): 벡터 에셋 구매 -> LoRA로 화풍 통일 -> 자동 누끼/모듈화 -> 웹 에디터 등록 (`Design.md:5`). 모듈은 캐릭터 본체(머리/몸통 분리), 배경/소품(투명 PNG), 효과음/말풍선(SVG) (`Design.md:7`).
2. 편집 계층 (사용자 측): 좌측 에셋 탭 - 중앙 캔버스 - 우측 레이어/스타일 패널 (`Design.md:29`). 드래그 앤 드롭, 레이어 순서 조정, 독립 조립 (`PRD.md:21`). 상태는 `editorStore { layers[], selectedId, history }` (`Design.md:21`).
3. 출력 계층: 컷들을 9:16 MP4로 자동 렌더링 (`PRD.md:25`), 브라우저 FFmpeg.wasm (`Design.md:17`). 인스타툰 이미지 내보내기는 명시되지 않음.
4. 노출/수익 계층: GEO 구조화 데이터 (`PRD.md:27`), 무료 워터마크 / 구독 시 무제한 에셋과 영상 내보내기 (`PRD.md:31`), B2B 마스코트 셋업 (`PRD.md:33`).

## 3. 기획상의 문제점

| # | 심각도 | 분류 | 위치(파일명:섹션) | 내용 |
|---|--------|------|------|------|
| 1 | 높음 | 보안 | `PRD.md:4 비즈니스 모델`(31) + `Design.md:2 기술 스택`(17) | 워터마크와 "영상 내보내기는 프리미엄"을 브라우저 FFmpeg.wasm으로 처리하면 렌더링 전 과정이 클라이언트에 있어 워터마크 제거, 무료 사용자의 MP4 생성을 서버가 막을 수 없다. 과금 모델이 기술 설계에 의해 무력화된다 |
| 2 | 높음 | 보안 | `PRD.md:4`(31) + `Design.md:2`(15) | "프리미엄 무제한 에셋"의 접근 제어가 없다. Supabase Storage 공개 버킷에 에셋을 두면 URL만으로 전체 라이브러리를 수집할 수 있다. 플랜별 에셋 등급, signed URL, RLS 정책이 정의되어야 한다 |
| 3 | 높음 | 누락 | `Design.md:3 핵심 데이터 구조`(21-23) | 데이터 구조가 단일 캔버스 `layers[]` 뿐이라 "컷" 개념이 없다. 인스타툰(다컷 캐러셀)과 "컷들을 영상으로"(`PRD.md:25`)를 표현할 수 없고, 프로젝트 저장/불러오기 스키마도 없다 |
| 4 | 높음 | 모순 | `Design.md:1 에셋 파이프라인`(7) vs `Design.md:3`(23) | 캐릭터를 머리/몸통으로 분리하고 표정 레이어를 얹는다고 했으나 레이어 필드는 `{ id, type, src, position, rotation, scale }` 뿐이다. 부착 관계(그룹/부모), flip, opacity, zIndex, 말풍선 텍스트/폰트/꼬리 방향이 없어 PRD의 핵심 기능(표정 교체, 말풍선 편집)을 담을 수 없다 |
| 5 | 높음 | 기술리스크 | `Design.md:1`(5) | "LoRA로 화풍 통일 -> 자동 누끼"는 학습 데이터, GPU 호스팅, 품질 검수 기준이 전혀 없다. 또한 이것이 운영자용 오프라인 파이프라인인지 사용자 기능인지 불명확하다. MVP 일정에 들어가면 가장 큰 지연 요인이 된다 |
| 6 | 높음 | 기술리스크 | `PRD.md:2 핵심 타겟 및 문제 해결`(15) + `Design.md:1`(5) | 구매한 벡터 에셋을 AI로 변형해 SaaS로 재배포하는 것은 대부분의 스톡 라이선스(재판매/템플릿화 금지)와 충돌할 수 있다. 에셋 출처와 라이선스 정책이 없으면 사업 자체가 법적 리스크를 가진다 |
| 7 | 중간 | 기술리스크 | `Design.md:2`(17) | FFmpeg.wasm 멀티스레드는 SharedArrayBuffer 때문에 COOP/COEP 헤더가 필요하고, 이 경우 Supabase Storage 등 외부 이미지에 CORP/CORS 설정이 필수다. 모바일 브라우저 메모리 한계, 30초 9:16 1080p 인코딩 시 수 분 소요로 "5분 만에"(`PRD.md:7`) 목표와 충돌한다 |
| 8 | 중간 | 기술리스크 | `Claude.md 개발 규칙`(17) + `Design.md:3`(21) | Fabric.js는 자체 객체 트리를 상태로 가진다. Zustand `layers[]`와 Fabric 캔버스를 둘 다 원천으로 두면 동기화 버그가 생긴다. 어느 쪽이 원천인지, "델타"의 형식(JSON Patch/커맨드)이 무엇인지 정의되지 않았다 |
| 9 | 중간 | 모호성 | `PRD.md:3 핵심 기능`(27) | GEO의 대상이 불명확하다. 결과물은 인스타/쇼츠로 반출되므로 플랫폼이 공개 페이지를 호스팅하지 않으면 구조화 데이터를 붙일 곳이 없다. 공개 갤러리/작품 페이지의 존재 여부부터 결정해야 한다 |
| 10 | 중간 | 누락 | `PRD.md:3`(23) | "15가지 필수 행동 모듈"의 목록, 표정 수, 캐릭터 수, 배경/말풍선 수량, 파일 포맷(PNG/SVG 혼용 기준)이 없다. 에셋 제작이 개발과 병행되어야 하므로 MVP 에셋 명세가 가장 먼저 필요하다 |
| 11 | 중간 | 누락 | `PRD.md:3`(25) | 숏폼 변환 규칙이 없다: 컷당 노출 시간, 전환 효과, 4:5/1:1 컷을 9:16에 배치하는 방식(레터박스/크롭/팬), BGM/효과음/TTS/자막 포함 여부 |
| 12 | 중간 | 누락 | `PRD.md:4`(31) | 요금제 가격, 무료 한도(프로젝트 수/내보내기 횟수), 결제 수단(Toss/Stripe), 구독 해지/환불 정책이 없다 |
| 13 | 중간 | 범위과다 | `PRD.md:4`(33), `PRD.md:3`(27) | B2B 마스코트 모듈화와 GEO는 핵심 편집 경험과 무관하며 MVP에서 제외 가능하다 |
| 14 | 낮음 | 모순 | `Claude.md 필수 지침`(7) | "기존 아키텍처 패턴(Zustand, Fabric.js)을 엄격히 준수"라고 하나 기존 코드가 없다. 첫 골격 구현 전에는 따를 패턴이 없으므로 초기 구현 시 패턴을 정의하는 문서가 필요하다 |
| 15 | 낮음 | 모호성 | `Claude.md 개발 규칙`(21) | "모든 코드 및 문서는 한국어"는 식별자까지 한국어로 오해될 수 있다. "주석/문서/UI 문구는 한국어, 식별자는 영어"로 명확히 해야 한다 |
| 16 | 낮음 | 누락 | `Claude.md`(5, 25, 29) | `@DESIGN.md`로 참조하나 실제 파일명은 `Design.md`. Windows에서는 동작하지만 Linux/CI/Vercel에서는 대소문자 불일치 |
| 17 | 낮음 | 누락 | `PRD.md` 전체 | 성공 지표(5분 내 1편 완성률 등), 지원 브라우저, 캔버스 해상도(1080x1350 등), 자동 저장 주기, 접근성 요구가 없다 |

### 심각도 높음 상세

- **#1 클라이언트 렌더링과 과금 충돌**: 브라우저가 영상을 만들면 워터마크 오버레이는 클라이언트 JS 한 줄로 끌 수 있고, "영상 내보내기는 구독자만"이라는 제한도 UI 숨김 수준에 그친다. 유료 기능의 결과물(워터마크 없는 MP4)은 서버에서 만들고, 서버가 구독 상태를 확인한 뒤 signed URL로만 내려줘야 한다. 무료 미리보기만 브라우저에서 처리하는 혼합 구조를 권장한다.
- **#2 에셋 접근 제어**: 이 제품의 자산은 에셋 라이브러리 자체다. `assets` 테이블에 `tier(free/premium)`를 두고, 프리미엄 원본은 private 버킷 + 짧은 만료 signed URL로 발급하며, 에디터에는 저해상도 미리보기만 공개해야 한다.
- **#3 컷/프로젝트 모델 누락**: 최소한 `project -> cuts[] -> layers[]` 계층과 캔버스 크기, 배경색, 컷 순서, 컷당 영상 시간 필드가 필요하다. 저장은 `cuts.doc jsonb`(Fabric `toObject` 결과가 아닌 자체 스키마)로 두어 엔진 교체 시에도 데이터가 유지되게 한다.
- **#4 레이어 필드 부족**: 레이어를 `kind`별 판별 유니온으로 정의해야 한다. 예: `character { characterId, poseId, expressionId, flipX }`, `bubble { templateId, text, fontSize, tail }`, `image { assetId }`, 공통 `{ id, x, y, rotation, scale, opacity, zIndex, locked }`.
- **#5, #6 에셋 파이프라인과 라이선스**: MVP는 LoRA/자동 누끼 없이 "디자이너가 직접 만든(또는 상업 재배포 허용 라이선스) 캐릭터 1~2종"으로 시작해야 일정과 법적 리스크를 모두 줄인다. LoRA 파이프라인은 B2B 셋업과 함께 2차 범위로 미룬다.

## 4. 효율적 구현 전략

### 권장 아키텍처

- **단일 Next.js 16 앱 + Supabase**. 에디터 페이지(`/editor/[projectId]`)는 `dynamic(() => import(...), { ssr: false })`로 Fabric.js를 클라이언트 전용 로드한다.
- **상태 원천은 Zustand 문서 모델, Fabric은 뷰**. `editorStore`가 `project/cuts/layers`(자체 스키마)를 소유하고, `src/components/canvas/` 의 어댑터가 문서 -> Fabric 객체로 단방향 반영한다. Fabric 이벤트(`object:modified`)는 커맨드로 변환해 스토어에 dispatch한다. 히스토리는 immer `produceWithPatches`로 patch/inversePatch를 쌓아 `Claude.md:17`의 "델타" 요구를 충족한다.
- **내보내기 이원화**. 이미지(인스타툰 PNG, 1080x1350)는 클라이언트 `canvas.toDataURL`로 즉시 생성하되 무료는 워터마크를 포함. MP4는 서버 렌더 잡: 클라이언트가 컷별 PNG를 Storage에 올리면 서버(또는 별도 워커)가 FFmpeg로 9:16 영상을 만들고 구독 상태를 확인해 워터마크 여부를 결정한다. FFmpeg.wasm은 "저해상도 미리보기" 용도로만 2단계에서 검토한다.
- **데이터 모델 초안**: `profiles(plan)`, `characters`, `assets(kind, character_id, pose, expression, tier, storage_path, preview_path)`, `projects(user_id, title, aspect)`, `cuts(project_id, order, doc jsonb, duration_ms)`, `render_jobs(project_id, status, output_path)`, `subscriptions`. 모든 사용자 테이블은 `user_id = auth.uid()` 기반 RLS, `render_jobs`/`subscriptions`의 상태 변경은 service role 전용.

### 재사용할 수 있는 기존 프로젝트/모듈

워크스페이스 전체에서 Fabric/Konva/FFmpeg.wasm/dnd-kit 사용 사례는 없다(모든 `package.json` 검색 결과 0건). 따라서 캔버스 에디터는 신규 구현이고, 재사용 대상은 골격/인증/미디어/과금이다.

| 재사용 대상 | 출처 | 용도 | 주의점 (기존 리뷰 근거) |
|------|------|------|------|
| Next 16 + Supabase SSR 골격: `src/lib/supabase/{client,server,middleware}.ts`, `src/middleware.ts`, `src/components/ui/*`(shadcn 19종), `zustand` 의존성 | **Nomad-BlogStudio** | 프로젝트 시작점. `basic-master-module`은 `app/` 4개 파일뿐인 create-next-app 수준이라 BlogStudio 골격이 더 효율적 | `tsc` 오류 0으로 가장 깨끗한 편. 단 `supabase/migrations/*`는 RLS 결함(org_members 임의 가입, credits RPC 권한 미검사, `docs/reference/reviews/Nomad-BlogStudio.md` 3장 #1-#3)이 있으므로 마이그레이션은 복사하지 말고 새로 작성 |
| 서버 FFmpeg 래퍼: `src/lib/media/ffmpeg.ts`, `ken-burns.ts`(이미지 배열 -> 1080x1920 30fps 영상, 이미지당 시간/줌 옵션), `layer-composite.ts`(BGM/이미지 오버레이), `thumbnail.ts`, `watermark.ts` | **NOMAD Shorts Maker** | "컷 PNG 배열 -> 9:16 MP4"가 `ken-burns.ts`의 `animate(imagePaths, audioPath, outputPath)`와 거의 일치. 워터마크 오버레이는 `layer-composite.ts` 패턴으로 추가 | `child_process` 기반이라 Vercel 서버리스에서는 실행 불가. Railway/Fly 단일 워커 또는 Supabase 외부 컨테이너 필요. BullMQ 파이프라인은 미연결 상태(`docs/reference/reviews/NOMAD_Shorts_Maker.md` 1장)이므로 가져오지 말고 `render_jobs` 테이블 폴링으로 단순화 |
| Toss 결제 승인 흐름: `src/app/api/billing/{checkout,confirm}` | Nomad-BlogStudio / NOMAD Shorts Maker | 구독 결제 | 두 프로젝트 모두 플랜/웹훅/크레딧 권한 결함 보고됨. 서버측 승인 패턴만 참고하고 플랜 상태 갱신은 service role 전용으로 재작성 |
| 비동기 AI 생성 + 웹훅 + Realtime 갱신: `lib/image/fal.ts`, `app/api/webhook/fal` | sellingstudio | 2단계의 AI 배경/소품 생성, 렌더 잡 진행률 Realtime 푸시 패턴 | 웹훅 서명 미검증, `plan`을 요청 바디에서 받는 결함(`docs/reference/reviews/sellingstudio.md` 3장 #3, #4)은 반드시 수정 후 사용 |
| `src/lib/ai/fal-image.ts` | Nomad-BlogStudio | 2단계 AI 배경 생성(Flux) | 키 미설정 시 placeholder 반환하는 폴백은 운영에서 제거 |
| 다크 대시보드 토큰/레이아웃 | Hospital | `bg-slate-950` 계열 다크 UI, 사이드바 셸 참고 | 구조만 참고 (도메인 무관) |

### MVP 범위 축소안

| 구분 | MVP 포함 | MVP 제외 (2차 이후) |
|------|------|------|
| 에셋 | 캐릭터 2종 x 행동 15 x 표정 6, 배경 20, 말풍선 10, 효과 텍스트 10 (수작업, 상업 라이선스 확인) | LoRA 화풍 통일, 자동 누끼, 사용자 업로드 |
| 에디터 | 다컷(최대 10컷, 4:5), 드래그 배치, 이동/회전/크기/반전, 레이어 순서, 표정 교체, 말풍선 텍스트, Undo/Redo, 자동 저장 | 그룹 편집, 애니메이션 키프레임, 협업 |
| 내보내기 | 컷별 PNG/ZIP (무료 워터마크), 9:16 MP4 서버 렌더 (구독자, 컷당 고정 시간 + 기본 BGM 1종) | FFmpeg.wasm 미리보기, TTS/자막, 전환 효과 다양화 |
| 수익 | 무료/프로 2플랜, Toss 정기결제 | 크레딧, B2B 마스코트 셋업 |
| 노출 | 없음 | 공개 작품 페이지 + JSON-LD(GEO) |

### 단계별 로드맵

1. **0단계 (1주) 기획 보강**: 컷/레이어 스키마, 에셋 명세서(행동 15개 목록, 파일 규격), 요금제 수치, 영상 규칙을 `PRD.md`/`Design.md`에 추가. `Claude.md`의 모순(#14-#16) 정리.
2. **1단계 (2~3주) 골격과 에디터 코어**: BlogStudio 골격 이식, 새 마이그레이션(RLS 포함), 에셋 카탈로그/Storage 정책, Fabric 어댑터 + Zustand 문서 모델 + 히스토리, 3단 레이아웃.
3. **2단계 (2주) 내보내기와 과금**: PNG/ZIP 내보내기, Shorts Maker `ken-burns.ts` 기반 렌더 워커와 `render_jobs`, 워터마크 서버 적용, Toss 구독.
4. **3단계 (선택)**: 공개 작품 페이지 + GEO, AI 배경 생성(fal), LoRA 기반 B2B 마스코트 파이프라인.

## 5. 구현 작업 목록 및 권장 모델

| # | 작업 | 우선순위 | 규모 | 권장 모델 | 이유 |
|---|------|------|------|------|------|
| 1 | 0단계 기획 보강: `project/cuts/layers` 판별 유니온 스키마, 에셋 명세, 영상 변환 규칙, 플랜 한도를 `Design.md`/`PRD.md`에 작성 | P0 | M | Fable 5.1 | 기획안만 있는 프로젝트의 설계. 이후 모든 작업의 기준 |
| 2 | Supabase 마이그레이션 신규 작성: profiles/characters/assets/projects/cuts/render_jobs/subscriptions + RLS, Storage 버킷(public preview, private premium, exports) 정책 | P0 | M | Fable 5.1 | 데이터 모델과 권한 설계. 기존 프로젝트들이 RLS에서 반복적으로 실패한 영역 |
| 3 | Nomad-BlogStudio 골격 이식: Next 16, `lib/supabase/*`, `middleware.ts`, shadcn ui, 로그인/회원가입, 다크 테마 토큰. `Claude.md` 파일명/언어 규칙 정리 | P0 | S | Sonnet 5.5 | 복사와 설정 정리 중심의 보일러플레이트 |
| 4 | `editorStore`(Zustand + immer patches) 문서 모델, 커맨드 API, Undo/Redo, 디바운스 자동 저장(`cuts.doc`) | P0 | M | Opus 5.5 | 정의된 스키마 기반 상태관리 구현, 2~5개 파일 |
| 5 | Fabric.js v6 어댑터(`src/components/canvas/`): 문서 -> Fabric 단방향 렌더, `object:modified` -> 커맨드 변환, 선택/변형/레이어 순서, SSR 비활성 로드 | P0 | L | Fable 5.1 | 이중 상태 원천 문제(#8)를 결정하는 핵심 아키텍처. 잘못 잡으면 전 기능에 동기화 버그 |
| 6 | 3단 에디터 UI: 좌측 에셋 탭(캐릭터/행동/표정/배경/말풍선 필터), 중앙 캔버스 + 컷 스트립, 우측 레이어/속성 패널 | P1 | M | Sonnet 5.5 | 반복적 shadcn 컴포넌트 작업 |
| 7 | 캐릭터 레이어 표정 교체와 말풍선 텍스트 편집(폰트, 꼬리 방향, 자동 줄바꿈) | P1 | M | Opus 5.5 | 명확한 중간 규모 기능 |
| 8 | 에셋 카탈로그 API + signed URL 발급(플랜별 tier 검사), 관리자용 에셋 일괄 등록 스크립트 | P0 | M | Opus 5.5 | 권한 검사가 있으나 범위가 명확. 정책 자체는 #2에서 확정 |
| 9 | PNG/ZIP 내보내기(1080x1350, 무료 플랜 워터마크) | P1 | S | Sonnet 5.5 | Fabric `toDataURL` + JSZip 조합의 단순 작업 |
| 10 | MP4 렌더 워커: Shorts Maker `ken-burns.ts`/`layer-composite.ts`/`watermark.ts` 이식, `render_jobs` 폴링 워커(Railway), 구독 확인 후 워터마크 결정, 결과 signed URL, Realtime 진행률 | P1 | L | Opus 5.5 | 기존 모듈 재사용 중심의 API/워커 연동. 과금 판단은 서버 한 곳으로 한정 |
| 11 | Toss 정기결제(빌링키) + 웹훅 서명 검증 + `subscriptions` 상태 갱신(service role 전용) | P1 | M | Fable 5.1 | 결제/권한 로직. 참고할 기존 구현들에 결함이 보고되어 실수 비용이 큼 |
| 12 | 에디터 핵심 단위/통합 테스트: 커맨드/히스토리, 스키마 직렬화 왕복, RLS 정책 테스트 | P1 | M | Opus 5.5 | 테스트 설계 |
| 13 | 랜딩/가격 페이지, 온보딩 템플릿 3종(첫 진입 5분 완성 경험) | P2 | S | Sonnet 5.5 | UI/문구 |
| 14 | 공개 작품 페이지 + JSON-LD(CreativeWork/ComicStory) GEO | P2 | S | Sonnet 5.5 | 정형화된 마크업 작업, 3단계 |

## 6. 종합 평가

- **실현 가능성**: 중상. 캔버스 조립 에디터 + 서버 FFmpeg 렌더는 검증된 조합이고, 골격/미디어/결제 모듈을 워크스페이스에서 재사용할 수 있어 축소한 MVP는 4~6주에 가능하다. 다만 원 기획 그대로(LoRA 화풍 통일, 자동 누끼, 브라우저 FFmpeg.wasm, GEO, B2B)는 기술/법적 리스크가 커 실현 가능성이 낮다. 성패는 코드가 아니라 "상업 이용 가능한 일관된 캐릭터 에셋"을 확보하는 데 달려 있다.
- **강점**: (1) 문제 정의가 날카롭다. AI 이미지의 캐릭터 일관성 문제를 조립형 모듈로 우회하는 포지셔닝이 명확하다. (2) 기술 스택이 워크스페이스 표준(Next.js + Supabase + shadcn + Zustand)과 일치해 재사용성이 높다. (3) 에디터 레이아웃과 상태 관리 원칙(격리, 델타 히스토리, 디바운스)이 미리 정해져 있다.
- **약점**: (1) 데이터 모델에 컷과 캐릭터 부착 구조가 없어 핵심 기능을 담지 못한다. (2) 클라이언트 렌더링 설계가 Freemium 과금(워터마크, 영상 내보내기 제한)과 충돌한다. (3) 에셋 파이프라인(LoRA)과 라이선스가 미정이라 콘텐츠 공급이 불확실하다.
- **모델별 비율** (14개 작업 기준): Fable 5.1 4개(29%), Opus 5.5 5개(36%), Sonnet 5.5 5개(36%).
- **권장 진행 순서**: 기획 보강과 스키마/RLS 확정(Fable) -> 골격 이식과 에디터 코어(Sonnet 골격, Fable 어댑터, Opus 스토어) -> 내보내기/렌더 워커/결제(Opus, Fable) -> UI 다듬기와 GEO(Sonnet).
- **주 담당 모델: Fable 5.1**. 이 프로젝트는 코드가 없고 기획 문서도 데이터 모델과 과금 경계가 비어 있어, 첫 단계에서 내리는 결정(컷/레이어 스키마, Zustand와 Fabric 사이의 상태 원천, 서버/클라이언트 렌더 경계, 에셋 접근 RLS)이 이후 모든 구현의 품질을 좌우한다. 이 설계와 초기 골격을 Fable 5.1이 맡고, 이후 정의된 기능 구현은 Opus 5.5, UI 반복 작업은 Sonnet 5.5로 넘기는 것이 비용 대비 가장 효율적이다.
