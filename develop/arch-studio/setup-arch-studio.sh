#!/usr/bin/env bash
# setup-arch-studio.sh — 멀티에이전트 베이스를 복사해 arch-studio 개발 폴더를 만든다 (Git Bash / Linux)
#
# 사용:  bash setup-arch-studio.sh            실제 실행
#        bash setup-arch-studio.sh --dry-run  할 일만 출력(아무것도 바꾸지 않음)
#
# 하는 일(순서대로)
#   1) 데스크톱 도구(rustc, cargo, Tauri CLI 2.x, Windows면 MSVC 툴체인·WebView2)를 확인한다(경고만, 중단하지 않음)
#   2) 베이스 원본을 개발 폴더로 복사한다(원본은 읽기만 한다)
#   3) 복사본 안의 init-project.sh 로 초기화한다(--reset-git: 템플릿 git 이력을 끊는다)
#   4) arch-studio-root 안의 내용물(docs, supabase, infra, .claude)을 복사본 루트에 붙여넣는다
#   5) 복사본의 docs/etc(베이스 설명서 PDF)를 지운다
#   6) 에이전트 모델을 주 Opus / 부 Sonnet / 고문 Fable 구성으로 맞춘다(복사본의 .claude/agents 만)
#   7) 무결성 점검을 다시 실행한다
# 하지 않는 일: 커밋, 원격 푸시, 의존성 설치, Rust·Tauri 설치, 스캐폴딩, 원격 DB 변경
set -euo pipefail

PRODUCT="arch-studio"
APP_ID="arch"
BASE="${BASE:-D:/WorkSpace/DEV/MultiAgent-Service-Fullstack-Tree-Framwork}"
TARGET="${TARGET:-D:/WorkSpace/DEV/$PRODUCT}"
HERE="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKG="$HERE/$PRODUCT-root"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY" = 1 ]; then say "  (dry-run) $*"; else eval "$@"; fi; }
fail() { say "중단: $*" >&2; exit 1; }
WARN=0
warn() { say "  경고: $*"; WARN=$((WARN + 1)); }

say "[0/7] 사전 확인 (제품 $PRODUCT, 앱 id $APP_ID)"
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

say "[1/7] 데스크톱 도구 확인(경고만, 개발서 2장)"
if command -v rustc >/dev/null 2>&1; then
  say "  rustc: $(rustc --version 2>/dev/null)"
else
  warn "rustc 가 없습니다. https://rustup.rs 에서 Rust stable 을 설치하세요(apps/desktop/src-tauri 빌드에 필요)"
fi
if command -v cargo >/dev/null 2>&1; then
  say "  cargo: $(cargo --version 2>/dev/null)"
  if cargo tauri --version >/dev/null 2>&1; then
    TV="$(cargo tauri --version 2>/dev/null)"
    say "  Tauri CLI: $TV"
    case "$TV" in
      *" 2."*) : ;;
      *) warn "Tauri CLI 가 2.x 가 아닙니다($TV). 이 제품은 Tauri 2.x 를 씁니다" ;;
    esac
  else
    say "  Tauri CLI(cargo tauri): 없음. AR-06-004 가 apps/desktop 에 @tauri-apps/cli 2.x 를 넣으면 pnpm 으로 실행합니다"
    say "    (선택) 지금 설치: cargo install tauri-cli --version \"^2\" --locked"
  fi
  if cargo audit --version >/dev/null 2>&1; then :; else
    say "  cargo-audit: 없음(선택). 설치: cargo install cargo-audit --locked"
  fi
else
  warn "cargo 가 없습니다(Rust 설치에 포함)"
fi
case "$(uname -s 2>/dev/null || echo unknown)" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v rustup >/dev/null 2>&1; then
      TC="$(rustup show active-toolchain 2>/dev/null || true)"
      case "$TC" in
        *msvc*) say "  Rust 툴체인: $TC" ;;
        *) warn "Rust 툴체인이 MSVC 가 아닙니다($TC). Tauri Windows 빌드는 *-pc-windows-msvc 와 Visual Studio C++ Build Tools 가 필요합니다" ;;
      esac
    fi
    if command -v reg >/dev/null 2>&1; then
      WV="$(MSYS2_ARG_CONV_EXCL='*' reg query 'HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' //v pv 2>/dev/null | awk '/pv/ {print $NF}' || true)"
      [ -z "$WV" ] && WV="$(MSYS2_ARG_CONV_EXCL='*' reg query 'HKCU\Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' //v pv 2>/dev/null | awk '/pv/ {print $NF}' || true)"
      if [ -n "$WV" ]; then say "  WebView2: $WV"; else warn "WebView2 런타임을 확인하지 못했습니다(Windows 11 은 기본 포함, 10 은 설치 필요)"; fi
    fi
    ;;
  *) say "  (Windows 가 아니라 MSVC 툴체인·WebView2 확인을 건너뜁니다. 데스크톱 MVP 빌드 대상은 Windows 10/11 x64)" ;;
esac
[ "$WARN" -gt 0 ] && say "  데스크톱 도구 경고 $WARN 건. 설치는 계속하며, W0 의 AR-06-004(셸 골격) 전에 해소하세요"

say "[2/7] 베이스 복사"
run "cp -r \"$BASE\" \"$TARGET\""

say "[3/7] 복사본에서 init-project.sh 실행(복사본 안의 스크립트만 실행합니다)"
if [ "$DRY" = 1 ]; then
  say "  (dry-run) (cd \"$TARGET\" && bash init-project.sh $PRODUCT --reset-git)"
else
  ( cd "$TARGET" && bash init-project.sh "$PRODUCT" --reset-git ) || fail "init-project.sh 실패. 위 메시지를 확인하세요"
fi

say "[4/7] $PRODUCT-root 내용물 붙여넣기(docs, supabase, infra, .claude)"
run "cp -r \"$PKG/.\" \"$TARGET/\""

say "[5/7] docs/etc 삭제(베이스 설명서 PDF, 제품 개발에 쓰지 않음)"
run "rm -rf \"$TARGET/docs/etc\""

say "[6/7] 에이전트 모델 지정: plan-challenger=Fable(고문), 도메인 expert 3개=Sonnet(부)"
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

say "[7/7] 무결성 점검"
if [ "$DRY" = 1 ]; then
  say "  (dry-run) (cd \"$TARGET\" && bash _shared/check-invariants.sh)"
else
  ( cd "$TARGET" && bash _shared/check-invariants.sh ) || say "  무결성 점검에 FAIL 이 있습니다. 커밋 전에 해소하세요"
fi

say ""
say "완료. 다음 순서:"
say "  1) $TARGET/_shared/project-profile.md 의 스택 버전과 명령을 채웁니다(arch-studio_develop.md 6장)"
say "  2) $TARGET 에서 claude 를 실행하고 /agent-check 로 에이전트를 확인합니다"
say "  3) arch-studio_develop.md 7장(로컬 DB)부터 진행하고, W0 에서 AR-06-019 도면 스파이크를 먼저 지시합니다(9.4절)"
[ "$WARN" -gt 0 ] && say "  참고: 데스크톱 도구 경고 $WARN 건이 남아 있습니다([1/7] 출력)"
exit 0
