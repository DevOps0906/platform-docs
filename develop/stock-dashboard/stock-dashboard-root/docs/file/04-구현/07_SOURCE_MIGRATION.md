# 07 원본 이식과 폐기: Stock Dashboard

작성일 2026-10-12. 원본 `구현해야 할 프로젝트/Stock_Trader_nomad`는 문서 2개(`PRD.md` 61행, `claude.md` 32행)뿐이고 코드가 없다(`docs/reference/reviews/Stock_Trader_nomad.md:3`). 따라서 "이식"은 요구사항과 화면 지침의 이식이며, 코드 자산은 리뷰 4.3이 지목한 다른 워크스페이스 모듈을 `_platform-core` 경유로 쓴다.

AI 관련 원본 자산(2026-10-13 점검): 원본의 AI 사용은 PRD 3.3의 멀티 AI 어드바이저(GPT-4o, Sonnet 3.5, Opus 4.5, Haiku 4.5 모델명 하드코딩, 3사 x 4전략, 매수가/목표가/손절가 카드, `PRD.md:32-36`)와 `claude.md` 2.2의 우측 AI 패널뿐이다. RAG, 위키, Dify, 음성, 3D는 원본에 없어 모두 신규다(확정 결정 13~17). 매핑: 어드바이저 → 그래프 `stock.diagnosis`(가격 카드 폐기, 위험 수준은 서버 규칙), 3사 비교 → Phase 2(코어 요청 R-8), AI 패널 위치 → 채팅 패널(03장 3.7절), 모델 토글 → 라우터 설정(코드에 모델명 없음), 리더보드 → Phase 2 내부용. 신규 AI 기능은 `docs/reference/reviews/Stock_Trader_nomad.md`의 리뷰 #3(투자 권유), #16(모델명)을 차단 설계로 흡수한다.

## 1. 원본별 자산 분류

### 1.1 Stock_Trader_nomad

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `PRD.md` 3.1 멀티 브로커 통합 조회(증권사/Total 탭, 스켈레톤) | 기획만 | 이식(증권사 1곳, 모의 계좌로 축소) | ST-F-003, ST-F-006, ST-06-012/017 | `PRD.md:21-24`, `docs/reference/00_MERGE_ANALYSIS.md:1276` |
| `PRD.md` 3.1 "스크래핑" 대안 | 기획만 | 폐기(영구) | - | `PRD.md:22`, `docs/reference/00_MERGE_ANALYSIS.md:1281` |
| `PRD.md` 3.2 실시간 시세, 블링크, 당일 라인 차트 | 기획만 | 이식(상주 워커 중계 + zustand) | ST-F-007, ST-06-015/016 | `PRD.md:26-30`, `docs/reference/00_MERGE_ANALYSIS.md:1277` |
| `PRD.md` 3.3 멀티 AI 어드바이저(3사 x 4전략, 매수가/목표가/손절가 카드) | 기획만 | 이식 축소: MVP는 AI 1개 진단(가격 없음), 3사 비교는 Phase 2. 가격 카드는 폐기(법률 검토 전) | ST-F-011, ST-F-014 | `PRD.md:32-36`, `docs/reference/00_MERGE_ANALYSIS.md:1278` |
| `PRD.md:36` 리스크 레벨 "안전, 위험, 위험함" | 기획만 | 디벨롭: 낮음/중간/높음 + 서버 판정 규칙 | 02장 5절 | `docs/reference/reviews/Stock_Trader_nomad.md:53` |
| `PRD.md` 3.4 AI 추천 성과 리더보드 | 기획만 | 이식(내부 전용, `idea-eval-v1` 규칙 고정, Phase 2). 공개는 폐기 | ST-F-013 | `docs/reference/00_MERGE_ANALYSIS.md:1279` |
| `PRD.md:41` "+52.23%" 수익률 예시 | 기획만 | 폐기(허위 수치 금지 문구 예) | 01_PRD 6.6 | `PRD.md:41` |
| `PRD.md` 3.5 매매 일지 자동 동기화, 종목 상세 모달(PER/PBR/ROE/EPS/배당) | 기획만 | 이식(조회 전용) | ST-F-008, ST-F-009 | `docs/reference/00_MERGE_ANALYSIS.md:1275`, `:1280` |
| `PRD.md` 4장 스택(Context API / TanStack Query, Recharts / Chart.js) | 기획만 | 디벨롭: Recharts 하나, 시세는 zustand, 서버 데이터만 TanStack Query. Context로 시세 관리 폐기 | 02장 1절 | `docs/reference/reviews/Stock_Trader_nomad.md:16`, `:48` |
| `PRD.md` 5장 GEO, JSON-LD 금융 스키마 | 기획만 | 폐기(법률 검토 전 보류) | - | `docs/reference/00_MERGE_ANALYSIS.md:1282` |
| `claude.md` 1장 다크 테마(Deep Slate/Charcoal, Neon Green/Red/Amber) | 기획만 | 참고: 다크 기본은 유지, 색은 03장 토큰으로 교체(한국 관례 상승 빨강/하락 파랑) | 03장 4.3 | `claude.md:6-8`, `docs/file/03-설계/디자인/REFERENCES.md:207` |
| `claude.md` 2.1 `setInterval` 목업 시세 | 기획만 | 디벨롭: `MockBroker`가 같은 어댑터 계약으로 제공 | ST-06-008 | `docs/reference/reviews/Stock_Trader_nomad.md:47` |
| `claude.md` 2.1 원자적 상태 분리 | 기획만 | 이식(종목별 셀렉터) | ST-06-016 | `claude.md:17` |
| `claude.md` 2.2 우측 AI 패널, 모델 토글, 전략 버튼 | 기획만 | 참고: 패널 위치 유지, 모델 버전 뱃지 하드코딩 폐기 | 03장 3.1 | `claude.md:20-21` |
| `claude.md` 2.3 블러 Dialog 모달, Recharts 녹색 라인 | 기획만 | 이식(색은 토큰) | ST-06-018 | `claude.md:24-25` |
| `claude.md` 3장 룰 2 실존 종목 + 극단 수익률 목업 | 기획만 | 디벨롭: 실존 종목명 사용 가능, 모든 표시값에 "샘플 데이터" 배지 | 01_PRD 6.3 | `claude.md:31`, `docs/reference/reviews/Stock_Trader_nomad.md:56` |
| `claude.md` 3장 룰 3 마이크로데이터 `itemprop` | 기획만 | 폐기(GEO와 함께) | - | `claude.md:32` |
| 서비스명 "InvestGEN" | 기획만 | 보류(상표 확인 전) | 01_PRD D-6 | `PRD.md:4` |

### 1.2 리뷰 4.3이 지목한 재사용 모듈(다른 원본)

| 자산 | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `basic-master-module` 의존성 기준선 | 동작(골격) | 참고(버전 기준) | ST-06-006 | `docs/reference/reviews/Stock_Trader_nomad.md:92` |
| `sellingstudio/lib/supabase/{client,server,admin}.ts`, `proxy.ts`, shadcn UI 14종 | 동작 | 이식(코어 auth 패키지 경유) | `packages/core-db`, ST-06-006 | `docs/reference/reviews/Stock_Trader_nomad.md:93`, `SHARED_MODULES.md:51` |
| `sellingstudio/lib/llm/openrouter.ts` | 동작 | 이식(코어 llm gateway 경유, 스트리밍은 게이트웨이 보강분) | `packages/core-ai` | `docs/reference/reviews/Stock_Trader_nomad.md:93`, `SHARED_MODULES.md:202-204` |
| `Hospital/src/components/dashboard/{kpi-card,revenue-chart}.tsx`, `sidebar.tsx` | 동작 | 참고(구조만, 토큰 교체) | ST-06-011, ST-06-017 | `docs/reference/reviews/Stock_Trader_nomad.md:94` |
| `NOMAD Shorts Maker/src/lib/crypto.ts`(AES-256-GCM) | 부분(0키 폴백 결함) | 이식은 코어 vault 경유. 제품이 직접 복사하지 않음 | `packages/core-auth` | `docs/reference/reviews/Stock_Trader_nomad.md:95` |
| Flora-v2 SSE 교훈, ERP-Wesite RLS/Realtime 교훈 | - | 참고 | 02장 5절, 05장 | `docs/reference/reviews/Stock_Trader_nomad.md:96-97` |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| 대시보드 화면 구성 | 증권사 탭은 `broker_connections` 행에서 동적으로 생성(하나/키움 하드코딩 금지). 상승/하락 색은 토큰. 고지 하단 고정 |
| 시세 블링크 | Context 대신 zustand 셀렉터, `prefers-reduced-motion` 대응, 지연 배지 추가 |
| AI 어드바이저 | 매수가/목표가/손절가 카드 제거, 위험 수준은 서버 규칙, 출력 zod + DB CHECK, 크레딧 선차감, 모델명은 설정 |
| 리더보드 | 공개 → 조직 내부, 계산 규칙 고정, 표본 20건 기준, 고지 |
| 매매 일지 | 수동 입력 없음(동기화), 메모만 사용자 쓰기, CSV |
| 종목 상세 모달 | 재무지표 출처·기준기간 필수, 차트 데이터는 사용자 본인 시세 |
| Supabase 클라이언트·proxy | 역할 분기는 `session_context`, 베타·동의 리다이렉트 추가, 프로필 없으면 로그아웃 |
| 암호화 | 0키 폴백 제거된 코어 vault 사용, `key_version` 기록 |
| LLM 클라이언트 | 브라우저 직접 호출 금지, `ai_usage` 기록, 폴백 1회, 실패 환불 |

## 3. 폐기 목록과 사유

분석의 "폐기" 행은 3개(`docs/reference/00_MERGE_ANALYSIS.md:1281-1283`)이고 항목으로는 4개다. 전부 적는다.

| # | 폐기 항목 | 분석 근거 | 사유 |
|---|---|---|---|
| 1 | 스크래핑(증권사 ID/비밀번호·인증서 기반 조회) | `00_MERGE_ANALYSIS.md:1281` "폐기(영구)" | 증권사 ID/비밀번호·인증서를 서버에 저장하게 되고(리뷰 #1), 약관 위반·계정 차단 위험과 마이데이터 허가 영역 문제(리뷰 #4). API 어댑터만 허용 |
| 2 | 공개 GEO, JSON-LD 금융 스키마(마이크로데이터 포함) | `00_MERGE_ANALYSIS.md:1282` "폐기(법률 검토 전 보류)" | AI 추천 수익률을 외부 검색에 노출하면 유사투자자문·성과 과장 광고 위험을 키운다(리뷰 #17, #3, #8). 방 페이지·대시보드는 noindex |
| 3 | 모델명 하드코딩(`GPT-4o`, `Sonnet 3.5`, `Opus 4.5`, `Haiku 4.5`) | `00_MERGE_ANALYSIS.md:1283` "폐기" | 세대가 섞여 곧 낡는다(리뷰 #16). 모델 목록은 llm gateway 설정 |
| 4 | Context API로 시세 상태 관리 | `00_MERGE_ANALYSIS.md:1283` "폐기" | 틱마다 구독 컴포넌트 전체 리렌더(리뷰 #10). zustand 종목별 셀렉터로 대체 |

분석 "폐기"는 아니지만 이 기획에서 범위 밖으로 둔 것(참고): 실전 주문(별도 결정), 공개 리더보드(법률 검토 전), 개별 종목 매수가·목표가·손절가 카드(법률 검토 전), 원본 예시 수익률 문구.

## 4. 복사 금지 결함

`SECURITY_BASELINE.md` 14장 중 해당 항목과 리뷰에서 찾은 제품 고유 결함이다.

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 크레딧 RPC EXECUTE 미회수, 비원자 차감 | `SECURITY_BASELINE.md:219-220` | 브라우저에서 크레딧 지급, 음수 잔액 | 코어 `consume/grant/refund_credits`(service_role)만 |
| 웹훅 서명 미검증, orderId 파싱, `customerKey = Date.now()` | `SECURITY_BASELINE.md:221-222` | 위조 결제 | 코어 Toss 흐름(Phase 2) |
| 토큰 평문 저장, 0키 폴백 | `SECURITY_BASELINE.md:224`, `docs/reference/reviews/Stock_Trader_nomad.md:95` | DB 유출 시 계좌 접근 | `encrypted_credentials` + 키 없으면 기동 실패 |
| 세션 없는 백그라운드 작업이 RLS에 막혀 무동작 | `SECURITY_BASELINE.md:225`, `docs/reference/reviews/Stock_Trader_nomad.md:95`(#8, #10 사례) | 동기화가 조용히 실패 | 워커는 service_role, `next/headers` 의존 금지 |
| `user_plans FOR ALL`(셀프 업그레이드) | `SECURITY_BASELINE.md:226` | 플랜 자기 변경 | SELECT 정책만 + guard 트리거(스모크 42501) |
| 프로필 없으면 admin, 클라이언트 PageGuard | `SECURITY_BASELINE.md:229` | 권한 상승 | 서버 `proxy.ts` + RLS |
| RLS 정책 안 자기참조(42P17) | `SECURITY_BASELINE.md:230` | 정책 오류·우회 | `has_stock_access` 등 DEFINER 헬퍼만 |
| 인증 없는 공개 AI 프록시, CORS `*` | `SECURITY_BASELINE.md:232` | 키 도용, 비용 폭증 | `requireSession` + 크레딧 + 레이트 리밋 |
| 실키 `.env` 커밋 | `SECURITY_BASELINE.md:235` | 키 유출 | `.env.example`만, spike 키도 커밋 금지 |
| 한글 `\b` 경계 금지어 매칭 | `SECURITY_BASELINE.md:236` | 금칙어 필터 무효 | 한글 경계 처리 사전(ST-06-026) |
| 증권사 키를 클라이언트 번들·`NEXT_PUBLIC_`에 두기 | `docs/reference/reviews/Stock_Trader_nomad.md:56` | 계좌 탈취 | `server-only`, 번들 검사 |
| 계좌번호·키를 로그·오류 메시지에 출력 | `docs/reference/reviews/Stock_Trader_nomad.md:80` | 유출 | 로그 마스킹 유틸 |
| 실존 종목 극단 수익률 목업을 배지 없이 표시 | `claude.md:31`, `docs/reference/reviews/Stock_Trader_nomad.md:56` | 실데이터 오인, 허위 수치 | "샘플 데이터" 배지, `is_sample` 컬럼 |
| AI 추천에서 주문 직접 생성("즉각 반영") | `PRD.md:8`, `docs/reference/reviews/Stock_Trader_nomad.md:85` | 금전 손실 | 사람 확인 RPC, AI는 입력란 채우기만 |
| Vercel 함수에서 장시간 SSE·WebSocket 유지 | `docs/reference/reviews/Stock_Trader_nomad.md:44`, `:71` | 연결 끊김, 시세 누락 | 상주 워커 |
| `EventSource`로 AI 스트리밍(GET 전용) | `docs/reference/reviews/Stock_Trader_nomad.md:96` | POST 본문 전송 불가 | `fetch(POST)` + `ReadableStream` |
| 개인 API 시세를 다른 사용자에게 재배포 | `docs/reference/reviews/Stock_Trader_nomad.md:44` | 약관 충돌 | 사용자 본인 연결만, 틱 저장 없음 |
| raise 뒤 상태 UPDATE 기대(롤백 함정) | `DB_CONVENTIONS.md:296`(코어 PM001. 코어는 2026-10-13 `fail_payment_order`로 분리 해결) | 실패 기록 소실 | 차단·만료는 상태 기록 후 반환 |
| 브라우저·Next.js에서 LLM 직접 호출, LLM 키를 Vercel·워커에 두기 | `docs/reference/reviews/Stock_Trader_nomad.md:93`(openrouter.ts 이식안), `SECURITY_BASELINE.md:299` | 키 유출, 라우팅·국외 이전 동의 우회 | LLM 키는 FastAPI 전용, 브라우저는 `/api/ai/*`만 |
| 모델이 만든 텍스트를 검사 없이 사용자에게 스트리밍 | `docs/reference/reviews/Stock_Trader_nomad.md:96`(스트리밍 권고), 원본 `PRD.md:32-36` | 투자 권유·가격 표현이 먼저 노출됨 | 투자 권유 금지 검사 통과 뒤 재생(02장 5.3절) |
| Dify 안의 LLM 노드로 사용자 노출 답변 생성 | `docs/file/03-설계/공용코어/AI_ARCHITECTURE.md:62-64` | 검사 우회 경로 | 답변은 FastAPI `/tools/answer`만, Dify는 분류와 고정 문구 |
| 보유 수량·금액·평단을 AI·Dify·음성 제공자에 전송 | 01_PRD 6.7절 | 개인신용정보 국외 이전, 개별 맞춤 조언으로 해석될 위험 | 비율·종목코드만, 요청 캡처 테스트(ST-06-051) |
| 뉴스 본문·시세를 허락 없이 색인·재배포 | 01_PRD 6.1절 | 저작권·약관 | `STOCK_RAG_SOURCES` 허용 목록, 틱 저장 없음 |
| 클라이언트가 보낸 임의 텍스트를 TTS | 제안 | 음성 생성 남용, 검사 우회 | DB의 검사 통과 텍스트만 낭독 |
| 3D 장면에 수익률·우상향 곡선·상승/하락 색 | 01_PRD 6.6절, `HERO_3D.md:88` | 수익 약속 오인 | 03장 4.5절 규칙과 단위 테스트 |
| 공유 비밀키 서명 토큰, Dify 입력에 토큰·개인정보 | `SECURITY_BASELINE.md:284-285` | 한 곳 유출 시 위조, Dify 로그 평문 | EdDSA 서명 토큰, 대화 매핑 |
| `tailwind.config.js`, v3 문법, hex 하드코딩 | `DESIGN_SYSTEM.md:63-73` | 디자인 시스템 정답 소스 이중화 | Tailwind CSS v4 `@theme` |

## 5. 아카이브 절차

| 단계 | 작업 |
|---|---|
| 1 | 원본 폴더 `구현해야 할 프로젝트/Stock_Trader_nomad`는 수정하지 않고 MVP 출시 후 `archive/Stock_Trader_nomad`로 이동(사용자 승인 후, 이 작업에서는 하지 않음) |
| 2 | 원본에 키나 `.env`가 없음을 확인했다(문서 2개뿐). 키 재발급 대상 없음 |
| 3 | spike(ST-06-004)에서 발급한 증권사 테스트 키는 spike 종료 시 폐기·재발급하고 저장소에 남기지 않는다 |
| 4 | zip 중복 없음(원본 폴더에 파일 2개) |
