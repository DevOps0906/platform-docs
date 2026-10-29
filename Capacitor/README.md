# Capacitor: 모바일 앱 공용 가이드

작성일 2026-10-14. 이 폴더는 platform-docs의 제품(`products/`)을 iOS·Android 앱으로 만들 때 공통으로 따르는 **기획 지시사항**(3장)과 **개발 방법 지시사항**(4장, 6장)이다. 코드는 없고 지침과 계약 예시만 있다(`docs/products/_PRODUCT_AGENT_BRIEF.md:6`과 같은 원칙). 데스크톱은 [`../Tauri/README.md`](../Tauri/README.md)를 본다.

이 문서의 지위: 공용 지침 초안. `_platform-core`와 확정 결정이 우선한다. 특히 확정 결정 9("sellingstudio 모바일 앱은 MVP 이후", `docs/products/00_MERGE_ANALYSIS.md:17`)에 따라 모바일 앱은 모든 제품에서 MVP 이후가 기본이다. 근거 없는 수치·정책은 "제안", 원문을 확인하지 않은 외부 사실(스토어 정책, 법령)은 "미확인" 또는 "원문 확인 필요"로 적는다.

## 0. 읽는 순서

| 순서 | 문서 | 왜 |
|---|---|---|
| 1 | 이 문서 1장 | 앱이 정말 필요한지(PWA로 충분한지) |
| 2 | [`../Tauri/README.md`](../Tauri/README.md) 2장 | "Supabase/Firebase를 웹처럼 그대로 쓴다"는 설명의 검토(데스크톱·모바일 공통) |
| 3 | 이 문서 2장 | 모바일에서 추가로 달라지는 점 |
| 4 | 이 문서 3장 | 제품 PRD에 넣어야 할 기획 항목(스토어 정책, 결제, 푸시, 개인정보) |
| 5 | 이 문서 4~6장 | 구조, 설정, 플러그인, 빌드, 작업 분해 |
| 6 | 이 문서 5장 | 자기 제품의 적용 방안 |

## 1. 결론 요약

| 항목 | 내용 |
|---|---|
| 한 줄 | 제품 화면(React)을 정적 번들로 앱에 싣고, 푸시·카메라·마이크·파일·딥링크 같은 기기 기능만 Capacitor 플러그인으로 붙인다. 클라우드(Next.js Route Handler, FastAPI, Supabase)는 바뀌지 않는다 |
| 기준 버전 | Capacitor 8(2025-12-09 발표). 새 iOS 프로젝트는 Swift Package Manager가 기본이고 CocoaPods도 계속 지원한다. Android는 내장 `SystemBars`로 상태·내비게이션 바와 엣지 투 엣지를 관리한다. 최소 OS 버전·Node 버전은 공식 업데이트 가이드로 구현 시 확인한다 |
| 웹뷰 | iOS WKWebView, Android System WebView. 같은 코드라도 OS·기기마다 성능과 기능이 다르다 |
| 먼저 검토할 대안 | PWA. 홈 화면 설치, 오프라인 캐시, 웹 푸시(iOS는 홈 화면에 추가한 웹앱에서 지원)로 충분하면 앱을 만들지 않는다. 스토어 심사·인앱결제 정책·두 OS 빌드 비용이 없다(린 원칙) |
| 앱이 필요한 경우 | (1) 신뢰도 높은 푸시가 핵심 가치 (2) 카메라·마이크·파일을 자주 쓰는 현장 작업 (3) 스토어 검색 노출이 마케팅 채널 (4) 생체 인증·보안 저장소가 필요 |
| 앱을 만들지 말아야 하는 경우 | 웹 화면을 그대로 감싼 것뿐인 앱. 스토어 심사에서 "최소 기능" 사유로 반려될 위험이 크고(원문 확인 필요), 사용자에게도 이득이 없다 |

## 2. 모바일에서 추가로 달라지는 점

Tauri 가이드 2장의 검토(소셜 로그인은 시스템 브라우저, 토큰은 보안 저장소, 셸에 비밀 금지, 서버 기능은 클라우드에 남김, 로컬·클라우드 정본 구분)는 모바일에도 그대로 적용된다. 아래는 모바일에서 더해지는 것이다.

| # | 항목 | 내용 |
|---|---|---|
| 1 | 소셜 로그인 | `@capacitor/browser`(iOS SFSafariViewController, Android Custom Tabs 계열의 시스템 브라우저)로 OAuth URL을 연다 → Universal Link/App Link 또는 커스텀 스킴으로 복귀 → `@capacitor/app`의 `appUrlOpen`에서 `code`를 받아 `exchangeCodeForSession`. 앱 내부 WebView로 Google 로그인을 열면 차단된다 |
| 2 | Apple 로그인 | 제3자 소셜 로그인을 넣으면 Apple 심사 지침상 개인정보 보호형 로그인 대안(Sign in with Apple 등)을 함께 제공해야 할 수 있다(지침 4.8, 원문 확인 필요). 이메일·비밀번호만 쓰면 해당하지 않는다 |
| 3 | 토큰 저장 | `@capacitor/preferences`는 로컬 데이터베이스나 비밀 저장소가 아니다(공식 문서: 데이터베이스 용도가 아님). 세션 토큰은 iOS Keychain·Android Keystore 기반 보안 저장소 플러그인에 둔다(플러그인 선정 시 유지 상태 확인, 미확인) |
| 4 | Firebase의 위치 | Android 원격 푸시는 FCM 경로를 쓰므로 Firebase 프로젝트가 필요하다. 그러나 인증·DB·스토리지는 Supabase 하나로 유지한다. Firebase Auth·Firestore를 함께 쓰면 RLS·감사·크레딧 규칙이 두 벌이 된다 |
| 5 | 결제 | 앱 안에서 디지털 상품(크레딧, 구독, 기능 해제)을 팔면 스토어 인앱결제 정책 대상이 된다. 이 레포의 크레딧 판매 구조(Toss 단일 PG, 확정 결정 4)와 바로 충돌하므로 3.3절 전략을 PRD에서 먼저 정한다 |
| 6 | 계정 삭제 | 앱에서 가입할 수 있으면 앱 안에서 계정 삭제를 시작할 수 있어야 한다(Apple 지침, Google Play 데이터 삭제 정책. 원문 확인 필요). 코어의 soft delete → 30일 → purge 절차(`docs/products/_platform-core/SECURITY_BASELINE.md` 12장)를 앱 화면에 연결한다 |
| 7 | 원격 셸 | `server.url`로 배포된 웹을 띄우는 "원격 셸"은 구현이 빠르지만, 웹 래퍼로 보여 심사 위험이 있고 오프라인이 안 되며 원격 콘텐츠가 플러그인을 부를 수 있다. 기본은 정적 번들, 원격 셸은 개발·사내 배포용(4.2절) |
| 8 | 백그라운드 | 앱이 백그라운드로 가면 웹뷰 JS가 멈출 수 있다. 긴 작업(업로드, AI 생성)은 서버 잡(`core.jobs`)으로 돌리고 끝나면 푸시로 알린다 |

## 3. 기획 지시사항 (제품 PRD에 넣을 것)

모바일 앱을 기획하는 제품은 `01_PRD.md`의 해당 장에 아래 항목을 채운다. 장 구조는 `docs/products/_platform-core/DOC_TEMPLATE.md` 2.2절 그대로 두고 표를 추가한다.

### 3.1 범위와 가치 (01_PRD 1~2장)

| 항목 | 써야 할 내용 |
|---|---|
| 모바일 페르소나 | 언제·어디서 휴대폰으로 이 제품을 여는지(이동 중 확인, 현장 촬영, 알림 대응) |
| 웹 대비 이득 | 1장 "앱이 필요한 경우" 중 무엇에 해당하는지. 해당 없으면 PWA로 결정 |
| 모바일 범위 | 모바일에서 할 수 있는 일과 웹·데스크톱에서만 하는 일을 표로 나눈다. 모바일 MVP는 "확인·승인·알림·촬영" 위주로 좁게(제안) |
| 단계 | 확정 결정 9에 따라 Phase 2 이후. 앞당기려면 열린 결정으로 올린다 |

### 3.2 스토어 정책 점검표 (01_PRD 6장)

| 항목 | 점검 내용 | 상태 |
|---|---|---|
| 최소 기능 | 웹 래퍼가 아닌 앱 고유 가치(푸시, 카메라, 오프라인, 기기 연동)를 2개 이상 제공 | 원문 확인 필요(Apple 지침 4.2) |
| 소셜 로그인 | 제3자 로그인 제공 시 대안 로그인 제공 의무 여부 | 원문 확인 필요(Apple 지침 4.8) |
| 계정 삭제 | 앱 안 삭제 시작 경로, 삭제 범위·보관 의무 안내 | 원문 확인 필요(Apple·Google) |
| 개인정보 표기 | App Store 개인정보 라벨, Google Play 데이터 보안 섹션, 처리방침 URL | 제품별 작성 |
| 권한 사용 목적 | 카메라·마이크·사진·위치·알림 권한마다 한국어 사용 목적 문구(iOS `Info.plist`, Android 권한 안내) | 제품별 작성 |
| 연령 등급 | 스토어 연령 등급 설문. 운세(astro-ai)·금융(stock-dashboard)·미성년자(admin-suite sms)는 별도 검토 | 제품별 |
| 디지털 상품 결제 | 3.3절 전략 | 제품별 결정 |
| 코드 원격 업데이트 | 웹 번들 원격 업데이트(OTA)는 앱의 주 목적을 바꾸지 않는 범위에서만(원문 확인 필요) | 4.8절 |

### 3.3 결제 전략 (01_PRD 4장, 가장 먼저 결정)

| 전략 | 내용 | 수수료(확인 범위) | 맞는 제품 | 위험 |
|---|---|---|---|---|
| (a) 스토어 인앱결제 | 크레딧·구독을 앱스토어·플레이 결제로 판매. 영수증을 서버가 검증해 `core.grant_credits` | 표준 30%, 조건부 15%(원문 확인 필요) | 개인 소비자 대상 디지털 상품(astro-ai 리포트 크레딧 등) | 가격 이원화(웹과 앱 가격 차이), 영수증 검증·환불 동기화 개발, 코어 결제 모델 확장 필요 |
| (b) 국내 제3자 결제 | 한국 스토어에서 허용된 외부 결제 시스템(Toss 등) 사용 | 약 26% + PG 수수료(합계 31~36%라는 보도) | (a)와 같으나 Toss 일원화를 원할 때 | 수수료 절감이 거의 없고 스토어별 절차가 다르다 |
| (c) 앱에서 판매하지 않음 | 앱은 로그인·사용만, 구매는 웹(데스크톱)에서. 앱 안에 결제 화면을 두지 않는다 | 0% | B2B·조직 판매 제품, 설치형 판매 제품, 웹 사용 비중이 큰 제품 | 앱 안에서 외부 결제로 안내하는 문구·링크 허용 범위가 국가·시점·앱 성격마다 다르다(원문 확인 필요). 개인 소비자 앱은 심사 위험 |
| (d) 실물·대면 서비스 | 앱 밖에서 소비되는 실물 상품·사람이 제공하는 서비스는 인앱결제 대상이 아니다(원문 확인 필요) | PG 수수료만 | microweb-studio 대행 제작, 커머스 실물 상품 | 디지털 기능 해제와 섞이면 (a) 대상 |

가격: (a)·(b)를 쓰는 제품은 앱 가격을 웹 가격과 따로 산정해 스토어 수수료를 마진 계산에 넣는다. 산정 방법은 `Price_Plans/_common/PRICING_PRINCIPLES.md`를 따르고 결과는 `Price_Plans/<제품>/PRICE_PLAN.md`에 "앱 가격" 절로 추가한다.

권고(제안): 모바일 1차는 **(c)**로 시작해 앱 안 결제를 만들지 않는다. 이유: 이 레포의 결제·크레딧 정본은 Toss 웹훅 + `core.confirm_payment_order`이고(확정 결정 4), 앱 매출 비중이 확인되기 전에 인앱결제 연동(영수증 검증, 환불 동기화, 가격 이원화)을 만들면 비용이 크다. 개인 소비자 대상이라 (c)가 심사를 통과하지 못하면 (a)를 Phase 3에서 붙인다(코어 요청 M-C3). 수수료 근거: [쿠키뉴스 2026-01-09](https://www.kukinews.com/article/view/kuk202601080137).

### 3.4 푸시 알림 기획 (01_PRD 3장, 6장)

| 항목 | 써야 할 내용 |
|---|---|
| 알림 목록 | 알림 종류마다: 트리거(어떤 서버 이벤트), 대상, 문구, 딥링크 목적지, 빈도 상한 |
| 정보성과 광고성 구분 | 결과 완료·결제·보안 알림은 정보성. 할인·이벤트·재방문 유도는 광고성. 광고성은 수신 동의, 야간(오후 9시~오전 8시) 전송 별도 동의, 주기적 수신 동의 확인, "(광고)" 표기가 필요하다(정보통신망법, 법무 확인 필요) |
| 동의 기록 | 수신 동의는 공용 알림 모듈 notify의 `notify.preferences`(사용자·채널·주제별 동의)에 두고, 동의 증빙(시각, 고지문 버전)은 compliance 모듈 `consents`에 남긴다(`docs/products/_platform-core/COMMON_MODULES_ROADMAP.md` 4.1절, `:237`). notify가 출시되기 전에는 `core.audit_log`에 같은 정보를 남긴다 |
| 금지 | 푸시 문구에도 제품 금지 문구표(`01_PRD.md` 6.1절)를 적용한다. 운세·투자 제품은 단정·보장 표현 금지 |
| 측정 | 푸시 동의율, 알림 클릭률, 알림으로 인한 앱 삭제율 |

### 3.5 개인정보·권한·데이터 (01_PRD 6장)

| 항목 | 규칙 |
|---|---|
| 기기 데이터 | 기기 토큰(푸시), 기기 모델·OS 버전만 수집. 광고 식별자는 수집하지 않는다(제안: 광고 SDK를 넣지 않는 한 필요 없다) |
| 사진·녹음 | 업로드 전 미리보기와 삭제 경로를 제공. 녹음은 코어 음성 규칙(제3자 고지, 원본 보존 기간)을 그대로 따른다(`docs/products/_platform-core/VOICE_ARCHITECTURE.md:90-95`) |
| 로컬 저장 | Tauri 가이드 4.1절 A~D 분류를 그대로 쓴다. 휴대폰 분실을 가정해 로컬에는 최소한만 둔다 |
| 미성년자 | 만 14세 미만은 법정대리인 동의가 필요하다. 학교 관리(admin-suite sms)처럼 미성년자 정보를 다루는 앱은 별도 법무 검토 전 착수하지 않는다 |
| 국외 이전 | 푸시 전송 경로(FCM, APNs)는 국외 사업자다. 처리방침의 위탁·국외 이전 항목에 추가한다 |

### 3.6 모바일 KPI (01_PRD 7장, 제안)

| 지표 | 목표(제안) | 측정 |
|---|---|---|
| 설치 → 로그인 | 50% 이상 | 앱 첫 실행 대비 로그인 성공 |
| 푸시 동의율 | 40% 이상 | 권한 요청 대비 허용 |
| 크래시 없는 세션 비율 | 99.5% 이상 | 크래시 리포팅 도구 |
| 앱 사용자의 웹 결제 전환 | 측정 | (c) 전략일 때 앱 사용자 중 웹 결제 비율 |
| 스토어 평점 | 4.0 이상 | 스토어 콘솔 |

## 4. 개발 방법 지시사항

### 4.1 구조 (제안)

```
<제품 개발 폴더>/
├── apps/web/            Next.js 16.2 (클라우드: 랜딩, Route Handler, 결제, 딥링크 검증 파일)
├── apps/api/            FastAPI (AI)
├── apps/mobile/         Capacitor 앱
│   ├── src/             Vite + React 진입점(모바일 레이아웃, 하단 탭)
│   ├── capacitor.config.ts
│   ├── ios/  android/   네이티브 프로젝트(커밋 대상, 생성 후 직접 수정 최소화)
├── packages/ui/  packages/features/  packages/engine/   ← 웹·데스크톱과 공유
├── packages/shell-bridge/   NativeBridge(Tauri 가이드 10장) + Capacitor 구현
└── supabase/
```

- 화면은 `packages/shell-bridge`만 부르고 `@capacitor/*`를 직접 import하지 않는다. 데스크톱(Tauri)·웹과 같은 인터페이스를 쓴다(Tauri 가이드 10장). 모바일 전용 기능(푸시, 카메라, 햅틱)은 인터페이스에 선택 속성으로 추가한다.
- 화면 빌드는 Vite + React Router가 기본이다(Tauri 가이드 열린 결정 T-D1과 같은 이유). Next.js를 쓰면 `output: 'export'`와 같은 제약이 생긴다.

### 4.2 `capacitor.config.ts` 기준 (계약 예시)

| 키 | 값 | 이유 |
|---|---|---|
| `appId` | 역도메인 형식, 제품별(예: `com.<회사>.<제품>`) | 스토어 등록 후 변경 불가 |
| `webDir` | `dist`(Vite 출력) | 정적 번들 |
| `server.url` | 개발 빌드에서만 개발 서버 주소. 운영 빌드에는 넣지 않는다 | 원격 셸 금지(2장 7번). nomad-commerce의 기존 원격 셸 계획(`docs/products/nomad-commerce/01_PRD.md:131`, `06_AGENT_PLAN.md:67`)은 착수 전에 이 기준과 다시 맞춘다 |
| `server.cleartext` | `false` | 평문 HTTP 금지(`docs/products/nomad-commerce/07_SOURCE_MIGRATION.md:141`의 결함 재발 방지) |
| `server.androidScheme` | `https` | 웹 저장소·쿠키 동작을 https 출처로 맞춘다 |
| 웹뷰 디버깅 | 운영 빌드에서 끈다 | 원격 검사 차단 |

### 4.3 플러그인 기준

| 용도 | 플러그인 | 비고 |
|---|---|---|
| 앱 수명주기, 딥링크 수신 | `@capacitor/app` | `appUrlOpen`, 백 버튼 |
| 시스템 브라우저(OAuth, 웹 결제, 외부 링크) | `@capacitor/browser` | 앱 내부 WebView로 외부 사이트를 열지 않는다 |
| 원격 푸시 | `@capacitor/push-notifications` | Android FCM, iOS APNs |
| 로컬 알림 | `@capacitor/local-notifications` | 오프라인 리마인더 |
| 카메라·사진 | `@capacitor/camera` | 업로드 전 리사이즈 |
| 파일 | `@capacitor/filesystem` | 앱 전용 디렉터리만 |
| 공유 | `@capacitor/share` | PDF·이미지 공유 |
| 네트워크 상태 | `@capacitor/network` | 오프라인 대기열 |
| 기기 정보 | `@capacitor/device` | 기기 모델·OS 버전 |
| 비민감 설정 | `@capacitor/preferences` | 테마, 마지막 탭 등만. 토큰·개인정보 금지 |
| 보안 저장소 | 커뮤니티 플러그인(Keychain/Keystore) | 선정 시 유지 상태·라이선스 확인(미확인) |
| 로컬 DB | 커뮤니티 SQLite 플러그인 | B·C 분류 데이터가 있는 제품만(Tauri 가이드 4장) |
| 상태·내비게이션 바 | Capacitor 8 `SystemBars` | 엣지 투 엣지 대응 |

플러그인 원칙: 공식 플러그인 우선, 커뮤니티 플러그인은 최근 릴리스·이슈 대응·라이선스를 확인하고 `06_AGENT_PLAN.md`에 선정 사유를 남긴다. 모든 플러그인 호출은 `packages/shell-bridge`에서만.

### 4.4 인증 구현

| 단계 | 내용 |
|---|---|
| 클라이언트 | `createClient(url, anonKey, { auth: { storage: <보안 저장소 어댑터>, flowType: 'pkce', autoRefreshToken: true, persistSession: true, detectSessionInUrl: false } })` |
| 소셜 로그인 | `signInWithOAuth({ provider, options: { redirectTo: 'https://<웹 도메인>/auth/mobile-callback' 또는 '<스킴>://auth/callback', skipBrowserRedirect: true } })` → `Browser.open({ url })` → `appUrlOpen`에서 `code` 추출 → `exchangeCodeForSession(code)` → `Browser.close()` |
| 딥링크 방식 | Universal Link(iOS)·App Link(Android) 우선. `apps/web`이 `/.well-known/apple-app-site-association`, `/.well-known/assetlinks.json`을 제공한다. 커스텀 스킴은 대체 경로 |
| 가입 | `options.data.signup_app` 필수(`docs/products/_platform-core/SHARED_MODULES.md:84`) |
| Route Handler 호출 | `Authorization: Bearer`. 코어 요청 T-C1(Tauri 가이드 15장)이 선행 조건 |
| 앱 복귀 | 포그라운드 복귀 시 세션 갱신 먼저 시도, 실패하면 로그인 화면 |
| 인증 단계 | 확정 결정 22의 단계(A Mock → B Google → C1 카카오, C2 네이버)를 따른다. 셸 앱의 단계별 차이(Mock은 개발 빌드 전용, 콜백은 앱에서 교환, 네이버 브리지는 코어 요청 T-C7 전까지 미제공)는 Tauri 가이드 5.4절이 정본 |

### 4.5 푸시 구현

푸시는 공용 알림 모듈 notify의 채널 하나로 만든다. notify는 제품이 `notify.send({ template, to, data, channel })` 하나만 부르고 채널 선택·재시도·수신 동의·발송 기록을 모듈이 맡는 구조이며, 이메일·알림톡·SMS·인앱이 MVP, 웹 푸시가 확장 채널로 잡혀 있다(`docs/products/_platform-core/COMMON_MODULES_ROADMAP.md` 4.1절). 네이티브 앱 푸시는 그 옆에 채널 `push`를 더하는 방식으로 넣고, 제품이 따로 푸시 테이블이나 전송 코드를 만들지 않는다.

| 구성 | 내용 |
|---|---|
| 기기 토큰 저장 | notify 보강안에 웹 푸시 구독 표 `notify.push_subscriptions`(VAPID, 브라우저별 endpoint)가 이미 계획되어 있다(`docs/products/_platform-core/COMMON_MODULES_ROADMAP.md:237`). 새 표를 만들지 않고 이 표에 `platform`(web, ios, android)과 네이티브 토큰(해시 + 암호화 원문), `last_seen_at`, `revoked_at`을 더하는 확장을 모듈 요청 M-C1로 올린다. 등록·폐기 RPC는 본인 기기만(RLS). 제품 스키마에 따로 만들지 않는다 |
| 전송 | notify의 큐 `notify.send`가 채널 `push`일 때 FCM HTTP v1·APNs로 보낸다(모듈 요청 M-C2). 서비스 계정 키는 워커 환경변수에만. 웹 푸시(VAPID) 채널과 같은 템플릿·동의·발송 기록을 쓴다 |
| 트리거 | 제품 이벤트(잡 완료, 결제 확정, 승인 요청)가 `notify.send`를 호출한다. 클라이언트가 다른 사용자에게 푸시를 보내는 경로는 만들지 않는다 |
| 딥링크 | 알림 payload에는 목적지 경로와 id만. 본문·개인정보·금액을 넣지 않는다 |
| 동의 | 3.4절. notify가 `notify.preferences`로 광고성 동의·야간 동의를 확인하고, 없으면 발송하지 않는다 |
| 토큰 정리 | 전송 실패(토큰 무효) 시 `revoked_at` 기록, 로그아웃 시 해당 기기 토큰 폐기 |
| 웹 푸시와의 관계 | PWA 웹 푸시로 먼저 검증하는 제품(local-news NW-F-038, astro-ai 등)은 앱이 생겨도 같은 템플릿과 동의를 쓴다. 사용자가 웹과 앱 둘 다 켜면 notify가 중복 발송을 막는다(제안: 같은 사용자·같은 메시지는 앱 우선 1회) |

### 4.6 오프라인과 로컬 데이터

Tauri 가이드 4장(정본 위치 A~D, 동기화 규약)을 그대로 쓴다. 모바일 추가 규칙:

| 규칙 | 내용 |
|---|---|
| 최소 보관 | 기기 분실을 가정해 A 분류 캐시는 짧게(제안 7일) 두고 로그아웃 시 삭제 |
| 대기열 | 오프라인에서 만든 작업(촬영 업로드, 승인)은 outbox에 두고 온라인 복귀 시 전송. 대기 건수를 화면에 보인다 |
| 대용량 | 사진·녹음은 업로드 성공 후 로컬 사본을 지울지 사용자 설정으로 둔다 |

### 4.7 성능

| 항목 | 기준 |
|---|---|
| 첫 화면 | 스플래시 후 2초 안에 상호작용 가능(제안). 번들 분할, 라우트별 지연 로딩 |
| 목록 | 100행 이상은 가상 스크롤 |
| 이미지 | 업로드 전 장변 2048px 이하로 축소(제안) |
| 3D | 모바일 3D는 히어로 표준의 모바일 예산(300KB, 30fps)을 넘기지 않는다(`docs/design-module/_design-guide/HERO_3D.md:32-41`). 3D 편집 기능은 모바일에 두지 않는다 |
| 웹뷰 차이 | iOS·Android 실기기에서 각각 측정. 시뮬레이터 수치로 합격 판정하지 않는다 |

### 4.8 원격 웹 번들 업데이트(OTA)

| 항목 | 기준 |
|---|---|
| 허용 범위 | 화면·문구·버그 수정 같은 웹 번들 변경만. 네이티브 플러그인 추가·권한 변경·앱의 주 목적 변경은 스토어 배포(원문 확인 필요) |
| 무결성 | 번들 서명 검증, 실패 시 이전 번들로 롤백 |
| 도입 시점 | 첫 스토어 출시 후 배포 빈도가 주 1회를 넘을 때 검토(제안). 상용 서비스와 자체 호스팅은 비용·유지 상태를 비교해 결정(미확인) |

### 4.9 빌드·출시

| 항목 | iOS | Android |
|---|---|---|
| 도구 | Xcode(Capacitor 8 새 프로젝트는 SPM 기본) | Android Studio, Gradle |
| 서명 | Apple Developer 계정, 배포 인증서·프로비저닝 | 업로드 키(Play 앱 서명 사용) |
| 테스트 배포 | TestFlight | Play Console 내부 테스트 |
| 자동화 | CI에서 빌드·서명·업로드(도구는 구현 시 선택) | 같음 |
| 버전 | 웹 번들 버전과 네이티브 빌드 번호를 함께 기록 | 같음 |
| 심사 준비 | 데모 계정, 권한 사용 목적 문구, 개인정보 라벨, 계정 삭제 경로 | 데이터 보안 섹션, 계정 삭제 URL |

### 4.10 보안

| 항목 | 규칙 |
|---|---|
| 비밀 | 앱 번들에 service_role, LLM 키, 결제 시크릿, FCM 서버 키를 넣지 않는다. 클라이언트용 `google-services.json`·`GoogleService-Info.plist`는 비밀이 아니지만 Firebase 콘솔에서 앱 제한을 건다 |
| 통신 | HTTPS만(`cleartext: false`). CSP의 `connect-src`는 제품 API·Supabase·필요한 제공자 도메인만 |
| 외부 콘텐츠 | 외부 사이트는 시스템 브라우저로. 앱 웹뷰에 원격 페이지를 띄우지 않는다 |
| 로그 | 토큰·개인정보·업로드 본문을 콘솔·크래시 리포트에 남기지 않는다 |
| 루팅·탈옥 | 탐지에 보안을 의존하지 않는다. 권한 판정은 서버(`docs/products/_platform-core/SECURITY_BASELINE.md:183`) |

## 5. 제품별 적용 방안

모든 제품의 모바일 앱은 확정 결정 9에 따라 Phase 2 이후다. 아래 단계·우선순위는 제안이며 각 제품 `01_PRD.md` 2장에서 확정한다.

| 제품 | 모바일 가치 | 핵심 기기 기능 | 모바일 범위(제안) | 결제 전략(3.3절) | 권고 |
|---|---|---|---|---|---|
| astro-ai | 큼(개인 소비자, 반복 방문) | 푸시, PDF 열람·공유 | 리포트 열람, 가족 프로필, 새 리포트 신청 | (a) 우선 검토. 경쟁 앱이 모두 앱스토어 충전형 재화·정액권을 판다(`Price_Plans/astro-ai/PRICE_PLAN.md:76-85`). 개인 소비자 디지털 상품이라 (c)는 심사 위험이 높다 | Phase 2. 먼저 PWA + 웹 푸시로 재방문 효과 측정 |
| nomad-commerce | 중간(셀러 이동 중 확인) | 푸시(주문·업로드 결과), 카메라(상품 사진) | 업로드 상태, 실패 알림, 사진 촬영 업로드 | (c) | Phase 2(기존 CM-06-040). 원격 셸 계획을 정적 번들 기준으로 재검토 |
| sceneflow | 중간 | 푸시(제작 완료·업로드 결과·성과), 카메라 원본 업로드 | 진행 확인, 승인, 원본 촬영 업로드 | (c) | Phase 2 |
| nomad-docs | 중간 | 마이크(회의 녹음), 푸시(승인 요청), PDF 공유 | 회의 녹음 → 회의록, 문서 열람·확정 승인 | (c) | Phase 2. 녹음 제3자 고지 화면 필수 |
| book-trailer | 중간 | 푸시(렌더 완료·승인 결과), 공유 시트(완성 영상을 SNS 앱으로), 카메라·사진첩(표지·장면 이미지) | 렌더 진행 확인, 완성 영상 미리보기·공유, 승인 결과 알림. 편집 작업실은 웹 유지 | (c) | Phase 2. 영상 파일은 서명 URL로 내려받아 OS 공유 시트로 넘긴다(앱 안 재인코딩 없음) |
| study-note | 중간 | 마이크(수업 녹음), 오프라인 노트 열람 | 녹음 업로드, 학습 일지 열람 | (c) 또는 (a) | Phase 2. PWA 먼저 |
| admin-suite(erp) | 중간 | 카메라(바코드 스캔), 푸시(재고 경고) | 입출고 스캔, 재고 조회 | (c)(조직 계약) | Phase 2 |
| stock-dashboard | 큼 | 푸시(알림 조건) | 잔고·알림 확인 | (c) | Phase 3. 금융 규제·투자 권유 금지 문구 검토 후, 푸시 문구도 compliance 대상 |
| admin-suite(hms, sms) | 중간 | 푸시(대기 순번, 학부모 알림) | 순번 알림, 공지 열람 | (c)(기관 계약) | Phase 3. 의료정보·미성년자 규제 확인 전 착수 금지 |
| live-poll | 낮음 | 없음(청중은 QR 웹) | 진행자 리모컨 정도 | 해당 없음 | 웹 유지 |
| microweb-studio | 낮음 | 푸시(문의 알림) | 운영자 문의 확인 | (d)(대행 제작 서비스) | Phase 3. 하객은 웹 유지 |
| toon-factory | 낮음 | 공유 | 완성 회차 열람·공유 | (c) | Phase 3 |
| flora-publishing | 낮음 | 오디오 재생 | 원고 열람, 낭독 듣기 | (c) | Phase 3 |
| nomad-blog | 낮음 | 푸시(발행 결과) | 발행 현황 | (c) | 웹 유지(PWA 웹 푸시로 대체) |
| arch-studio | 낮음 | 카메라(대지 사진), 파일 | 제안서·렌더 열람, 대지 사진 첨부 | (c)(설치형 판매) | Phase 3. 3D 편집은 데스크톱 전용 |
| local-news | 중간~큼 | 독자: 속보 푸시. 기자: 현장 사진·녹음 업로드 | 독자 앱은 기사 열람·속보 알림, 기자 앱은 취재 사진·녹음 업로드와 데스크 승인 알림 | 독자 앱 (c), 유료 멤버십·페이월을 앱 안에서 팔면 (a) 대상. 기자 앱 (c) | Phase 2 이후. 독자 푸시는 PWA 웹 푸시(NW-F-038, P1)로 먼저 검증. 신문사마다 이름이 다른 화이트라벨 앱(Multi-tenant_Theming)을 스토어에 따로 올리는 방식은 Apple 지침 4.2.6(템플릿 앱) 제한 여부를 먼저 확인한다(원문 확인 필요) |
| website-floria | 없음 | 없음 | 해당 없음 | 해당 없음 | 웹 유지 |

## 6. 개발 지시사항 (에이전트용)

### 6.1 착수 조건

| 조건 | 내용 |
|---|---|
| PRD | 3장 표들이 제품 `01_PRD.md`에 채워져 있고, 결제 전략(3.3절)이 결정되어 있다 |
| 코어 | T-C1(Bearer 세션), T-C2(CORS), T-C8(셸 로그인 마무리)이 반영되어 있다. 푸시를 쓰면 notify 모듈과 M-C1, M-C2도 |
| 계정 | Apple Developer, Google Play Console, Firebase 프로젝트(FCM용) 준비 |
| 웹 선행 | `apps/web`에 딥링크 검증 파일과 모바일 OAuth 콜백 페이지(필요 시) 배포 |

### 6.2 작업 분해 템플릿

작업 ID는 `<제품약어>-M-###`로 제품 `06_AGENT_PLAN.md`에 넣는다.

| 순서 | 작업 | 소유 경로 | 권장 모델 | 수용 기준 |
|---|---|---|---|---|
| M-001 | 앱 골격: `apps/mobile`(Vite + React), `capacitor.config.ts`(4.2절), iOS·Android 프로젝트 생성 | `apps/mobile/**` | Haiku | 두 OS 실기기에서 빈 화면 실행, `server.url` 운영 빌드 0건, cleartext 꺼짐 |
| M-002 | `packages/shell-bridge` Capacitor 구현 | `packages/shell-bridge/capacitor/**` | Opus | 웹·데스크톱과 같은 인터페이스 테스트 통과 |
| M-003 | 보안 저장소 어댑터 + Supabase 클라이언트 | `packages/shell-bridge/capacitor/secure-store/**` | Opus | Preferences·localStorage에 토큰 0건 |
| M-004 | 소셜 로그인(인증 단계 B 이후): 시스템 브라우저 + Universal/App Link | `packages/features/auth/**`, `apps/web/public/.well-known/**` | Opus | Google 로그인 성공, 앱 내부 WebView OAuth 0건 |
| M-005 | 모바일 레이아웃(하단 탭, 안전 영역, SystemBars) | `apps/mobile/src/layout/**` | Sonnet | 노치·제스처 바 기기에서 겹침 0 |
| M-006 | 제품 모바일 범위 화면 이식 | `packages/features/**`(제품 기능 디렉터리) | Sonnet | PRD 모바일 범위 표의 화면 전부 동작 |
| M-007 | 푸시: 권한 요청 시점, 토큰 등록, 수신·딥링크 이동 | `packages/features/push/**` | Opus | 토큰 등록·폐기, 알림 탭 시 목적지 이동, 광고성 알림 동의 없으면 미수신 |
| M-008 | 제품 이벤트에서 `notify.send`(채널 `push`) 호출 연결 | 제품 이벤트 핸들러(모듈 요청 M-C2 반영 후) | Opus | 무효 토큰 자동 폐기, payload에 본문·개인정보 0 |
| M-009 | 계정 삭제 화면(코어 삭제 절차 연결) | `packages/features/account/**` | Opus | 앱에서 삭제 요청 → 30일 유예 안내 → 철회 가능 |
| M-010 | 오프라인 대기열(제품에 B·C 분류가 있을 때) | `packages/features/offline/**` | Opus | 비행기 모드에서 작업 → 복귀 후 전송, 충돌 시 병합 화면 |
| M-011 | 빌드·서명·테스트 배포 자동화 | CI 설정 | Sonnet | 태그로 TestFlight·Play 내부 테스트 업로드 |
| M-012 | 심사 준비물: 권한 문구, 개인정보 라벨, 데모 계정, 스크린샷 | `apps/mobile/store/**` | Sonnet | 3.2절 점검표 전부 체크 |
| M-013 | 보안 점검(4.10절) | 리뷰 전용 | Fable | 위반 0 |

웨이브(제안): W0 = M-001, M-002 / W1 = M-003, M-004, M-005 / W2 = M-006, M-009 / W3 = M-007, M-008, M-010 / W4 = M-011, M-012, M-013.

### 6.3 요청 프롬프트 예시 (베이스 `_templates/dev-request-prompt.md` 형식)

개발 묶음 생성 스크립트(`develop/_shared/tools/build_root.py:91-98`)가 이 폴더를 복사하지 않으므로, 묶음에 넣기 전까지는 platform-docs 원본 경로를 지시한다.

```
D:/WorkSpace/DEV/<제품>/docs/file 의 모든 파일과 D:/WorkSpace/platform/docs/Capacitor/README.md, D:/WorkSpace/platform/docs/Tauri/README.md 2장을 최대한 자세히 읽고 분석한다.

[요구사항]
<약어>-M-004: Capacitor 앱에서 Google 로그인을 시스템 브라우저 + App Link/Universal Link + PKCE 로 구현한다.
완료 조건 = ① 앱 내부 WebView 로 OAuth 페이지를 여는 코드 0건 ② iOS·Android 실기기 로그인 성공
③ 시작하지 않은 콜백 URL 무시 ④ signup_app 메타데이터 포함 ⑤ Capacitor/README.md 4.4절 준수.

[작업의 특성]
작업 대상 경로: packages/features/auth/, apps/web/public/.well-known/
supabase/ 와 코어 패키지는 수정하지 않는다.

이 요구와 근거 산출물(baseline)로 작업을 만들어 진행한다.
승인·결정 사항은 묻지 말고 먼저 진행한 뒤, 임의로 결정한 내용은 log.md 에 [DECISION] 으로 남긴다.
```

### 6.4 금지 패턴

| 분류 | 금지 |
|---|---|
| 셸 | 운영 빌드의 `server.url` 원격 셸, cleartext, 앱 웹뷰에 외부 사이트 로드 |
| 인증 | 앱 내부 WebView 소셜 로그인, Preferences·localStorage 토큰 저장 |
| 결제 | 결제 전략 결정 없이 앱 안에 결제 화면 추가, 클라이언트 결제 결과로 크레딧 지급 |
| 푸시 | 동의 없는 광고성 푸시, payload에 개인정보·본문·금액, 클라이언트에서 타인에게 푸시 전송 |
| 비밀 | 앱 번들에 서버 키·FCM 서버 키 |
| 데이터 | Firebase Auth·Firestore를 Supabase와 병행해 정본을 둘로 나누기 |

## 7. 열린 결정

| ID | 결정 | 선택지 | 권고 |
|---|---|---|---|
| M-D1 | 모바일 첫 제품 | astro-ai, nomad-commerce(기존 계획), nomad-docs(회의 녹음) | 결제 전략 (c)로 갈 수 있고 기기 기능 가치가 분명한 제품부터. nomad-commerce는 기존 계획이 있으나 원격 셸 기준 재검토가 먼저 |
| M-D2 | 결제 전략 기본값 | 3.3절 (a)~(d) | (c). 개인 소비자 디지털 상품 제품만 제품별로 (a) 검토 |
| M-D3 | 보안 저장소·SQLite 플러그인 선정 | 커뮤니티 후보 비교 | 첫 모바일 제품 W0에서 유지 상태·라이선스 확인 후 공용으로 고정 |
| M-D4 | OTA 업데이트 도입 | (a) 미도입 (b) 상용 서비스 (c) 자체 호스팅 | (a)로 시작, 4.8절 조건 충족 시 비교 |
| M-D5 | 크래시 리포팅 도구 | 상용 후보 비교 | 개인정보 전송 범위(로그 마스킹) 확인 후 결정(미확인) |

## 8. 코어 요청

| ID | 요청 | 이유 |
|---|---|---|
| T-C1, T-C2, T-C6, T-C7, T-C8 | Bearer 세션, CORS 규격, 앱 Redirect URL 등록, 네이버 브리지용 교환 코드, 셸 로그인 마무리 엔드포인트(Tauri 가이드 15장과 같음) | 앱은 쿠키 세션을 쓰지 않고 콜백을 앱에서 받는다 |
| M-C1 | notify `notify.push_subscriptions`를 네이티브 토큰까지 받도록 확장(`platform` web·ios·android), 등록·폐기 RPC(RLS: 본인 기기만) | 4.5절. 공용 모듈 요청이라 `COMMON_MODULES_ROADMAP.md` 8장 절차를 따른다 |
| M-C2 | notify 채널 `push`(FCM HTTP v1, APNs) 전송과 웹 푸시·앱 푸시 중복 방지 | 4.5절, 3.4절 |
| M-C3 | 스토어 인앱결제 영수증 검증과 `payment_orders` 확장(Phase 3, (a) 전략 제품이 생길 때) | 3.3절 |
| M-C4 | 계정 삭제 요청·철회 RPC를 앱에서 호출할 수 있게 공개 범위 정리 | 2장 6번 |

## 9. 출처 (확인일 2026-10-14)

| 내용 | 출처 |
|---|---|
| Capacitor 8 발표(2025-12-09), SPM 기본, SystemBars | [Ionic Blog: Announcing Capacitor 8](https://ionic.io/blog/announcing-capacitor-8) |
| Preferences는 데이터베이스 용도가 아님, SQLite 기반 저장소 권장 | [Capacitor Preferences API](https://capacitorjs.com/docs/apis/preferences) |
| 네이티브 앱 OAuth·딥링크 흐름(`skipBrowserRedirect`) | [Supabase: Native Mobile Deep Linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking) |
| Google 임베디드 웹뷰 OAuth 차단 | [Google Developers Blog (2021-06)](https://developers.googleblog.com/2021/06/upcoming-security-changes-to-googles-oauth-2.0-authorization-endpoint.html) |
| 국내 제3자 결제 수수료 약 26%, PG 포함 31~36% | [쿠키뉴스 2026-01-09](https://www.kukinews.com/article/view/kuk202601080137) |
| 기존 레포 결정: Capacitor는 MVP 이후, 원격 셸 결함 | `docs/products/00_MERGE_ANALYSIS.md:17`, `:921-924`, `docs/products/nomad-commerce/07_SOURCE_MIGRATION.md:141` |
