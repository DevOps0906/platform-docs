# 05_RUNTIME_AND_DOMAINS — 요청 처리, 캐시, 커스텀 도메인, 메일, 장애 대응

작성일 2026-10-14. 호스팅은 Vercel(웹), Supabase(DB·Storage) 기준. 외부 서비스 API 이름·버전은 구현 시 각 공식 문서로 확인한다(표에 "확인 필요"로 표시).

## 1. 테넌트 식별 순서

| 순서 | 조건 | 해석 호출 | 화면 |
|---|---|---|---|
| 1 | 호스트가 활성 커스텀 도메인 | `resolve_tenant(host, null, null)` | 그 조직·그 앱 |
| 2 | 호스트가 `<slug>.<플랫폼 루트 도메인>` | `resolve_tenant(null, slug, app)` | 그 조직. 대표 커스텀 도메인(`primary_domain`)이 있으면 같은 경로로 **301 이동** |
| 3 | 플랫폼 루트 도메인 + 로그인 사용자 | `resolve_tenant(null, session.org.slug, app)` | 사용자의 현재 조직 테마(앱 내부 화면만) |
| 4 | 그 외, 또는 결과 `null` | - | 제품 기본 브랜드 |

- `app`은 배포마다 고정값(`NEXT_PUBLIC_APP_ID` 같은 공개 상수)이다. 커스텀 도메인은 DB의 `tenant_domains.app_id`를 따른다. 두 값이 다르면 404(다른 제품 배포로 들어온 도메인).
- 단계가 0이 되면(구독 해지, 정지) 해석 결과가 `null`이 되어 즉시 기본 브랜드로 돌아간다. 커스텀 도메인 접속은 "서비스가 일시 중지되었습니다" 안내 페이지로 보낸다(데이터 노출 없음).

## 2. 캐시와 무효화

| 캐시 | 키·태그 | 수명 | 무효화 이벤트 |
|---|---|---|---|
| 요청 내 | React `cache(getTenant)` | 요청 1회 | - |
| 서버 교차 요청 | 태그 `host:<host>`, `tenant:<org_id>` | 기본 1시간(제안), 태그로 즉시 무효화 | 테마 게시·되돌리기, 설정·라벨 저장, 도메인 상태 변경, 단계 변경(플랜 변경 웹훅·오버라이드 저장) |
| 브라우저 | 로고·파비콘 URL에 `?v=<theme.version>` | 1년(불변 파일) | 새 버전이 새 URL |
| CDN(Storage 공개 버킷) | 경로 | Supabase 기본 | 슬롯 파일은 `<theme_id>/` 아래라 테마마다 경로가 달라 덮어쓰기 문제가 없다 |

무효화는 변경을 일으킨 Route Handler가 응답 전에 실행한다. 웹훅·크론처럼 Next.js 밖에서 생긴 변경은 내부 엔드포인트(`POST /api/internal/tenant/revalidate`, 서명 필요)로 태그를 무효화한다. Next.js 16의 태그 무효화 API(`revalidateTag`, 게시 직후 관리자 화면 즉시 반영용 API 등)는 구현 시 16.2 문서로 확인한다(확인 필요).

## 3. 렌더링 규칙 (깜빡임·노출 사고 방지)

| 규칙 | 이유 |
|---|---|
| 테마 CSS·서체 클래스·파비콘·타이틀은 루트 레이아웃이 서버에서 렌더 | 첫 화면부터 고객사 브랜드. 클라이언트에서 바꾸면 플랫폼 색이 잠깐 보인다 |
| 다크 모드 선택 스크립트(`data-theme`)는 `<head>` 맨 앞 인라인(nonce) | 다크 깜빡임 방지(기존 방식 유지) |
| 공개 랜딩(`(marketing)`)도 테넌트가 있으면 테넌트 브랜드. 단 플랫폼 마케팅 문구(제품 소개, 가격)는 테넌트 도메인에서 숨김 | 고객사 도메인에서 우리 회사 가격표가 보이면 화이트라벨이 깨진다 |
| "Powered by"는 단계 설정으로 제어(제안: L1 표시, L2 이상 숨김 가능 = `features.hide_powered_by`) | 상품 차등 |
| 메타데이터: `title` 템플릿 `%s \| <brand_name>`, `og:site_name`, `manifest.name`, `theme_color` | 공유·설치 시 브랜드 |

## 4. 커스텀 도메인 연결 (L2)

### 4.1 흐름

| 단계 | 누가 | 하는 일 | DB |
|---|---|---|---|
| 1 | 고객사 owner/admin | 설정 > 도메인에 `app.acme.co.kr` 입력 | `request_tenant_domain` → `pending` |
| 2 | Route Handler(서버) | Vercel 프로젝트에 도메인 추가(Vercel REST API의 프로젝트 도메인 추가, 확인 필요). 응답의 검증·DNS 안내를 저장 | `set_tenant_domain_status('verifying', 안내)` |
| 3 | 고객사 | DNS 설정: 서브도메인은 CNAME, 루트 도메인은 A 레코드(값은 Vercel 안내 그대로 표시). 이미 다른 Vercel 계정에 붙은 도메인이면 TXT 소유 확인 레코드 추가 | - |
| 4 | 크론(10분) | 프로젝트 도메인 조회·검증 API로 상태 확인(확인 필요) → 인증서 발급까지 확인 | `active` + 첫 활성이면 `is_primary` / 실패 누적 24시간이면 `failed` |
| 5 | 서버 | 캐시 태그 `host:<host>`·`tenant:<org>` 무효화, 고객사에 완료 메일 | - |
| 해지 | owner/admin 또는 운영자 | Vercel에서 도메인 제거 → `removed` | 같은 호스트 이름 재요청 가능 |

### 4.2 규칙

| 항목 | 규칙 |
|---|---|
| 서브도메인 | 플랫폼 루트 도메인에 와일드카드(`*.myplatform.com`)를 한 번 연결해 두고 조직 slug로 해석한다. 행을 만들지 않는다. Vercel 와일드카드 도메인은 네임서버를 Vercel로 두는 방식이 필요할 수 있다(확인 필요) |
| slug | 회사 조직 slug는 운영자(service_role)만 바꾼다(코어 `guard_organization_columns`). 예약어 목록(`www`, `app`, `api`, `admin`, `mail`, `docs`, `status` 등)은 쓰지 않는다 |
| 개수·형식 | 조직당 5개(TM004), 소문자 FQDN, 전 플랫폼 유일(TM005) |
| 소유권 | 실제 소유 확인은 호스팅(Vercel)의 검증과 DNS가 맡는다. DB `active`는 그 결과만 반영 |
| HTTPS | 인증서는 호스팅이 발급. `active` 전에는 해석하지 않는다(테스트 항목 "활성화 전 도메인은 해석되지 않음") |
| 모델 B | 고객사 전용 배포(별도 Vercel 프로젝트)면 도메인은 그 프로젝트에 붙이고 `tenant_deployments.vercel_project_id`로 관리 |
| 이동 | 서브도메인 접속은 대표 커스텀 도메인으로 301(검색 중복 방지). 대표 도메인이 `failed`가 되면 이동을 멈춘다 |

## 5. 메일

| 항목 | 규칙 |
|---|---|
| 발신 이름 | `tenant_settings.email_from_name`(없으면 `brand_name`). 헤더 주입 문자는 DB가 거부 |
| 발신 주소·도메인 | 기본은 플랫폼 발신 도메인(`no-reply@mail.<플랫폼>`)과 `Reply-To: support_email`. SPF·DKIM·DMARC는 플랫폼 도메인 하나만 관리 |
| 고객 도메인 발신 | L4 옵션: 고객 DNS에 DKIM·SPF 레코드 추가가 필요하므로 별도 견적. 메일 발송 서비스의 도메인 인증 API 사용(확인 필요) |
| 디자인 | 머리 이미지 `email_header`, 버튼 색은 `brand` hex, 푸터에 `legal` 사업자 정보·수신 거부 |
| 라벨 | 메일 문구도 `t(key)`(테넌트 라벨 적용) |

## 6. 장애와 폴백

| 상황 | 동작 |
|---|---|
| `resolve_tenant` 오류·지연(제안: 300ms 초과) | 마지막 캐시 값이 있으면 사용, 없으면 기본 브랜드로 렌더하고 오류 기록. 페이지를 실패시키지 않는다 |
| 로고 파일 없음·로드 실패 | 02장 3절 슬롯 폴백(브랜드 이름 텍스트, 첫 글자 마크) |
| 서체 키가 레지스트리에 없음 | 기본 서체 |
| 허용 목록 밖 토큰(DB 직접 수정 등) | `themeCss`가 무시하고 기록 |
| 확장 키가 레지스트리에 없음 | `<Slot>` fallback, 훅은 건너뛰고 기록 |
| 도메인 인증서 만료·DNS 변경 | 크론이 `failed`로 바꾸고 고객사·운영자에게 알림, 서브도메인 이동 중지 |

## 7. 관측

| 항목 | 기록 |
|---|---|
| 해석 | 호스트, 결과 org_id·단계·테마 버전, 캐시 적중 여부, 소요 시간(샘플링) |
| 변경 | 감사 로그 `theme.publish`, `theme.clone`, `domain.request`, `domain.status`(DB가 기록), 설정·라벨 저장(Route Handler가 `write_audit`) |
| 경고 | 도메인 `failed`, 해석 오류율, 대비 자동 보정 비율(높으면 팔레트 규칙 조정) |
