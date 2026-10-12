# 07 원본 이식과 폐기: Live Poll

## 1. 원본별 자산 분류

원본 `구현해야 할 프로젝트/Slido_Project/`에는 코드가 없고 문서 2개뿐이다(`docs/reviews/Slido_Project.md:3`).

| 자산(파일/디렉토리) | 상태 | 처리 | 대상 위치 | 근거 |
|---|---|---|---|---|
| `PRD.md` 3절 유저 플로우(호스트/참가자) | 기획만 | 이식(디벨롭) | 01장 1, 3절, 03장 2절 | 원본 PRD:12-13 |
| `PRD.md` 4.1 방 생성/삭제/관리, 상태 3단계 | 기획만 | 이식(유지) | LP-F-002, 003 | 분석:1254 |
| `PRD.md` 4.1 OBS 전체화면/크로마키 | 기획만 | 이식(디벨롭: 투명/그린/다크 파라미터) | LP-F-012 | 분석:1258 |
| `PRD.md` 4.2 닉네임/익명 입장, 무새로고침 전환 | 기획만 | 이식(유지) | LP-F-007, 005 | 분석:1255 |
| `PRD.md` 4.2 1인 1표(IP + LocalStorage/Cookie) | 기획만 | 디벨롭(참가자 토큰 + unique, IP는 실패 레이트 리밋 신호만) | LP-F-008, 05장 7절 | 분석:1257 |
| `PRD.md` 4.3 WebSocket/SSE 브로드캐스트 | 기획만 | 디벨롭(Realtime Broadcast 묶음 전송) | 02장 5-1절 | 분석:1256 |
| `PRD.md` 4.3, 5절 Redis 집계 | 기획만 | 폐기(2단계 보류) | 3절 | 분석:1260 |
| `PRD.md` 5절 Socket.io / FastAPI 후보 | 기획만 | 폐기 | 3절 | 분석:1259 |
| `PRD.md` 2절 지연 0.5초, 모바일, 트래픽 급증 | 기획만 | 이식(수치화) | 01장 5절 | 리뷰:39 |
| `CLAUDE.md` 2절 GEO 최적화 | 기획만 | 랜딩만 유지, 방 페이지는 폐기(noindex) | LP-F-024, 3절 | 분석:1261 |
| `CLAUDE.md` 2절 폴링 금지 | 기획만 | 이식 | 04장 1절 | 원본 CLAUDE:8 |
| `CLAUDE.md` 2절 경량 렌더링(CSS 애니메이션, 경량 차트) | 기획만 | 이식 | 02장 1절 | 원본 CLAUDE:9 |
| `CLAUDE.md` 3절 훅/UI 분리, 메모이제이션 | 기획만 | 이식 | 02장 2절, CLAUDE.md 5장 | 원본 CLAUDE:12-13 |
| `CLAUDE.md` 3절 IP 해시 검증 미들웨어 | 기획만 | 디벨롭(HMAC, 저장 안 함) | 05장 7절 | 리뷰:42 |
| `CLAUDE.md` 5절 재연결 로직 명시 | 기획만 | 이식(디벨롭: 스냅샷 복구, seq) | LP-F-010 | 원본 CLAUDE:21 |
| 리뷰가 지목한 재사용 자산(basic-master-module, Nomad-BlogStudio supabase 클라이언트/shadcn, Hospital 실시간 훅 구조, recharts) | 동작/부분 | 참고 | LP-06-001, 013, 015 | 리뷰:72-81 |

## 2. 이식 자산 상세

| 자산 | 수정할 점 |
|---|---|
| 플로우와 상태 제어 | 상태를 draft/live/ended/archived(행사) + draft/open/closed(문항)로 나누고 전이를 트리거/RPC로 강제. "대기" = live 행사에 열린 문항 없음 |
| 1인 1표 | 클라이언트 식별(LocalStorage)을 서버 발급 httpOnly 토큰으로 바꾸고 DB unique로 판정. IP 차단 없음 |
| 실시간 엔진 | 투표마다 전송하지 않는다. 워커가 행사별 묶음 상태를 private 채널로 보낸다. 클라이언트는 seq로 순서와 유실을 판단 |
| OBS 모드 | 로그인 없는 오버레이 키 URL. 키는 해시만 저장, 재발급 가능 |
| 재연결 | 백오프 + 재구독 직후 스냅샷 1회. 15초 무수신 감지(hb) |
| 재사용 자산 | Supabase 클라이언트 3종은 `packages/core-db`를 쓴다(직접 복사하지 않음). Hospital 훅은 구조만 참고하고 아래 4절 결함을 피한다. 차트는 진행자 콘솔만 recharts, 청중/발표/오버레이는 CSS 막대 |

## 3. 폐기 목록과 사유

분석 "폐기" 3건(`docs/products/00_MERGE_ANALYSIS.md:1259-1261`)을 모두 적는다.

| 항목 | 분석 근거 | 사유 |
|---|---|---|
| 실시간 스택 후보 Socket.io, FastAPI WebSocket | `00_MERGE_ANALYSIS.md:1259` | Vercel 서버리스는 상주 WebSocket 서버를 띄울 수 없어 별도 서버와 Redis adapter가 필요하고 MVP가 2배 이상 커진다(리뷰:54). Supabase Realtime으로 확정했다 |
| Redis 집계(카운팅/캐싱) | `00_MERGE_ANALYSIS.md:1260` | 투표는 INSERT 1회, 집계는 워커가 행사별 250ms마다 한 번이라 Postgres만으로 처리량이 충분하다(리뷰:45). LP-06-027 부하 테스트에서 필요하다고 나오면 Phase 3에 다시 본다 |
| 방(행사) 페이지 GEO | `00_MERGE_ANALYSIS.md:1261` | 일시적이고 비공개인 페이지라 검색 노출 가치가 없고 오히려 noindex 해야 한다(리뷰:49). GEO는 랜딩에만 적용 |

추가로 이 기획에서 버린 것(분석에는 디벨롭으로 분류):

| 항목 | 사유 |
|---|---|
| IP 기반 하드 차단 | 같은 Wi-Fi/CGNAT 정상 사용자를 막는다(리뷰:55) |
| IP 해시 영구 저장 | 개인정보 처리와 역산 위험(리뷰:56). HMAC 레이트 리밋 키(1일)로 대체 |
| Supabase 익명 로그인 | 코어 가입 트리거가 익명 사용자마다 조직을 만든다(05장 7절) |
| `postgres_changes` 구독 | 구독자마다 권한 검사가 일어나 대규모에 부적합(리뷰:65) |
| `poll_counts` 원자적 증분 테이블(리뷰 권장안) | 같은 카운터 행에 300건/초가 몰리는 핫 로우 경합. 집계는 워커 시점 계산으로 대체(02장 5-1절) |

## 4. 복사 금지 결함

| 패턴 | 출처 | 왜 금지 | 대체 |
|---|---|---|---|
| 이벤트마다 전체 재조회 | `docs/reviews/Slido_Project.md:74`(Hospital #17) | 3,000명이 동시에 재조회하면 DB 폭주 | 브로드캐스트 페이로드 직접 반영, 스냅샷은 공백/재연결 때만 |
| 같은 화면에서 훅 2회 호출로 채널 중복 | `docs/reviews/Slido_Project.md:74`(Hospital #8) | 메시지 중복 처리, 연결 수 2배 | 훅 내부 채널 참조 카운트(LP-06-013) |
| 연결 상태 콜백 없음 | `docs/reviews/Slido_Project.md:74` | 끊김을 사용자가 모른다 | 연결 배지 4종 |
| `as any` 캐스팅 | `docs/reviews/Slido_Project.md:74`(Hospital #14), `SECURITY_BASELINE.md` 10장 | 타입 우회로 계약 위반이 숨는다 | 생성 타입 + zod |
| RLS 자기참조 재귀, `USING(true)` 업데이트 정책 | `docs/reviews/Slido_Project.md:78`(ERP, sellingstudio), `SECURITY_BASELINE.md` 14장 | 42P17 또는 전 행 수정 허용 | 코어 헬퍼만 사용, 쓰기 정책에 with check(05장 4절) |
| 프로필 없으면 admin, 클라이언트 PageGuard | `SECURITY_BASELINE.md` 14장 | 권한 상승, RSC 노출 | 서버 `requireSession`, 프로필 없으면 로그아웃 |
| 실키가 든 `.env` 커밋 | `SECURITY_BASELINE.md` 14장 | 키 유출 | env 검증 + `.env*` gitignore |
| `FOR ALL` 플랜/크레딧 정책 | `SECURITY_BASELINE.md` 14장 | 셀프 업그레이드 | 플랜은 코어 엔타이틀먼트만 읽는다 |
| 한글에 `\b` 경계 금지어 | `SECURITY_BASELINE.md` 14장 | 필터 무효 | `normalize_text` 부분 일치(조각:44) |
| 공개 Broadcast 채널에서 서버 메시지와 클라이언트 메시지를 구분 없이 신뢰 | 이 기획(02장 5-1절) | 토픽을 아는 청중이 가짜 결과를 보낼 수 있다 | private 채널, 송신 정책 없음 |
| 레이트 리밋 히트 뒤 raise | 이 기획(조각 머리 주석 5) | 히트가 롤백되어 대입 공격이 세어지지 않는다(코어 `confirm_payment_order` 결함과 같은 원리) | 청중 RPC는 jsonb `{ok:false, code}` 반환 |

## 5. 아카이브 절차

| 단계 | 내용 |
|---|---|
| 1 | 원본 폴더 `구현해야 할 프로젝트/Slido_Project/`는 문서 2개뿐이다. 앱 저장소 생성(LP-06-001) 뒤 `archive/Slido_Project/`로 옮기는 것은 사용자가 결정한다(이 작업에서는 옮기지 않음) |
| 2 | 키 재발급: 원본에 키가 없어 해당 없음 |
| 3 | zip 중복: 없음 |
| 4 | 원본 PRD/CLAUDE의 내용은 01~07장에 흡수됐으므로 앱 저장소에는 복사하지 않는다 |
