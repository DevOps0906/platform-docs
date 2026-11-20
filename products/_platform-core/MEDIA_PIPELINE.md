# 공용 미디어 파이프라인 (WhisperX · HyperFrames · FFmpeg 적용 기획)

작성일 2026-11-20. 상태: **제안** (확정 결정 아님). 이 문서는 새 파일이며 기존 공용 문서(`VOICE_ARCHITECTURE.md` 등)는 고치지 않았다. 공용 계약 변경은 5장에 제안으로만 적고, 채택 시 별도 PR로 반영한다.

## 1. 배경

숏폼 제작 도구를 소개한 영상(2026-11-20 시청)에서 "캡컷 없이 클로드로 영상 편집"에 쓰는 무료 도구 3종이 나왔다. 영상 속 설명과 검색으로 확인한 내용, 그리고 이 저장소군의 현황을 대조해 적용 지점을 정리한다.

| 도구 | 하는 일 | 영상 속 설명 |
|---|---|---|
| HyperFrames | HTML(CSS·JS)을 영상으로 렌더링 | 자막과 모션 그래픽을 MP4로 변환 |
| WhisperX | 음성 인식과 단어별 타임스탬프 | 단어 단위 시각으로 정확한 자막 |
| FFmpeg | 자르기·붙이기·합성·인코딩 | 컷 편집용 무료 도구 |

## 2. 도구 3종 요약과 확인 상태

| 항목 | HyperFrames | WhisperX | FFmpeg |
|---|---|---|---|
| 라이선스 | Apache-2.0 (검색 결과 기준, 레포 LICENSE 원문 **미확인**) | BSD-2-Clause (공식 README 기준) | 빌드 옵션에 따라 LGPL 또는 GPL (제품별 결정, 6장) |
| 실행 환경 | Node 필요. 버전은 OpenMontage 안내서 기준 22 이상(`OpenMontage:docs/GUIDEBOOK_ko.md:45`), 공식 문서 **미확인** | Python, GPU 권장. faster-whisper 백엔드는 8GB 미만 GPU로 large-v2 구동 가능(공식 README 기준) | 모든 제품에서 이미 사용 |
| Claude 연계 | Claude Code 플러그인과 claude.ai 커넥터 존재(검색 결과 기준) | 없음 (라이브러리) | 없음 |
| 한국어 단어 정렬 | 해당 없음 | 한국어용 정렬 모델 지원 여부 **미확인** (공식 README에 언어 목록 없음). 2장 검증 스파이크 S1에서 확인 | 해당 없음 |
| Remotion과의 관계 | 대안 렌더 엔진. Remotion 컴포지션을 옮겨 주는 공식 스킬이 있다고 함(검색 결과 기준) | 해당 없음 | Remotion 내부에서도 사용 |

주의: 위 표의 "검색 결과 기준" 항목은 웹 검색 요약으로 확인한 것이며, 도입 전 각 저장소 원문으로 재확인한다.

## 3. 저장소 현황 (2026-11-20 점검)

점검 방식: 각 레포를 클론해 `whisper`, `whisperx`, `hyperframes`, `remotion`, `ffmpeg` 문자열을 검색했다. HyperFrames는 **어느 제품 레포에도 없다**(OpenMontage 사본에만 있음).

| 제품 | STT | 렌더 엔진 | 자막 처리 | 근거 |
|---|---|---|---|---|
| SceneFlow | faster-whisper, 단어 시각 옵션 켜짐(기본 true) | FFmpeg(MVP), Remotion은 Phase 2 검토 | 단어 시각을 ASS로 만들어 번인 | `SceneFlow:services/media-worker/handlers/stt.py:56`, `:98` · `SceneFlow:README.md:140` · `SceneFlow:tasks/DECISIONS-2026-10-28.md:9` |
| 글로벌쇼츠 스튜디오 | Whisper(워커) | FFmpeg + Remotion Player. 편집 task-007이 "Remotion 라이선스 결정 필요"로 대기 | LLM 출력 JSON 기반 | `global-shorts-studio:AGENTS.md:11` · `global-shorts-studio:tasks/NOW.md:4` · `global-shorts-studio:docs/PLAN.md:271` |
| Shopping-Shorts-Maker | 없음(대본 기반 한 줄 자막) | FFmpeg 워커 컨테이너(LGPL) | 한 줄 자막 | `Shopping-Shorts-Maker:docs/planning.md:138`, `:783` |
| Nomadroom-Studio | faster-whisper small·CPU, 보안 검사 통과 시에만 | FFmpeg | 편집안의 컷·자막 폼 | `Nomadroom-Studio:tasks/plan-variety-shorts.md:89` · `Nomadroom-Studio:docs/03_SCREENS_UX.md:17` |
| CineDram-Studio | faster-whisper medium(GPU) 또는 small(CPU) | ffmpeg(미리보기), 최종은 캡컷 수작업 | SRT 생성 | `CineDram-Studio:skills/shorts-blueprint/SKILL.md:71` · `CineDram-Studio:README.md:4` |
| Flora-V1 북트레일러 | 없음 | Remotion 4.0.x + FFmpeg | 컴포지션 안 텍스트 | `Flora-V1:docs/platform/book-trailer/02_ARCHITECTURE.md:11` |
| Motion-Studio | 없음 | Remotion 4.0.539 (`@remotion/captions` 포함) | Remotion 캡션 패키지 | `Motion-Studio:package.json` |
| KNOWFLOW-AI | faster-whisper 기본, 단어 시각·화자 구분은 WhisperX 선택 | FFmpeg(장면 캡처, L2) | 전사 편집기·SRT 내보내기 | `KNOWFLOW-AI:docs/blueprints/stt-voice/README.md:54` |
| NOMAD Classroom | 없음 | 없음 | 없음 | 영상 기능 없음 |
| platform-docs 공용 | `SttResult.segments`(구간 단위만) | 미디어 워커(Whisper·demucs·FFmpeg) | 없음 | `products/_platform-core/VOICE_ARCHITECTURE.md:28` · `products/_platform-core/SHARED_MODULES.md:25` |

핵심 사실: SceneFlow는 이미 faster-whisper의 단어 시각 기능을 쓰고 있다. 따라서 WhisperX 도입은 "단어 시각이 새로 생긴다"가 아니라 **"정렬 정확도가 더 좋아지는가"를 검증하는 일**이다. 효과는 가설이며 S1에서 수치로 확인한다.

## 4. 적용 대상 7개와 우선순위 (제안)

| 순위 | 대상 | 적용 내용 | 선행 조건 | 메모 위치 |
|---|---|---|---|---|
| 1 | SceneFlow | STT 어댑터에 WhisperX 백엔드 추가(옵션), 자막 타이밍 5단계 정확도 검증. Phase 2 모션 렌더 후보에 HyperFrames 추가 | S1 | `SceneFlow:docs/file/04-구현/08_MEDIA_PIPELINE_ADOPTION.md` |
| 2 | 글로벌쇼츠 스튜디오 | task-007 편집의 렌더 런타임 결정에 HyperFrames를 대안으로 포함. 워커 STT 후보 비교 | S2, S3 | `global-shorts-studio:docs/MEDIA_PIPELINE_ADOPTION.md` |
| 3 | Shopping-Shorts-Maker | 05 편집 단계 자막을 대본 한 줄에서 단어 시각 기반으로 확장 검토. 가격·CTA 오버레이 후보 | S1 | `Shopping-Shorts-Maker:docs/MEDIA_PIPELINE_ADOPTION.md` |
| 4 | Nomadroom-Studio · CineDram-Studio | SRT 정밀화(WhisperX), 캡컷 수작업 구간의 자동화 가능성 평가 | S1 | 각 레포 `docs/MEDIA_PIPELINE_ADOPTION.md` |
| 5 | Flora-V1 북트레일러 · Motion-Studio | 기존 Remotion 유지. 신규 템플릿 1종만 HyperFrames로 비교 제작 | S2 | 각 레포 `docs/MEDIA_PIPELINE_ADOPTION.md` |
| 6 | KNOWFLOW-AI · NOMAD Classroom | KNOWFLOW 전사 편집기의 WhisperX 선택안 구체화. Classroom은 강의 영상 자막 기능이 생길 때 참조 | S1 | 각 레포 `docs/MEDIA_PIPELINE_ADOPTION.md` |
| 7 | platform-docs 공용 코어 | `SttResult`에 단어 단위 필드 추가 제안(5장), 렌더 런타임 선택 규칙(6장) | 채택 결정 | 이 문서 |

Flora-V2·humscore·ContentFlow-AI·WebNovel-Studio 등 영상 렌더가 없는 레포는 대상이 아니다.

## 5. 공용 계약 변경 제안 (VOICE_ARCHITECTURE 기준)

현재 계약은 구간(segment) 단위 시각만 돌려준다(`VOICE_ARCHITECTURE.md:28`). 단어 시각을 선택 필드로 추가하는 방안을 제안한다. 기존 호출자는 영향이 없다.

```ts
interface SttWord { word: string; start: number; end: number; score?: number }
interface SttSegment { start: number; end: number; text: string; words?: SttWord[] }
interface SttResult  {
  text: string
  segments?: SttSegment[]
  durationSeconds: number
  provider: VoiceProvider
  model: string
  alignment?: 'none' | 'whisper-word' | 'forced'  // 정렬 방식 기록
}
```

| 항목 | 제안 | 이유 |
|---|---|---|
| 필드 성격 | 모두 선택(optional) | 기존 `elevenlabs` 구현을 깨지 않음 |
| `alignment` | 어떤 방식으로 시각을 얻었는지 기록 | 품질 비교와 사용량 정산 근거 |
| 라우팅 | `core.resolve_ai_route`의 `stt` 종류에 기능 플래그(`word_align`) 추가 | 제품별로 켜고 끔 |
| 사용량 기록 | `core.ai_usage` stt 행에 `alignment` 메타 | 크레딧 단가 차등 가능성 |

반영 방법: 공용 폴더는 제품 작업에서 고치지 않는 규칙(`AGENTS.md` 4장)에 따라, 각 제품 `06_AGENT_PLAN.md` 6절 "공용 모듈 요청"에 이 5장을 인용해 요청한다. 이 PR은 요청 근거 문서만 추가한다.

## 6. 렌더 런타임 선택 규칙 (제안)

| 기준 | FFmpeg 단독 | Remotion | HyperFrames |
|---|---|---|---|
| 적합한 작업 | 컷·이어붙이기·자막 번인·인코딩 | React로 만든 템플릿형 영상, 앱 안 미리보기 | HTML로 만든 모션 그래픽·자막 오버레이 |
| 이미 쓰는 곳 | 전 제품 | Flora-V1, Motion-Studio, 글로벌쇼츠(Player) | 없음 |
| 라이선스 부담 | 빌드 옵션 확인 필요 | 상업 이용 조건 **미확인**(글로벌쇼츠 task-007 대기 중) | Apache-2.0 (원문 미확인) |
| 전환 비용 | 해당 없음 | 해당 없음 | 컴포지션 변환 스킬 존재(검색 결과 기준) |

선택 원칙(제안):
- 컷 편집·합성·인코딩은 항상 FFmpeg.
- 이미 Remotion으로 구현된 제품(Flora-V1, Motion-Studio)은 바꾸지 않는다.
- 신규 모션 렌더가 필요하고 Remotion 라이선스가 확정되지 않았으면 HyperFrames를 먼저 비교한다.
- 한 제품 안에서 두 런타임을 섞지 않는다. 런타임은 제안 단계에서 정하고 중간에 바꾸지 않는다.

FFmpeg 빌드 정책은 제품마다 다르므로 통일하지 않는다.

| 제품 | 현재 정책 | 근거 |
|---|---|---|
| 글로벌쇼츠 스튜디오 | 서버 내부·이미지 비배포 조건으로 GPL FFmpeg 허용(사용자 결정 2026-11-19) | `global-shorts-studio:AGENTS.md:25` |
| Shopping-Shorts-Maker | LGPL 빌드. GPL 도구(libx264)에도 GPL 거부 적용 여부는 ADR-0002 미결 | `Shopping-Shorts-Maker:docs/planning.md:783` · `Shopping-Shorts-Maker:tasks/NOW.md:30` |

## 7. 검증 스파이크 (린 검증, 개발 전 확인)

합격 기준 수치는 모두 **제안**이며, 첫 실측 뒤 조정한다.

| ID | 질문 | 방법 | 합격 기준(제안) | 소요(제안) |
|---|---|---|---|---|
| S1 | WhisperX가 한국어 단어 정렬에서 faster-whisper 단어 시각보다 낫나 | 실제 숏폼 3편(각 30~60초)을 두 방식으로 돌려 자막 싱크를 눈으로 비교하고, 단어 20개의 시작 시각 오차를 수동 측정 | 한국어 정렬 모델이 동작하고 오차가 더 작음 | 반나절 |
| S2 | HyperFrames와 Remotion의 결과·제작 시간 비교 | 같은 15초 자막 오버레이 템플릿 1종을 양쪽으로 제작 | 품질 동등, 에이전트 제작 시간이 같거나 짧음 | 1일 |
| S3 | 라이선스 | 두 렌더러와 WhisperX의 LICENSE 원문, 정렬 모델 약관 확인(`secscan license`) | 상업 SaaS 사용 가능 | 2시간 |

S1에서 한국어 정렬이 안 되면 WhisperX 도입은 중단하고 faster-whisper 단어 시각을 유지한다.

## 8. 위험과 하지 않을 것

| 항목 | 내용 | 근거 |
|---|---|---|
| OpenMontage 코드 복사 금지 | OpenMontage는 AGPLv3다. 코드·문구·식별자를 복사하지 않고 설계 참고만 한다 | `SceneFlow:AGENTS.md:26` |
| 화자 구분 모델 약관 | WhisperX의 화자 구분(pyannote)은 모델 약관 확인이 필요하다. 이 기획에는 화자 구분을 넣지 않는다 | `KNOWFLOW-AI:docs/blueprints/stt-voice/README.md:54` |
| 한국어 정렬 | 지원 여부 미확인. S1 통과 전에는 제품 문서에 "확정"으로 쓰지 않는다 | 2장 |
| 외부 사실 | "검색 결과 기준" 항목은 S3에서 원문 확인 후 갱신한다 | 2장 |
| 범위 | 이 PR은 문서만 추가한다. 코드·의존성·DB는 바꾸지 않는다 | 이 PR |

## 9. 사업 연결 (제안)

| 항목 | 내용 |
|---|---|
| 상품 차별점 | 단어 단위 하이라이트 자막은 숏폼 편집 상품의 눈에 띄는 기능이 될 수 있다(효과는 미검증) |
| 크레딧 | 정렬 방식(`alignment`)별로 항목을 나눌 수 있다. 금액은 S1·S2 실측 뒤 정한다 |
| 콘텐츠 | 위 파이프라인을 직접 만드는 과정은 강의·전자책·마케팅 소재로 재사용 가능 |
| 첫 검증 | 도구 소개형 숏폼은 좋아요보다 저장이 많은 사례(영상 기준 저장 787, 좋아요 504)가 있어 수요 신호로 참고할 수 있다 |
