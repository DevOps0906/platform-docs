# 공용 Dify 설치·운영 가이드

작성일 2026-10-13. 확정 결정 14(Dify: 채팅·운영용 공용 자체 호스팅 1개)의 설치 문서입니다. 구조와 규칙은 `docs/products/_platform-core/AI_ARCHITECTURE.md` 1, 2, 3장이 정본이며, 이 문서는 설치와 운영 절차만 적습니다. Dify의 정확한 버전, 메뉴 이름, 기능 이름은 구현 시 Dify 공식 문서로 확인해 주세요. 아래 화면 이름은 모두 "구현 시 확인"입니다.

## 1. 역할과 원칙

| 항목 | 내용 |
|---|---|
| 역할 | 제품별 채팅 앱(Chatflow), 프롬프트 관리, 대화 이력 확인, 운영 화면 |
| 하지 않는 일 | 조직 데이터 보관, 조직 구분, 과금. 이것들은 Next.js와 FastAPI가 합니다 |
| 개수 | 서버 1대(공용). 제품마다 앱 1개 |
| 위치 | `D:\WorkSpace\DEV\platform-dify\` (제안) |
| 조직 구분 | 대화 매핑으로만 합니다. Next.js가 대화를 DB에 먼저 기록하고, Dify에는 토큰이 아니라 대화 id와 서버가 만든 `dify_user`만 넘깁니다. Dify는 조직 구조를 모릅니다 |
| hms | hms는 공용 Dify를 쓰지 않습니다(전용 서버에서 Next.js → FastAPI 직접 경로) |
| 금지 | Dify 내장 지식베이스에 조직 데이터를 넣지 않습니다. 브라우저에서 Dify를 직접 호출하지 않습니다 |

## 2. 설치 (공식 Docker Compose)

사전 준비: Docker(Windows는 Docker Desktop + WSL2), Git, 여유 메모리 8GB 이상(권장, 구현 시 Dify 문서 기준으로 확인).

Git Bash / Linux:

```bash
mkdir -p /d/WorkSpace/DEV && cd /d/WorkSpace/DEV
git clone https://github.com/langgenius/dify.git platform-dify
cd platform-dify/docker
cp .env.example .env
# .env 편집: SECRET_KEY, 데이터베이스·Redis 비밀번호를 새 값으로 바꿉니다
docker compose up -d
docker compose ps
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force D:\WorkSpace\DEV | Out-Null
Set-Location D:\WorkSpace\DEV
git clone https://github.com/langgenius/dify.git platform-dify
Set-Location platform-dify\docker
Copy-Item .env.example .env
# .env 편집: SECRET_KEY, 데이터베이스·Redis 비밀번호를 새 값으로 바꿉니다
docker compose up -d
docker compose ps
```

- 저장소 경로와 compose 파일 이름, `.env` 변수 이름은 설치하는 버전의 공식 문서로 확인합니다(구현 시 확인).
- `.env`와 비밀번호는 git에 올리지 않습니다. 이 폴더는 제품 저장소 밖에 둡니다.
- 외부 공개는 리버스 프록시(HTTPS)를 앞에 두고, 관리 화면은 접근 IP를 제한합니다(제안).

## 3. 초기 관리자

1. 브라우저에서 설치 화면 경로로 접속합니다(보통 `http://localhost/install`. 구현 시 확인).
2. 관리자 이메일, 이름, 비밀번호를 정합니다. 개인 계정이 아니라 팀 공용 운영 계정을 권장합니다(제안).
3. 로그인 후 워크스페이스 이름을 정하고, 가입 허용 설정은 끕니다(초대만).

## 4. FastAPI 라우터를 모델 공급자로 등록

의도 분류, 대화 요약 같은 보조 LLM 노드가 플랫폼 라우터를 거치도록, FastAPI의 `POST /v1/chat/completions`를 OpenAI 호환 모델 공급자로 등록합니다(`AI_ARCHITECTURE.md` 8장 표).

| 항목 | 값 |
|---|---|
| 공급자 종류 | OpenAI 호환(OpenAI-API-compatible) 공급자. 이름은 구현 시 확인 |
| Base URL | FastAPI 서버 주소 + `/v1` (예: `http://host.docker.internal:8000/v1`, Dify 컨테이너에서 접근 가능한 주소여야 합니다) |
| API Key | `DIFY_INTERNAL_API_KEY` 값(내부 API 키). Dify 모델 설정 화면에만 입력합니다 |
| 모델 이름 | 플랫폼 라우터의 별칭 1개(예: `platform-default`, 제안). 실제 모델은 `core.resolve_ai_route`가 정합니다 |
| 주의 | 이 경로로 조직 데이터를 보내지 않습니다(조직 구분이 없는 요청). 사용량은 앱 단위 운영비로 기록됩니다 |

## 5. 제품별 Chatflow 앱

제품마다 앱 1개를 만듭니다(예: `astro-ai`, `flora-publishing` ...). 앱 이름은 `core.apps.id`와 같게 합니다(제안).

### 5.1 입력 변수

| 변수 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `platform_conversation_id` | 텍스트 | 예 | Next.js가 `core.ai_conversations`에 먼저 기록한 플랫폼 대화 id(UUID). 비밀이 아닌 식별자이며 클라이언트 입력을 쓰지 않습니다. 사용자 입력창에는 보이지 않게 숨김 처리합니다 |

- Dify Chat API의 `user` 값은 Next.js가 만든 불투명한 `dify_user`(예: HMAC(org:sub))를 넣습니다. 이 값이 대화에 저장된 `dify_user`와 같아야 FastAPI가 요청을 받습니다.
- 서명 토큰은 Dify에 넘기지 않습니다. Dify 입력값은 Dify DB와 콘솔 로그에 평문으로 남기 때문입니다.

### 5.2 흐름 (권장 골격)

| 순서 | 노드 | 내용 |
|---|---|---|
| 1 | 시작 | 사용자 질문 + `platform_conversation_id` |
| 2 | (선택) 질문 분류 | 보조 LLM 노드. 4장 모델 공급자 사용 |
| 3 | HTTP 요청 | `POST {FASTAPI}/tools/answer`, 헤더 `Authorization: Bearer {DIFY_INTERNAL_API_KEY}`(제품별 내부 키), 본문 `{"query": "{{사용자 질문}}", "platform_conversation_id": "{{platform_conversation_id}}", "user": "{{sys.user}}"}` (변수 문법은 구현 시 확인) |
| 4 | 응답 | FastAPI가 돌려준 `answer`와 `citations`를 그대로 출력 |

- 그래프 실행이 필요한 기능은 `POST {FASTAPI}/tools/graph/{name}`(내부 키 + 대화 매핑, 그래프별 허용 목록)을 같은 방식으로 부릅니다.
- 요청 본문에 조직 id를 넣지 않습니다. FastAPI는 내부 키를 확인한 뒤 `ai_conversations`에서 대화 존재, `status='active'`, `dify_user`와 `sys.user` 일치, app 일치를 확인하고 그 행의 org·user만 신뢰합니다.
- HTTP 노드의 실패는 오류로 사용자에게 보여 주고, 모의 답변으로 숨기지 않습니다.
- 노드 이름과 변수 문법(`{{ }}` 표기 등)은 설치한 Dify 버전 문서로 확인합니다(구현 시 확인).

## 6. 외부 지식 API (조직 구분 없는 지식만)

| 항목 | 내용 |
|---|---|
| 용도 | 해설집, FAQ처럼 모든 조직이 같이 보는 제품 공통 지식 |
| 연결 대상 | FastAPI `POST /dify/retrieval` (내부 API 키 인증) |
| 금지 | 조직 데이터. 외부 지식 API는 요청마다 조직을 넘길 수 없습니다 |
| 등록 | Dify의 "외부 지식 API" 설정 화면에서 엔드포인트와 API 키를 입력합니다(이름·형식은 구현 시 확인) |

## 7. 앱 키 관리

| 키 | 보관 | 금지 |
|---|---|---|
| Dify 앱 API 키(제품별) | 해당 제품 Next.js 서버 환경변수(예: `DIFY_APP_KEY`, `DIFY_BASE_URL`) | `NEXT_PUBLIC_` 접두사, 브라우저 코드, git |
| `DIFY_INTERNAL_API_KEY` | FastAPI와 Dify 모델 공급자 설정 | 다른 용도로 재사용 |
| `AI_TOKEN_PRIVATE_KEY` / `AI_TOKEN_JWKS_URL` | 개인키는 해당 제품 Next.js만, 공개키는 FastAPI | Dify에는 서명 키를 두지 않습니다 |

키는 분기마다 또는 유출이 의심되면 바꿉니다(제안). 교체 순서: 새 키 발급 → 제품 환경변수 교체 → 배포 → 옛 키 폐기.

## 7.1 Dify 데이터 보호

Dify DB는 조직 데이터 저장소로 취급합니다(`AI_ARCHITECTURE.md` 3장). 대화 로그에 사용자 발화와 HTTP 노드가 돌려준 근거 문서 내용이 남기 때문입니다.

| 항목 | 규칙 |
|---|---|
| 콘솔 계정 | 최소 인원만, 2단계 인증 사용, 가입 허용 끔, 퇴사·역할 변경 시 즉시 정리 |
| 로그 보존 | 대화 로그 보존 기간을 정해 주기적으로 삭제합니다(제안 30일). 개인정보 처리방침의 처리 위탁·보관 항목에 반영합니다 |
| 백업 | 8장 백업 파일은 암호화해 보관하고 보존 기간이 지나면 폐기합니다 |
| 접근 | 관리 화면은 접근 IP 제한(2장), 데이터베이스·Redis 포트는 외부에 열지 않습니다 |

## 8. 백업

| 대상 | 방법 |
|---|---|
| 데이터베이스(PostgreSQL 컨테이너) | 매일 덤프. 예: `docker compose exec db pg_dump -U <사용자> <DB명> > backup.sql` (서비스·DB 이름은 compose 파일에서 확인) |
| 업로드·볼륨 | `docker/volumes/` 폴더를 통째로 복사(서비스를 잠시 멈추고) |
| `.env` | 암호화된 비밀 저장소에 별도 보관 |
| 주기·보관 | 일 1회, 14일 보관(제안). 복원 연습을 분기마다 합니다 |

PowerShell 예시:

```powershell
$stamp = Get-Date -Format yyyyMMdd
docker compose exec -T db pg_dump -U postgres dify > "D:\WorkSpace\DEV\backup\dify-$stamp.sql"
```

## 9. 업그레이드

1. 업그레이드 전에 8장 백업을 합니다.
2. 공식 릴리스 노트와 마이그레이션 안내를 읽습니다(구현 시 확인).
3. 점검 창에서 진행합니다.

```bash
cd /d/WorkSpace/DEV/platform-dify/docker
docker compose down
git pull origin main        # 또는 고정할 릴리스 태그로 checkout
diff .env .env.example      # 새 변수가 있는지 확인
docker compose pull
docker compose up -d
```

```powershell
Set-Location D:\WorkSpace\DEV\platform-dify\docker
docker compose down
git pull origin main
Compare-Object (Get-Content .env) (Get-Content .env.example)
docker compose pull
docker compose up -d
```

4. 제품별 Chatflow 앱이 동작하는지(대화 id 전달, HTTP 노드, 출처 표시) 스모크 테스트합니다(대화 매핑 전달 포함).
5. 운영에서는 `main`을 따라가지 말고 릴리스 태그로 고정하는 것을 권장합니다(제안).

## 10. 점검표

| 점검 | 기대 |
|---|---|
| Dify 앱 키가 클라이언트 번들에 없다 | 예 |
| HTTP 노드 본문에 org 값이 없고 내부 키 + 대화 id + `sys.user`만 있다 | 예 |
| 내부 키 없이, 또는 `sys.user`가 다른 값으로 `/tools/answer` 호출 | 401/403 |
| 종료·보관된 대화 id로 `/tools/answer` 호출 | 403 |
| Dify 입력 변수·로그에 서명 토큰이 없다 | 예 |
| 외부 지식 API에 조직 데이터가 없다 | 예 |
| 백업 복원 연습 기록이 있다 | 분기 1회 |
