# media 개발 지시서 (`@nomad/media`)

기획 정본: `products/_platform-core/common-modules/media.md`. 공통 규칙·적용 절차: [`README.md`](README.md).

## 1. 만들 것 (v1.0)

서명 업로드, 중복 검사, 처리 잡(EXIF 제거·크기 측정·프리셋 사본), 메타데이터(대체 텍스트·캡션·출처·라이선스·만료·AI 생성), 사용처 추적과 삭제 보호, 라이선스 만료 잡, 라이브러리·선택기·반응형 이미지 컴포넌트.

## 2. 파일

| 경로 | 책임 |
|---|---|
| `sql/0250_media.sql` | `assets`, `renditions`, `usages`, `settings`, RPC(`register_upload`, `finalize_upload`, `update_meta`, `attach`, `detach`, `delete_asset`), 함수 `alt_text_ok`(editorial 가드용) |
| `src/server/upload.ts`, `attach.ts`, `rendition.ts` | 공개 API |
| `worker/handlers/media/process.ts` | sharp로 프리셋 생성(WebP·AVIF + JPEG 대체), EXIF 제거 |
| `worker/handlers/media/license-expiry.ts` | 일 1회 만료 이벤트 |
| `src/ui/MediaPicker.tsx`, `MediaLibrary.tsx`, `ResponsiveImage.tsx` | 화면 |

## 3. 구현 순서

| 순서 | 작업 | 확인 |
|---|---|---|
| 1 | SQL + Storage 경로 규칙(`<org>/<app>/media/<asset>/…`, 첫 폴더 org = 코어 `storage_org_id` 정책 그대로) | 다른 org 경로 업로드 거부 |
| 2 | 등록 → 서명 URL → 완료 → 잡 | 같은 파일 두 번 올리면 같은 id |
| 3 | 프리셋 사본(결정 MD-D1 (b)) | 원본 4000px JPEG → `hero_1600` WebP 200KB 이하(목표, 제안) |
| 4 | `ResponsiveImage`: `srcset`, `sizes`, `width`·`height` 필수, LCP 이미지는 `priority` | CLS 0, Lighthouse LCP 개선 |
| 5 | 사용처·삭제 보호, 만료 잡 | 사용 중 삭제 `MD003` |
| 6 | 라이브러리 화면: 필터(대체 텍스트 없음, 만료 임박, AI 생성) | axe 위반 0 |

## 4. 외부 서비스·공식 문서

| 주제 | 링크 |
|---|---|
| Supabase 서명 업로드 URL | https://supabase.com/docs/reference/javascript/storage-from-createsigneduploadurl |
| Supabase 이미지 변환(MD-D1 (a) 선택 시) | https://supabase.com/docs/guides/storage/serving/image-transformations |
| sharp | https://sharp.pixelplumbing.com |
| LCP 최적화 | https://web.dev/articles/optimize-lcp |
| 대체 텍스트 기준(WCAG 1.1.1) | https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html |

## 5. 제품 주입 값

`appId`, `presets`(제품 추가 프리셋, 예 microweb `square_1080`), `requireAlt`(local-news·website-floria `true`), `maxUploadMb`, `allowedMime`, 만료 시 대체 이미지 경로.

## 6. 테스트

형식·용량 거부(`MD001`·`MD002`), 중복, 처리 실패 재시도 후 `failed`, 사본 없을 때 원본을 내보내지 않음, EXIF GPS 제거 확인(샘플 사진), 만료 이벤트 → 소유 모듈 콜백.

## 7. 자주 나는 문제

| 증상 | 원인·해결 |
|---|---|
| HEIC 업로드 실패 | 허용 형식에 넣고 처리 잡에서 JPEG·WebP로 변환(sharp HEIF 지원 빌드 확인) |
| 사본이 캐시돼 메타 수정이 안 보임 | 사본 경로에 버전 붙이기(`…/v<n>/hero_1600.webp`) |
