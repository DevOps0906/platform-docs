# M7 compliance-desk: 법정 준수 데스크

작성일 2026-10-15. 법 조문 요약 정본은 `docs/products/local-news/01_PRD.md` 법·개인정보 절, 표 정본 `docs/products/local-news/05_DATA_MODEL.md`. 조문 번호·기간은 2차 출처 기준이며 law.go.kr 원문 대조는 미확인이다(이 문서 작성 도구로 law.go.kr 접근 불가).

## 1. 목적과 범위

지역신문이 놓치기 쉬운 법정 의무를 제품이 "기본값으로" 지키게 한다. 경쟁 제품에서 확인하지 못한 차별점이다(`docs/products/local-news/README.md` 2장). 이 모듈은 규칙(판정 함수·SLA·표시 문구)의 소유자이고, 다른 모듈은 이 규칙을 호출한다.

| 구분 | 범위 | 기능 |
|---|---|---|
| MVP(P0) | 필요적 게재사항 완성 판정(미완성이면 독자 사이트 공개 차단), 법정 푸터·청소년보호책임자 표시, 정책 페이지(청소년보호정책·개인정보처리방침·윤리강령), 주간 자체기사 비율·신규 게재·보도자료 비율 경고, 정정·반론·추후보도 청구 접수와 3일 통지·7일 게재 SLA, 원기사 정정 연결 표시, 광고·기사형 광고 라벨 규칙, AI 생성·보조 표시 | NW-F-002, 017, 027, 028, 032, 041 |
| 확장(P1) | 선거 모드(여론조사 공표 금지 기간 차단, 필수 표시 템플릿, 댓글 정책) | NW-F-044 |
| 하지 않음 | 법률 자문 문구, 언론중재위원회 절차 대행, 기사 내용의 명예훼손 자동 판정 | - |

## 2. 벤치마크

| 대상 | 가져올 것 | 가져오지 않을 것 | 출처 URL |
|---|---|---|---|
| Newspack 정정·해명(Corrections & Clarifications) | 기사별 정정 항목(유형·우선순위·설명·일시)을 편집기 사이드바에서 관리, 우선순위로 표시 위치 결정 | 미국식 자율 정정만(우리는 법정 청구 SLA까지) | https://help.newspack.com/?p=15444 (2026-10-15 열람 확인) |
| Trust Project 신뢰 지표 | 기사 유형 라벨(뉴스·의견·스폰서), 지역 취재 표시, 정정·피드백 창구 공개 | 인증 마크 사용(가입 필요) | https://thetrustproject.org/trust-indicators/ (2026-10-15 열람 확인) |
| 한국 지역지 푸터(한라일보, 용인시민신문, 옥천신문) | 발행인·편집인·등록번호·등록일·청소년보호책임자·최초발행일 전 항목 표기 | 청소년보호책임자를 이름 없이 링크만 두는 방식(경인일보) | https://www.ihalla.com , https://www.yongin21.co.kr , http://www.okinews.com/ (조사 에이전트 2026-10-15 열람, 이 문서에서 재확인 안 함) |
| 법령 요약(신문법·언론중재법·공직선거법·AI기본법) | 3절 규칙 표의 의무 | - | https://www.wipo.int/wipolex/en/text/438729 (신문법 2015년판), https://mobile.newsis.com/view/NISX20260121_0003484769 (AI기본법), https://www.journalist.or.kr/news/article.html?no=57255 (언론계 AI 준칙) |

## 3. 소유·소비

| 구분 | 내용 |
|---|---|
| 소유 표 | `correction_requests`, `election_periods` |
| 소유 함수·RPC | 뷰 `correction_sla`, `news.is_profile_complete`(`news.is_public_newspaper`와 함께), `news.election_blackout_active`, `news.upsert_election_period`, `news.compliance_weekly_stats`, `news.submit_correction_request`(service 경유), `news.respond_correction_request`, 게시 게이트 판정 함수(라벨·선거 엠바고), 표시 문구 사전 |
| 쓰는 코어 | jobs(SLA 타이머·주간 통계 잡), audit, storage(청구 첨부), rate_limit(청구 폼) |
| 쓰는 모듈 | M1 기사·`newspapers`(읽기 전용 뷰), M1 `record_article_correction`(정정 게재는 M1 RPC 호출) |
| 소비자 | M1 게시 RPC(게이트), M3(광고 라벨), M4(광고성 표기), M5(선거 댓글 정책), M8(리포트의 자체기사 비율), 독자 화면 푸터·정정 블록 |

## 4. 데이터 (요약, 상세 `docs/products/local-news/05_DATA_MODEL.md`)

| 표·함수 | 핵심(요약) |
|---|---|
| `correction_requests` | 원기사 id 또는 URL, 종류(`correction`·`rebuttal`·`follow_up`), 청구인 이메일·전화·독자 id, 청구 내용, 첨부, 접수 경로(`web`·`email`·`mail`·`phone`·`arbitration`), 접수 시각, 통지 기한(`notify_due_at`), 상태, 결정 시각·결정자·메모, 통지 시각, 게재 기한(`publish_due_at`), 게재 시각, 정정 리비전 id |
| `election_periods` | 조직(신문사마다 행, 전국 선거는 `source='platform'`으로 운영자가 일괄 생성), 이름, 선거일, 공표 금지 시작·끝(`poll_blackout_from`·`poll_blackout_until`), 댓글 정책(`normal`·`disabled`), 상태(`active`·`canceled`) |
| `compliance_weekly_stats(org, week_start)` | 월요일 시작 주. jsonb: 게시 합계, 유형별 수(original·press_release·AI 보도자료·wire·contribution·sponsored), `original_ratio`, 경고 플래그(`no_new_articles`, `original_ratio_below_30`, `press_release_ratio_high`) |
| 뷰 `correction_sla` | 통지 기한 초과·게재 기한 초과 여부(`security_invoker`, 청구 RLS를 따른다) |
| `is_profile_complete(org)` | M1 `newspapers.profile_completed_at`이 있으면 true. 완성 판정 항목은 10개(제호, 법인명, 등록번호, 등록일, 발행인, 편집인, 청소년보호책임자, 발행소 주소, 전화, 최초발행일)이고 M1 표 트리거가 계산한다(05장 SQL). 규칙(어떤 항목이 필수인가)의 소유자는 M7, 계산 위치는 M1 트리거 |

## 5. 인터페이스

```ts
// src/modules/compliance-desk/server/index.ts — 계약 예시(구현 파일 아님)
export type GateReason = 'profile_incomplete' | 'label_missing' | 'election_embargo' | 'poll_disclosure_missing' | 'ai_disclosure_missing' | 'ai_review_required'   // SQLSTATE 코드 값 정본은 05장 SQL
export interface ComplianceDeskApi {
  checkPublishable(orgId: string, article: { type: string; isPoll: boolean; pollDisclosure?: string; sponsorLabel?: string; aiAssisted: boolean; aiDisclosure?: string; origin: string }, at: Date): Promise<{ ok: boolean; reasons: GateReason[] }>  // 게시 RPC 안 판정과 같은 규칙(화면 미리보기용)
  legalFooter(orgId: string): Promise<{ lines: Array<{ label: string; value: string }>; youthOfficer: string } | null>   // null이면 사이트 공개 차단 화면
  labelFor(kind: 'ad_slot' | 'sponsored_article' | 'newsletter_ad' | 'ai_assisted' | 'ai_voice'): string                // 표시 문구 사전(버전 관리)
  weeklyStats(orgId: string, weekStart: string): Promise<WeeklyStats>         // rpc news.compliance_weekly_stats
  submitCorrectionRequest(input: CorrectionRequestInput & { turnstileToken?: string; requestId: string }): Promise<{ id: string; reference: string; receivedAt: string; notifyDueAt: string }>  // 웹 폼은 service, 우편·전화 접수는 DESK가 직접(channel)
  respond(requestId: string, action: 'reviewing' | 'accept' | 'reject' | 'withdrawn', note?: string): Promise<void>   // rpc news.respond_correction_request(CHIEF), accept면 게재 기한 = 수용 + 7일(불변)
  activeElection(orgId: string, at: Date): Promise<ElectionPeriod | null>
}
```

| 이벤트 | 발생 | 구독 |
|---|---|---|
| `news.correction.received` | 청구 접수 | 발행인·편집인 알림(즉시) |
| `news.correction.sla_warning` | 통지·게재 기한 24시간 전(제안) | 편집인 알림 |
| `news.correction.overdue` | 기한 초과 | 발행인 알림, 대시보드 빨간 표시 |
| `news.compliance.ratio_warning` | 주중 자체기사 비율이 30%에 가까움(제안 35% 미만) | 편집인 알림 |
| `news.election.started` / `.ended` | 기간 경계(`poll_blackout_from`·`_until`) | M5 댓글 정책(`comment_policy='disabled'`면 작성 중지), M1 게이트 |
| 구독: `news.article.corrected`(M1) | 청구 상태 `published`로 | - |

## 6. 상태·규칙

| 현재 | 허용 전이 | 누가 |
|---|---|---|
| `received` | `reviewing`, `accepted`, `rejected`(사유 필수), `withdrawn` | editor 이상 / 청구인 |
| `reviewing` | `accepted`, `rejected`, `withdrawn` | editor 이상 / 청구인 |
| `accepted` | `published`(정정 게재 리비전 기록 시) | 시스템(M1 `record_article_correction`) |

언론중재위원회 조정 신청은 상태가 아니라 접수 경로 `arbitration`과 메모로 남긴다(05장 SQL 기준. 별도 상태가 필요하면 05장 변경 제안).

| 규칙 | 내용 | 근거(2차 출처, 원문 미확인) |
|---|---|---|
| 공개 차단 | `is_profile_complete=false`면 독자 사이트는 "준비 중" 페이지만, 게시 RPC 거부 | 신문법 제21조(필요적 게재사항) |
| 청소년보호책임자 | 모든 독자 페이지 푸터에 성명 표시(링크만으로 대체 불가), 접힘형 푸터(템플릿 C)도 성명은 펼침 없이 보임 | 신문법 시행령 제7조의2 |
| 자체기사 비율 | 주간 게시 중 `original` 비율 30% 이상 목표. `press_release`(AI 초안 포함)와 `wire`는 제외, `contribution` 포함 여부는 D-9로 결정(제안: 별도 표시하고 비율에는 제외) | 신문법 제2조·시행령 제2조, 포털 제휴 자체기사 비중(https://journalist.or.kr/news/article.html?no=60389) |
| 주간 신규 게재 | 7일 동안 게시 0이면 경고 | 신문법 시행령(인터넷신문 요건) |
| 정정 SLA | 접수 후 3일 안에 수용 여부를 청구인에게 통지, 수용 시 7일 안에 게재. 기한은 달력일 기준으로 계산하고 공휴일 처리는 미확인 | 언론중재법 제14조·제15조(청구 기간: 안 날부터 3개월·보도 후 6개월. 조문 원문 미확인) |
| 정정 표시 | 원기사 상단에 "정정·반론보도 있음" 링크, 정정 기사는 원기사와 같은 섹션·같은 첫 화면 노출 기간(제안 24시간) | 언론중재법 제15조(게재 방법, 원문 미확인) |
| 광고 라벨 | 문구 사전: 슬롯 "광고", `sponsored` 기사 "광고" 또는 "기사형 광고" + 광고주명. 끌 수 없음 | 신문법 제6조 제3항 |
| AI 표시 | AI 초안·요약을 사람이 검수해 게시한 기사는 "AI 보조" 표시, 오디오 기사는 "AI 음성" 표시, 생성 이미지는 "AI 생성 이미지" 캡션. 문구는 D-9 | AI기본법(2026-01-22 시행), 언론계 AI 준칙 |
| 선거 모드 | 기간 중 `is_poll` 기사 게시 거부(`news.election_blackout_active`)(이미 게시된 기사의 처리는 미확인, 편집인 경고만), 여론조사 기사 필수 표시 템플릿(조사의뢰자·조사기관·조사일시·대상·방법·표본·오차 등, 항목 정본은 중앙선거여론조사심의위원회 기준 미확인), 댓글 사전 검토 토글 | 공직선거법 제108조 |

## 7. 실패 동작

| 상황 | 동작 |
|---|---|
| 판정 함수 오류 | 게시를 막는 쪽으로 실패(fail-closed). 사유 "준수 판정 실패, 다시 시도" |
| SLA 타이머 잡 지연 | 기한은 DB 컬럼이 정본이고 화면은 매 조회 때 계산. 잡은 알림만 담당하므로 지연돼도 기한이 바뀌지 않는다 |
| 청구 폼 첨부 실패 | 청구는 접수(기한 시작)하고 첨부 재제출 안내. 접수 시각은 서버 시각 |
| 주간 통계 계산 실패 | 마지막 값 + "갱신 실패" 표시, 다음 잡에서 재계산 |

## 8. 보안·개인정보

| 항목 | 규칙 |
|---|---|
| 청구인 정보 | 편집인 이상만 열람, 열람 감사. 처리 완료 후 보관 기간(제안 3년, 소송 대비 기간 미확인) 뒤 파기 |
| 기한 조작 | 접수 시각·기한 컬럼은 사용자 UPDATE 불가(전이 RPC만, `docs/products/_platform-core/DB_CONVENTIONS.md:221-230`) |
| 매체정보 | 필요적 게재사항은 공개 정보지만 변경 이력은 감사 로그로 남긴다(발행인 변경 추적) |
| 전국 선거 | `source='platform'` 행은 플랫폼 운영자만 생성·수정, 신문사는 `source='newsroom'` 행(보궐 등)만 |

## 9. 수용 기준

| 기능 | 기준 |
|---|---|
| NW-F-002 | 항목 하나라도 비면 독자 사이트 공개 페이지 0(준비 중 페이지만), 게시 RPC 거부 |
| NW-F-028 | 모든 독자 페이지 HTML에 청소년보호책임자 성명, 정책 페이지 3종 존재 |
| NW-F-027 | 접수 즉시 기한 2개 계산, 기한 24시간 전 경고, 초과 시 대시보드 표시, 원기사에 정정 링크 |
| NW-F-032 | M3 라벨 테스트와 같은 문구 사전 사용(문구 하나만 바꾸면 전부 반영) |
| NW-F-041 | 주간 비율·신규 게재·보도자료 비율이 기사 목록 집계와 일치(테스트 데이터로 확인) |
| NW-F-044 | 공표 금지 기간에 여론조사 기사 게시 거부, 기간 밖은 필수 표시 템플릿 없으면 거부 |
| NW-F-017 | M1 수용 기준과 같이 정정 기록과 공개 표시 연결 |

## 10. 추출 조건

추출하지 않는다. 신문법·언론중재법·공직선거법에 묶인 뉴스 전용 모듈이다. 다만 "표시 문구 사전 + 게시 게이트" 구조는 코어 compliance 모듈(`docs/products/_platform-core/SHARED_MODULES.md:355-376`)의 게이트 규칙과 같은 모양(PASS·WARN·FAIL)으로 맞춰 둔다.
