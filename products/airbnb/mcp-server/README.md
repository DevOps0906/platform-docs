# Stay MCP 서버 뼈대

정본 문서는 `../MCP.md`, 공통 규칙은 `../../_platform-core/MCP_BASELINE.md`. 이 폴더는 **뼈대**이며 아직 배포 대상이 아니다.

## 지금 들어 있는 것 (MVP, 읽기 전용 R0)

| 도구 | 호출 RPC |
|---|---|
| `stay_search_listings` | `search_listings` |
| `stay_get_listing` | `get_listing_public` |
| `stay_get_unavailable_dates` | `listing_unavailable_ranges` |
| `stay_get_listing_reviews` | `listing_reviews_public` |

## 의도적으로 없는 것

- service_role 키 (설정에 있으면 시작을 거부)
- 예약 확정·승인·취소·삭제·결제 도구
- 정확한 주소·좌표·체크인 안내 (출력 허용 목록에 없음, 테스트로 강제)
- 로그인 도구와 `stay_prepare_reservation` (MCP.md D-M1, D-M3, D-M5 결정 후)

## 실행

```
cp .env.example .env     # 값은 직접 채운다. 커밋하지 않는다
npm install
npm run typecheck
npm test
npm run dev:stdio        # 로컬 MCP 클라이언트 연결용
npm run dev:http         # 127.0.0.1:8787/mcp (Streamable HTTP, 익명 30회/분)
```

## 확인이 남은 가정

- RPC가 돌려주는 jsonb 키는 `0002_stay_domain.sql`(`stay_listing_card`, `get_listing_public`, `listing_reviews_public`) 기준이다. 마이그레이션이 바뀌면 `src/tools/shared.ts` 허용 목록을 같이 고친다.
- 실제 Supabase에 붙여 호출하는 통합 테스트는 아직 없다. 지금 테스트는 가짜 DB로 출력 필터와 오류 처리를 확인한다.
- 원격 배포 시 인증(OAuth), 다중 인스턴스 레이트 리밋, 로그는 MCP.md 8절 결정 후 추가한다.
