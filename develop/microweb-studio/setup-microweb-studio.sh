#!/usr/bin/env bash
# setup-microweb-studio.sh — 멀티에이전트 베이스를 복사해 microweb-studio 개발 폴더를 만든다 (Git Bash / Linux)
#
# 사용:  bash setup-microweb-studio.sh            실제 실행
#        bash setup-microweb-studio.sh --dry-run  할 일만 출력(아무것도 바꾸지 않음)
#
# 하는 일(순서대로)
#   1) 베이스 원본을 개발 폴더로 복사한다(원본은 읽기만 한다)
#   2) 복사본 안의 init-project.sh 로 초기화한다(--reset-git: 템플릿 git 이력을 끊는다)
#   3) microweb-studio-root 안의 내용물(docs, supabase, infra, .claude)을 복사본 루트에 붙여넣는다
#   4) 복사본의 docs/etc(베이스 설명서 PDF)를 지운다
#   5) 에이전트 모델을 주 Opus / 부 Sonnet / 고문 Fable 구성으로 맞춘다(복사본의 .claude/agents 만)
#   6) 무결성 점검을 다시 실행한다
# 하지 않는 일: 커밋, 원격 푸시, 의존성 설치, 스캐폴딩, 원격 DB 변경
set -euo pipefail

PRODUCT="microweb-studio"
BASE="${BASE:-D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork}"
TARGET="${TARGET:-D:/WorkSpace/DEV/$PRODUCT}"
HERE="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKG="$HERE/$PRODUCT-root"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY" = 1 ]; then say "  (dry-run) $*"; else eval "$@"; fi; }
fail() { say "중단: $*" >&2; exit 1; }

say "[0/6] 사전 확인"
[ -d "$BASE" ] || fail "베이스 원본이 없습니다: $BASE"
[ -f "$BASE/init-project.sh" ] || fail "베이스에 init-project.sh 가 없습니다: $BASE"
[ -d "$PKG" ] || fail "붙여넣을 묶음이 없습니다: $PKG"
[ -e "$TARGET" ] && fail "대상 폴더가 이미 있습니다(덮어쓰지 않습니다): $TARGET"
for t in git jq; do
  command -v "$t" >/dev/null 2>&1 || fail "필수 도구가 없습니다: $t (베이스 INSTALL.md §1)"
done
# Windows의 python3 는 Microsoft Store 스텁일 수 있다(베이스 INSTALL.md §2). 실제로 실행되는 쪽을 고른다.
PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys' >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -n "$PY" ] || fail "실행 가능한 Python 이 없습니다(python3 또는 python)"
say "  베이스: $BASE"
say "  대상:   $TARGET"
say "  묶음:   $PKG"

say "[1/6] 베이스 복사"
run "cp -r \"$BASE\" \"$TARGET\""

say "[2/6] 복사본에서 init-project.sh 실행(복사본 안의 스크립트만 실행합니다)"
if [ "$DRY" = 1 ]; then
  say "  (dry-run) (cd \"$TARGET\" && bash init-project.sh $PRODUCT --reset-git)"
else
  ( cd "$TARGET" && bash init-project.sh "$PRODUCT" --reset-git ) || fail "init-project.sh 실패. 위 메시지를 확인하세요"
fi

say "[3/6] $PRODUCT-root 내용물 붙여넣기(docs, supabase, infra, .claude)"
run "cp -r \"$PKG/.\" \"$TARGET/\""

say "[4/6] docs/etc 삭제(베이스 설명서 PDF, 제품 개발에 쓰지 않음)"
run "rm -rf \"$TARGET/docs/etc\""

say "[5/6] 에이전트 모델 지정: plan-challenger=Fable(고문), 도메인 expert 3개=Sonnet(부)"
if [ "$DRY" = 1 ]; then
  say "  (dry-run) .claude/agents/plan-challenger.md  model: opus -> model: claude-fable-5-1"
  say "  (dry-run) .claude/agents/{nextjs,fastapi,supabase}-expert.md  frontmatter 에 model: sonnet 추가"
else
  PYTHONUTF8=1 "$PY" - "$TARGET/.claude/agents" <<'PY'
import io, os, re, sys
d = sys.argv[1]
def edit(name, fn):
    p = os.path.join(d, name)
    raw = io.open(p, 'rb').read()
    crlf = b'\r\n' in raw
    text = raw.decode('utf-8').replace('\r\n', '\n')
    new = fn(text)
    if crlf:
        new = new.replace('\n', '\r\n')
    io.open(p, 'wb').write(new.encode('utf-8'))
def fm_split(t):
    m = re.match(r'^---\n(.*?)\n---\n', t, re.S)
    if not m:
        raise SystemExit('frontmatter 없음')
    return m
def set_model(model):
    def fn(t):
        m = fm_split(t)
        fm = m.group(1)
        if re.search(r'^model:', fm, re.M):
            fm = re.sub(r'^model:.*$', 'model: ' + model, fm, flags=re.M)
        else:
            fm = fm + '\nmodel: ' + model
        return '---\n' + fm + '\n---\n' + t[m.end():]
    return fn
edit('plan-challenger.md', set_model('claude-fable-5-1'))
for n in ('nextjs-expert.md', 'fastapi-expert.md', 'supabase-expert.md'):
    edit(n, set_model('sonnet'))
print('  모델 지정 완료')
PY
fi

say "[6/6] 무결성 점검"
if [ "$DRY" = 1 ]; then
  say "  (dry-run) (cd \"$TARGET\" && bash _shared/check-invariants.sh)"
else
  ( cd "$TARGET" && bash _shared/check-invariants.sh ) || say "  무결성 점검에 FAIL 이 있습니다. 커밋 전에 해소하세요"
fi

say ""
say "완료. 다음 순서:"
say "  1) $TARGET/_shared/project-profile.md 의 스택 버전과 명령을 채웁니다(microweb-studio_develop.md 6절)"
say "  2) $TARGET 에서 claude 를 실행하고 /agent-check 로 에이전트를 확인합니다"
say "  3) microweb-studio_develop.md 7절부터 진행합니다"
