# 공용 음성 서버와 ElevenLabs 설정 가이드

작성일 2026-10-13. 확정 결정 16(음성 이원화)의 설치 문서입니다. 구조, 대체 규칙, 개인정보 규칙은 `docs/products/_platform-core/VOICE_ARCHITECTURE.md`가 정본이고, 이 문서는 설치와 운영 절차만 적습니다. 모델 이름과 버전, 외부 서비스의 약관과 요금은 "구현 시 확인"입니다.

## 1. 두 경로 요약

| 경로 | 구현 | 위치 | 키/인증 |
|---|---|---|---|
| ElevenLabs | TypeScript 공식 SDK, `packages/core-voice`의 `elevenlabs` 어댑터 | Next.js 서버에서만 호출 | `ELEVENLABS_API_KEY`(서버 전용) |
| 오픈소스 음성 서버 | FastAPI(Python) + GPU, `oss-voice` 어댑터가 호출 | `D:\WorkSpace\DEV\platform-voice\` (제안) | Next.js가 발급한 서명 토큰(`scope=voice`) |

## 2. 오픈소스 음성 서버

### 2.1 사전 준비

| 항목 | Linux | Windows |
|---|---|---|
| GPU 드라이버 | NVIDIA 드라이버 설치(`nvidia-smi`로 확인) | NVIDIA 드라이버 설치(Windows 쪽에만 설치. WSL2에는 별도 설치하지 않음) |
| 컨테이너 | Docker Engine + NVIDIA Container Toolkit | WSL2 + Docker Desktop(WSL2 백엔드, GPU 지원 켜기) |
| 확인 명령 | `docker run --rm --gpus all nvidia/cuda:<태그> nvidia-smi` | 같은 명령을 PowerShell 또는 WSL2 터미널에서 실행 |

CUDA 이미지 태그, 드라이버 최소 버전은 사용하는 faster-whisper(CTranslate2) 버전 문서로 구현 시 확인합니다.

Git Bash / Linux에서 GPU 확인:

```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi   # 태그는 예시, 구현 시 확인
```

PowerShell에서 GPU 확인:

```powershell
nvidia-smi
wsl --status
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

### 2.2 서비스 구성 (제안)

```
D:\WorkSpace\DEV\platform-voice\
├── docker-compose.yml
├── .env                  비밀(git 제외): AI_TOKEN_JWKS_URL(또는 공개키 파일 경로) 등. 서명용 개인키는 두지 않음
├── app/
│   ├── main.py           FastAPI: /healthz, /stt, /tts
│   ├── auth.py           서명 토큰 검증(EdDSA, JWKS/공개키, aud=platform-ai:<app>, scope=voice)
│   ├── stt.py            faster-whisper + silero-vad
│   ├── tts.py            TTS 모델 로더(4장 체크표 통과 모델만)
│   └── limits.py         길이·크기·레이트 리밋
└── models/               모델 가중치(볼륨 마운트, git 제외)
```

| 엔드포인트 | 입력 | 처리 | 출력 |
|---|---|---|---|
| `GET /healthz` | 없음 | GPU와 모델 로드 상태 | `ok` |
| `POST /stt` | 오디오 파일(multipart), `language` | silero-vad로 무음 구간 제거와 발화 끝 감지 → faster-whisper 변환 | `text`, `segments`, `duration_seconds`, `model` |
| `POST /tts` | `text`, `voice_id`, `language`, `format` | TTS 모델 합성, 스트리밍 응답 | 오디오 스트림(mp3/ogg), `X-Characters` 헤더 |

### 2.3 서명 토큰 검증과 제한

| 항목 | 규칙 |
|---|---|
| 인증 | `Authorization: Bearer <서명 토큰>`. 서명(EdDSA/Ed25519를 `AI_TOKEN_JWKS_URL`의 공개키로 검증, 공유 비밀키 없음), `exp`, `iss`, `aud=platform-ai:<app>`(자기 app만 수락), `scope`에 `voice` 포함을 확인합니다. 토큰이 없거나 무효면 401/403 |
| 조직 | 토큰의 `org`를 로그와 레이트 리밋 키로만 씁니다. 요청 본문의 조직 값은 무시합니다 |
| 요청당 길이 | STT 10분, TTS 5,000자(제안) |
| 파일 크기 | 50MB(제안) |
| 레이트 리밋 | 조직·사용자별 분당 요청 수(값은 구현 시 정하고 `SECURITY_BASELINE.md` 8장 형식을 따름) |
| 오디오 저장 | 서버는 요청 처리 후 오디오를 디스크에 남기지 않습니다(임시 파일은 요청 종료 시 삭제) |
| 네트워크 | 서버 간 사설망 또는 방화벽으로 Next.js 서버에서 오는 요청만 허용합니다. 브라우저에서 직접 호출 금지 |
| 로그 | 음성 원본, 변환 텍스트 전문, 토큰을 로그에 남기지 않습니다 |

### 2.4 실행

Git Bash / Linux:

```bash
cd /d/WorkSpace/DEV/platform-voice
cp .env.example .env        # AI_TOKEN_JWKS_URL 등을 채웁니다(개인키는 넣지 않습니다)
docker compose up -d --build
docker compose logs -f voice
curl -s http://localhost:8100/healthz
```

PowerShell:

```powershell
Set-Location D:\WorkSpace\DEV\platform-voice
Copy-Item .env.example .env
docker compose up -d --build
docker compose logs -f voice
Invoke-RestMethod http://localhost:8100/healthz
```

포트 8100은 예시입니다(제안). 모델 크기(large-v3, turbo 등)와 GPU 메모리 요구량은 구현 시 GPU 사양과 지연 목표로 정합니다.

### 2.5 hms 예외

진료 관련 음성·텍스트는 공용 음성 서버와 ElevenLabs로 보내지 않습니다. hms는 전용 제공자 `hms-voice`(전용 음성 서버)만 쓰고 공용 음성 서버는 어떤 경우에도 쓰지 않습니다(사용자 결정 2026-10-13, `VOICE_ARCHITECTURE.md` 3장). 인스턴스는 별도 호스트에 같은 이미지를 배포하고, 공개키는 hms 앱 것만 등록합니다.

## 3. ElevenLabs 설정

| 단계 | 내용 |
|---|---|
| 1 | ElevenLabs 계정과 API 키를 발급합니다. 요금제, 상업 이용 조건, 데이터 보관 정책은 ElevenLabs 약관으로 구현 시 확인합니다 |
| 2 | 키를 Next.js 서버 환경변수 `ELEVENLABS_API_KEY`에 넣습니다. `NEXT_PUBLIC_` 접두사 금지, 브라우저로 전달 금지 |
| 3 | `packages/core-voice`에서 TypeScript 공식 SDK(패키지 이름은 구현 시 npm에서 확인)로 `elevenlabs` 어댑터를 구현합니다. `VoiceAdapter.stt/tts` 인터페이스는 `VOICE_ARCHITECTURE.md` 2장 |
| 4 | 제품별 기본 보이스 목록을 정합니다. 보이스 클로닝은 본인 음성에 한해 신원 확인 + 동의 절차가 있을 때만(Phase 2 제안). 타인 목소리 복제는 법적 위험(퍼블리시티권, 부정경쟁)으로 제공하지 않습니다 |
| 5 | `core.ai_providers`의 `elevenlabs`(`cross_border=true`)를 확인하고 개인정보 처리방침에 제공자와 국외 이전을 적습니다. 조직의 국외 이전 동의(`set_ai_cross_border_ack`)가 없으면 호출하지 않습니다. 데이터 보관 정책과 제로 리텐션 옵션은 결정 항목입니다 |
| 6 | `core.ai_model_prices`에 단가가 있는지 확인합니다(seed 기본: STT 3 크레딧/분, TTS 5 크레딧/1천 자, 제안) |

Git Bash / Linux 환경변수 설정(로컬 개발):

```bash
echo 'ELEVENLABS_API_KEY=...' >> apps/web/.env.local     # git에 올리지 않습니다
```

```powershell
Add-Content apps\web\.env.local 'ELEVENLABS_API_KEY=...'
```

## 4. 모델 라이선스 체크표 (TTS/STT 선택 시 필수)

새 모델을 도입하기 전에 이 표를 채워서 `docs/wiki/decisions/`(개발 위키) 또는 제품 06장 작업 기록에 남깁니다. 가중치 라이선스와 코드 라이선스는 다를 수 있으므로 둘 다 확인합니다. 결과는 `core.ai_model_prices.license`에 적습니다.

| 항목 | 확인 내용 |
|---|---|
| 모델 이름·버전 | 정확한 체크포인트 이름 |
| 코드 라이선스 | 추론 코드의 라이선스(MIT, Apache-2.0 등) |
| 가중치 라이선스 | 모델 파일(체크포인트)의 라이선스. 코드와 다를 수 있음 |
| 상업 이용 허용 | 예 / 아니오 / 조건부(조건 기록). 유료 서비스 기준 |
| 한국어 지원 | 예 / 아니오. 직접 품질 청취 평가 기록 |
| 출처 링크 | 라이선스 원문 URL과 확인 일자 |
| 학습 데이터 제약 | 데이터 출처로 인한 이용 제한이 있는지 |
| 보이스 | 기본 목소리의 사용 권리(클로닝 시 동의 필요) |
| 판정 | 통과 / 보류 / 금지 |

사전 판정 예(2026-10-13 기준 기획 단계 메모. 도입 시 원문으로 다시 확인):

| 모델 | 용도 | 상업 이용 | 판정 | 비고 |
|---|---|---|---|---|
| faster-whisper (코드 MIT) + Whisper 모델 | STT | 코드 MIT. 모델 가중치 라이선스는 구현 시 확인 | 통과 예정(확인 필요) | 모델 크기는 GPU 사양으로 확정 |
| silero-vad (MIT) | 무음 감지 | 허용(MIT) | 통과 예정(확인 필요) | |
| F5-TTS 공개 가중치 | TTS | 아니오(CC-BY-NC) | 금지 | `flora/f5-tts`는 내부 실험용으로만 |
| Coqui XTTS | TTS | 아니오(CPML, 비상업) | 금지 | |
| CosyVoice2 | TTS | Apache-2.0(고문 의견) | 라이선스 원문 확인 필요 | 코드와 가중치 라이선스를 각각 확인, 한국어 품질 검증 |
| Zonos | TTS | Apache-2.0(고문 의견) | 라이선스 원문 확인 필요 | 코드와 가중치 라이선스를 각각 확인, 한국어 지원 범위 확인 |
| MeloTTS | TTS | MIT | 라이선스 원문 확인 필요 | 품질이 상대적으로 낮음 |
| Chatterbox-Multilingual | TTS | MIT(고문 의견) | 라이선스 원문 확인 필요 | 코드와 가중치 라이선스를 각각 확인, 한국어 품질 검증 |
| 그 외 한국어 TTS 후보 | TTS | 구현 시 확인 | 보류 | 위 체크표를 채워서 통과한 모델만 도입 |

비상업 라이선스(CC-BY-NC, CPML, 연구용 전용 등) 모델은 유료 서비스에 쓰지 않습니다(`SECURITY_BASELINE.md` 16장).

## 5. 점검표

| 점검 | 기대 |
|---|---|
| 토큰 없이 `/stt` 호출 | 401/403 |
| 다른 app의 `aud`를 가진 토큰, 다른 키로 서명한 토큰 | 401/403 |
| `scope`에 `voice`가 없는 토큰 | 403 |
| 10분 초과 오디오, 50MB 초과 파일 | 거부 |
| 브라우저 번들에 `ELEVENLABS_API_KEY`, 음성 서버 주소 | 없음 |
| 요청 종료 후 서버 디스크에 오디오 | 없음 |
| 새 TTS 모델 도입 | 4장 체크표 통과 기록 있음 |
