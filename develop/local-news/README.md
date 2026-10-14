# local-news 개발 묶음 — 로컬뉴스 클라우드(가칭)

여러 지역신문사가 구독하는 멀티테넌트 뉴스룸 SaaS입니다. 편집국 콘솔(기사 작성·데스크 승인·홈 편집·광고·뉴스레터·법정 표기), 신문사마다 자기 제호·도메인으로 열리는 독자 사이트(메인 템플릿 3종), 보도자료 → AI 초안·편집국 AI 어시스턴트·인터뷰 받아쓰기·오디오 기사가 들어갑니다.

| 항목 | 내용 |
|---|---|
| 주 사용자 | 인터넷 지역신문·지역 주간·일간지 편집국, 지역 독자, 지역 업소·기관 |
| DB 스키마(모듈러 번호) | `news`(2500). 1차는 단독 Supabase 프로젝트 |
| 개발 작업 수 | 56개(`products/local-news/06_AGENT_PLAN.md`, 인증 B·C 4개 포함) |
| 인증 단계 | 편집국·독자 모두 Mock(Stage A)로 시작 → G1 후 Google + 이메일(B) → G2 후 카카오·네이버(독자 P1, 편집국 P2 선택). [`local-news_develop.md`](local-news_develop.md) 19장 |
| 공통모듈 | 8개(뉴스룸 CMS, 독자 멤버십, 광고, 뉴스레터·푸시, 커뮤니티, 배포·SEO, 법정 준수, 검색·분석). 기획서 `products/local-news/modules/`, 개발서 [`modules/`](modules/) |
| 기획서 | [`products/local-news/`](../../products/local-news/) |

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`local-news_develop.md`](local-news_develop.md) | 개발 방법 안내서. 0장부터 순서대로 |
| [`modules/`](modules/) | 공통모듈 8개 개발서와 README(만드는 순서, 디렉토리, 외부 서비스 링크, 테스트) |
| `setup-local-news.sh` / `setup-local-news.ps1` | 베이스 레포를 복사해 개발 폴더 `D:\WorkSpace\DEV\local-news\`를 만들고 묶음을 붙이는 설치 스크립트. 먼저 `--dry-run` / `-DryRun` |
| `local-news-root/` | 개발 폴더 루트에 붙는 내용. 직접 고치지 않고 `../_shared/tools/build_root.py`로 다시 만든다 |

## 시작하기

```bash
bash /d/WorkSpace/platform/docs/develop/local-news/setup-local-news.sh --dry-run   # 할 일 확인
bash /d/WorkSpace/platform/docs/develop/local-news/setup-local-news.sh             # 실제 실행
```
