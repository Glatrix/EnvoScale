#!/bin/sh
# EnvoScale bootstrap entry point for POSIX systems (Linux, macOS, Git Bash on Windows).
# Uses only POSIX shell tools, plus NASM through adapters/bootstrap/nasm (Phase A).
#
#   ./bootstrap.sh build   assemble Stage 0 (build/stage0/envoc0, envoc0.exe), build Stage 1
#                          with it (build/stage1/envoc1, envoc1.exe), then Stage 2 with
#                          Stage 1 (build/stage2/envoc, envoc.exe)
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
BUILD2="$ROOT/build/stage2"
STAGE2="$ROOT/compiler"
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

    # Stage 2 is an Envo-S1 program (PLAN D16); the native envoc1 builds it for both OSes.
    mkdir -p "$BUILD2"
    envoc1="$BUILD1/envoc1$(host_suffix)"
    set --
    while IFS= read -r f || [ -n "$f" ]; do
        f=$(printf '%s' "$f" | tr -d '\r')
        [ -n "$f" ] && set -- "$@" "$f"
    done < "$STAGE2/files.txt"
    for unit in "x86_64-linux:envoc" "x86_64-windows:envoc.exe"; do
        target=${unit%%:*}
        out=${unit#*:}
        say "build     compiler -> build/stage2/$out"
        (cd "$STAGE2" && "$envoc1" build "$@" -o "$BUILD2/$out" --target "$target") \
            || fail "building Stage 2 ($target) failed"
        size=$(wc -c < "$BUILD2/$out" | tr -d ' ')
        say "          $size bytes  sha256 $(sha256 "$BUILD2/$out")"
    done
    chmod +x "$BUILD2/envoc"

    # envo holds the compiler (PLAN D26): tools/envo plus compiler/ without its entry
    # file, built by Stage 2 with the library (--lib).
    mkdir -p "$ROOT/build/envo"
    envoc2="$BUILD2/envoc$(host_suffix)"
    set --
    while IFS= read -r f || [ -n "$f" ]; do
        f=$(printf '%s' "$f" | tr -d '\r')
        [ -n "$f" ] && set -- "$@" "$f"
    done < "$ROOT/tools/envo/files.txt"
    while IFS= read -r f || [ -n "$f" ]; do
        f=$(printf '%s' "$f" | tr -d '\r')
        [ -n "$f" ] && [ "$f" != driver/main.envo ] && set -- "$@" "compiler/$f"
    done < "$STAGE2/files.txt"
    for unit in "x86_64-linux:envo" "x86_64-windows:envo.exe"; do
        target=${unit%%:*}
        out=${unit#*:}
        say "build     tools/envo -> build/envo/$out"
        (cd "$ROOT" && "$envoc2" build -O2 --lib "$ROOT" "$@" -o "$ROOT/build/envo/$out" --target "$target") \
            || fail "building envo ($target) failed"
        say "          $(wc -c < "$ROOT/build/envo/$out" | tr -d ' ') bytes"
    done
    chmod +x "$ROOT/build/envo/envo"
}

# ------------------------------------------------------------------- test
passed=0
failed=0
pass() { passed=$((passed + 1)); }
bad() { failed=$((failed + 1)); say "FAIL  $1"; [ -n "${2:-}" ] && say "      $2"; return 0; }

# run <dir> <args...>: runs the native envoc0 in <dir>; sets rc, and leaves
# stdout/stderr in $TMP/out and $TMP/err.
# Stage 2 only (M3.7): compiles each of the files to an object (--unit), links the objects
# and prints a problem unless the result is the executable `build` wrote. $1: the
# directory, $2: that executable, then the files.
objects() {
    odir=$1
    oprog=$2
    shift 2
    rm -f "$oprog".*.eo
    k=0
    for u in "$@"; do
        run "$odir" compile "$@" --unit "$u" -o "$oprog.$k.eo"
        if [ "$rc" -ne 0 ]; then echo "compile --unit $u failed: $(cat "$TMP/err")"; return; fi
        k=$((k + 1))
    done
    run "$odir" link "$oprog".*.eo -o "$oprog.linked"
    if [ "$rc" -ne 0 ]; then echo "link failed: $(cat "$TMP/err")"; return; fi
    if ! cmp -s "$oprog" "$oprog.linked"; then echo 'the linked executable differs from the build'; fi
}

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
    # Programs compiled and run: by Stage 0, then by Stage 1, which must give the same
    # output and exit codes (M2.7, PLAN D14); then by Stage 2, whose executables must be
    # byte-identical to Stage 1's (M3.6).
    stage0_exe=$EXE
    for compiler in envoc0 envoc1 envoc; do
    case $compiler in
        envoc0) EXE=$stage0_exe ;;
        envoc1) EXE="$BUILD1/envoc1$(host_suffix)" ;;
        envoc) EXE="$BUILD2/envoc$(host_suffix)" ;;
    esac
        rundir="$ROOT/build/run-$compiler"
        mkdir -p "$rundir"
        # Envo-S1 programs (tests/spec/s1-run) run under Stages 1 and 2 only.
        run_suites="core-run s1-run"
        [ "$compiler" = envoc0 ] && run_suites=core-run
        # programs only Stage 2 accepts (tests/spec/s2-run, M3.10)
        [ "$compiler" = envoc ] && run_suites="core-run s1-run s2-run"
        for suite in $run_suites; do
        say "run tests ($compiler): tests/spec/$suite"
        for f in "$ROOT"/tests/spec/$suite/*.envo; do
            base=$(basename "$f" .envo)
            name="$compiler spec/$suite/$base.envo"
            sed -n 's|^// expect: \(.*\)$|\1|p' "$f" | tr -d '\r' > "$TMP/expected"
            want_code=$(sed -n 's|^// expect-exit: \([0-9]*\).*|\1|p' "$f" | head -n 1)
            panic=$(sed -n 's|^// expect-panic: \(.*\)$|\1|p' "$f" | tr -d '\r' | head -n 1)
            [ -n "$want_code" ] || want_code=0
            [ -z "$panic" ] || want_code=101
            program="$rundir/$base"
            case "$EXE" in *.exe) program="$program.exe" ;; esac
            run "$rundir" build "$f" -o "$program"
            if [ "$rc" -ne 0 ]; then bad "$name" "build failed: $(cat "$TMP/err")"; continue; fi
            if [ "$suite" = s2-run ]; then
                # Stage 1 rejects it, with the code the test names
                stage1=$(sed -n 's|^// stage1-error: \(E[0-9]*\).*|\1|p' "$f" | tr -d '\r' | head -n 1)
                saved=$EXE
                EXE="$BUILD1/envoc1$(host_suffix)"
                mv "$TMP/out" "$TMP/run-out"
                run "$rundir" check "$f"
                mv "$TMP/run-out" "$TMP/out"
                EXE=$saved
                if [ -z "$stage1" ] || [ "$rc" -ne 1 ] || ! grep -q "error\[$stage1\]" "$TMP/err"; then bad "$name" "envoc1 should reject it with ${stage1:-a // stage1-error: code}: exit $rc"; continue; fi
            elif [ "$compiler" = envoc ]; then
                if ! cmp -s "$program" "$ROOT/build/run-envoc1/${program##*/}"; then bad "$name" 'the executable differs from the envoc1 build'; continue; fi
            fi
            if [ "$compiler" = envoc ]; then
                problem=$(objects "$rundir" "$program" "$f")
                if [ -n "$problem" ]; then bad "$name" "$problem"; continue; fi
                # the object holds the program's EIR, in the binary form
                run "$rundir" eir "$f"
                mv "$TMP/out" "$TMP/eir"
                run "$rundir" eir-check "$program.0.eo"
                if [ "$rc" -ne 0 ] || ! cmp -s "$TMP/eir" "$TMP/out"; then bad "$name" "eir-check of the object differs from eir: exit $rc"; continue; fi
            fi
            set +e
            (cd "$rundir" && "$program") > "$TMP/out" 2> "$TMP/err"
            rc=$?
            set -e
            tr -d '\r' < "$TMP/out" > "$TMP/actual"
            if ! cmp -s "$TMP/expected" "$TMP/actual"; then bad "$name" 'stdout differs:'; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; continue; fi
            if [ "$rc" -ne "$want_code" ]; then bad "$name" "exit code $rc, expected $want_code: $(cat "$TMP/err")"; continue; fi
            if [ -n "$panic" ] && ! grep -q -F "panic: $panic" "$TMP/err"; then bad "$name" "stderr: $(cat "$TMP/err")"; continue; fi
            if [ "$compiler" = envoc ]; then
                # -O2 (M3.8): the same output, exit code and panic
                fast="$rundir/$base-O2$(host_suffix)"
                run "$rundir" build -O2 "$f" -o "$fast"
                if [ "$rc" -ne 0 ]; then bad "$name" "-O2 build failed: $(cat "$TMP/err")"; continue; fi
                set +e
                (cd "$rundir" && "$fast") > "$TMP/out" 2> "$TMP/err"
                rc=$?
                set -e
                tr -d '\r' < "$TMP/out" > "$TMP/actual"
                if ! cmp -s "$TMP/expected" "$TMP/actual" || [ "$rc" -ne "$want_code" ]; then bad "$name" "-O2: stdout or exit code ($rc) differs"; continue; fi
                if [ -n "$panic" ] && ! grep -q -F "panic: $panic" "$TMP/err"; then bad "$name" "-O2 stderr: $(cat "$TMP/err")"; continue; fi
            fi
            pass
        done
        done

        # Multi-file programs: one folder per test. main.envo is the entry file and holds
        # the annotations; the other .envo files follow in name order. Either
        # `// expect-error: E#### @ <file>:L:C` (envoc0 check) or `// expect:` lines (build, run).
        # Envo-S1 programs of several files (tests/spec/s1-multi) under Stages 1 and 2 only.
        multi_suites="core-multi s1-multi"
        [ "$compiler" = envoc0 ] && multi_suites=core-multi
        for msuite in $multi_suites; do
        say "multi-file tests ($compiler): tests/spec/$msuite"
        for d in "$ROOT"/tests/spec/$msuite/*/; do
            d=${d%/}
            base=$(basename "$d")
            name="$compiler spec/$msuite/$base"
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
            program="$rundir/$msuite-$base"
            case "$EXE" in *.exe) program="$program.exe" ;; esac
            run "$d" build "$@" -o "$program"
            if [ "$rc" -ne 0 ]; then bad "$name" "build failed: $(cat "$TMP/err")"; continue; fi
            if [ "$compiler" = envoc ]; then
                if ! cmp -s "$program" "$ROOT/build/run-envoc1/${program##*/}"; then bad "$name" 'the executable differs from the envoc1 build'; continue; fi
                problem=$(objects "$d" "$program" "$@")
                if [ -n "$problem" ]; then bad "$name" "$problem"; continue; fi
            fi
            set +e
            (cd "$rundir" && "$program") > "$TMP/out" 2> "$TMP/err"
            rc=$?
            set -e
            tr -d '\r' < "$TMP/out" > "$TMP/actual"
            if ! cmp -s "$TMP/expected" "$TMP/actual"; then bad "$name" 'stdout differs:'; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; continue; fi
            if [ "$rc" -ne 0 ]; then bad "$name" "exit code $rc: $(cat "$TMP/err")"; continue; fi
            if [ "$compiler" = envoc ]; then
                fast="$rundir/$msuite-$base-O2$(host_suffix)"
                run "$d" build -O2 "$@" -o "$fast"
                if [ "$rc" -ne 0 ]; then bad "$name" "-O2 build failed: $(cat "$TMP/err")"; continue; fi
                set +e
                (cd "$rundir" && "$fast") > "$TMP/out" 2> "$TMP/err"
                rc=$?
                set -e
                tr -d '\r' < "$TMP/out" > "$TMP/actual"
                if ! cmp -s "$TMP/expected" "$TMP/actual" || [ "$rc" -ne 0 ]; then bad "$name" "-O2: stdout or exit code ($rc) differs"; continue; fi
            fi
            pass
        done
        done
    done
    EXE=$stage0_exe

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
    run "$STAGE1" embed runtime/common.envo runtime/linux.envo runtime/windows.envo prelude/prelude.envo
    tr -d '\r' < "$STAGE1/runtime/embedded.envo" > "$TMP/expected"
    tr -d '\r' < "$TMP/out" > "$TMP/actual"
    if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
    else bad 'envoc1 embedded runtime' "bootstrap/stage1/runtime/embedded.envo is stale: regenerate it with envoc1 embed (see docs/architecture/stage1.md)"; fi
    # Stage 2 embeds the same runtime and prelude (compiler/driver/runtime.envo).
    run "$ROOT" embed bootstrap/stage1/runtime/common.envo bootstrap/stage1/runtime/linux.envo bootstrap/stage1/runtime/windows.envo bootstrap/stage1/prelude/prelude.envo
    tr -d '\r' < "$ROOT/compiler/driver/runtime.envo" > "$TMP/expected"
    tr -d '\r' < "$TMP/out" > "$TMP/actual"
    if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
    else bad 'envoc embedded runtime' "compiler/driver/runtime.envo is stale: regenerate it with envoc1 embed and Stage 1's runtime and prelude files (see docs/architecture/stage2.md)"; fi
    # and the WebAssembly OS layer, as RUNTIME_WASM (compiler/driver/runtime_wasm.envo)
    run "$ROOT" embed compiler/runtime/wasm.envo
    tr -d '\r' < "$ROOT/compiler/driver/runtime_wasm.envo" > "$TMP/expected"
    tr -d '\r' < "$TMP/out" | sed 's/^const str RUNTIME_0 = /const str RUNTIME_WASM = /' > "$TMP/actual"
    if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
    else bad 'envoc embedded wasm runtime' 'compiler/driver/runtime_wasm.envo is stale: regenerate it with envoc1 embed compiler/runtime/wasm.envo, renaming RUNTIME_0 to RUNTIME_WASM'; fi

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
    for suite in 01-lexical:lex:both core-syntax:parse:core core-types:check:core s1-syntax:parse:s1 s1-types:check:s1 s1-own:check:s1; do
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

    say ''
    say 'stage 2 smoke tests'
    EXE="$BUILD2/envoc$(host_suffix)"
    run "$ROOT" version
    if [ "$rc" -eq 0 ] && grep -q '^envoc ' "$TMP/out"; then pass; else bad 'envoc version' "exit $rc"; fi
    run "$ROOT" selftest
    if [ "$rc" -eq 0 ] && grep -q '^selftest: ok' "$TMP/out"; then pass; else bad 'envoc selftest' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    run "$ROOT"
    if [ "$rc" -eq 2 ] && grep -q '^usage: envoc' "$TMP/err"; then pass; else bad 'envoc no arguments' "exit $rc"; fi
    run "$ROOT" frobnicate
    if [ "$rc" -eq 2 ] && grep -q "^envoc: error: unknown command 'frobnicate'" "$TMP/err"; then pass; else bad 'envoc unknown command' "exit $rc"; fi

    # The Stage 2 front end and checker (M3.2-M3.5): the lexer, parser and checker goldens
    # and the lexical, syntax, type and ownership spec tests, in the same modes as for
    # Stage 1; then the same output as envoc1 from `lex` and `parse` on every source file,
    # from `check` on the run programs and goldens, and on both compilers' sources (D17).
    # Keep in step with bootstrap.ps1.
    envoc2=$EXE
    for suite in lexer:lex:.tokens:both parser:parse:.ast:both s1-parser:parse:.ast:s1 check:check:.check:both; do
      sdir=${suite%%:*}; rest=${suite#*:}; cmd=${rest%%:*}; rest=${rest#*:}; ext=${rest%%:*}; modes=${rest#*:}
      for mode in --core s1; do
        [ "$modes" = s1 ] && [ "$mode" = --core ] && continue
        if [ "$mode" = --core ]; then set -- --core; else set --; fi
        say "stage 2 golden tests ($mode): tests/golden/$sdir"
        dir="$ROOT/tests/golden/$sdir"
        for f in "$dir"/*.envo; do
            base=$(basename "$f")
            name="stage2 $mode golden/$sdir/$base"
            run "$dir" "$@" "$cmd" "$base"
            if [ "$rc" -ne 0 ]; then bad "$name" "exit $rc: $(tr -d '\r' < "$TMP/err")"; continue; fi
            tr -d '\r' < "${f%.envo}$ext" > "$TMP/expected"
            tr -d '\r' < "$TMP/out" > "$TMP/actual"
            if cmp -s "$TMP/expected" "$TMP/actual"; then pass
            else bad "$name" 'output differs:'; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; fi
        done
      done
    done
    for suite in 01-lexical:lex:both core-syntax:parse:core s1-syntax:parse:s1 core-types:check:core s1-types:check:s1 s1-own:check:s1 s2-own:check:s1; do
      sdir=${suite%%:*}; rest=${suite#*:}; cmd=${rest%%:*}; modes=${rest#*:}
      for mode in --core s1; do
        [ "$modes" = core ] && [ "$mode" = s1 ] && continue
        [ "$modes" = s1 ] && [ "$mode" = --core ] && continue
        if [ "$mode" = --core ]; then set -- --core; else set --; fi
        say "stage 2 spec tests ($mode): tests/spec/$sdir"
        dir="$ROOT/tests/spec/$sdir"
        for f in "$dir"/*.envo; do
            base=$(basename "$f")
            line=$(LC_ALL=C grep -a -m1 '^// expect-error: ' "$f" | tr -d '\r' || true)
            code=$(printf '%s\n' "$line" | sed 's|^// expect-error: \(E[0-9][0-9][0-9][0-9]\).*|\1|')
            if [ "$mode" = s1 ]; then
                case "$code" in E090[1-4]) code=E0950 ;; esac
            fi
            pos=${line##* @ }; pos=${pos%% *}
            want="$base:$pos: error[$code]"
            run "$dir" "$@" "$cmd" "$base"
            if [ "$rc" -eq 1 ] && LC_ALL=C grep -a -q -F "$want" "$TMP/err"; then pass
            else bad "stage2 $mode spec/$sdir/$base" "expected exit 1 with '$want'; got exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
        done
      done
    done
    # EIR (M3.6): the same goldens and verifier errors as Stage 1.
    say 'stage 2 golden tests: tests/golden/eir'
    dir="$ROOT/tests/golden/eir"
    for f in "$dir"/*.eir; do
        base=$(basename "$f")
        tr -d '\r' < "${f%.eir}.out" > "$TMP/expected"
        for input in "$base" "${base%.eir}.out"; do
            run "$dir" eir-check "$input"
            tr -d '\r' < "$TMP/out" > "$TMP/actual"
            if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
            else bad "stage2 golden/eir/$input" "exit $rc: $(tr -d '\r' < "$TMP/err")"; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; fi
        done
        # the binary form (M3.7): text -> binary -> text, and binary -> binary
        run "$dir" eir-check "$base" -o "$TMP/1.eirb"
        [ "$rc" -eq 0 ] && run "$dir" eir-check "$TMP/1.eirb"
        tr -d '\r' < "$TMP/out" > "$TMP/actual"
        [ "$rc" -eq 0 ] && run "$dir" eir-check "$TMP/1.eirb" -o "$TMP/2.eirb"
        if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual" && cmp -s "$TMP/1.eirb" "$TMP/2.eirb"; then pass
        else bad "stage2 golden/eir/$base (binary)" "exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
    done
    # -O2's EIR passes (M3.8)
    say 'stage 2 golden tests: tests/golden/opt'
    dir="$ROOT/tests/golden/opt"
    for f in "$dir"/*.eir; do
        base=$(basename "$f")
        tr -d '\r' < "${f%.eir}.out" > "$TMP/expected"
        run "$dir" eir-check "$base" -O2
        tr -d '\r' < "$TMP/out" > "$TMP/actual"
        if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
        else bad "stage2 golden/opt/$base" "exit $rc: $(tr -d '\r' < "$TMP/err")"; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; fi
    done
    say 'stage 2 spec tests: tests/spec/eir'
    dir="$ROOT/tests/spec/eir"
    for f in "$dir"/*.eir; do
        base=$(basename "$f")
        line=$(grep -m1 '^; expect-error: ' "$f" | tr -d '\r' || true)
        code=$(printf '%s\n' "$line" | sed 's|^; expect-error: \(E[0-9]*\) @ .*|\1|')
        pos=${line##* @ }; pos=${pos%% *}
        want="$base:$pos: error[$code]"
        run "$dir" eir-check "$base"
        if [ "$rc" -eq 1 ] && grep -q -F "$want" "$TMP/err"; then pass
        else bad "stage2 spec/eir/$base" "expected exit 1 with '$want'; got exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
    done
    # The standard platform and the examples (PLAN D29): `envo test` builds and runs each
    # library test, adapter test and conformance suite (the suites against the reference
    # and the native adapters) at -O0 and -O2, and builds each example package. Keep in
    # step with bootstrap.ps1.
    say 'envo test: lib, adapters, tests/conformance, examples'
    envo="$ROOT/build/envo/envo$(host_suffix)"
    set +e
    (cd "$ROOT" && "$envo" test lib adapters tests/conformance examples) > "$TMP/out" 2> "$TMP/err"
    rc=$?
    set -e
    summary=$(grep -E '^[0-9]+ passed, [0-9]+ failed' "$TMP/out" | tail -n 1 || true)
    if [ -z "$summary" ]; then
        bad 'envo test' "no summary (exit $rc): $(cat "$TMP/err")"
    else
        np=${summary%% passed*}
        nf=${summary#*, }
        nf=${nf%% failed*}
        passed=$((passed + np))
        if [ "$nf" -gt 0 ] || [ "$rc" -ne 0 ]; then
            bad 'envo test' "$(cat "$TMP/out")"
            if [ "$nf" -gt 1 ]; then failed=$((failed + nf - 1)); fi
        fi
    fi
    # The script runtime (PLAN D35): every spec run program, and every multi-file one, runs
    # in the VM (`envo run -A`) with the output, exit code and panic it has natively.
    say 'script runtime: tests/spec/core-run, s1-run, s2-run and the multi-file programs in the VM'
    vmdir="$ROOT/build/run-vm"
    mkdir -p "$vmdir"
    for suite in core-run s1-run s2-run; do
        for f in "$ROOT"/tests/spec/$suite/*.envo; do
            name="vm spec/$suite/$(basename "$f")"
            sed -n 's|^// expect: \(.*\)$|\1|p' "$f" | tr -d '\r' > "$TMP/expected"
            want_code=$(sed -n 's|^// expect-exit: \([0-9]*\).*|\1|p' "$f" | head -n 1)
            panic=$(sed -n 's|^// expect-panic: \(.*\)$|\1|p' "$f" | tr -d '\r' | head -n 1)
            [ -n "$want_code" ] || want_code=0
            [ -z "$panic" ] || want_code=101
            set +e
            (cd "$vmdir" && "$envo" run -A "$f") > "$TMP/out" 2> "$TMP/err"
            rc=$?
            set -e
            tr -d '\r' < "$TMP/out" > "$TMP/actual"
            if ! cmp -s "$TMP/expected" "$TMP/actual"; then bad "$name" 'stdout differs:'; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; continue; fi
            if [ "$rc" -ne "$want_code" ]; then bad "$name" "exit code $rc, expected $want_code: $(cat "$TMP/err")"; continue; fi
            if [ -n "$panic" ] && ! grep -q -F "panic: $panic" "$TMP/err"; then bad "$name" "stderr: $(cat "$TMP/err")"; continue; fi
            pass
        done
    done
    for msuite in core-multi s1-multi; do
        for d in "$ROOT"/tests/spec/$msuite/*/; do
            d=${d%/}
            grep -q '^// expect-error: ' "$d/main.envo" && continue
            set -- main.envo
            for f in "$d"/*.envo; do
                f=$(basename "$f")
                [ "$f" = main.envo ] || set -- "$@" "$f"
            done
            sed -n 's|^// expect: \(.*\)$|\1|p' "$d/main.envo" | tr -d '\r' > "$TMP/expected"
            set +e
            (cd "$d" && "$envo" run -A "$@") > "$TMP/out" 2> "$TMP/err"
            rc=$?
            set -e
            tr -d '\r' < "$TMP/out" > "$TMP/actual"
            if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
            else bad "vm spec/$msuite/$(basename "$d")" "exit $rc: $(cat "$TMP/err")"; fi
        done
    done
    # Permissions (PLAN D34): each tests/sandbox program runs with its `// allow:` lines as
    # --allow, in a scratch copy of the folder; stdout must be its `// expect:` lines and
    # stderr must hold each `// expect-stderr:` text (tests/sandbox/README.md)
    say 'script runtime permissions: tests/sandbox'
    boxdir="$ROOT/build/run-sandbox"
    rm -rf "$boxdir"
    mkdir -p "$boxdir"
    cp "$ROOT"/tests/sandbox/*.envo "$boxdir"/
    for f in "$boxdir"/*.envo; do
        base=$(basename "$f")
        set -- run
        while IFS= read -r a; do
            [ -n "$a" ] && set -- "$@" --allow "$a"
        done <<EOF_ALLOW
$(sed -n 's|^// allow: \(.*\)$|\1|p' "$f" | tr -d '\r')
EOF_ALLOW
        set -- "$@" "$base"
        sed -n 's|^// expect: \(.*\)$|\1|p' "$f" | tr -d '\r' > "$TMP/expected"
        set +e
        (cd "$boxdir" && "$envo" "$@") > "$TMP/out" 2> "$TMP/err"
        rc=$?
        set -e
        tr -d '\r' < "$TMP/out" > "$TMP/actual"
        problem=
        if [ "$rc" -ne 0 ]; then problem="exit $rc: $(cat "$TMP/err")"
        elif ! cmp -s "$TMP/expected" "$TMP/actual"; then problem='stdout differs'; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true
        else
            while IFS= read -r want; do
                [ -n "$want" ] || continue
                grep -q -F -- "$want" "$TMP/err" || problem="stderr lacks '$want': $(cat "$TMP/err")"
            done <<EOF_ERR
$(sed -n 's|^// expect-stderr: \(.*\)$|\1|p' "$f" | tr -d '\r')
EOF_ERR
        fi
        if [ -z "$problem" ]; then pass; else bad "sandbox $base" "$problem"; fi
    done
    # A script run through its shebang line (PLAN D33), where the system has `env`: an
    # executable file starting with `#!/usr/bin/env envo`, found on PATH
    if [ -z "$(host_suffix)" ] && [ -x /usr/bin/env ]; then
        say 'script runtime: a #!/usr/bin/env envo script'
        printf '#!/usr/bin/env envo\nuse std.env;\nList<str> all = env.Args();\nforeach (var a in all.AsSlice()) print(a);\n' > "$boxdir/args.envo"
        chmod +x "$boxdir/args.envo"
        set +e
        (cd "$boxdir" && PATH="$ROOT/build/envo:$PATH" ./args.envo one 'two words') > "$TMP/out" 2> "$TMP/err"
        rc=$?
        set -e
        printf 'one\ntwo words\n' > "$TMP/expected"
        if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/out"; then pass; else bad 'shebang script' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    fi
    # The TLS 1.3 client against openssl s_server (tests/tls/README.md), where openssl is
    # installed
    if command -v openssl > /dev/null 2>&1; then
        say 'tls: tests/tls/client.envo against openssl s_server'
        tdir="$ROOT/build/run-tls"
        rm -rf "$tdir"
        mkdir -p "$tdir"
        tls_ok=1
        (
            cd "$tdir"
            export MSYS_NO_PATHCONV=1
            openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout ca.key -out ca.pem -days 30 -subj "/CN=Envo Test CA" -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign" &&
            openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout other.key -out other.pem -days 30 -subj "/CN=Other CA" &&
            printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\nbasicConstraints=CA:FALSE\n' > leaf.ext &&
            openssl req -newkey rsa:2048 -nodes -keyout rsa.key -out rsa.csr -subj "/CN=localhost" &&
            openssl x509 -req -in rsa.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out rsa.pem -days 30 -sha256 -extfile leaf.ext &&
            openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout ec.key -out ec.csr -subj "/CN=localhost" &&
            openssl x509 -req -in ec.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out ec.pem -days 30 -sha256 -extfile leaf.ext
        ) > "$TMP/out" 2>&1 || tls_ok=0
        if [ "$tls_ok" -eq 0 ]; then bad 'tls certificates' "$(cat "$TMP/out")"; else
            EXE=$envoc2
            run "$tdir" build --lib "$ROOT" "$ROOT/tests/tls/client.envo" -o "$tdir/client$(host_suffix)"
            if [ "$rc" -ne 0 ]; then bad 'tls client build' "$(cat "$TMP/err")"; else
                port=18443
                for case in "rsa:TLS_AES_128_GCM_SHA256:ca.pem:HTTP/1.0 200 ok" "ec:TLS_CHACHA20_POLY1305_SHA256:ca.pem:HTTP/1.0 200 ok" "ec:TLS_AES_128_GCM_SHA256:other.pem:failed: the server's certificate is not trusted"; do
                    key=${case%%:*}; rest=${case#*:}
                    suite=${rest%%:*}; rest=${rest#*:}
                    trust=${rest%%:*}; want=${rest#*:}
                    port=$((port + 1))
                    (cd "$tdir" && exec openssl s_server -tls1_3 -accept "$port" -cert "$key.pem" -key "$key.key" -ciphersuites "$suite" -www -quiet) > "$tdir/server.log" 2>&1 &
                    spid=$!
                    sleep 1
                    set +e
                    (cd "$tdir" && "$tdir/client$(host_suffix)" "$trust" "$port") > "$TMP/out" 2> "$TMP/err"
                    rc=$?
                    set -e
                    kill "$spid" 2> /dev/null || true
                    wait "$spid" 2> /dev/null || true
                    if [ "$rc" -eq 0 ] && grep -q -F "$want" "$TMP/out"; then pass; else bad "tls $key $suite trusting $trust" "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
                done
            fi
        fi
    else
        say 'tls: skipped (no openssl on this machine)'
    fi
    # The WebAssembly backend: the spec run programs and library tests under Node.js (adapters/interop/js/test-wasm.js)
    if command -v node > /dev/null 2>&1; then
        say 'wasm: tests/spec run programs and lib tests as WebAssembly under Node.js'
        set +e
        node "$ROOT/adapters/interop/js/test-wasm.js" "$envoc2" > "$TMP/out" 2>&1
        rc=$?
        set -e
        if [ "$rc" -eq 0 ]; then pass; else bad 'wasm spec run programs' "$(tail -n 40 "$TMP/out")"; fi
    else
        say 'wasm: skipped (no Node.js on this machine)'
    fi
    # envo's own commands: new, run, test, check, explain, version (tests/envo/README.md)
    say 'envo commands: new, run, test, check, explain, version'
    erun="$ROOT/build/run-envo"
    rm -rf "$erun"
    mkdir -p "$erun"
    envo_do() {
        set +e
        (cd "$erun" && "$envo" "$@") > "$TMP/out" 2> "$TMP/err"
        rc=$?
        set -e
    }
    envo_do new demo
    if [ "$rc" -eq 0 ] && [ -f "$erun/demo/envo.envon" ]; then pass; else bad 'envo new' "exit $rc: $(cat "$TMP/err")"; fi
    envo_do run demo
    if [ "$rc" -eq 0 ] && [ "$(tr -d '\r' < "$TMP/out")" = 'Hello, demo!' ]; then pass; else bad 'envo run' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    envo_do run --native demo
    if [ "$rc" -eq 0 ] && [ "$(tr -d '\r' < "$TMP/out")" = 'Hello, demo!' ]; then pass; else bad 'envo run --native' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    envo_do test demo
    if [ "$rc" -eq 0 ] && grep -q '4 passed, 0 failed' "$TMP/out"; then pass; else bad 'envo test (package)' "exit $rc: $(cat "$TMP/out")"; fi
    printf 'i32 x = ;\n' > "$erun/bad.envo"
    envo_do check bad.envo
    if [ "$rc" -eq 1 ] && grep -q -F 'bad.envo:1:9: error[E0101]' "$TMP/err" && grep -q -F '1 | i32 x = ;' "$TMP/err" && grep -q -F 'envo explain E0101' "$TMP/err"; then pass; else bad 'envo check' "exit $rc: $(cat "$TMP/err")"; fi
    envo_do explain E0004
    if [ "$rc" -eq 0 ] && grep -q -F 'E0004: unterminated string literal' "$TMP/out" && grep -q -F '[lex.str.1]' "$TMP/out"; then pass; else bad 'envo explain' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    envo_do explain E9999
    if [ "$rc" -eq 1 ]; then pass; else bad 'envo explain (unknown)' "exit $rc"; fi
    envo_do version
    if [ "$rc" -eq 0 ] && grep -q '^envo ' "$TMP/out"; then pass; else bad 'envo version' "exit $rc"; fi
    # envo repl: cells piped in; each cell's output shows once, a bad cell shows its error
    set +e
    printf 'print("hello")\ni32 Twice(i32 x) {\n    return x * 2;\n}\nuse alloc.text;\nprint(text.Int(Twice(21) as i64).AsStr())\nu8 bad = nope;\n:quit\n' | (cd "$erun" && "$envo" repl) > "$TMP/out" 2> "$TMP/err"
    rc=$?
    set -e
    hellos=$(grep -o hello "$TMP/out" | wc -l | tr -d ' ')
    if [ "$rc" -eq 0 ] && [ "$hellos" -eq 1 ] && grep -q '> 42$' "$TMP/out" && grep -q -F 'error[E0203]' "$TMP/out"; then pass; else bad 'envo repl' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    envo_do frobnicate
    if [ "$rc" -eq 2 ]; then pass; else bad 'envo (unknown command)' "exit $rc"; fi
    # envo fmt: each tests/golden/fmt/name.envo formats to name.expected, which formats to
    # itself; and the repository's own code is already in the canonical layout
    say 'envo fmt: tests/golden/fmt, and --check on the code'
    for f in "$ROOT"/tests/golden/fmt/*.envo; do
        expected="${f%.envo}.expected"
        tr -d '\r' < "$expected" > "$TMP/expected"
        envo_do fmt --stdout "$f"
        tr -d '\r' < "$TMP/out" > "$TMP/actual"
        if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
        else bad "golden fmt/$(basename "$f")" "exit $rc: $(cat "$TMP/err")"; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; fi
        envo_do fmt --stdout "$expected"
        tr -d '\r' < "$TMP/out" > "$TMP/actual"
        if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
        else bad "golden fmt/$(basename "$f") (formatting the expected output changes it)" "exit $rc"; fi
    done
    set +e
    (cd "$ROOT" && "$envo" fmt --check lib adapters tools tests/conformance compiler bootstrap/stage1 runtime examples) > "$TMP/out" 2> "$TMP/err"
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then pass; else bad 'envo fmt --check (run envo fmt on these files)' "$(cat "$TMP/out" "$TMP/err")"; fi
    # envo lsp: tests/lsp/session.jsonl, framed, piped in; the bodies it writes back must
    # be tests/lsp/expected.jsonl (tests/lsp/README.md)
    say 'envo lsp: tests/lsp/session.jsonl'
    lspdir="$ROOT/build/run-lsp"
    mkdir -p "$lspdir"
    # Git Bash on Windows: the URI needs the Windows form of the path (C:/...)
    if command -v cygpath > /dev/null 2>&1; then uri="file:///$(cygpath -m "$lspdir")/doc.envo"
    else uri="file://$lspdir/doc.envo"; fi
    : > "$TMP/lsp-in"
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(printf '%s' "$line" | tr -d '\r')
        [ -n "$line" ] || continue
        body=$(printf '%s' "$line" | sed "s|[\$]{URI}|$uri|g")
        printf 'Content-Length: %d\r\n\r\n%s' "$(printf '%s' "$body" | wc -c | tr -d ' ')" "$body" >> "$TMP/lsp-in"
    done < "$ROOT/tests/lsp/session.jsonl"
    set +e
    (cd "$lspdir" && "$envo" lsp) < "$TMP/lsp-in" > "$TMP/out" 2> "$TMP/err"
    rc=$?
    set -e
    tr -d '\r' < "$TMP/out" | sed 's/Content-Length: [0-9]*$//' | sed 's/^Content-Length: [0-9]*$//' | grep -v '^$' | sed "s|$uri|\${URI}|g" > "$TMP/actual" || true
    tr -d '\r' < "$ROOT/tests/lsp/expected.jsonl" | grep -v '^$' > "$TMP/expected"
    if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
    else bad 'envo lsp' "exit $rc: $(cat "$TMP/err")"; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; fi
    # Library resolution errors (M4.1): `// lib: root` checks against tests/spec/lib/root
    # instead of the repository
    say 'stage 2 spec tests: tests/spec/lib'
    dir="$ROOT/tests/spec/lib"
    for f in "$dir"/*.envo; do
        base=$(basename "$f")
        line=$(grep -m1 '^// expect-error: ' "$f" | tr -d '\r' || true)
        code=$(printf '%s\n' "$line" | sed 's|^// expect-error: \(E[0-9]*\) @ .*|\1|')
        where=${line##* @ }
        case "$where" in
            *.envo:*) want="$where: error[$code]" ;;
            *) want="$base:$where: error[$code]" ;;
        esac
        libroot="$ROOT"
        if grep -q '^// lib: root' "$f"; then libroot=root; fi
        run "$dir" check --lib "$libroot" "$base"
        if [ "$rc" -eq 1 ] && grep -q -F "$want" "$TMP/err"; then pass
        else bad "stage2 spec/lib/$base" "expected exit 1 with '$want'; got exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
    done
    say 'stage 2 against envoc1: lex and parse on every .envo file in compiler/, bootstrap/stage1/, tests/; check on the run programs and goldens; eir on the run programs'
    for f in $(cd "$ROOT" && find compiler bootstrap/stage1 tests -name '*.envo' | LC_ALL=C sort); do
        dir="$ROOT/$(dirname "$f")"
        base=$(basename "$f")
        cmds='lex parse'
        case "$f" in
            tests/spec/core-run/*|tests/spec/s1-run/*) cmds='lex parse check eir' ;;
            tests/golden/*) cmds='lex parse check' ;;
        esac
        for cmd in $cmds; do
            EXE=$ENVOC1
            run "$dir" "$cmd" "$base"
            rc1=$rc
            mv "$TMP/out" "$TMP/out1"
            mv "$TMP/err" "$TMP/err1"
            EXE=$envoc2
            run "$dir" "$cmd" "$base"
            if [ "$rc" -eq "$rc1" ] && cmp -s "$TMP/out1" "$TMP/out" && cmp -s "$TMP/err1" "$TMP/err"; then pass
            else bad "stage2 $cmd $f" "differs from envoc1 (exit $rc1 vs $rc)"; fi
        done
    done
    for unit in bootstrap/stage1:--core compiler:s1 bootstrap/stage1:--core:eir compiler:s1:eir; do
        pass_eir=0
        case "$unit" in *:eir) pass_eir=1; unit=${unit%:eir} ;; esac
        dir="$ROOT/${unit%%:*}"
        cmd=check
        [ "$pass_eir" = 1 ] && cmd=eir
        if [ "${unit#*:}" = --core ]; then set -- --core "$cmd"; else set -- "$cmd"; fi
        while IFS= read -r f || [ -n "$f" ]; do
            f=$(printf '%s' "$f" | tr -d '\r')
            [ -n "$f" ] && set -- "$@" "$f"
        done < "$dir/files.txt"
        EXE=$ENVOC1
        run "$dir" "$@"
        rc1=$rc
        mv "$TMP/out" "$TMP/out1"
        mv "$TMP/err" "$TMP/err1"
        EXE=$envoc2
        run "$dir" "$@"
        if [ "$rc" -eq "$rc1" ] && cmp -s "$TMP/out1" "$TMP/out" && cmp -s "$TMP/err1" "$TMP/err"; then pass
        else bad "stage2 $cmd ${unit%%:*}" "differs from envoc1 (exit $rc1 vs $rc)"; fi
    done
    # Stage 2 builds Stage 1 as envoc1 does, and builds itself into the envoc that envoc1
    # built, for both targets (M3.6).
    selfdir="$ROOT/build/run-envoc"
    for unit in bootstrap/stage1:--core:x86_64-linux compiler::x86_64-linux compiler::x86_64-windows; do
        dir="$ROOT/${unit%%:*}"
        target=${unit##*:}
        set -- build
        case "$unit" in *:--core:*) set -- --core build ;; esac
        while IFS= read -r f || [ -n "$f" ]; do
            f=$(printf '%s' "$f" | tr -d '\r')
            [ -n "$f" ] && set -- "$@" "$f"
        done < "$dir/files.txt"
        what="stage2 build ${unit%%:*} ($target)"
        if [ "${unit%%:*}" = compiler ]; then
            want="$BUILD2/envoc"
            [ "$target" = x86_64-windows ] && want="$BUILD2/envoc.exe"
        else
            want="$selfdir/self-stage1-envoc1"
            EXE=$ENVOC1
            run "$dir" "$@" -o "$want" --target "$target"
            if [ "$rc" -ne 0 ]; then bad "$what" "envoc1 failed: exit $rc"; continue; fi
        fi
        EXE=$envoc2
        run "$dir" "$@" -o "$selfdir/self-$target" --target "$target"
        if [ "$rc" -eq 0 ] && cmp -s "$want" "$selfdir/self-$target"; then pass
        else bad "$what" "exit $rc, or the executable differs from envoc1's"; fi
    done
    # Stage 2 at -O2 (M3.8): it builds Stage 2 into the same bytes as envoc1's build at
    # -O0, and into itself at -O2
    set -- build
    while IFS= read -r f || [ -n "$f" ]; do
        f=$(printf '%s' "$f" | tr -d '\r')
        [ -n "$f" ] && set -- "$@" "$f"
    done < "$ROOT/compiler/files.txt"
    fast="$selfdir/envoc-O2$(host_suffix)"
    run "$ROOT/compiler" "$@" -O2 -o "$fast"
    saved=$EXE
    EXE=$fast
    [ "$rc" -eq 0 ] && run "$ROOT/compiler" "$@" -o "$selfdir/by-O2$(host_suffix)"
    [ "$rc" -eq 0 ] && run "$ROOT/compiler" "$@" -O2 -o "$selfdir/by-O2-O2$(host_suffix)"
    EXE=$saved
    if [ "$rc" -eq 0 ] && cmp -s "$selfdir/by-O2$(host_suffix)" "$BUILD2/envoc$(host_suffix)" && cmp -s "$fast" "$selfdir/by-O2-O2$(host_suffix)"; then pass
    else bad 'stage2 -O2 self-build' "exit $rc, or the -O2 compiler's output differs"; fi
    # Stage 2 through an object of itself (M3.7), and link errors
    set -- compile
    while IFS= read -r f || [ -n "$f" ]; do
        f=$(printf '%s' "$f" | tr -d '\r')
        [ -n "$f" ] && set -- "$@" "$f"
    done < "$ROOT/compiler/files.txt"
    run "$ROOT/compiler" "$@" -o "$selfdir/self.eo"
    [ "$rc" -eq 0 ] && run "$ROOT/compiler" link "$selfdir/self.eo" -o "$selfdir/self-linked"
    if [ "$rc" -eq 0 ] && cmp -s "$selfdir/self-linked" "$BUILD2/envoc$(host_suffix)"; then pass
    else bad 'stage2 compile and link compiler' "exit $rc, or the executable differs from build/stage2"; fi
    run "$ROOT" link "$selfdir/core-multi-program$(host_suffix).0.eo" -o "$selfdir/none"
    if [ "$rc" -eq 1 ] && grep -q 'no object defines @' "$TMP/err"; then pass; else bad 'stage2 link with a unit missing' "exit $rc: $(cat "$TMP/err")"; fi
    run "$ROOT" link "$selfdir/core-multi-program$(host_suffix).0.eo" "$selfdir/s1-multi-namespaces$(host_suffix).0.eo" -o "$selfdir/none"
    if [ "$rc" -eq 1 ] && grep -q 'compiled from different programs' "$TMP/err"; then pass; else bad 'stage2 link of two programs' "exit $rc: $(cat "$TMP/err")"; fi
    printf 'EIR\000\002\000' > "$selfdir/v2.eo"
    run "$ROOT" link "$selfdir/v2.eo" -o "$selfdir/none"
    if [ "$rc" -eq 1 ] && grep -q 'binary EIR version 2; this envoc reads version 1' "$TMP/err"; then pass; else bad 'stage2 link of an unknown version' "exit $rc: $(cat "$TMP/err")"; fi
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
             LICENSE envo.envon bootstrap.sh bootstrap.ps1 docs/PLAN.md docs/rfcs/0000-template.md \
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
# compare <dir-a> <dir-b>: both builds (each a copy of build/, with stage0/, stage1/ and
# stage2/) must be byte-identical (brief 4.1).
# The fixed point (PLAN D18, M3.9): stage2a (build/stage2, built by envoc1) builds Stage 2
# at -O2 into build/stage2b, and stage2b builds it again into build/stage2c, for both
# targets. stage2b and stage2c must be byte-identical.
do_fixedpoint() {
    do_build
    set --
    while IFS= read -r f || [ -n "$f" ]; do
        f=$(printf '%s' "$f" | tr -d '\r')
        [ -n "$f" ] && set -- "$@" "$f"
    done < "$STAGE2/files.txt"
    for step in stage2:stage2b stage2b:stage2c; do
        from=${step%%:*}
        to=${step#*:}
        mkdir -p "$ROOT/build/$to"
        exe="$ROOT/build/$from/envoc$(host_suffix)"
        for unit in "x86_64-linux:envoc" "x86_64-windows:envoc.exe"; do
            target=${unit%%:*}
            out=${unit#*:}
            say "build     compiler -> build/$to/$out (by build/$from/envoc$(host_suffix), -O2)"
            (cd "$STAGE2" && "$exe" build "$@" -O2 -o "$ROOT/build/$to/$out" --target "$target") \
                || fail "building Stage 2 ($target) with build/$from failed"
            say "          $(wc -c < "$ROOT/build/$to/$out" | tr -d ' ') bytes  sha256 $(sha256 "$ROOT/build/$to/$out")"
        done
        chmod +x "$ROOT/build/$to/envoc"
    done
    for out in envoc envoc.exe; do
        if cmp -s "$ROOT/build/stage2b/$out" "$ROOT/build/stage2c/$out"; then say "fixed point: stage2b/$out = stage2c/$out"
        else fail "no fixed point: build/stage2b/$out and build/stage2c/$out differ"; fi
    done
}

do_compare() {
    [ "$#" -eq 2 ] || fail "usage: ./bootstrap.sh compare <dir-a> <dir-b>"
    differ=0
    files='stage0/envoc0 stage0/envoc0.exe stage1/envoc1 stage1/envoc1.exe stage2/envoc stage2/envoc.exe'
    # after `fixedpoint`, the fixed-point compilers too
    [ -d "$1/stage2c" ] && files="$files stage2c/envoc stage2c/envoc.exe"
    for f in $files; do
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
    fixedpoint) do_fixedpoint ;;
    test)  do_test ;;
    check) do_check ;;
    clean) rm -rf "$ROOT/build"; say 'removed build/' ;;
    help|*)
        say 'usage: ./bootstrap.sh <build|test|fixedpoint|check|clean|help>'
        say '  build   assemble Stage 0 (needs NASM; see adapters/bootstrap/nasm/README.md), then build Stage 1'
        say '  test    build, then run the Stage 0 and Stage 1 tests'
        say '  check   repository layout, lib->adapters imports, Hello World Gallery limits'
        say '  fixedpoint  build, then Stage 2 by itself twice at -O2 (build/stage2b, build/stage2c); they must match'
        say '  compare <dir-a> <dir-b>   require two builds (copies of build/) to be byte-identical'
        say '  clean   delete build/'
        [ "${1:-help}" = help ] || exit 2 ;;
esac
