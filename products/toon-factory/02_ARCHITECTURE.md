# 02 아키텍처: Toon Factory

작성일 2026-10-12. 공용 모듈은 `docs/products/_platform-core/SHARED_MODULES.md`를 참조만 하고 재정의하지 않는다.

## 1. 스택

| 레이어 | 기술 | 버전 | 근거 |
|---|---|---|---|
| 웹 앱 | Next.js App Router, TypeScript strict | 16.x(고정 버전, `latest` 금지) | `Toon-Factory/Design.md:11`, 리뷰 `docs/reviews/Toon-Factory.md:14`, `SECURITY_BASELINE.md:210` |
| UI | Tailwind CSS v4, shadcn/ui, Lucide 아이콘 | 프로젝트 고정 | `Toon-Factory/Design.md:11`, `DESIGN_PRINCIPLES.md:149` |
| 캔버스 | Fabric.js v6(브라우저: 뷰 전용, 워커: `fabric/node` 렌더) | 6.x | `Toon-Factory/Design.md:13`. 노드 렌더 경로는 제안(8절 아래 위험 표) |
| 상태 | Zustand + immer(`produceWithPatches`) | 5.x / 10.x | `Toon-Factory/Claude.md:17`, 리뷰 `:76` |
| 문서 스키마 | zod 판별 유니온(`packages/toon-doc`) | 3.x | 리뷰 #4 `:68` |
| DB/인증/스토리지 | Supabase(PostgreSQL 15), 모듈러 `core` + `toon` 스키마 | - | `Toon-Factory/Design.md:15`, 05장 |
| 잡 | `core.jobs` + TS 워커(`services/toon-worker`, 폴링 루프 `runWorker`) | - | `SHARED_MODULES.md:402-424`. 확정 결정 6의 BullMQ는 video 범위라 쓰지 않는다 |
| 이미지 렌더 | `fabric/node` + node-canvas 계열 + sharp(PNG/JPG 인코딩, 메타데이터) | 고정 | 제안 |
| 영상 렌더 | FFmpeg 바이너리(워커 컨테이너), Shorts Maker `ken-burns.ts`/`layer-composite.ts` 인자 이식 | FFmpeg 6.x | 분석 `docs/products/00_MERGE_ANALYSIS.md:1299`, `:1309` |
| AI | `_platform-core` LLM 게이트웨이, fal client | - | `SHARED_MODULES.md:198-249` |
| 결제 | Toss Payments(`core-billing/toss`) | - | 확정 결정 4 |

## 2. 모듈 경계

```
apps/toon/
  src/app/(marketing)/        랜딩, 가격
  src/app/(auth)/             로그인, 가입, 비밀번호
  src/app/(legal)/            약관, 처리방침, AI 정책, 에셋 이용 허락
  src/app/app/                로그인 후 화면(작품, 콘티, 라이브러리, 내보내기, 결제, 설정, 온보딩)
  src/app/editor/[episodeId]/ 에디터 페이지(dynamic import, ssr:false)
  src/app/admin/              platform_admin 카탈로그 화면
  src/app/api/<영역>/          Route Handler(catalog, storyboard, dialogue, generations, exports, jobs, billing, webhooks, admin)
  src/components/canvas/      Fabric 어댑터(문서 → Fabric 단방향, 이벤트 → 커맨드). Fabric 코드는 여기만
  src/components/editor/      3패널 UI, 인스펙터
  src/components/export/      내보내기 패널, 진행률
  src/stores/                 editorStore(문서 모델, 커맨드, 히스토리, 자동 저장)
  src/lib/server/             세션 가드, 기능 게이팅(entitlements), 단가표(pricing), 오류 매핑
  src/lib/env/                환경변수 검증
packages/toon-doc/
  src/schema/                 CutDoc zod 스키마, 버전 마이그레이션(v1 →)
  src/render/                 renderCut(doc, resolver, fabricNs) 브라우저/노드 공용
  src/layout/                 말풍선 줄바꿈·꼬리 기하, 표정 앵커 계산(순수 함수)
  src/storyboard/             콘티 JSON → CutDoc 변환(scriptToDocs)
  src/presets/                내보내기 프리셋(인스타, 웹툰 스트립, 쇼츠)
services/toon-worker/
  src/handlers/storyboard/    storyboard.generate
  src/handlers/image/         image.generate (fal)
  src/handlers/export-image/  export.png / export.zip / export.strip
  src/handlers/export-mp4/    export.mp4
  src/media/                  FFmpeg 인자 구성(Shorts Maker 이식)
  src/schedules/              정기결제 청구, 만료 내보내기 정리
tools/catalog-import/         카탈로그 일괄 등록 CLI(service_role)
tools/sql-mono/               모듈러 조각 → 모놀리스 변환
supabase/                     마이그레이션, tests
```

원칙: (1) 같은 렌더 코드(`packages/toon-doc/src/render`)를 에디터 미리보기와 서버 내보내기가 함께 쓴다. 편집 화면과 결과물이 다르게 나오는 문제를 구조로 막는다. (2) 상태 원천은 `editorStore`의 문서이고 Fabric은 뷰다(리뷰 #8, `docs/reviews/Toon-Factory.md:52`). (3) 결과물 생성, 크레딧, 플랜 판정은 서버만 한다.

### 2.1 에디터 데이터 흐름

| 단계 | 동작 |
|---|---|
| 1 | 페이지 진입: 회차의 컷 목록(RLS 조회) → 문서 zod 검증 → 버전 마이그레이션 |
| 2 | 문서가 참조하는 카탈로그 에셋 id를 모아 `POST /api/catalog/sign`(편집용 1024px 서명 URL 15분) |
| 3 | 어댑터가 `renderCut`으로 Fabric 객체 생성(단방향). rAF로 묶어 그린다 |
| 4 | 사용자 조작 → Fabric `object:modified` → 커맨드(`moveLayer`, `swapExpression` 등) → store `produceWithPatches` → 히스토리(100단계) |
| 5 | 문서 변경 → 1.5초 디바운스(최대 10초) → `rpc toon.save_cut_doc(cut, doc, revision)` → `TN409`면 충돌 배너 |
| 6 | 서명 URL 만료 2분 전 재발급 |

### 2.2 컷 문서 스키마 (`packages/toon-doc/src/schema`, 계약 예시)

```ts
type AssetRef = { source: 'catalog'; assetId: string } | { source: 'user'; userAssetId: string }
interface LayerBase { id: string; name?: string; x: number; y: number; rotation: number; scaleX: number; scaleY: number; opacity: number; locked: boolean; hidden: boolean }
interface CharacterLayer extends LayerBase { kind: 'character'; characterId: string; poseAssetId: string; expressionAssetId: string | null; flipX: boolean; expressionOffset?: { dx: number; dy: number; ds: number } }
interface BubbleLayer extends LayerBase { kind: 'bubble'; templateAssetId: string; text: string; fontFamily: 'nanum_pen' | 'gaegu' | 'do_hyeon' | 'plex_kr'; fontSize: number; align: 'left' | 'center' | 'right'; width: number; padding: number; tail: { x: number; y: number } | null; bubbleType: 'speech' | 'thought' | 'narration' | 'sfx' }
interface ImageLayer extends LayerBase { kind: 'image'; ref: AssetRef }
interface TextLayer extends LayerBase { kind: 'text'; text: string; fontFamily: BubbleLayer['fontFamily']; fontSize: number; color: string; strokeColor: string | null; strokeWidth: number; effectAssetId: string | null }
type Layer = CharacterLayer | BubbleLayer | ImageLayer | TextLayer
interface CutDoc { v: 1; background: { color: string; ref: AssetRef | null }; layers: Layer[] }   // 배열 순서 = z 순서(뒤 → 앞)
```

좌표는 컷 픽셀 공간이다. 표정 위치는 포즈 에셋의 `anchors.head`(정규화 좌표)로 계산하므로 레이어에 부모-자식 관계를 두지 않는다(리뷰 #4). 글꼴 4종은 OFL 글꼴 파일을 웹과 워커에 같은 파일로 번들한다(글꼴 라이선스 확인은 TN-06-034).

## 3. 공용 모듈 사용

| 공용 모듈 | 용도 | 호출 위치 | 비고 |
|---|---|---|---|
| auth | 세션, 가입(`signup_app='toon'`), `requireSession('toon')` | `src/proxy.ts`, 모든 Route Handler 진입부 | `SHARED_MODULES.md:46-72` |
| org | 개인 조직 1개만 노출 | 세션 | 팀 기능 없음 |
| credits | 콘티 3, 대사 1, 배경 4/장, MP4 3 선차감 | `src/app/api/*` (service_role) | `priceOf('toon', action)` 단가표는 `src/lib/server/pricing.ts` |
| toss | Pro 구독(빌링키), 크레딧팩(일반결제) | `src/app/api/billing/*`, `services/toon-worker/src/schedules/` | `SHARED_MODULES.md:127-151` |
| webhooks | Toss, fal 수신 | `src/app/api/webhooks/{toss,fal}` | 서명 실패 401, 중복 200 |
| llm gateway | purpose `toon.storyboard`, `toon.dialogue`, `toon.prompt_en` | 워커 콘티 핸들러, 대사 Route Handler, 이미지 핸들러 | 5절 |
| fal client | 배경 생성, 결과 Storage 복사 | `services/toon-worker/src/handlers/image/` | 안전 필터 ON |
| compliance | 프롬프트·대사 규칙 단계(무료) | 생성 Route Handler | LLM 판정 단계는 쓰지 않는다(제안: 비용 대비 효과 낮음) |
| storage | `exports` 버킷, 서명 URL | 내보내기, 다운로드 | 제품 버킷 3개는 05장 2.5절 |
| audit | 다운로드, AI 가시 표기 해제, 카탈로그 공개, 에셋 보관 | 각 Route Handler, `toon.archive_user_asset` | `SHARED_MODULES.md:386-400` |
| jobs | 7개 job_type | 4절 | Realtime은 `core.jobs` 구독 |
| oauth, affiliate, automation-core, sns uploader, weasyprint | 사용 안 함 | - | sns uploader는 Phase 3 |

## 4. 잡과 워커

큐 이름 `toon.ai`, `toon.render`(`DB_CONVENTIONS.md:21`). 워커 1개 프로세스가 두 큐를 따로 클레임한다(동시성: ai 4, render 2). 제품 기록(`toon.generations`, `toon.exports`)은 워커가 `core.jobs`와 같은 트랜잭션 흐름에서 상태를 미러링한다.

| `job_type` | 큐 | 런타임 | 크레딧 선차감 | 재시도 | 환불 조건 |
|---|---|---|---|---|---|
| `storyboard.generate` | `toon.ai` | TS | 3 | max_attempts 2(LLM 타임아웃/5xx만) | 최종 실패 자동(`fail_job`) |
| `image.generate` | `toon.ai` | TS | 4 x 장수 | 3(fal 제출 실패). 안전 필터 거부는 재시도 없음 | 최종 실패 자동. 2장 중 1장만 실패하면 실패분 `refund_credits(p_amount=4)` |
| `export.png` | `toon.render` | TS(fabric/node + sharp) | 0 | 3 | 해당 없음 |
| `export.zip` | `toon.render` | TS | 0 | 3 | 해당 없음 |
| `export.strip` | `toon.render` | TS | 0 | 3 | 해당 없음 |
| `export.mp4` | `toon.render` | TS + FFmpeg | 3 | 2 | 최종 실패 자동 |
| `cut.thumbnail` | `toon.render` | TS | 0 | 1 | 해당 없음 |

스케줄(워커 크론, service_role): 매일 03:00 KST `expires_at < now()`인 내보내기 파일 삭제, 매일 빌링키 청구(`CORE_SPEC.md:223-233`), 매 10분 30분 넘은 `image.generate` 실패 처리. 코어 스케줄(`CORE_SPEC.md:383-395`)은 코어 담당 크론이 돈다.

렌더 워커의 판정 순서(리뷰 #1, #2 차단의 서버 쪽): (1) `exports` 행의 `watermark` 값만 믿는다(요청 페이로드의 값은 없다), (2) 문서가 참조하는 카탈로그 에셋을 `toon.org_asset_access`로 다시 확인하고 하나라도 허용 밖이면 `fail_job(retryable=false)` + `TN003`, (3) 원본은 `toon-catalog` 버킷에서 service_role로 읽는다, (4) 사용자 에셋의 `ai_generated`를 모아 `exports.ai_label`을 기록한다.

## 5. AI 라우팅

| purpose | 모델(fast/quality) | 크레딧 | 폴백 |
|---|---|---|---|
| `toon.storyboard` | quality | 3(잡 단위) | 게이트웨이 폴백 모델 1회 → 실패 시 환불 |
| `toon.dialogue` | fast | 1 | 폴백 1회 |
| `toon.prompt_en` | fast | 배경 단가에 포함 | 실패 시 원문 한국어 프롬프트로 진행하지 않고 실패 처리(품질 보호) |

모델 이름은 게이트웨이 모델 맵에서 고른다(`SHARED_MODULES.md:198-226`). 콘티 응답은 JSON 모드 + zod 검증, 검증 실패 1회 재요청.

| 이미지 용도 | fal 모델(후보) | 크기 | 비고 |
|---|---|---|---|
| 배경(기본) | Flux 계열 빠른 모델 | 컷 크기에 맞춤(최대 2048) | 모델 ID와 상업 이용 조건 미확인. 화이트리스트에 상업 이용 확인된 모델만 둔다 |
| 배경(고품질, Phase 2) | Flux 계열 고품질 모델 | 같음 | 단가 별도 |
| 배경 제거(Phase 2) | fal 배경 제거 모델 | - | 미확인 |
| 캐릭터 시트(Phase 2) | 참조 이미지 조건 생성 모델 | 1024 | fal client에 참조 이미지 입력 추가 필요(06장 6절 코어 요청) |

배경 프롬프트 조립: `[style_preset 문구] + [영어 장면] + "no people, no characters, no text"`, 부정 프롬프트 `person, face, hands, text, watermark, logo`. 시드는 기록해 재생성에 쓴다.

## 6. 리뷰 "높음" 결함의 차단 설계

리뷰 "높음" 6건(#1~#6, `docs/reviews/Toon-Factory.md:45-50`) 중 보안·데이터 결함 #1~#4는 05장 7절, 기술·법률 리스크 #5, #6은 여기에 둔다. 합계 6건 = 차단 설계 6건.

| 리뷰 #n | 출처 | 결함 요약 | 차단 설계 | 담당 장/작업 |
|---|---|---|---|---|
| `docs/reviews/Toon-Factory.md` 3장 #5 | `Toon-Factory/Design.md:5`, 리뷰 `:49` | LoRA 화풍 통일·자동 누끼는 학습 데이터, GPU, 검수 기준이 없고 운영자용인지 사용자 기능인지 불명확해 MVP 지연 요인 | (1) MVP에서 LoRA와 자동 누끼를 뺀다(07장 3절). (2) 카탈로그는 디자이너가 만든 투명 PNG를 `tools/catalog-import`로 등록하는 오프라인 운영자 파이프라인으로 고정한다. 등록 시 검수 기준: 포즈 PNG 2048px 이상 높이, 알파 채널, `anchors.head` 필수, 표정 6종 같은 캔버스 크기(CLI가 검증 실패 시 등록 거부). (3) AI는 캐릭터를 그리지 않는다. 배경만 fal로 생성해 GPU 호스팅이 없다. (4) 일관성 확장은 Phase 2 캐릭터 시트(참조 이미지 + 셀 단위 사용자 승인)로 하고 LoRA는 Phase 3 B2B와 묶는다 | 02장 5절, TN-06-012, TN-06-038 |
| `docs/reviews/Toon-Factory.md` 3장 #6 | `Toon-Factory/PRD.md:15`, `Design.md:5`, 리뷰 `:50` | 구매한 벡터 에셋을 AI로 변형해 재배포하면 스톡 라이선스(재판매·템플릿화 금지)와 충돌 | (1) 카탈로그 출처를 `in_house`, `commissioned`(저작권 양도 계약), `licensed_commercial`(재배포 허용 라이선스) 세 가지로 제한하고 스톡 변형은 금지(`2000_toon.sql:101-102`). (2) `license_ref`(계약·증빙 식별자) 필수, `license_verified_at/by`가 없으면 팩을 공개할 수 없다(CHECK `asset_packs_publish_license_check`, `2000_toon.sql:111-113`). (3) 검증은 platform_admin만, 감사 로그 기록. (4) 사용자에게는 에셋 이용 허락 범위(재배포·상표 등록·AI 학습 금지)를 약관과 `caption.txt`로 고지(01장 6.2절). (5) fal 모델은 상업 이용이 확인된 것만 화이트리스트 | 05장 2.1절, TN-06-012, TN-06-013 |

## 7. 배포 토폴로지

| 구성 | 위치 | 비고 |
|---|---|---|
| 웹 앱 | Vercel | Route Handler는 짧은 작업만(서명 URL, 잡 등록, 결제 승인). FFmpeg와 fabric/node는 Vercel에서 실행하지 않는다(`docs/reviews/Toon-Factory.md:87`) |
| 워커 | Railway 컨테이너 1~2개(`services/toon-worker`, FFmpeg + 글꼴 포함 이미지) | 공개 포트 없음. Supabase에 service_role로만 접속 |
| DB/Storage/Realtime | Supabase(모듈러 통합 프로젝트) | `toon` 스키마를 `[api].schemas`에 추가 |
| 외부 | Toss, fal, LLM 제공자 | 워커와 Route Handler에서만 호출 |

네트워크 경계: 브라우저는 Supabase(anon key, RLS)와 Next Route Handler만 호출한다. 원본 에셋과 내보내기 결과는 서명 URL로만 내려간다. 워커는 입력을 DB에서 읽고 결과를 Storage에 쓴다. 웹훅(Toss, fal)은 Vercel Route Handler가 받아 `core.webhook_events`에 기록한다.

위험과 대응

| 위험 | 대응 |
|---|---|
| fabric/node 렌더가 브라우저와 픽셀이 다름 | 골든 이미지 테스트(차이 0.5% 이하, TN-06-006). 글꼴 같은 파일 사용 |
| 워커 장애 | 잡은 대기열에 남음. `reap_stale_jobs(600)` |
| 서명 URL 대량 발급으로 원본 수집 | 편집용은 1024px이고 원본은 서명 URL로 나가지 않는다. 발급 레이트 리밋 600개/10분 |

## 8. 환경변수

| 변수 | 용도 | 공개 여부 | 누락 시 |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 브라우저 클라이언트 | 공개 | 기동 실패 |
| `SUPABASE_SERVICE_ROLE_KEY` | 서버, 워커 | 비공개 | 기동 실패 |
| `SUPABASE_DB_SCHEMA` | `core`(모듈러) / `public`(모놀리스) | 비공개 | 기동 실패 |
| `TOON_SCHEMA` | `toon` / `public` | 비공개 | 기동 실패 |
| `NEXT_PUBLIC_TOSS_CLIENT_KEY` | 결제창 | 공개 | 결제 화면 비활성 + 기동 경고 |
| `TOSS_SECRET_KEY`, `TOSS_WEBHOOK_SECRET` | 승인, 웹훅 검증 | 비공개 | 기동 실패 |
| `BILLING_KEY_ENC_KEY_V1`, `BILLING_KEY_ENC_KEY_VERSION` | 빌링키 AES-256-GCM | 비공개 | 기동 실패(0키 폴백 금지) |
| `FAL_KEY` | fal | 비공개(워커) | 워커 기동 실패 |
| `LLM_*`(게이트웨이 설정) | LLM | 비공개 | 기동 실패 |
| `FAL_WEBHOOK_URL` | fal 웹훅 주소 | 비공개 | 폴링만으로 동작 + 경고 |
| `FFMPEG_PATH` | 워커 | 비공개 | 워커 기동 시 `ffmpeg -version` 실패면 기동 실패 |
| `TOON_FONT_DIR` | 워커 글꼴 | 비공개 | 글꼴 4종 확인 실패면 기동 실패 |
| `RATE_LIMIT_SALT` | IP 해시 | 비공개 | 기동 실패 |
