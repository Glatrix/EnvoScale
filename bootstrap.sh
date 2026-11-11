#!/bin/sh
# EnvoScale bootstrap entry point for POSIX systems (Linux, macOS, Git Bash on Windows).
# Uses only POSIX shell tools, plus NASM through adapters/bootstrap/nasm (Phase A).
#
#   ./bootstrap.sh build   assemble Stage 0: build/stage0/envoc0 and build/stage0/envoc0.exe
#   ./bootstrap.sh test    build, then run the Stage 0 test suites with the native binary
#   ./bootstrap.sh check   repository checks: layout, lib->adapters imports, gallery limits
#   ./bootstrap.sh clean   delete build/
#   ./bootstrap.sh help
#
# bootstrap.ps1 is the Windows twin of this script; keep the two in step.
set -eu

ROOT=$(cd "$(dirname "$0")" && pwd)
BUILD="$ROOT/build/stage0"
STAGE0="$ROOT/bootstrap/stage0"

say() { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
    else echo "(no sha256 tool)"; fi
}

# ------------------------------------------------------------------- build
do_build() {
    mkdir -p "$BUILD"
    for unit in "envoc0-linux.eas:envoc0" "envoc0-windows.eas:envoc0.exe"; do
        src=${unit%%:*}
        out=${unit#*:}
        say "assemble  bootstrap/stage0/$src -> build/stage0/$out"
        sh "$ROOT/adapters/bootstrap/nasm/assemble.sh" "$STAGE0/$src" "$BUILD/$out" "$STAGE0" \
            || fail "assembling $src failed"
        size=$(wc -c < "$BUILD/$out" | tr -d ' ')
        say "          $size bytes  sha256 $(sha256 "$BUILD/$out")"
    done
    chmod +x "$BUILD/envoc0"
}

# ------------------------------------------------------------------- test
passed=0
failed=0
pass() { passed=$((passed + 1)); }
bad() { failed=$((failed + 1)); say "FAIL  $1"; [ -n "${2:-}" ] && say "      $2"; return 0; }

# run <dir> <args...>: runs the native envoc0 in <dir>; sets rc, and leaves
# stdout/stderr in $TMP/out and $TMP/err.
run() {
    dir=$1; shift
    set +e
    (cd "$dir" && "$EXE" "$@") > "$TMP/out" 2> "$TMP/err"
    rc=$?
    set -e
}

do_test() {
    do_build
    case "$(uname -s)" in
        Linux) EXE="$BUILD/envoc0" ;;
        MINGW*|MSYS*|CYGWIN*) EXE="$BUILD/envoc0.exe" ;;
        *) fail "no native Stage 0 for $(uname -s) yet (supported: Linux, Windows); see docs/porting/CHECKLIST.md" ;;
    esac
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT

    say ''
    say 'smoke tests'
    run "$ROOT" version
    if [ "$rc" -eq 0 ] && grep -q '^envoc0 ' "$TMP/out"; then pass; else bad version "exit $rc"; fi
    run "$ROOT"
    if [ "$rc" -eq 2 ] && grep -q '^usage: envoc0' "$TMP/err"; then pass; else bad 'no arguments' "exit $rc"; fi
    run "$ROOT" frobnicate
    if [ "$rc" -eq 2 ] && grep -q "^envoc0: error: unknown command 'frobnicate'" "$TMP/err"; then pass; else bad 'unknown command' "exit $rc"; fi
    run "$ROOT" lex 'no such file.envo'
    if [ "$rc" -eq 1 ] && grep -q "^envoc0: error: cannot open 'no such file.envo'" "$TMP/err"; then pass; else bad 'missing file' "exit $rc"; fi

    say 'golden tests: tests/golden/lexer'
    dir="$ROOT/tests/golden/lexer"
    for f in "$dir"/*.envo; do
        base=$(basename "$f")
        name="golden/lexer/$base"
        tokens="${f%.envo}.tokens"
        [ -f "$tokens" ] || { bad "$name" 'missing .tokens file'; continue; }
        run "$dir" lex "$base"
        if [ "$rc" -ne 0 ]; then bad "$name" "exit $rc: $(tr -d '\r' < "$TMP/err")"; continue; fi
        tr -d '\r' < "$tokens" > "$TMP/expected"
        tr -d '\r' < "$TMP/out" > "$TMP/actual"
        if cmp -s "$TMP/expected" "$TMP/actual"; then pass
        else bad "$name" 'token dump differs:'; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; fi
    done

    say 'spec tests: tests/spec/01-lexical'
    dir="$ROOT/tests/spec/01-lexical"
    for f in "$dir"/*.envo; do
        base=$(basename "$f")
        name="spec/01-lexical/$base"
        line=$(LC_ALL=C grep -a -m1 '^// expect-error: ' "$f" | tr -d '\r' || true)
        [ -n "$line" ] || { bad "$name" 'no // expect-error: annotation'; continue; }
        code=$(printf '%s\n' "$line" | sed 's|^// expect-error: \(E[0-9][0-9][0-9][0-9]\).*|\1|')
        want="error[$code]"
        case "$line" in
            *' @ '*) pos=${line##* @ }; pos=${pos%% *}; want="$base:$pos: error[$code]" ;;
        esac
        run "$dir" lex "$base"
        if [ "$rc" -eq 1 ] && LC_ALL=C grep -a -q -F "$want" "$TMP/err"; then pass
        else bad "$name" "expected exit 1 with '$want'; got exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
    done

    say ''
    say "$passed passed, $failed failed"
    [ "$failed" -eq 0 ] || exit 1
}

# ------------------------------------------------------------------- check
do_check() {
    problems=0
    problem() { printf 'check: %s\n' "$*" >&2; problems=$((problems + 1)); }

    for f in README.md CHARTER.md STATUS.md CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md \
             LICENSE envo.eon bootstrap.sh bootstrap.ps1 docs/PLAN.md docs/rfcs/0000-template.md \
             docs/porting/CHECKLIST.md; do
        [ -f "$ROOT/$f" ] || problem "missing file: $f"
    done

    dirs=0
    while IFS= read -r d || [ -n "$d" ]; do
        d=$(printf '%s' "$d" | tr -d '\r')
        case "$d" in ''|'#'*) continue ;; esac
        dirs=$((dirs + 1))
        [ -f "$ROOT/$d/README.md" ] || problem "layout: $d/README.md is missing"
    done < "$ROOT/tests/layout.txt"

    # Charter 2.3: lib/** must never import adapters/**. The compiler enforces this
    # from M3; until then a text check catches it.
    hits=$(find "$ROOT/lib" -name '*.envo' -exec grep -n -E '^[[:space:]]*(use|using)[[:space:]]+adapters([^A-Za-z0-9_]|$)' /dev/null {} + 2>/dev/null || true)
    [ -z "$hits" ] || problem "lib imports an adapter: $hits"

    # Brief 17: no Hello World Gallery program may grow past its line count.
    gallery="$ROOT/tests/spec/hello"
    entries=0
    while IFS= read -r l || [ -n "$l" ]; do
        l=$(printf '%s' "$l" | tr -d '\r')
        case "$l" in ''|'#'*) continue ;; esac
        file=${l%% *}
        limit=${l##* }
        entries=$((entries + 1))
        if [ ! -f "$gallery/$file" ]; then problem "gallery: $file is missing"; continue; fi
        count=$(tr -d '\r' < "$gallery/$file" | grep -c -v -e '^[[:space:]]*$' -e '^[[:space:]]*//' || true)
        [ "$count" -le "$limit" ] || problem "gallery: $file has $count code lines, limit is $limit"
    done < "$gallery/limits.txt"
    [ "$entries" -eq 11 ] || problem "gallery: limits.txt lists $entries programs, the brief has 11"

    [ "$problems" -eq 0 ] || fail "$problems problem(s)"
    say "check: ok ($dirs layout folders, $entries gallery programs, no lib->adapters imports)"
}

case "${1:-help}" in
    build) do_build ;;
    test)  do_test ;;
    check) do_check ;;
    clean) rm -rf "$ROOT/build"; say 'removed build/' ;;
    help|*)
        say 'usage: ./bootstrap.sh <build|test|check|clean|help>'
        say '  build   assemble Stage 0 (needs NASM; see adapters/bootstrap/nasm/README.md)'
        say '  test    build, then run the Stage 0 test suites'
        say '  check   repository layout, lib->adapters imports, Hello World Gallery limits'
        say '  clean   delete build/'
        [ "${1:-help}" = help ] || exit 2 ;;
esac
