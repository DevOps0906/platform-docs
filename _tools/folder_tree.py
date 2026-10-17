"""저장소 폴더 구조를 FOLDER_TREE.md로 만든다.

usage: python3 -I _tools/folder_tree.py      (저장소 루트에서 실행)
- git이 관리하는 파일만 센다. 괄호 안 숫자는 그 폴더 아래 파일 수
- 1장: 개발 묶음(develop/<제품>/<제품>-root/)은 sceneflow만 펼친 요약 트리
- 2장: 모든 폴더를 펼친 전체 트리
"""
import collections
import re
import subprocess

files = [f for f in subprocess.run(['git', '-c', 'core.quotepath=false', 'ls-files'],
                                   capture_output=True, text=True, check=True).stdout.split('\n') if f]
cnt = collections.Counter()
for f in files:
    p = f.split('/')
    for i in range(1, len(p)):
        cnt['/'.join(p[:i])] += 1
children = collections.defaultdict(list)
for d in sorted(cnt):
    children[d.rsplit('/', 1)[0] if '/' in d else ''].append(d)
BUNDLE = re.compile(r'develop/[^/]+/[^/]+-root$')
SHOW = 'develop/sceneflow/'


def render(short):
    out = [f'platform-docs/  (파일 {len(files):,}개, 폴더 {len(cnt)}개)']

    def walk(d, prefix):
        ks = sorted(children[d], key=lambda x: (not x.split('/')[-1].startswith('_'), x.split('/')[-1].lower()))
        for i, k in enumerate(ks):
            last = i == len(ks) - 1
            line = prefix + ('└── ' if last else '├── ') + k.split('/')[-1] + f'/  ({cnt[k]})'
            if short and BUNDLE.match(k) and not k.startswith(SHOW):
                out.append(line + '  ※ sceneflow-root와 같은 구조')
                continue
            out.append(line)
            walk(k, prefix + ('    ' if last else '│   '))
    walk('', '')
    return '\n'.join(out)


doc = f"""# FOLDER_TREE — 저장소 폴더 구조

`python3 -I _tools/folder_tree.py`로 만든 생성물입니다. 폴더를 추가·삭제·이름 변경한 뒤 다시 실행합니다. 괄호 안 숫자는 그 폴더 아래 파일 수입니다.

`develop/<제품>/<제품>-root/`는 `develop/_shared/tools/build_root.py`가 만드는 사본 묶음이라 손으로 고치지 않습니다. 묶음 16개의 구조는 거의 같고, local-news만 `03-설계/모듈/`, `reference/research/`(원본 리뷰 대신), `supabase/tests/`가 있습니다.

## 1. 요약 트리 (개발 묶음은 sceneflow만 펼침)

```
{render(True)}
```

## 2. 전체 트리

```
{render(False)}
```
"""
open('FOLDER_TREE.md', 'w', encoding='utf-8').write(doc)
print(f'FOLDER_TREE.md: 파일 {len(files)}개, 폴더 {len(cnt)}개')
