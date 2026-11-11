#!/bin/sh
# EnvoScale bootstrap entry point for POSIX systems (Linux, macOS, Git Bash on Windows).
# Uses only POSIX shell tools, plus NASM through adapters/bootstrap/nasm (Phase A).
#
#   ./bootstrap.sh build   assemble Stage 0 (build/stage0/envoc0, envoc0.exe), then build
#                          Stage 1 with it (build/stage1/envoc1, envoc1.exe)
#   ./bootstrap.sh test    build, then run the Stage 0 and Stage 1 tests with the native binaries
#   ./bootstrap.sh check   repository checks: layout, lib->adapters imports, gallery limits
#   ./bootstrap.sh clean   delete build/
#   ./bootstrap.sh help
#
# bootstrap.ps1 is the Windows twin of this script; keep the two in step.
set -eu

ROOT=$(cd "$(dirname "$0")" && pwd)
BUILD="$ROOT/build/stage0"
BUILD1="$ROOT/build/stage1"
STAGE0="$ROOT/bootstrap/stage0"
STAGE1="$ROOT/bootstrap/stage1"

say() { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
    else echo "(no sha256 tool)"; fi
}

# host_suffix: "" on Linux, ".exe" on Windows; the native binaries' file suffix.
host_suffix() {
    case "$(uname -s)" in
        Linux) printf '' ;;
        MINGW*|MSYS*|CYGWIN*) printf '.exe' ;;
        *) fail "no native Stage 0 for $(uname -s) yet (supported: Linux, Windows); see docs/porting/CHECKLIST.md" ;;
    esac
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

    # Stage 1 is an Envo-Core program (PLAN D11); the native envoc0 builds it for both OSes.
    mkdir -p "$BUILD1"
    envoc0="$BUILD/envoc0$(host_suffix)"
    set --
    while IFS= read -r f || [ -n "$f" ]; do
        f=$(printf '%s' "$f" | tr -d '\r')
        [ -n "$f" ] && set -- "$@" "$f"
    done < "$STAGE1/files.txt"
    for unit in "x86_64-linux:envoc1" "x86_64-windows:envoc1.exe"; do
        target=${unit%%:*}
        out=${unit#*:}
        say "build     bootstrap/stage1 -> build/stage1/$out"
        (cd "$STAGE1" && "$envoc0" build "$@" -o "$BUILD1/$out" --target "$target") \
            || fail "building Stage 1 ($target) failed"
        size=$(wc -c < "$BUILD1/$out" | tr -d ' ')
        say "          $size bytes  sha256 $(sha256 "$BUILD1/$out")"
    done
    chmod +x "$BUILD1/envoc1"
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
    EXE="$BUILD/envoc0$(host_suffix)"
    ENVOC1="$BUILD1/envoc1$(host_suffix)"
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
    # Paths are UTF-8 on every OS: a name with a space, a Latin, a CJK and a non-BMP character.
    uname=$(printf 'u\303\274nicode \346\227\245\360\237\230\200.envo')
    printf 'print("hi")\n' > "$TMP/$uname"
    run "$TMP" lex "$uname"
    if [ "$rc" -eq 0 ] && head -n 1 "$TMP/out" | grep -q '^1:1 n ident print'; then pass; else bad 'unicode path' "exit $rc: $(cat "$TMP/err")"; fi
    # Cross-compilation: this host builds the other OS's executable (it can only check the header).
    printf 'print("hi")
' > "$TMP/cross.envo"
    case "$EXE" in
        *.exe) other=x86_64-linux; magic='7f454c46' ;;
        *) other=x86_64-windows; magic='4d5a' ;;
    esac
    run "$TMP" build cross.envo -o cross-out --target "$other"
    got=$(od -A n -t x1 -N 4 "$TMP/cross-out" 2>/dev/null | tr -d ' \n')
    case "$got" in "$magic"*) pass ;; *) bad "cross build ($other)" "exit $rc, header $got" ;; esac

    # Golden suites: tests/golden/<dir>/<name>.envo -> <name><ext>, produced by
    # `envoc0 <command>`. Keep this list in step with bootstrap.ps1.
    for suite in lexer:lex:.tokens parser:parse:.ast check:check:.check; do
      sdir=${suite%%:*}; rest=${suite#*:}; cmd=${rest%%:*}; ext=${rest#*:}
      say "golden tests: tests/golden/$sdir"
      dir="$ROOT/tests/golden/$sdir"
      for f in "$dir"/*.envo; do
        base=$(basename "$f")
        name="golden/$sdir/$base"
        expected="${f%.envo}$ext"
        [ -f "$expected" ] || { bad "$name" "missing $ext file"; continue; }
        run "$dir" "$cmd" "$base"
        if [ "$rc" -ne 0 ]; then bad "$name" "exit $rc: $(tr -d '\r' < "$TMP/err")"; continue; fi
        tr -d '\r' < "$expected" > "$TMP/expected"
        tr -d '\r' < "$TMP/out" > "$TMP/actual"
        if cmp -s "$TMP/expected" "$TMP/actual"; then pass
        else bad "$name" 'output differs:'; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; fi
      done
    done

    # Spec error tests run through `envoc0 check`, which lexes and parses first, so
    # lexical and syntax errors are still reported by their own stage.
    # Keep this list in step with bootstrap.ps1.
    for sdir in 01-lexical core-syntax core-types; do
      say "spec tests: tests/spec/$sdir"
      dir="$ROOT/tests/spec/$sdir"
      for f in "$dir"/*.envo; do
        base=$(basename "$f")
        name="spec/$sdir/$base"
        line=$(LC_ALL=C grep -a -m1 '^// expect-error: ' "$f" | tr -d '\r' || true)
        [ -n "$line" ] || { bad "$name" 'no // expect-error: annotation'; continue; }
        code=$(printf '%s\n' "$line" | sed 's|^// expect-error: \(E[0-9][0-9][0-9][0-9]\).*|\1|')
        want="error[$code]"
        case "$line" in
            *' @ '*) pos=${line##* @ }; pos=${pos%% *}; want="$base:$pos: error[$code]" ;;
        esac
        run "$dir" check "$base"
        if grep -q -F '(no message for this error code)' "$TMP/err"; then bad "$name" "missing message: $(cat "$TMP/err")"
        elif [ "$rc" -eq 1 ] && LC_ALL=C grep -a -q -F "$want" "$TMP/err"; then pass
        else bad "$name" "expected exit 1 with '$want'; got exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
      done
    done

    # Programs compiled and run: `// expect:` stdout lines, `// expect-exit: N`,
    # `// expect-panic: <reason>` (exit 101 and "panic: <reason>" on stderr).
    say 'run tests: tests/spec/core-run'
    rundir="$BUILD/run"
    mkdir -p "$rundir"
    for f in "$ROOT"/tests/spec/core-run/*.envo; do
        base=$(basename "$f" .envo)
        name="spec/core-run/$base.envo"
        sed -n 's|^// expect: \(.*\)$|\1|p' "$f" | tr -d '\r' > "$TMP/expected"
        want_code=$(sed -n 's|^// expect-exit: \([0-9]*\).*|\1|p' "$f" | head -n 1)
        panic=$(sed -n 's|^// expect-panic: \(.*\)$|\1|p' "$f" | tr -d '\r' | head -n 1)
        [ -n "$want_code" ] || want_code=0
        [ -z "$panic" ] || want_code=101
        program="$rundir/$base"
        case "$EXE" in *.exe) program="$program.exe" ;; esac
        run "$rundir" build "$f" -o "$program"
        if [ "$rc" -ne 0 ]; then bad "$name" "build failed: $(cat "$TMP/err")"; continue; fi
        set +e
        (cd "$rundir" && "$program") > "$TMP/out" 2> "$TMP/err"
        rc=$?
        set -e
        tr -d '\r' < "$TMP/out" > "$TMP/actual"
        if ! cmp -s "$TMP/expected" "$TMP/actual"; then bad "$name" 'stdout differs:'; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; continue; fi
        if [ "$rc" -ne "$want_code" ]; then bad "$name" "exit code $rc, expected $want_code: $(cat "$TMP/err")"; continue; fi
        if [ -n "$panic" ] && ! grep -q -F "panic: $panic" "$TMP/err"; then bad "$name" "stderr: $(cat "$TMP/err")"; continue; fi
        pass
    done

    # Multi-file programs: one folder per test. main.envo is the entry file and holds
    # the annotations; the other .envo files follow in name order. Either
    # `// expect-error: E#### @ <file>:L:C` (envoc0 check) or `// expect:` lines (build, run).
    say 'multi-file tests: tests/spec/core-multi'
    for d in "$ROOT"/tests/spec/core-multi/*/; do
        d=${d%/}
        base=$(basename "$d")
        name="spec/core-multi/$base"
        set -- main.envo
        for f in "$d"/*.envo; do
            f=$(basename "$f")
            [ "$f" = main.envo ] || set -- "$@" "$f"
        done
        line=$(grep -m1 '^// expect-error: ' "$d/main.envo" | tr -d '\r' || true)
        if [ -n "$line" ]; then
            code=$(printf '%s\n' "$line" | sed 's|^// expect-error: \(E[0-9]*\) @ .*|\1|')
            want="${line##* @ }: error[$code]"
            run "$d" check "$@"
            if [ "$rc" -eq 1 ] && grep -q -F "$want" "$TMP/err"; then pass
            else bad "$name" "expected exit 1 with '$want'; got exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
            continue
        fi
        sed -n 's|^// expect: \(.*\)$|\1|p' "$d/main.envo" | tr -d '\r' > "$TMP/expected"
        program="$rundir/multi-$base"
        case "$EXE" in *.exe) program="$program.exe" ;; esac
        run "$d" build "$@" -o "$program"
        if [ "$rc" -ne 0 ]; then bad "$name" "build failed: $(cat "$TMP/err")"; continue; fi
        set +e
        (cd "$rundir" && "$program") > "$TMP/out" 2> "$TMP/err"
        rc=$?
        set -e
        tr -d '\r' < "$TMP/out" > "$TMP/actual"
        if ! cmp -s "$TMP/expected" "$TMP/actual"; then bad "$name" 'stdout differs:'; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; continue; fi
        if [ "$rc" -ne 0 ]; then bad "$name" "exit code $rc: $(cat "$TMP/err")"; continue; fi
        pass
    done

    say ''
    say 'stage 1 smoke tests'
    stage0_exe=$EXE
    EXE=$ENVOC1
    run "$ROOT" version
    if [ "$rc" -eq 0 ] && grep -q '^envoc1 ' "$TMP/out"; then pass; else bad 'envoc1 version' "exit $rc"; fi
    run "$ROOT" selftest
    if [ "$rc" -eq 0 ] && grep -q '^selftest: ok' "$TMP/out"; then pass; else bad 'envoc1 selftest' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    run "$ROOT"
    if [ "$rc" -eq 2 ] && grep -q '^usage: envoc1' "$TMP/err"; then pass; else bad 'envoc1 no arguments' "exit $rc"; fi
    run "$ROOT" frobnicate
    if [ "$rc" -eq 2 ] && grep -q "^envoc1: error: unknown command 'frobnicate'" "$TMP/err"; then pass; else bad 'envoc1 unknown command' "exit $rc"; fi

    # The runtime embedded in envoc1 must be generated from the current runtime sources.
    run "$STAGE1" embed runtime/common.envo runtime/linux.envo runtime/windows.envo
    tr -d '\r' < "$STAGE1/runtime/embedded.envo" > "$TMP/expected"
    tr -d '\r' < "$TMP/out" > "$TMP/actual"
    if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
    else bad 'envoc1 embedded runtime' "bootstrap/stage1/runtime/embedded.envo is stale: regenerate it with envoc1 embed (see docs/architecture/stage1.md)"; fi

    # The x86-64 encoder and image writer: a minimal native program must exit with 42.
    case "$ENVOC1" in *.exe) host_os=windows ;; *) host_os=linux ;; esac
    run "$TMP" selftest-image "$TMP/t42" "$host_os"
    if [ "$rc" -eq 0 ]; then
        set +e
        "$TMP/t42"
        rc=$?
        set -e
        if [ "$rc" -eq 42 ]; then pass; else bad 'envoc1 selftest-image' "exit $rc, expected 42"; fi
    else
        bad 'envoc1 selftest-image' "exit $rc: $(cat "$TMP/err")"
    fi

    # Differential tests (PLAN D14). Golden suites: envoc1 must print exactly envoc0's
    # expected files, in --core mode and in Envo-S1 mode (Core programs mean the same in
    # S1). Spec suites: the same error code at the same position; lexical tests run in
    # both modes (E0901-E0904 become E0950 in S1), syntax tests in --core mode.
    # Keep these lists in step with bootstrap.ps1.
    for suite in lexer:lex:.tokens:both parser:parse:.ast:both check:check:.check:both s1-parser:parse:.ast:s1; do
      sdir=${suite%%:*}; rest=${suite#*:}; cmd=${rest%%:*}; rest=${rest#*:}; ext=${rest%%:*}; modes=${rest#*:}
      for mode in --core s1; do
        [ "$modes" = s1 ] && [ "$mode" = --core ] && continue
        say "stage 1 golden tests ($mode): tests/golden/$sdir"
        dir="$ROOT/tests/golden/$sdir"
        for f in "$dir"/*.envo; do
            base=$(basename "$f")
            name="stage1 $mode golden/$sdir/$base"
            if [ "$mode" = --core ]; then run "$dir" --core "$cmd" "$base"; else run "$dir" "$cmd" "$base"; fi
            if [ "$rc" -ne 0 ]; then bad "$name" "exit $rc: $(tr -d '\r' < "$TMP/err")"; continue; fi
            tr -d '\r' < "${f%.envo}$ext" > "$TMP/expected"
            tr -d '\r' < "$TMP/out" > "$TMP/actual"
            if cmp -s "$TMP/expected" "$TMP/actual"; then pass
            else bad "$name" 'output differs:'; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; fi
        done
      done
    done
    for suite in 01-lexical:lex:both core-syntax:parse:core core-types:check:core s1-syntax:parse:s1; do
      sdir=${suite%%:*}; rest=${suite#*:}; cmd=${rest%%:*}; modes=${rest#*:}
      for mode in --core s1; do
        [ "$modes" = core ] && [ "$mode" = s1 ] && continue
        [ "$modes" = s1 ] && [ "$mode" = --core ] && continue
        say "stage 1 spec tests ($mode): tests/spec/$sdir"
        dir="$ROOT/tests/spec/$sdir"
        for f in "$dir"/*.envo; do
            base=$(basename "$f")
            name="stage1 $mode spec/$sdir/$base"
            line=$(LC_ALL=C grep -a -m1 '^// expect-error: ' "$f" | tr -d '\r' || true)
            code=$(printf '%s\n' "$line" | sed 's|^// expect-error: \(E[0-9][0-9][0-9][0-9]\).*|\1|')
            if [ "$mode" = s1 ]; then
                case "$code" in E090[1-4]) code=E0950 ;; esac
            fi
            pos=${line##* @ }; pos=${pos%% *}
            want="$base:$pos: error[$code]"
            if [ "$mode" = --core ]; then run "$dir" --core "$cmd" "$base"; else run "$dir" "$cmd" "$base"; fi
            if [ "$rc" -eq 1 ] && LC_ALL=C grep -a -q -F "$want" "$TMP/err"; then pass
            else bad "$name" "expected exit 1 with '$want'; got exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
        done
      done
    done
    # Multi-file error tests, and Stage 1 checking its own source (D14).
    say "stage 1 multi-file tests (--core): tests/spec/core-multi"
    for d in "$ROOT"/tests/spec/core-multi/*/; do
        line=$(grep -m1 '^// expect-error: ' "$d/main.envo" | tr -d '\r' || true)
        [ -n "$line" ] || continue
        set -- main.envo
        for f in "$d"*.envo; do
            f=$(basename "$f")
            [ "$f" = main.envo ] || set -- "$@" "$f"
        done
        code=$(printf '%s\n' "$line" | sed 's|^// expect-error: \(E[0-9]*\) @ .*|\1|')
        want="${line##* @ }: error[$code]"
        run "$d" --core check "$@"
        if [ "$rc" -eq 1 ] && grep -q -F "$want" "$TMP/err"; then pass
        else bad "stage1 --core core-multi/$(basename "$d")" "expected exit 1 with '$want'; got exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
    done
    # EIR v1 (M2.6): canonical printing round-trips, and verifier errors.
    say 'stage 1 golden tests: tests/golden/eir'
    dir="$ROOT/tests/golden/eir"
    for f in "$dir"/*.eir; do
        base=$(basename "$f")
        tr -d '\r' < "${f%.eir}.out" > "$TMP/expected"
        for input in "$base" "${base%.eir}.out"; do
            run "$dir" eir-check "$input"
            tr -d '\r' < "$TMP/out" > "$TMP/actual"
            if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
            else bad "golden/eir/$input" "exit $rc: $(tr -d '\r' < "$TMP/err")"; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; fi
        done
    done
    say 'stage 1 spec tests: tests/spec/eir'
    dir="$ROOT/tests/spec/eir"
    for f in "$dir"/*.eir; do
        base=$(basename "$f")
        line=$(grep -m1 '^; expect-error: ' "$f" | tr -d '\r' || true)
        code=$(printf '%s\n' "$line" | sed 's|^; expect-error: \(E[0-9]*\) @ .*|\1|')
        pos=${line##* @ }; pos=${pos%% *}
        want="$base:$pos: error[$code]"
        run "$dir" eir-check "$base"
        if [ "$rc" -eq 1 ] && grep -q -F "$want" "$TMP/err"; then pass
        else bad "spec/eir/$base" "expected exit 1 with '$want'; got exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
    done
    say 'stage 1 self-check: envoc1 --core check bootstrap/stage1'
    set --
    while IFS= read -r f || [ -n "$f" ]; do
        f=$(printf '%s' "$f" | tr -d '\r')
        [ -n "$f" ] && set -- "$@" "$f"
    done < "$STAGE1/files.txt"
    run "$STAGE1" --core check "$@"
    if [ "$rc" -eq 0 ]; then pass; else bad 'stage1 self-check' "exit $rc: $(head -c 300 "$TMP/err")"; fi
    EXE=$stage0_exe

    say ''
    say "$passed passed, $failed failed"
    [ "$failed" -eq 0 ] || exit 1
}

# ------------------------------------------------------------------- check
do_check() {
    problems=0
    problem() { printf 'check: %s\n' "$*" >&2; problems=$((problems + 1)); }

    for f in README.md CHARTER.md STATUS.md CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md LICENSING.md CLA.md \
             TRADEMARKS.md LICENSES/PolyForm-Noncommercial-1.0.0.md LICENSES/LicenseRef-EnvoScale-Commercial.md \
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

    # docs/spec/eas.md: every jump states its size, so the bytes depend on the source alone.
    unsized=$(find "$ROOT/bootstrap" -name '*.eas' -exec grep -n -E '^[[:space:]]*j[a-z]+[[:space:]]+[.A-Za-z_]' /dev/null {} + \
        | grep -v -E ':[[:space:]]*j[a-z]+[[:space:]]+((short|near)[[:space:]]|r[a-z0-9]+[[:space:]]*(;|$))' || true)
    [ -z "$unsized" ] || problem "jumps without short/near: $unsized"

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

# ------------------------------------------------------------------- compare
# compare <dir-a> <dir-b>: both builds (each a copy of build/, with stage0/ and stage1/)
# must be byte-identical (brief 4.1).
do_compare() {
    [ "$#" -eq 2 ] || fail "usage: ./bootstrap.sh compare <dir-a> <dir-b>"
    differ=0
    for f in stage0/envoc0 stage0/envoc0.exe stage1/envoc1 stage1/envoc1.exe; do
        [ -f "$1/$f" ] || fail "missing $1/$f"
        [ -f "$2/$f" ] || fail "missing $2/$f"
        say "$f"
        say "  $1: $(wc -c < "$1/$f" | tr -d ' ') bytes  sha256 $(sha256 "$1/$f")"
        say "  $2: $(wc -c < "$2/$f" | tr -d ' ') bytes  sha256 $(sha256 "$2/$f")"
        if cmp -s "$1/$f" "$2/$f"; then say "  identical"
        else say "  DIFFERENT: $(cmp "$1/$f" "$2/$f" | head -n 1)"; differ=1; fi
    done
    [ "$differ" -eq 0 ] || fail "the builds are not byte-identical"
}

case "${1:-help}" in
    build) do_build ;;
    compare) shift; do_compare "$@" ;;
    test)  do_test ;;
    check) do_check ;;
    clean) rm -rf "$ROOT/build"; say 'removed build/' ;;
    help|*)
        say 'usage: ./bootstrap.sh <build|test|check|clean|help>'
        say '  build   assemble Stage 0 (needs NASM; see adapters/bootstrap/nasm/README.md), then build Stage 1'
        say '  test    build, then run the Stage 0 and Stage 1 tests'
        say '  check   repository layout, lib->adapters imports, Hello World Gallery limits'
        say '  compare <dir-a> <dir-b>   require two builds (copies of build/) to be byte-identical'
        say '  clean   delete build/'
        [ "${1:-help}" = help ] || exit 2 ;;
esac
