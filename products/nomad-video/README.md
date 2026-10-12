# NOMAD AI Factory (nomad-video)

## 1. 한 줄 정의

여러 YouTube 채널(최대 40개)과 IG/TikTok/Threads를 운영하는 1인 크리에이터, 커머스 운영자, 소규모 에이전시가 트렌드 레이더로 소재를 고르고, 숏폼(Track A~C), 롱폼(Track D), Lofi 단일 곡(Track E), 플레이리스트(Track F)를 크레딧 과금으로 자동 생산, 검사, 다채널 배포, 제휴 수익화까지 하는 조직 단위 SaaS다.

| 대상 사용자 | 상황 |
|---|---|
| 1인 숏폼 크리에이터 | 중국 드라마·상품 숏폼을 KO/JA/EN으로 더빙해 광고와 쿠팡파트너스 수익을 낸다 |
| 음원/플리 채널 운영자 | Suno로 Lofi 곡을 만들고 단일 곡 루프 영상과 무드별 플리 영상을 올린다 |
| 소규모 에이전시(Advanced) | 팀 5인이 40채널을 나눠 운영한다 |

## 2. 통합 근거

| 근거 | 내용 |
|---|---|
| 같은 제품의 세 세대 | Youtube_shots_Maker(1세대, FastAPI+Celery) → Nomad-BlogStudio(v0.3.0, 이름과 달리 숏폼 제품) → NOMAD Shorts Maker(v0.4.0)는 같은 파이프라인을 다룬다(`docs/products/00_MERGE_ANALYSIS.md:507-510`, `docs/reviews/Youtube_shots_Maker.md:69-76`, `docs/reviews/Nomad-BlogStudio.md:4`) |
| 베이스 | NOMAD Shorts Maker. 가장 최신 기획(v0.4.0)이고 BlogStudio 기능의 상위 집합이며 구현 범위가 가장 넓다(`docs/products/00_MERGE_ANALYSIS.md:527-530`) |
| 가져오는 것 | BlogStudio의 라우트 가드·서버 컴포넌트 조회 패턴, YSM의 Python 서비스 4종 중 미디어 관련(demucs, 다운로더, 프록시 풀, AES-GCM 방식)(`docs/products/00_MERGE_ANALYSIS.md:532-534`) |
| 확정 결정 1 | 블로그는 별도 제품(nomad-blog). video는 링크인바이오와 Track B 랜딩을 소유하고 공용 모듈만 공유 |
| 확정 결정 6 | TS(BullMQ FlowProducer) 오케스트레이션 + Python(Whisper, demucs, FFmpeg) 미디어 처리 |
| 확정 결정 7 | MVP = Track A~F 전부. Distrokid 자동 배포, 24시간 라이브, 보이스 클로닝은 2단계 |
| 확정 결정 8 | 플랜 정본 `NOMAD Shorts Maker/PRD_pricing.md` |
| 확정 결정 10 | 브랜드 NOMAD AI Factory, 폴더 `nomad-video` |
| 확정 결정 12 | 제휴는 `_platform-core` affiliate 모듈. 모든 Track 설명란·고정 댓글에 제휴 링크와 대가성 문구 자동 삽입 |

## 3. 원본 매핑

| 원본 프로젝트 | 리뷰 파일 | 완성도(리뷰 1장) | 가져오는 것 | 버리는 것 |
|---|---|---|---|---|
| NOMAD Shorts Maker | `docs/reviews/NOMAD_Shorts_Maker.md` | 약 35%(`:25`) | PRD/PRD_add/PRD_pricing 기획, 랜딩·대시보드 UI 셸, `lib/media/*`(무음컷, 켄번스, 레이어, 워터마크), `lib/platforms/*`(YouTube, Meta, TikTok, 쿠팡, Suno), `lib/radar/*`, `workers/*.py` 로직, 링크인바이오·랜딩 페이지 | Content Automator 블로그 코드(nomad-blog로 이관), user 기반 마이그레이션, 플랜 정의 3벌, Mock 로그인, `x-internal-call`, Edge Functions 3종, Remotion/CapCut 기획 |
| Nomad-BlogStudio | `docs/reviews/Nomad-BlogStudio.md` | 약 30%(`:19`) | 미들웨어 가드 패턴, 서버 컴포넌트 조회, zod/RHF/TanStack 구성, 롱폼 API 골격 | 저장소 전체(v0.3.0 하위 집합), 002 중복 RLS, `increment` 함수, 목업 API |
| Youtube_shots_Maker | `docs/reviews/Youtube_shots_Maker.md` | 작업 트리 약 5%, 스냅샷 `5f6d262` 기준 55~60%(`:36-38`) | `downloader.py`, `audio_separator.py`, `proxy_manager.py`, `stt.py`의 Whisper 처리, `geo_metadata.py` 프롬프트, AES-GCM 구현 방식 | FastAPI 라우터 9개, Celery, Next 14 프론트, 네이버 로그인 이메일 병합, role/plan 이중 권한, 블로그 서비스(nomad-blog로 이관) |

## 4. 문서 목록

| 파일 | 내용 |
|---|---|
| `01_PRD.md` | 페르소나, Track A~F 범위, 기능 요구사항과 수용 기준, 플랜·크레딧, 비기능, 법·금지 문구, KPI, 열린 결정 |
| `02_ARCHITECTURE.md` | 스택, 모듈 경계, 공용 모듈 사용, 잡/큐, AI 라우팅, 리뷰 "높음" 차단 설계(비보안), 배포, 환경변수 |
| `03_SCREENS_UX.md` | 화면 목록, 플로우, 화면 명세, 랜딩 디자인 방향, 상태 화면 |
| `04_API.md` | Route Handler, RPC, 잡 페이로드, 웹훅, 외부 어댑터, 오류 코드 |
| `05_DATA_MODEL.md` | 테이블 22개, 상태 전이, RLS, 리뷰 "높음" 차단 설계(보안·데이터) |
| `06_AGENT_PLAN.md` | 작업 40개, 웨이브, 모델 비율, 리뷰 작업 흡수표 |
| `07_SOURCE_MIGRATION.md` | 원본별 이식/폐기, 복사 금지 결함, 아카이브 절차 |
| `CLAUDE.md` | 개발 에이전트 지침 |
| `supabase/monolith/` | `0001_core_lite.sql`(코어 복사본), `0002_video_domain.sql`(모듈러 조각 변환본), `seed.sql` |
| 모듈러 조각 | `docs/products/_supabase-modular/migrations/1200_video.sql` |

## 5. DB 구조 선택

| 항목 | 결정 | 근거 |
|---|---|---|
| 1차(출시) | 모듈러(통합) `video` 스키마 | 크레딧 지갑, SNS 업로더, 커머스·블로그와 같은 계정을 공유해야 한다(`docs/products/_supabase-modular/ARCHITECTURE.md` 3장 nomad-video 행) |
| 모놀리스 | 같은 도메인 모델을 `public` 스키마로 변환해 둔다(고객사 분리나 장애 격리가 필요할 때) | `docs/products/_platform-core/DB_CONVENTIONS.md` 12장. `public` 스키마는 사용자 최종 확인 대기 |
