# develop/_shared — 제품 공용 설치 가이드와 도구

14개 제품의 개발 묶음이 함께 쓰는 자료입니다. 제품 폴더의 안내서가 필요한 곳에서 이 문서들을 가리킵니다.

| 경로 | 내용 |
|---|---|
| [`auth/README.md`](auth/README.md) | 소셜 로그인 개발 지시서(Google·카카오·네이버): 외부 콘솔 설정 절차와 공식 링크, 공용 모듈 `@nomad/core-auth` 구조, 테스트, 공용 모듈 완료 후 14개 제품 적용 절차. 기획 정본은 `products/_platform-core/AUTH_ROADMAP.md` |
| [`modules/README.md`](modules/README.md) | 공용모듈 7개(compliance, media, editorial, community, search, membership, ads) 개발 지시서: 패키지 구성, 만드는 순서, 버전, 15개 제품 적용 절차. 기획 정본은 `products/_platform-core/common-modules/` |
| [`dify/README.md`](dify/README.md) | 공용 Dify(AI 채팅·운영 서버) 설치·운영 가이드. 제품마다 앱 1개를 만든다 |
| [`llm/README.md`](llm/README.md) | LLM 키, 오픈소스 LLM 서버(vLLM), 기능별 모델 라우팅 설정(상용·오픈소스 이원화) |
| [`voice/README.md`](voice/README.md) | 공용 음성 서버와 ElevenLabs 설정(음성 대화, STT·TTS) |
| (이동) `llm-wiki` | 개발 위키 스킬(`SKILL.md`)·규칙(`WIKI_SCHEMA.md`)의 정본은 멀티에이전트 베이스(`MultiAgent-Service-Fullstack-Tree-Framwork`)로 옮겼다(2026-10-16). 묶음에 넣지 않는다 |
| [`tools/build_root.py`](tools/build_root.py) | 제품별 `<제품>-root/` 묶음을 다시 만드는 스크립트. 기획서(`products/`)를 고친 뒤 실행한다: `python -I build_root.py <제품>`, 경로 검사: `--check <제품>` |
