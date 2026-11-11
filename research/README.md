# research — 외부 조사 노트

영상·오픈소스를 조사해 "어느 제품에 적용할 수 있는가"를 기록하는 폴더다. **후보 기록이며 결정이 아니다.** 제품 기획서(`products/`)가 정본이고, 여기 내용을 제품에 반영하려면 그 제품 개발 착수 때 채택 여부를 정한다(공용모듈 적용표의 ○ 후보와 같은 방식).

| 날짜 | 노트 | 내용 | 확인 상태 |
|---|---|---|---|
| 2026-11-11 | [code-video-and-youtube-intake](2026-11-11_code-video-and-youtube-intake.md) | 코드 기반 영상 렌더(hyperframes 등), 디자인 스킬, 유튜브 링크 요약·캡처 오픈소스의 제품별 적용 후보 | 미검증(영상 분석·소개 페이지 기반) |

## 쓰는 규칙

- 파일 이름은 `YYYY-MM-DD_주제.md`, 위 표에 한 줄을 더한다.
- 확인 범위(직접 본 것, 못 본 것)와 출처 주소를 노트 첫머리·끝에 적는다.
- 디자인 기준은 이 저장소가 아니라 [nomad-design-modules](https://github.com/DevOps0906/nomad-design-modules)에서 관리한다(README 9장). 여기에는 후보만 적는다.
- 폴더·파일을 더하면 `python3 -I _tools/folder_tree.py`로 `FOLDER_TREE.md`를 다시 만든다.
