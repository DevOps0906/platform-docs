# M7 compliance-desk 개발 지시서

작성일 2026-10-15. 기획 정본 `D:/WorkSpace/platform/docs/products/local-news/modules/M7_compliance-desk.md`, 법 절 `D:/WorkSpace/platform/docs/products/local-news/01_PRD.md`, 표 `D:/WorkSpace/platform/docs/products/local-news/05_DATA_MODEL.md`. 조문 원문 대조는 미확인이므로 출시 전 법무 검토 작업을 06장에 둡니다.

## 1. 만들 것

| 부분 | 내용 | 우선 |
|---|---|---|
| 매체정보 판정 | 완성 판정 함수 연결, 미완성 신문사 독자 사이트 "준비 중" 페이지, 편집국 경고 배너 | P0 |
| 법정 푸터 | 전 페이지 푸터(필요적 게재사항 + 청소년보호책임자 성명), 정책 페이지 3종(청소년보호정책·개인정보처리방침·윤리강령) | P0 |
| 게시 게이트 | 라벨 규칙(`sponsor_label` 허용 목록), AI 표시 규칙(`ai_disclosure`), 선거 엠바고 — DB 판정과 같은 규칙의 화면 미리보기 | P0 |
| 문구 사전 | 광고·기사형 광고·AI 보조·AI 음성·AI 생성 이미지 표시 문구(버전 관리) | P0 |
| 주간 지표 | `compliance_weekly_stats` 대시보드, 자체기사 비율·신규 게재·보도자료 비율 경고 | P0 |
| 정정 청구 | 공개 청구 폼, 접수·통지 기한·게재 기한 타이머, 결정 화면, M1 정정 게재 연결, 원기사 링크 | P0 |
| 선거 모드 | 선거 기간 등록(플랫폼·신문사), 여론조사 기사 차단·필수 표시, 댓글 정책 | P1 |

## 2. 디렉토리·파일

모듈 모양은 이 폴더 `README.md` 3.1절, 경로·잡 이름 정본은 `D:/WorkSpace/platform/docs/products/local-news/02_ARCHITECTURE.md` 2·4절과 `D:/WorkSpace/platform/docs/products/local-news/04_API.md` 2절.

| 경로 | 책임 |
|---|---|
| `apps/web/src/modules/compliance-desk/server/index.ts` | `ComplianceDeskApi`, `labelFor` |
| `.../labels.ts`(이 문서 제안) | 표시 문구 사전(버전 상수). M1 렌더러·M3 `AdSlot`·M4 메일이 모두 이 파일을 쓴다. 허용 값은 05장 CHECK 목록과 같게 |
| `.../server/gate.ts` | 화면용 게이트 미리보기(최종 판정은 DB `news.publish_article`) |
| `.../server/corrections.ts` | 청구 접수(`/api/r/corrections` → `news.submit_correction_request`, service), 결정(`news.respond_correction_request`), 정정 게재는 M1 `recordCorrection` 호출 |
| `.../server/stats.ts` | `news.compliance_weekly_stats` 호출, 경고 계산 |
| `.../components/LegalFooter.tsx` | 템플릿 3종 공통, 접힘형에서도 청소년보호책임자 성명은 항상 보임 |
| `.../cache.ts` | `news:<org>:profile`(법정 푸터·정책 페이지, 매체정보 저장·선거 모드 전환 때) |
| `worker/src/handlers/news.stats/` | `news.correction_sla`(1시간), `news.compliance_weekly`(월요일 06:00 KST) |
| `apps/web/src/app/(reader)/_t/[host]/legal/{youth,privacy,ethics,corrections}` | 정책 페이지(02장 2절) |
| `apps/web/src/app/api/newsroom/{profile,corrections,compliance,elections}/*` | 편집국 API |

## 3. 구현 순서

| 순서 | 할 일 | 확인 |
|---|---|---|
| 1 | 매체정보 입력 화면(M1 RPC로 저장) + 완성 표시 | 항목 하나 지우면 독자 사이트 "준비 중" |
| 2 | `LegalFooter`를 독자 레이아웃 루트에 고정(템플릿이 끌 수 없음) | 모든 독자 페이지 HTML에 성명 |
| 3 | 정책 페이지 3종: 기본 문안 템플릿 + 신문사 편집(윤리강령은 외부 URL 허용) | 링크 깨짐 0 |
| 4 | `labels.ts` 문구 사전, M3 `AdSlot`·M1 렌더러 연결 | 문구 하나 바꾸면 전부 반영 |
| 5 | 게시 화면 게이트 미리보기(사유별 수정 링크) | DB 판정과 같은 결과(공유 테스트 케이스) |
| 6 | 정정 청구 폼(로그인 불필요, 연락처 필수, Turnstile) → `news.submit_correction_request`(service)가 접수 시각·통지 기한(+3일, 불변) 기록. 우편·전화 접수는 데스크가 같은 RPC로 직접 입력 | 접수 즉시 편집인 알림 |
| 7 | 결정 화면(`news.respond_correction_request`: reviewing·accept·reject·withdrawn) → 수용 시 게재 기한(+7일, 불변) → M1 `news.record_article_correction` → 상태 `published` | 원기사 상단 정정 링크 |
| 8 | `news.correction_sla`(1시간) 알림, 대시보드 빨간 표시 | 기한 조작 UPDATE 거부 |
| 9 | 주간 통계 대시보드와 `news.compliance_weekly`(월요일 06:00 KST) 경고 메일 | 시드 기사로 비율 일치 |
| 10 | (P1) 선거 기간: 플랫폼 운영자가 전국 선거를 등록하면 모든 신문사에 행 생성(`source='platform'`), 신문사는 보궐 등 추가 | 공표 금지 기간 여론조사 기사 게시 거부 |

## 4. 외부 서비스 설정

외부 계정 설정은 없습니다. 아래는 규칙 확인용 원문 출처입니다.

| 자료 | 용도 | 링크 |
|---|---|---|
| 국가법령정보센터 | 신문법 제2조·제6조·제21조, 시행령 제2조·제7조의2, 언론중재법 제14조·제15조, 공직선거법 제108조, AI기본법 원문 대조 | https://www.law.go.kr (이 도구로 접근 불가, 미확인) |
| 신문법 2015년판(영문 포함) | 조문 구조 참고 | https://www.wipo.int/wipolex/en/text/438729 (조사 에이전트 열람) |
| 언론중재위원회 | 정정·반론보도 청구 안내, 조정 신청 | https://www.pac.or.kr (미확인) |
| 중앙선거여론조사심의위원회 | 여론조사 공표 필수 표시 항목 | https://www.nesdc.go.kr (미확인) |
| AI기본법 시행 보도 | 생성형 AI 표시 의무, 계도기간 | https://mobile.newsis.com/view/NISX20260121_0003484769 (조사 에이전트 열람) |
| 언론계 생성형 AI 준칙 | AI 산출물 고지, 사람 감독 | https://www.journalist.or.kr/news/article.html?no=57255 (조사 에이전트 열람) |

## 5. 테스트

| 종류 | 항목 |
|---|---|
| 단위 | 기한 계산(접수 + 3일, 수용 + 7일, KST 자정 경계, 공휴일 미반영 표시), 비율 계산(유형별, D-9 규칙), 선거 기간 경계(투표 마감 시각) |
| 공유 케이스 | 게이트 판정 표를 JSON으로 두고 DB 함수 테스트(SQL)와 TS 미리보기 테스트가 같은 파일을 읽음 |
| RLS | 청구인 정보 editor 이상만, 기한 컬럼 사용자 UPDATE 불가, 전국 선거 행 신문사 수정 불가 |
| E2E | 매체정보 미완성 → 사이트 차단 → 완성 → 공개, 정정 청구 → 수용 → 게재 → 원기사 링크 |

## 6. 운영 점검표

- [ ] 출시 전 법무 검토(조문 번호·기간·표시 문구) 완료 기록
- [ ] 정정 기한 초과 건 0 유지(신문사별)
- [ ] 자체기사 비율 경고 신문사 목록 주간 확인
- [ ] 다음 전국 선거(2028 총선) 기간 등록 일정 캘린더
- [ ] AI 표시 문구 개정 시 문구 사전 버전 올림·감사

## 7. 자주 나는 문제

| 증상 | 원인 | 조치 |
|---|---|---|
| 독자 사이트가 "준비 중" | 필요적 게재사항 누락(최초발행일·청소년보호책임자가 자주 빠짐) | 편집국 배너의 누락 항목 확인 |
| 비율이 신문사 체감과 다름 | 기고(`contribution`) 집계 규칙(D-9) 차이 | 대시보드에 유형별 수를 같이 보여 줌 |
| 정정 기한이 하루 어긋남 | UTC로 계산 | 서버 계산을 `Asia/Seoul` 기준으로 고정 |
| 여론조사 기사가 막힘 | 선거 기간 중 | 정상. 기간 밖 게시 예약 |
