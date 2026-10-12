# 07 원본 이식과 폐기: NOMAD Blog

작성일 2026-10-12. CA 경로는 `NOMAD Shorts Maker/` 기준, YSM은 `[5f6d262] Youtube_shots_Maker/`(git 스냅샷, `git show`로만 읽음) 기준이다.

## 1. 원본별 자산 분류

### 1.1 NOMAD Shorts Maker 안의 Content Automator

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `src/skill/ai-engine/content-generator.ts` | 동작 | 이식(프롬프트 구조만) | `src/server/ai/prompts/` | `:10-47` |
| `src/skill/ai-engine/keyword-recommender.ts` | 동작 | 이식(추천 프롬프트, SEO 규칙) | `src/server/ai/prompts/`, `packages/blog-render`(SEO 규칙) | `:37-103` |
| `src/skill/ai-engine/hashtag-generator.ts` | 동작 | 참고(태그 추천으로 축소) | `src/server/ai/prompts/` | `:32-56` |
| `src/skill/channel-api/wordpress-client.ts` | 부분 | 이식 | `workers/blog-worker/src/channels/wordpress/` | `:17-70` |
| `src/skill/channel-api/coupang-client.ts` | 부분 | 참고(core-affiliate 쿠팡 어댑터 구현자에게 전달) | `packages/core-affiliate`(코어 소관) | `:5-41` |
| `src/skill/channel-api/instagram-client.ts` | 부분 | 폐기(sns-uploader로 일원화) | - | `docs/products/00_MERGE_ANALYSIS.md:632` |
| `src/skill/channel-api/my-blog-client.ts` | 부분 | 폐기(발신 웹훅으로 대체) | - | 3.2절 |
| `src/skill/playwright-engine/naver-blog-poster.ts` | 부분 | 이식 | `workers/blog-worker/src/channels/naver/` | `:15-56` |
| `src/skill/playwright-engine/naver-login.ts` | 부분 | 이식(우회 코드 제거) | 같은 곳 `login.ts` | `:9-63` |
| `src/skill/playwright-engine/tistory-poster.ts` | 부분 | 이식 | `workers/blog-worker/src/channels/tistory/` | `:20-85` |
| `src/skill/playwright-engine/brand-connect.ts` | 부분 | 이식 | `workers/blog-worker/src/handlers/brandconnect/` | `:22-134` |
| `src/skill/schedule-engine/queue-processor.ts`, `cron-handler.ts` | 부분 | 참고(cron 파서만, Phase 2) | - | `docs/reviews/NOMAD_Shorts_Maker.md:85` |
| `src/skill/automation-engine/*` | 부분 | 폐기(automation-core로) | - | `docs/products/00_MERGE_ANALYSIS.md:958` |
| `src/skill/meta-engine/token-refresher.ts` | 부분 | 폐기(sns-uploader 소관) | - | `:8-20` |
| `src/components/posts/MultiChannelEditor.tsx`(517줄) | 부분 | 참고(5탭 구성), 분할 재작성 | `src/app/(app)/posts/[id]/` | `docs/reviews/NOMAD_Shorts_Maker.md:62`, `:106` |
| `src/components/posts/AiGeneratePanel.tsx`, `CoupangLinkPanel.tsx`, `ChannelSelector.tsx`, `ChannelStatusModal.tsx` | 부분 | 참고 | `src/components/editor-shell/` | - |
| `src/components/posts/AutomationModeSelector.tsx` | 부분 | 폐기(reactflow/n8n/make 모드 선택 제거) | - | 3.2절 |
| `src/hooks/useCoupang.ts`, `usePosts.ts`, `useSchedules.ts`, `useChannelAccounts.ts` | 부분 | 폐기(TanStack Query + 새 API로) | - | - |
| `src/app/api/{posts,ai,coupang,brand-connect,accounts,schedules,publish,linkinbio,meta}` | 부분 | 참고(입출력 형태만) | `src/app/api/` | `docs/reviews/NOMAD_Shorts_Maker.md:81` |
| `supabase/migrations/001_initial.sql` | 부분 | 폐기(재매핑) | 05장 | `docs/products/00_MERGE_ANALYSIS.md:665` |
| `src/lib/plans.ts` | 동작 | 참고(가격·월 발행 수만) | 01장 4.1절 | `:18-71` |
| `src/lib/crypto.ts` | 부분 | 폐기(코어 vault) | - | `:4` |
| `src/taste/content-automator/*` | 부분 | 폐기 | - | `docs/products/00_MERGE_ANALYSIS.md:673` |

### 1.2 Youtube_shots_Maker Track D

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `backend/services/naver_blog.py` | 부분 | 이식(절차만 TS로) | `workers/blog-worker/src/channels/naver/` | `:180-288` |
| `backend/services/blog_writer.py` | 부분 | 참고(스타일 개념만), 프롬프트 폐기 | - | `:31-59` |
| `backend/tasks/blog_pipeline.py` | 부분 | 참고(재시도 간격 구조) | `workers/blog-worker/src/runtime/` | `:41-42` |
| `backend/models/blog.py` | 부분 | 참고(API 필드) | 04장 | `:17-36` |
| `backend/routers/blog.py` | 부분 | 폐기(FastAPI) | - | `docs/reviews/Youtube_shots_Maker.md:85` |
| `backend/services/naver_shopping.py` | 부분 | 폐기(Mock 폴백), API 형태만 참고(미확인) | - | `:153-182` |
| `backend/services/account_manager.py`(1,146줄) | 부분 | 참고(AES-GCM 키 길이 검증만, 코어 vault 구현자에게 전달) | - | `docs/reviews/Youtube_shots_Maker.md:165` |
| `backend/services/proxy_manager.py` | 부분 | 폐기(blog는 프록시 순환을 쓰지 않음, 01장 6.4절) | - | - |
| `app/api/auth/naver/*` | 부분 | 폐기 | - | `docs/reviews/Youtube_shots_Maker.md:84` |

### 1.3 nomad-ai-commerce, nomad-ai-factory

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `nomad-ai-commerce/app/api/blog/post/route.ts` | 부분 | 폐기 | - | `docs/reviews/nomad-ai-commerce.md:63` |
| `nomad-ai-commerce/PRD.md` 11단계 | 기획만 | 참고(워드프레스 발행 요구) | BL-F-040 | `nomad-ai-commerce/PRD.md:60-62` |
| `nomad-ai-factory/CLAUDE.md` GEO 블로그 3버전 | 기획만 | 참고(템플릿 info/essay/compare) | BL-F-011 | `nomad-ai-factory/CLAUDE.md:234`, `:242` |
| `nomad-ai-factory` BlogNode | 목업 | 폐기 | - | `nomad-ai-factory/CLAUDE.md:303` |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| `naver-blog-poster.ts` + `naver_blog.py` | (1) Route Handler 동기 실행 → 워커 잡 (2) 세션 쿠키는 vault에서 복호화 (3) 셀렉터를 상수 파일로(`#subject`, `.se-iframe`/`mainFrame`, 태그 입력, 발행 버튼) (4) `fill()`로 iframe 본문을 덮던 방식 대신 HTML 붙여넣기 이벤트 사용(정확한 방법은 구현 시 검증) (5) 태그 최대 10개 (6) 발행 후 URL을 확인하지 못하면 `unconfirmed`(YSM은 현재 URL을 성공으로 반환) (7) 랜덤 지연·마우스 이동·`AutomationControlled` 숨김 제거 (8) 대가성 문구가 첫 블록인지 입력 후 재확인 |
| `naver-login.ts` | JS로 입력값 직접 주입("봇 감지 우회", `:22`) 제거, 일반 입력 사용. CAPTCHA·추가 인증 감지 시 즉시 중단하고 `needs_reauth`. 로그인 화면 스크린샷 금지 |
| `tistory-poster.ts` | 카카오 아이디·비밀번호 평문 인자 → vault. 위와 같은 실패 처리. 공식 API 확인 시 어댑터 교체(미확인) |
| `wordpress-client.ts` | 사이트 URL SSRF 검사(https, 공인 IP, 리다이렉트 2회), 태그 생성 실패를 무시하지 않음, `status` 기본값 publish 유지, 타임아웃 30초, 401 → 채널 error |
| `brand-connect.ts` | `bc_${Date.now()}` 가짜 id 대신 실제 지원 번호 또는 null, 성공 판정 실패를 성공으로 반환하지 않음, `.catch(() => null)` 제거, 지원 메시지 기본 문구는 사용자 확인 후, 레이트 리밋, 위험 동의 확인 |
| `keyword-recommender.ts` | 직접 `fetch` Anthropic 호출 → llm gateway, 폴백 제거, 이모지 피드백(`:82-100`) 제거 |
| `content-generator.ts` | OpenAI SDK + OpenRouter → gateway, 마크다운 출력 → TipTap JSON 스키마, 금지 지시 추가 |
| `001_initial.sql` 매핑 | `channel_accounts` → `blog.channel_accounts` + `core.encrypted_credentials`. `blog_posts` → `blog.posts`. `post_channels` + `schedules` → `blog.post_publications` + `core.jobs`. `coupang_links` → `core.affiliate_links` + `blog.post_affiliate_links`. `brand_connect_items` → `core.brandconnect_applications`. `automation_configs` → Phase 2(automation-core). `linkinbio_items`, `user_profiles` → video 소관(링크인바이오는 video 소유, 확정 결정 1). 데이터 이관은 원본에 실사용자가 없으므로 하지 않는다(제안) |

## 3. 폐기 목록과 사유

### 3.1 분석에서 "폐기"로 분류한 항목(그룹 C 전부 + 블로그 관련 그룹 D)

| 대상 | 사유 | 근거 |
|---|---|---|
| YSM FastAPI 라우터 9개, Celery와 beat, Next 14 프론트, `start.ps1`, Dockerfile 2종, `docker-compose.yml`, `railway.toml` | 2세대로 대체, 서비스 함수만 이식. blog는 네이버 게시 절차만 TS로 가져옴 | `docs/products/00_MERGE_ANALYSIS.md:660` |
| YSM 작업 트리 잔해(pyc, `.venv`, `node_modules`, `.next`, 평문 키 `.env`) | 실행 불가, 키 유출 위험. 태그 보존 후 삭제(5절) | `:661` |
| YSM role/plan 이중 권한, 기본 등급 `admin` 표시 | 권한 오인. blog는 코어 org 역할 + 엔타이틀먼트 | `:662` |
| BS 저장소 자체 | v0.3.0 하위 집합. blog는 BS에서 가져올 것이 없음 | `:663` |
| BS 002 마이그레이션 중복 RLS, `increment` 함수 | 의미 오류 | `:664` |
| SM `001_initial.sql`(CA user 기준 9테이블), `002_billing.sql` | org 기준으로 재매핑(2절) 후 제거 | `:665` |
| SM 플랜 정의 3벌 | blog 플랜은 `core.plans` 한 곳(01장 4장) | `:666` |
| SM 결제 두 번째 경로(웹훅 orderId 파싱) | 위조 요청만 통과 | `:667` |
| `x-internal-call` 우회, `fetch(APP_URL+'/api/…')` 자기 호출 | 인증 우회. CA 큐 프로세서와 발행 라우트에 있었음 | `:668`, `NOMAD Shorts Maker/src/skill/schedule-engine/queue-processor.ts:62-66` |
| Mock 로그인(`lib/mock-auth.ts`) | 프로덕션 노출 | `:669` |
| LLM 클라이언트 3종, YSM Anthropic 직접 호출 | gateway 하나 | `:670` |
| Python 워커가 BullMQ 프로토콜을 흉내 내는 방식 | blog는 Python 워커 없음 | `:671` |
| 플레이보드 난수 성장률, 대시보드 더미 배열 | 가짜 지표. blog 대시보드도 실데이터만 | `:672` |
| 루트 문서 분기본, `taste-skill*.ts`, `files.zip`, `src/taste/content-automator` 테마 | 문서·테마 중복. CA 테마는 blog 토큰(03장 4.3절)으로 대체 | `:673` |
| Remotion, CapCut 익스포트 | blog와 무관(video 결정) | `:674` |
| ioredis 루트 직접 의존 | blog는 Redis 미사용 | `:675` |
| YouTube Live 24h | MVP 범위 밖(video) | `:598` |
| Supabase Edge Functions 3종(CA `process-schedule` 포함) | Next 라우트와 중복. blog 스케줄은 core.jobs `run_after` | `:643` |
| 제휴 링크 매칭 MonetizeNode(v1) | D 쪽 폐기, 기능은 affiliate 모듈 + blog 자동 삽입 | `:814` |
| CM `execute-flow` 자기 호출, `tableName` insert(블로그 원고 라우트 포함) | 보안 결함 | `:865` |

### 3.2 blog 자체 폐기 결정

| 대상 | 사유 |
|---|---|
| CA "내 블로그" 클라이언트(`my-blog-client.ts`) | 사용자 지정 URL로 키를 보내는 범용 POST는 SSRF·키 유출 위험. Phase 2 발신 웹훅(서명)으로 대체 |
| CA 자동화 모드 선택(reactflow/n8n/make 발행 모드) | 발행 경로를 core.jobs 하나로. n8n 모드는 콜백 전에 스케줄을 done 처리했다(`queue-processor.ts:102`) |
| Mock 브랜드커넥트 추천(`brand-connect/recommend/route.ts`) | 가짜 캠페인 표시 |
| 브랜드커넥트 "지원" 라우트가 DB 행만 만들고 제출하지 않던 구조(`brand-connect/apply/route.ts:15-29`) | 실제 제출 잡으로 대체 |
| 쿠팡 통계의 `revenue`/`conversion_count` 컬럼 | 갱신 경로 없음 → 0이 실적처럼 보임 |
| 해시태그·키워드 폴백 데이터 | 장애를 가짜 결과로 숨김(`SECURITY_BASELINE.md` 11장) |
| YSM 블로그 프롬프트와 LLM 실패 폴백 원고(`blog_writer.py:142-148`) | 가상 후기 요구, 가짜 원고 저장 |
| YSM 프록시 풀 | 자동화 탐지 회피 목적 사용 금지(01장 6.4절) |
| CA 인스타그램 클라이언트, Meta 토큰 갱신 | sns-uploader(video 소유)로 일원화 |

## 4. 복사 금지 결함

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 크레딧 RPC EXECUTE 미회수 | `docs/reviews/NOMAD_Shorts_Maker.md:78` | 브라우저에서 크레딧 지급 | 코어 RPC(service_role), 제품 함수 EXECUTE 허용 목록 |
| 웹훅 서명 선택적 검증, orderId 파싱 | `:79-80` | 위조 결제 | 공용 webhooks, `payment_orders` |
| `x-internal-call`, 자기 HTTP 호출 | `:81` | 인증 우회 | 잡 + 함수 직접 호출 |
| OAuth state 위조 | `:82`, `docs/reviews/Youtube_shots_Maker.md:83` | 타인 계정 연결 | `create/consume_oauth_state` |
| 0키 폴백 | `docs/reviews/NOMAD_Shorts_Maker.md:84` | 사실상 평문 | 키 없으면 기동 실패 |
| 세션 쿠키 평문 저장 | `NOMAD Shorts Maker/src/app/api/accounts/[id]/connect/route.ts:30` | DB 유출 시 네이버 계정 탈취 | `encrypted_credentials` |
| 세션 없는 백그라운드 작업 | `docs/reviews/NOMAD_Shorts_Maker.md:85` | 조용한 무동작 | 서비스 클라이언트 + 0행 오류 |
| `CRON_SECRET` 미설정이면 통과(`if (!internalCall && cronSecret && ...)`) | `NOMAD Shorts Maker/src/app/api/schedules/run/route.ts:23` | 누구나 큐 실행 | 공개 크론 라우트 없음 |
| Route Handler 안 Playwright 동기 실행(`maxDuration 120`) | `NOMAD Shorts Maker/src/app/api/posts/[id]/publish/route.ts:16`, `:217-241` | 서버리스 타임아웃, 중복 발행 | 워커 잡 |
| 발행 결과 불확실을 성공으로 반환하고 실패 시 자동 재시도 | `[5f6d262] Youtube_shots_Maker/backend/services/naver_blog.py:285-288`, `backend/tasks/blog_pipeline.py:258-261` | 중복 게시 | `unconfirmed` + 사용자 확인 |
| 봇 감지 우회(입력값 JS 주입, 랜덤 마우스, `AutomationControlled` 숨김, 프록시 순환) | `NOMAD Shorts Maker/src/skill/playwright-engine/naver-login.ts:22`, `[5f6d262] .../naver_blog.py:17-22`, `:155-170` | 약관 위반 가능성 증가, 계정 정지 위험 | 일반 입력, CAPTCHA 시 중단 |
| 가상 후기 프롬프트("실사용 후기 (구체적 수치)", "내돈내산") | `[5f6d262] .../blog_writer.py:41`, `:56` | 표시광고법 위반 소지 | 01장 6.5절 금지 지시, 체험형은 사용자 메모 필수 |
| sanitize 없는 `dangerouslySetInnerHTML` | `NOMAD Shorts Maker/src/components/posts/MultiChannelEditor.tsx:316` | XSS | 서버 렌더 + sanitize |
| 키 없을 때 Mock 데이터 반환 | `[5f6d262] .../naver_shopping.py:153-182`, `NOMAD Shorts Maker/src/app/api/brand-connect/recommend/route.ts:3` | 가짜 결과 | 오류 표시 |
| 전역 env 제휴 키(`COUPANG_ACCESS_KEY`) | `NOMAD Shorts Maker/src/skill/channel-api/coupang-client.ts:8-11` | 테넌트 격리 붕괴, 모든 사용자가 운영자 수익 계정 사용 | 조직별 vault |
| 사용자 지정 사이트 URL로 서버 fetch(SSRF) | `NOMAD Shorts Maker/src/app/api/accounts/[id]/connect/route.ts:41`, `:53` | 내부망 접근 | 공인 https만, 리다이렉트 제한 |
| cron 다음 실행을 서버 로컬 시간대로 계산 | `NOMAD Shorts Maker/src/skill/schedule-engine/cron-handler.ts:17-41` | KST/UTC 경계 오류 | KST 명시(Phase 2) |
| 태스크 결과 IDOR | `docs/reviews/Youtube_shots_Maker.md:85` | 타인 원고 노출 | core.jobs RLS |
| 네이버 이메일 자동 병합 | `:84` | 계정 탈취 | 미도입, 명시적 연결 |
| 예외 원문을 응답·URL로 노출 | `:88` | 내부 정보 누출 | 응답 봉투 사용자 문구 |
| 실키 `.env` 방치 | `:89` | 키 유출 | BL-06-035 |
| `user_plans FOR ALL`, 클라이언트 플랜 판정 | `SECURITY_BASELINE.md` 14장 | 셀프 업그레이드 | 엔타이틀먼트 서버 판정 |
| 한글에 `\b` 금지어 매칭 | `SECURITY_BASELINE.md` 14장 | 필터 무효 | compliance 공용 규칙 |

## 5. 아카이브 절차

| 단계 | 내용 | 승인 |
|---|---|---|
| 1 | YSM: `git tag archive/youtube-shots-maker-v1 5f6d262`(리뷰 권고 `docs/reviews/Youtube_shots_Maker.md:145`) | 사용자 |
| 2 | YSM 작업 트리 잔해(pyc, `.venv`, `node_modules`, `.next`, `tsconfig.tsbuildinfo`) 삭제와 루트 `.gitignore` 보강 | 사용자 |
| 3 | YSM `backend/.env`, `.env.local`과 Shorts Maker `.env.local`의 키 목록 대조 → 공유 키(OpenRouter, Anthropic, Supabase service key, 암호화 키) 재발급 → 파일 삭제(BL-06-035) | 사용자 |
| 4 | Shorts Maker: CA 부분(`src/skill/**`, `src/components/posts/*`, `001_initial.sql`, `src/taste/content-automator`)은 video 저장소 정리 시 `archive/content-automator`로 이동(video 계획과 조율) | video 담당 + 사용자 |
| 5 | `files.zip` 등 중복 압축본은 내용 동일 확인 후 삭제 | 사용자 |
| 6 | 이식 완료 파일 목록과 원본 커밋 해시를 `docs/migration/`에 기록(BL-06-033) | - |
