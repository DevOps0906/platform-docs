# compliance 개발 지시서 (`@nomad/compliance`)

기획 정본: `products/_platform-core/common-modules/compliance.md`. 공통 규칙·적용 절차: [`README.md`](README.md).

## 1. 만들 것 (v1.0)

정책 문서 버전과 게시, 동의 기록(추가만), 법정 표기 프로필(`kr_business`, `kr_ecommerce`, `kr_newspaper`, `kr_education`)과 완성 판정, 표시 라벨 사전과 `required_labels`, 재동의 판정, 공용 푸터·동의 체크박스·라벨 컴포넌트. 데이터 요청함은 v1.1.

## 2. 파일

| 경로 | 책임 |
|---|---|
| `sql/0150_compliance.sql` | 표 6개, 동의 기록 수정 거부 트리거(`CP001`), 함수 6개, 공개 뷰 `public_legal_footer` |
| `sql/seed/profile_rules.sql`, `label_definitions.sql` | 프로필 필수 필드·라벨 문구(배포 없이 고치는 값) |
| `src/server/consent.ts`, `policy.ts`, `profile.ts` | `recordConsent`, `hasConsent`, `needsReconsent`, `assertProfileComplete` |
| `src/labels.ts` | `requiredLabels` 순수 함수(SQL 함수와 같은 규칙표를 JSON으로 공유) |
| `src/ui/LegalFooter.tsx`, `ConsentCheckboxes.tsx`, `ContentLabel.tsx`, `ReconsentGate.tsx` | 화면 |
| `src/ui/admin/` | 정책 편집(마크다운 + 미리보기 + 효력일), 프로필 입력(빠진 필드 표시) |

## 3. 구현 순서

| 순서 | 작업 | 확인 |
|---|---|---|
| 1 | SQL + seed(필수 필드는 법무 확인 전 "미확인" 표시 컬럼 포함) | 스모크: 동의 UPDATE·DELETE 거부, 다른 org 동의 읽기 0 |
| 2 | `requiredLabels` TS·SQL 일치 테스트(같은 입력 표 50개) | 불일치 0 |
| 3 | 가입 흐름 연결: 코어 인증 약관 단계(`firstLoginPath`)에서 `ConsentCheckboxes` → `recordConsent` | 동의 없이 가입 완료 불가 |
| 4 | 재동의 게이트(필수 정책 새 버전) | 로그인 후 차단 화면 |
| 5 | 푸터: 서버 컴포넌트, 캐시 태그 `compliance:<org>:<app>:footer` | 프로필 저장 시 즉시 반영 |
| 6 | notify 연결: 광고성 발송 전 `hasConsent(..., 'marketing_email')`, 야간 발송은 `night_ads` | notify 계약 테스트 |

## 4. 외부 확인 (사람, 법무)

| 항목 | 링크 |
|---|---|
| 개인정보 보호법·시행령, 정보통신망법 제50조, 전자상거래법 제10조, 신문법 | https://www.law.go.kr |
| 개인정보 처리방침 작성 지침 | https://www.pipc.go.kr |
| 광고성 정보 전송 안내(불법스팸) | https://spam.kisa.or.kr |
| 추천·보증 심사지침 | https://www.ftc.go.kr |

확인 결과는 seed 값(`profile_rules.source_url`, `label_definitions`)으로만 반영하고 코드 상수에 조문·기한을 넣지 않습니다.

## 5. 제품 주입 값

| 값 | 예 |
|---|---|
| `profileKind` | website-floria `kr_business`, local-news `kr_newspaper` |
| `publishGuard` | local-news만 `true`(미완성 시 공개 차단) |
| `signupConsents` | `{ required: ['terms','privacy'], optional: ['marketing_email','night_ads'] }` |
| `labelPlacement` | `{ ad: 'badge', ai_generated: 'caption' }` |

## 6. 테스트

동의 기록 불변, 재동의 판정(버전 2→3), 프로필 미완성 시 `CP003`, 라벨 누락 `CP004`, 푸터 접근성(axe), org별 정책 덮어쓰기 우선순위.

## 7. 자주 나는 문제

| 증상 | 원인·해결 |
|---|---|
| 플랫폼 공통 정책이 org에 안 보임 | `current_policy`가 org 버전 → 공통 순서인지, 공통 행 `org_id is null` RLS 공개 정책 확인 |
| 이메일 구독자 동의 증빙이 없음 | 비회원은 subject `email`(해시)로 기록. 이중 동의 확인 시점에 notify가 기록 |
