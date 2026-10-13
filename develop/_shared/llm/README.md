# LLM 키, 오픈소스 LLM 서버(vLLM), 라우팅 설정 가이드

작성일 2026-10-13. 확정 결정 17(LLM 이원화)의 설치·운영 문서입니다. 라우팅 규칙과 대체 동작은 `docs/products/_platform-core/AI_ARCHITECTURE.md` 4장이 정본이고, DB는 `docs/products/_supabase-modular/migrations/0008_core_ai.sql`입니다. 모델 id, 가격, vLLM 옵션 이름은 "구현 시 확인"입니다.

## 1. 상용 API 키 (서버 전용)

| 제공자 | 환경변수 | 쓰는 곳 | 발급처 |
|---|---|---|---|
| Anthropic (Claude) | `ANTHROPIC_API_KEY` | FastAPI `apps/api` | Anthropic Console |
| OpenAI (ChatGPT) | `OPENAI_API_KEY` | FastAPI | OpenAI Platform |
| Google (Gemini) | `GOOGLE_API_KEY` | FastAPI | Google AI Studio |
| OpenRouter | `OPENROUTER_API_KEY` | FastAPI | OpenRouter |
| Voyage (임베딩) | `VOYAGE_API_KEY` | FastAPI | Voyage AI |

| 규칙 | 내용 |
|---|---|
| 서버 전용 | FastAPI 환경에만 둡니다. `NEXT_PUBLIC_` 접두사 금지, 브라우저 번들·git·로그 금지 |
| 분리 | 환경(개발/운영)별로 키를 따로 발급하고, 제공자 콘솔에서 월 사용 한도를 설정합니다(제안) |
| 고지 | 상용 제공자는 `cross_border=true`입니다. 개인정보 처리방침에 제공자를 적습니다 |
| 국외 이전 동의 | 조직이 `select core.set_ai_cross_border_ack(...)`(owner/admin, 고지문 버전 기록)로 동의하기 전에는 상용 제공자를 쓰지 않습니다. 동의 전에는 라우팅 체인에서 국외 제공자가 빠지고, 체인에 넣으려 하면 `AI002`로 거부됩니다. 제품 온보딩에서 고지와 동의를 받습니다 |
| 교체 | 새 키 발급 → 환경변수 교체 → 배포 → 옛 키 폐기 |

Git Bash / Linux (로컬 개발):

```bash
cd apps/api
cp .env.example .env     # 키를 채웁니다. .env는 git에 올리지 않습니다
```

PowerShell:

```powershell
Set-Location apps\api
Copy-Item .env.example .env
```

## 2. 공용 오픈소스 LLM 서버 (vLLM)

위치는 `D:\WorkSpace\DEV\platform-llm\` (제안)입니다. 사전 준비(NVIDIA 드라이버, NVIDIA Container Toolkit, Windows는 WSL2 + Docker Desktop GPU)는 `docs/develop/_shared/voice/README.md` 2.1절과 같습니다.

### 2.1 Docker Compose 예시

```yaml
# D:\WorkSpace\DEV\platform-llm\docker-compose.yml (제안, 옵션 이름은 vLLM 문서로 구현 시 확인)
services:
  vllm:
    image: vllm/vllm-openai:<고정 태그>      # latest 대신 태그 고정
    command: >
      --model <모델 id 또는 /models/경로>
      --served-model-name platform-oss
      --api-key ${OSS_LLM_API_KEY}
      --max-model-len 8192
    ports:
      - "8200:8000"
    volumes:
      - ./models:/models
      - ./hf-cache:/root/.cache/huggingface
    environment:
      - HUGGING_FACE_HUB_TOKEN=${HF_TOKEN}
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    restart: unless-stopped
```

Git Bash / Linux:

```bash
cd /d/WorkSpace/DEV/platform-llm
cp .env.example .env          # OSS_LLM_API_KEY, HF_TOKEN
docker compose up -d
curl -s http://localhost:8200/v1/models -H "Authorization: Bearer $OSS_LLM_API_KEY"
```

PowerShell:

```powershell
Set-Location D:\WorkSpace\DEV\platform-llm
Copy-Item .env.example .env
docker compose up -d
Invoke-RestMethod http://localhost:8200/v1/models -Headers @{ Authorization = "Bearer $env:OSS_LLM_API_KEY" }
```

### 2.2 FastAPI 연결

| 변수 | 값 |
|---|---|
| `OSS_LLM_BASE_URL` | vLLM 서버의 OpenAI 호환 주소, 예: `http://<서버>:8200/v1` |
| `OSS_LLM_API_KEY` | vLLM `--api-key` 값 (FastAPI 서버 환경에만) |

- vLLM은 OpenAI 호환 API라서 FastAPI 라우터의 `providers/oss.py`(OpenAI 호환 클라이언트)가 `oss-llm` 제공자로 호출합니다.
- 서버는 사설망에 두고 FastAPI 서버에서 오는 요청만 허용합니다. 브라우저에서 직접 호출하지 않습니다.
- GPU 메모리에 맞는 모델 크기와 양자화 선택은 구현 시 측정으로 정합니다.

## 3. 오픈소스 모델 라이선스 체크표

모델을 등록하기 전에 아래를 확인해 기록합니다. 후보 계열은 Qwen, Llama, Gemma 등이며 각 모델·버전의 라이선스를 반드시 원문으로 확인합니다(계열 이름만으로 통과시키지 않습니다).

| 항목 | 확인 내용 |
|---|---|
| 모델 이름·버전 | 정확한 체크포인트 이름 |
| 라이선스 이름과 원문 URL | 확인 일자 포함 |
| 상업 이용 | 허용 / 조건부 / 금지. 유료 서비스 기준 |
| 조건 | 월간 사용자 수 상한, 이름 표기, 파생 모델 명명 규칙, 허용 용도 제한(Acceptable Use Policy) |
| 한국어 성능 | 제품 평가셋(질의-정답)으로 측정한 결과 |
| 컨텍스트 길이·도구 호출 지원 | LangGraph 노드에 필요한지 |
| 판정 | 통과 / 보류 / 금지 |

비상업·연구용 전용 라이선스 모델은 유료 서비스에 쓰지 않습니다(`SECURITY_BASELINE.md` 16장). 통과한 모델만 4장으로 DB에 등록합니다.

## 4. DB 등록 (`ai_model_prices`, `ai_routing_settings`)

`ai_providers`의 `oss-llm`은 seed에 이미 있습니다. 모델별 단가 행은 `core.ai_model_prices`에 서비스 역할 또는 마이그레이션/seed로 추가합니다(사용자 쓰기 불가).

```sql
-- 모델 단가·라이선스 기록 (credits_per_unit은 GPU 원가 기준 제안값)
insert into core.ai_model_prices (provider_id, model, kind, unit, credits_per_unit, license) values
  ('oss-llm', 'platform-oss', 'llm', '1k_input_tokens',  0.2000, '<라이선스 이름, 확인 일자>'),
  ('oss-llm', 'platform-oss', 'llm', '1k_output_tokens', 0.5000, '<라이선스 이름, 확인 일자>')
on conflict (provider_id, model, kind, unit) do update
  set credits_per_unit = excluded.credits_per_unit, license = excluded.license;
```

- `model='*'`는 제공자 기본 단가입니다. 구체 모델 행이 있으면 그 행이 우선하는지 FastAPI 구현에서 확인합니다(구현 시 확인).
- 상용 제공자의 구체 모델 id와 단가는 각 제공자 문서로 확인해 같은 방식으로 추가합니다.

## 5. 라우팅 설정 (`set_ai_routing`, `ai_routing_settings`)

경로 결정은 `core.resolve_ai_route(org, app, feature, kind)`입니다. 가장 구체적인 설정(조직 > 플랫폼, 앱 > 전체, 기능 > `*`)을 씁니다. 플랫폼 기본값은 seed의 `ai_routing_settings`(org null, app null)에 있습니다.

| 모드 | 의미 |
|---|---|
| `commercial` | 체인의 상용 제공자만 |
| `open_source` | 오픈소스(`oss-llm`)만 |
| `auto` | 체인 순서대로. 장애·429·시간 초과·예산 초과 시 다음으로 대체 |

### 5.1 조직 관리자가 부르는 함수

`core.set_ai_routing(p_org_id, p_app_id, p_feature, p_kind, p_mode, p_chain, p_force_open_source)`는 조직 owner/admin이 호출할 수 있습니다. 플랫폼이 강제한 범위를 풀려고 하면 `AI001`로 거부됩니다.

```sql
-- 예 1: 조직의 채팅 기능을 오픈소스만 쓰도록 설정
select core.set_ai_routing(
  '<org uuid>', 'astro-ai', 'chat', 'llm', 'open_source',
  '[{"provider":"oss-llm","model":"*"}]'::jsonb, true);

-- 예 2: 조직의 요약 기능은 자동(Claude 우선, 실패 시 오픈소스)
select core.set_ai_routing(
  '<org uuid>', 'flora-publishing', 'summarize', 'llm', 'auto',
  '[{"provider":"anthropic","model":"*"},{"provider":"oss-llm","model":"*"}]'::jsonb, false);
```

- `force_open_source=true`이면 `mode`는 `open_source`여야 합니다(DB CHECK).
- 제품별 기능 기본값(org null, app=제품)은 제품 seed에 `ai_routing_settings` 행으로 넣습니다. 플랫폼 운영자(서비스 역할)가 설정합니다.
- hms처럼 민감 데이터 제품은 모든 kind를 `open_source` + `force_open_source`로 둔 기본 행을 갖습니다(`VOICE_ARCHITECTURE.md` 3장). hms는 전용 제공자 `hms-llm`(LLM), `hms-embed`(임베딩), `hms-voice`(음성)만 쓰고 공용 제공자와 상용 API는 비활성화합니다. 공용 GPU 서버로 대체하지 않습니다(사용자 결정 2026-10-13).
- 강제 오픈소스 범위는 상용으로 대체하지 않으며, 국외 이전 동의가 없는 조직도 같습니다. 모두 실패하면 오류로 처리합니다.

### 5.2 플랫폼 운영자 예시 (서비스 역할)

```sql
insert into core.ai_routing_settings (org_id, app_id, feature, kind, mode, chain, force_open_source) values
  (null, 'stock-dashboard', 'wiki.ingest', 'llm', 'open_source', '[{"provider":"oss-llm","model":"*"}]', true)
on conflict ((coalesce(org_id::text, '')), (coalesce(app_id, '')), feature, kind) do update
  set mode = excluded.mode, chain = excluded.chain, force_open_source = excluded.force_open_source;
```

## 6. 대체(fallback) 체인 동작

| 단계 | 동작 |
|---|---|
| 1 | `resolve_ai_route`가 모드와 체인을 돌려줍니다. 예: Claude → ChatGPT → Gemini → 오픈소스 |
| 2 | 라우터가 체인 첫 제공자를 호출합니다 |
| 3 | 장애, 429, 시간 초과, 예산 초과면 다음 제공자로 넘어갑니다. `core.ai_usage.status='fallback'`과 실제 제공자를 기록합니다 |
| 4 | 체인 전체가 실패하면 오류를 사용자에게 보여 주고 `refund_credits`로 환불하거나 차감하지 않습니다(mock 응답으로 숨기지 않음) |
| 예외 | `force_open_source` 범위는 상용으로 대체하지 않습니다. 오픈소스도 실패하면 실패로 처리합니다 |
| 개인정보 | `contains_pii=true` 입력, 민감 데이터 기능은 오픈소스만 씁니다 |

## 7. 점검표

| 점검 | 기대 |
|---|---|
| 상용 키가 FastAPI 환경 밖(브라우저, git, 로그)에 있다 | 없음 |
| vLLM 서버가 사설망에서만 접근된다 | 예 |
| 등록한 오픈소스 모델마다 3장 체크표 기록이 있다 | 예 |
| 조직 관리자가 강제 오픈소스 범위를 변경 | `AI001` |
| 강제 오픈소스 범위에서 상용 호출이 발생한다 | 없음 |
| 상용 장애를 가정한 대체 테스트 | `status='fallback'` 기록 |
