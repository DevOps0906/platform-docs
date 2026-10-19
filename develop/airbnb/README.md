# airbnb 개발 묶음 — Stay(가칭)

여행자(게스트)가 지도·날짜·인원으로 숙소를 찾아 예약을 요청하고, 개인 호스트가 13단계 마법사로 숙소를 올려 예약을 승인·관리하는 숙소 공유 서비스입니다(Airbnb 클론코딩 원본을 공용 코어 위에서 다시 설계). 숙소 AI 도우미, 자연어 검색, 숙소 소개 작성 도우미, 리뷰 요약, 호스트 위키, 음성 대화, 3D 히어로가 들어갑니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 게스트(여행자), 개인 호스트, 운영자 1인 |
| DB 스키마(모듈러 번호) | `stay`(2700, 제안·등록 요청). 이번 개발은 단독 Supabase `public` 스키마(모놀리스) |
| 개발 작업 수 | 45개(`products/airbnb/06_AGENT_PLAN.md`, SY-06-001~045, 사람 작업 1개 포함) |
| 인증 단계 | Mock(개발) → Google + 이메일(공개 베타 전) → 카카오·네이버(G2 후). 비로그인 검색·상세는 단계와 무관(`airbnb_develop.md` 19장) |
| 기획서 | [`products/airbnb/`](../../products/airbnb/) |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`airbnb_develop.md`](airbnb_develop.md) | 개발 방법 안내서. 0장부터 순서대로 따라간다 |

다른 제품에 있는 `setup-<제품>.sh` / `.ps1`과 `<제품>-root/` 묶음은 **아직 없습니다**(이번 묶음은 "핵심만"). docs 저장소에 넣은 뒤 아래 순서로 만듭니다.

| 순서 | 할 일 |
|---|---|
| 1 | `develop/_shared/tools/build_root.py`의 `REVIEWS` 딕셔너리에 `'airbnb': ['Airbnb_CloneCoding.md']`, `APP_ID` 딕셔너리에 `'airbnb': 'stay'`를 추가한다 |
| 2 | `python -I develop/_shared/tools/build_root.py airbnb` 실행 → `develop/airbnb/airbnb-root/` 생성(`--check`로 경로 검사) |
| 3 | `setup-live-poll.sh` / `.ps1`을 복사해 `setup-airbnb.*`로 이름을 바꾸고 제품명·경로(`live-poll` → `airbnb`)를 바꾼다 |

스크립트가 생기기 전에는 `airbnb_develop.md` 부록 A의 손 작업으로 바로 시작할 수 있습니다.

## 시작하기

```bash
# 스크립트를 만든 뒤
bash /d/WorkSpace/platform/docs/develop/airbnb/setup-airbnb.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/airbnb/setup-airbnb.sh             # 실제 실행
```

전체 흐름은 저장소 맨 위 [README](../../README.md) 6장을 참고한다.
