# media: 미디어 라이브러리 (공용모듈 기획서)

작성일 2026-10-15. 상태: 제안. 패키지 `@nomad/media`, 스키마 `media`(0250~0299), 오류 코드 `MD###`. 출처: local-news M1의 `news.media_assets`와 사진 처리 규칙(`docs/products/local-news/modules/M1_newsroom-cms.md`). 개발서 `docs/develop/_shared/modules/media.md`.

## 1. 문제

이미지를 쓰는 제품이 9개 이상이다(적용표 `README.md` 1장). 제품마다 업로드·리사이즈·대체 텍스트·저작권 표기를 따로 만들면 (1) 원본 이미지를 그대로 내보내 페이지가 무거워지고(LCP 악화) (2) 대체 텍스트 누락으로 접근성 기준(WCAG 1.1.1)을 못 지키며 (3) 사용 기간이 끝난 사진이 계속 노출되는 저작권 사고가 난다. 코어는 Storage 경로 규칙(`core.storage_org_id`, 첫 폴더 = org_id)만 주고, 자산 메타데이터와 사본은 없다.

## 2. 범위

| 구분 | 내용 |
|---|---|
| MVP | 업로드 등록·완료(서명 URL), 중복 검사(SHA-256), 크기별 사본(프리셋), 대체 텍스트·캡션·출처, 라이선스 종류와 만료, AI 생성 여부(compliance 라벨 연결), 사용처 추적(사용 중이면 삭제 불가), 라이브러리 화면·선택기 컴포넌트 |
| 확장 | 폴더·태그, 초점(focal point) 자르기, 영상·음성 트랜스코딩(sceneflow는 자체 파이프라인 유지), AI 대체 텍스트 제안(AI 게이트 경유, 사람 확인), EXIF 위치정보 자동 삭제 확인 리포트 |
| 제품에 남김 | 영상 렌더 파이프라인(sceneflow), 인쇄용 고해상도 PDF 자산(flora-publishing), 캐릭터 모듈 포즈·표정(toon-factory) |

## 3. 데이터 모델

| 표 | 주요 컬럼 | RLS·쓰기 |
|---|---|---|
| `media.assets` | `id`, `org_id`, `app_id`, `bucket`(`public-assets` 또는 `org-files`), `path`(`<org>/<app>/media/<id>/original.<ext>`), `kind`(`image`, `video`, `audio`, `file`), `mime`, `bytes`, `width`, `height`, `duration_ms`, `sha256`, `alt_text`, `caption`, `credit`, `license`(`own`, `licensed`, `wire`, `ugc`, `ai_generated`, `public_domain`), `license_expires_at`, `ai_generated`(bool), `status`(`uploading`→`ready`/`failed`, `deleted`), `created_by`, `created_at` | 읽기: org 멤버. 공개 버킷 자산은 사본 URL로만 노출. 쓰기: `media.register_upload`, `media.finalize_upload`, `media.update_meta`, `media.delete_asset` RPC. unique(`org_id`, `app_id`, `sha256`) |
| `media.renditions` | `asset_id`, `preset`(`thumb_320`, `card_640`, `content_960`, `hero_1600`, `og_1200x630`, `square_1080`), `path`, `width`, `height`, `format`(`webp`, `avif`, `jpeg`), `bytes` | 읽기: 자산과 같음. 쓰기: service(잡) |
| `media.usages` | `asset_id`, `owner_module`(예 `editorial`, `ads`, `news`), `owner_type`, `owner_id`, `role`(`hero`, `inline`, `creative`, `avatar`), `created_at` | 쓰기: 소유 모듈의 RPC가 `media.attach`/`media.detach` 호출 |
| `media.settings` | `org_id`, `app_id`, `max_upload_mb`, `allowed_mime`, `presets`(jsonb, 제품별 추가 프리셋), `require_alt`(bool), `strip_exif`(bool, 기본 true) | org admin |

함수: `media.alt_text_ok(owner_module, owner_type, owner_id)`(그 대상에 연결된 이미지에 대체 텍스트가 모두 있는가, editorial 게시 가드), `media.public_url(asset_id, preset)`.

오류 코드: `MD001` 허용되지 않는 형식, `MD002` 용량 초과, `MD003` 사용 중 자산 삭제 시도, `MD004` 대체 텍스트 필수인데 없음(게시 시점 검사), `MD005` 라이선스 만료 자산을 새로 연결.

## 4. 처리 흐름

| 단계 | 동작 |
|---|---|
| 1 등록 | 서버가 `media.register_upload`(형식·용량·중복 검사) → Storage 서명 업로드 URL 발급. 중복이면 기존 자산 id 반환 |
| 2 업로드 | 브라우저가 서명 URL로 원본 업로드(서버를 거치지 않음) |
| 3 완료 | `media.finalize_upload` → 잡 `media.process`(EXIF 제거, 크기 확인, 사본 생성, 차원 기록) → `ready` |
| 4 사용 | 소유 모듈이 `media.attach(asset, owner)`. 라이선스 만료면 `MD005` |
| 5 만료 | 일 1회 잡이 만료 자산을 찾아 이벤트 `media.asset.license_expired` → 소유 모듈이 비노출 처리(예: 기사 대표 사진을 기본 이미지로) |
| 6 삭제 | 사용처가 없을 때만. 원본·사본 Storage 삭제는 잡(30일 휴지통, 제안) |

사본 생성 방식은 결정 MD-D1(Supabase 이미지 변환 / 워커에서 sharp로 미리 생성).

## 5. 공개 API (TS 계약 예시)

```ts
// @nomad/media/server
registerUpload(input: { appId; orgId; filename; mime; bytes; sha256 }): Promise<{ assetId: string; uploadUrl?: string; duplicate: boolean }>
finalizeUpload(assetId: string): Promise<void>
attach(assetId: string, owner: { module: string; type: string; id: string; role: UsageRole }): Promise<void>
detach(assetId: string, owner: OwnerRef): Promise<void>
getRendition(assetId: string, preset: Preset): Promise<{ url: string; width: number; height: number }>
// @nomad/media/ui
<MediaPicker appId kinds={['image']} requireAlt onSelect /> <ResponsiveImage assetId sizes="(max-width: 768px) 100vw, 640px" />
```

`ResponsiveImage`는 `srcset`과 `width`·`height`를 항상 넣어 레이아웃 이동(CLS)을 막는다.

## 6. 이벤트

`media.asset.ready`, `media.asset.failed`, `media.asset.license_expired`, `media.asset.deleted`.

## 7. 보안·개인정보

| 항목 | 규칙 |
|---|---|
| EXIF | 위치정보(GPS) 포함 메타데이터는 기본 삭제(`strip_exif`). 제보 사진처럼 원본 증거가 필요한 경우만 비공개 버킷에 원본 보존 |
| 비공개 자산 | `org-files` 버킷은 서명 URL(짧은 만료)로만 |
| 외부 핫링크 | 외부 URL을 그대로 쓰지 않고 가져와 재호스팅(출처 표기 유지) |
| AI 생성 | `ai_generated = true`면 compliance `ai_generated` 라벨을 캡션에 자동 표시 |

## 8. 실패 동작

사본 생성 실패는 잡 재시도 3회 → `failed`와 라이브러리에 "다시 처리" 버튼. 원본은 지우지 않는다. 사본이 없을 때 원본을 대신 내보내지 않는다(대용량 노출 방지, 자리 표시 이미지).

## 9. local-news에서 옮기는 것

| local-news | 공용 |
|---|---|
| `news.media_assets` | `media.assets`(+ `renditions`, `usages`) |
| 이관 사진 `alt_text` 보충 규칙(07장 2절 4단계) | `require_alt` + 라이브러리 "대체 텍스트 없음" 필터 |
| 사진 출처·저작권 표기 | `credit`, `license`, `license_expires_at` |

## 10. 결정 필요

| ID | 결정 | 선택지 | 권고 |
|---|---|---|---|
| MD-D1 | 사본 생성 | (a) Supabase 이미지 변환(요청 시 변환, 유료 플랜 기능, 요금 확인 필요) (b) 워커에서 sharp로 프리셋 미리 생성 | (b). 비용 예측이 쉽고 CDN 캐시가 단순. 프리셋 밖 크기가 필요해지면 (a) 병행 |
| MD-D2 | 휴지통 보존 기간 | 즉시 / 30일 | 30일(제안) |
| MD-D3 | AI 대체 텍스트 제안 | 1차 포함 / 확장 | 확장(크레딧 과금 기능으로) |
