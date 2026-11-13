#!/bin/sh
# Builds and tests EnvoScale on Linux and on Windows with Git Bash. build.ps1 is the
# PowerShell twin for Windows; keep the two in step.
#
#   ./build.sh build      download the seed compiler, build the compiler with it, then with
#                         itself, then the envo tool: build/envoc/ and build/envo/
#   ./build.sh test       build, then every test
#   ./build.sh check      quick repository checks
#   ./build.sh dist       build, then the release archive in build/dist/
#   ./build.sh cross      build, then the run and library tests for aarch64 in build/cross/
#   ./build.sh cross-run <dir>   run those on an aarch64 Linux or macOS machine
#   ./build.sh compare <a> <b>   two builds (copies of build/) must be byte-identical
#   ./build.sh clean
#
# The seed is the compiler EnvoScaleAsm builds from assembly
# (https://github.com/envoscale/EnvoScaleAsm), downloaded from its releases, or built from
# its assembly when that download is not available. Set ENVO_SEED to use an envoc you
# already have instead.
set -eu

ROOT=$(cd "$(dirname "$0")" && pwd)
STAGE2="$ROOT/compiler"
BUILDA="$ROOT/build/envoc-seeded"
BUILD2="$ROOT/build/envoc"

SEED_TAG=seed-1
SEED_SHA_LINUX=4dc77e88ca305fc25dea2065e23b9184545ddedaf50ea866af20d44b091d2e8b
SEED_SHA_WINDOWS=46eaa09c84230fa654ba5e6b7534e57b745931d49686ad7fdde65f836a2f3290
SEED_URL="https://github.com/envoscale/EnvoScaleAsm/releases/download/$SEED_TAG"
SEED_ASM_REPO=https://github.com/envoscale/EnvoScaleAsm
SEED_ASM_REF=9222580cac7a83fc6ec168e973823cabe82f941f

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
        *) fail "no seed compiler for $(uname -s) yet (supported: Linux, Windows); see https://github.com/envoscale/EnvoScale/blob/main/porting/CHECKLIST.md" ;;
    esac
}

# ------------------------------------------------------------------- build
# seed: prints the path of the seed compiler, downloading and checking it the first time.
seed() {
    if [ -n "${ENVO_SEED:-}" ]; then printf '%s' "$ENVO_SEED"; return; fi
    case "$(host_suffix)" in
        .exe) name=envoc-x86_64-windows.exe; want=$SEED_SHA_WINDOWS ;;
        *) name=envoc-x86_64-linux; want=$SEED_SHA_LINUX ;;
    esac
    file="$ROOT/build/seed/$SEED_TAG/$name"
    if [ ! -f "$file" ]; then
        mkdir -p "$ROOT/build/seed/$SEED_TAG"
        say "download  $SEED_URL/$name" >&2
        got=
        if command -v curl >/dev/null 2>&1 && curl -fsSL -o "$file.part" "$SEED_URL/$name" 2>/dev/null; then got=yes
        elif command -v wget >/dev/null 2>&1 && wget -q -O "$file.part" "$SEED_URL/$name" 2>/dev/null; then got=yes; fi
        if [ -z "$got" ]; then
            # No download: build the seed from assembly, with EnvoScaleAsm at the commit
            # that made this release. The bytes must be the same either way.
            say "          not available: building the seed from assembly (EnvoScaleAsm)" >&2
            asm="$ROOT/build/seed/EnvoScaleAsm"
            [ -d "$asm/.git" ] || git clone -q "$SEED_ASM_REPO" "$asm" >&2 || fail "cloning $SEED_ASM_REPO failed; set ENVO_SEED to an envoc"
            git -C "$asm" fetch -q origin >&2 || true
            git -C "$asm" -c advice.detachedHead=false checkout -q "$SEED_ASM_REF" >&2 || fail "EnvoScaleAsm: cannot check out $SEED_ASM_REF"
            (cd "$asm" && ./bootstrap.sh seed) >&2 || fail "building the seed from assembly failed"
            cp "$asm/build/seed-release/$name" "$file.part"
        fi
        got=$(sha256 "$file.part")
        [ "$got" = "$want" ] || { rm -f "$file.part"; fail "the seed's sha256 is $got, expected $want"; }
        mv "$file.part" "$file"
        chmod +x "$file"
    fi
    printf '%s' "$file"
}

# files <list>: sets the positional parameters to the lines of a files.txt.
compiler_files() {
    set --
    while IFS= read -r f || [ -n "$f" ]; do
        f=$(printf '%s' "$f" | tr -d '\r')
        [ -n "$f" ] && printf '%s\n' "$f"
    done < "$STAGE2/files.txt"
}

do_build() {
    seedc=$(seed)
    # The seed builds the compiler for this host; that compiler builds it again for both
    # OSes, so build/envoc is the compiler as its own sources say, whatever the seed was.
    mkdir -p "$BUILDA" "$BUILD2"
    set -- $(compiler_files)
    say "build     compiler -> build/envoc-seeded (by the seed)"
    (cd "$STAGE2" && "$seedc" build -O2 "$@" -o "$BUILDA/envoc$(host_suffix)") || fail "building the compiler with the seed failed"
    for unit in "x86_64-linux:envoc" "x86_64-windows:envoc.exe"; do
        target=${unit%%:*}
        out=${unit#*:}
        say "build     compiler -> build/envoc/$out"
        (cd "$STAGE2" && "$BUILDA/envoc$(host_suffix)" build -O2 "$@" -o "$BUILD2/$out" --target "$target") \
            || fail "building the compiler ($target) failed"
        say "          $(wc -c < "$BUILD2/$out" | tr -d ' ') bytes  sha256 $(sha256 "$BUILD2/$out")"
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
        [ -n "$f" ] && [ "$f" != driver/main.envol ] && set -- "$@" "compiler/$f"
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

# run <dir> <args...>: runs $EXE in <dir>; sets rc, and leaves
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
    EXE="$BUILD2/envoc$(host_suffix)"
    envoc2=$EXE
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT

    # Hardening (PLAN D68): executables keep code and data apart (W^X)
    # and can be loaded anywhere (ASLR): Linux ET_DYN with an R+X and an R+W segment;
    # Windows with DYNAMIC_BASE and HIGH_ENTROPY_VA and no section both writable and executable
    say ''
    say 'hardening: W^X and ASLR in the executables envoc builds'
    u8at() { od -An -t u1 -j "$2" -N 1 "$1" | tr -d ' '; }
    u16at() { echo $(( $(u8at "$1" "$2") + 256 * $(u8at "$1" $(($2 + 1))) )); }
    u32at() { echo $(( $(u16at "$1" "$2") + 65536 * $(u16at "$1" $(($2 + 2))) )); }
    h_hsrc="$ROOT/tests/spec/core-run/$(ls "$ROOT/tests/spec/core-run" | head -n 1)"
    for h_comp in "$BUILD2/envoc$(host_suffix)"; do
        set +e
        "$h_comp" build "$h_hsrc" -o "$TMP/h-linux" --target x86_64-linux > /dev/null 2>&1
        "$h_comp" build "$h_hsrc" -o "$TMP/h-win.exe" --target x86_64-windows > /dev/null 2>&1
        set -e
        h_et=$(u16at "$TMP/h-linux" 16)
        h_f0=$(u32at "$TMP/h-linux" 68)
        h_f1=$(u32at "$TMP/h-linux" 124)
        if [ "$h_et" -eq 3 ] && [ "$h_f0" -eq 5 ] && [ "$h_f1" -eq 6 ]; then pass; else bad "hardening: ELF from ${h_comp##*/}" "e_type $h_et, segment flags $h_f0 and $h_f1"; fi
        h_pe=$(u32at "$TMP/h-win.exe" 60)
        h_dll=$(u16at "$TMP/h-win.exe" $((h_pe + 94)))
        h_ns=$(u16at "$TMP/h-win.exe" $((h_pe + 6)))
        h_wx=0
        h_i=0
        while [ "$h_i" -lt "$h_ns" ]; do
            h_c=$(u32at "$TMP/h-win.exe" $((0x16C + 40 * h_i)))
            if [ $((h_c & 0x20000000)) -ne 0 ] && [ $((h_c & 0x80000000)) -ne 0 ]; then h_wx=1; fi
            h_i=$((h_i + 1))
        done
        if [ $((h_dll & 0x60)) -eq 96 ] && [ "$h_ns" -ge 2 ] && [ "$h_wx" -eq 0 ]; then pass; else bad "hardening: PE from ${h_comp##*/}" "DllCharacteristics $h_dll, $h_ns sections, writable code: $h_wx"; fi
    done

    say ''
    say 'smoke tests'
    run "$ROOT" lex 'no such file.envol'
    if [ "$rc" -eq 1 ] && grep -q "^envoc: error: cannot open 'no such file.envol'" "$TMP/err"; then pass; else bad 'missing file' "exit $rc"; fi
    # Paths are UTF-8 on every OS: a name with a space, a Latin, a CJK and a non-BMP character.
    uname=$(printf 'u\303\274nicode \346\227\245\360\237\230\200.envol')
    printf 'print("hi")\n' > "$TMP/$uname"
    run "$TMP" lex "$uname"
    if [ "$rc" -eq 0 ] && head -n 1 "$TMP/out" | grep -q '^1:1 n ident print'; then pass; else bad 'unicode path' "exit $rc: $(cat "$TMP/err")"; fi
    # Cross-compilation: this host builds the other OS's executable (it can only check the header).
    printf 'print("hi")
' > "$TMP/cross.envol"
    case "$EXE" in
        *.exe) other=x86_64-linux; magic='7f454c46' ;;
        *) other=x86_64-windows; magic='4d5a' ;;
    esac
    run "$TMP" build cross.envol -o cross-out --target "$other"
    got=$(od -A n -t x1 -N 4 "$TMP/cross-out" 2>/dev/null | tr -d ' \n')
    case "$got" in "$magic"*) pass ;; *) bad "cross build ($other)" "exit $rc, header $got" ;; esac

    # Programs compiled and run: `// expect:` stdout lines, `// expect-exit: N`,
    # `// expect-panic: <reason>` (exit 101 and "panic: <reason>" on stderr).
    for compiler in envoc; do
        rundir="$ROOT/build/run-$compiler"
        mkdir -p "$rundir"
        run_suites="core-run s1-run s2-run"
        for suite in $run_suites; do
        say "run tests ($compiler): tests/spec/$suite"
        for f in "$ROOT"/tests/spec/$suite/*.envol; do
            base=$(basename "$f" .envol)
            name="$compiler spec/$suite/$base.envol"
            sed -n 's|^// expect: \(.*\)$|\1|p' "$f" | tr -d '\r' > "$TMP/expected"
            want_code=$(sed -n 's|^// expect-exit: \([0-9]*\).*|\1|p' "$f" | head -n 1)
            panic=$(sed -n 's|^// expect-panic: \(.*\)$|\1|p' "$f" | tr -d '\r' | head -n 1)
            [ -n "$want_code" ] || want_code=0
            [ -z "$panic" ] || want_code=101
            program="$rundir/$base"
            case "$EXE" in *.exe) program="$program.exe" ;; esac
            run "$rundir" build "$f" -o "$program"
            if [ "$rc" -ne 0 ]; then bad "$name" "build failed: $(cat "$TMP/err")"; continue; fi
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

        # Multi-file programs: one folder per test. main.envol is the entry file and holds
        # the annotations; the other .envol files follow in name order. Either
        # `// expect-error: E#### @ <file>:L:C` (envoc check) or `// expect:` lines (build, run).
        # Envo-S1 programs of several files (tests/spec/s1-multi) under Stages 1 and 2 only.
        multi_suites="core-multi s1-multi"
        for msuite in $multi_suites; do
        say "multi-file tests ($compiler): tests/spec/$msuite"
        for d in "$ROOT"/tests/spec/$msuite/*/; do
            d=${d%/}
            base=$(basename "$d")
            name="$compiler spec/$msuite/$base"
            set -- main.envol
            for f in "$d"/*.envol; do
                f=$(basename "$f")
                [ "$f" = main.envol ] || set -- "$@" "$f"
            done
            line=$(grep -m1 '^// expect-error: ' "$d/main.envol" | tr -d '\r' || true)
            if [ -n "$line" ]; then
                code=$(printf '%s\n' "$line" | sed 's|^// expect-error: \(E[0-9]*\) @ .*|\1|')
                want="${line##* @ }: error[$code]"
                run "$d" check "$@"
                if [ "$rc" -eq 1 ] && grep -q -F "$want" "$TMP/err"; then pass
                else bad "$name" "expected exit 1 with '$want'; got exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
                continue
            fi
            sed -n 's|^// expect: \(.*\)$|\1|p' "$d/main.envol" | tr -d '\r' > "$TMP/expected"
            program="$rundir/$msuite-$base"
            case "$EXE" in *.exe) program="$program.exe" ;; esac
            run "$d" build "$@" -o "$program"
            if [ "$rc" -ne 0 ]; then bad "$name" "build failed: $(cat "$TMP/err")"; continue; fi
            if [ "$compiler" = envoc ]; then
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

    EXE=$envoc2

    # The runtime and prelude compiled into every program (compiler/driver/runtime*.envol)
    # must be generated from the current sources in compiler/runtime.
    say 'embedded runtime: compiler/driver/runtime*.envol'
    run "$ROOT" embed compiler/runtime/common.envol compiler/runtime/linux.envol compiler/runtime/windows.envol compiler/runtime/prelude.envol
    tr -d '\r' < "$ROOT/compiler/driver/runtime.envol" > "$TMP/expected"
    tr -d '\r' < "$TMP/out" > "$TMP/actual"
    if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
    else bad 'embedded runtime' "compiler/driver/runtime.envol is stale: regenerate it with envoc embed compiler/runtime/common.envol compiler/runtime/linux.envol compiler/runtime/windows.envol compiler/runtime/prelude.envol"; fi
    for unit in wasm:WASM:wasm linux_aarch64:A64:a64 macos_aarch64:MACOS:macos; do
        rsrc=${unit%%:*}; rest=${unit#*:}; rname=${rest%%:*}; rout=${rest#*:}
        run "$ROOT" embed "compiler/runtime/$rsrc.envol"
        tr -d '\r' < "$ROOT/compiler/driver/runtime_$rout.envol" > "$TMP/expected"
        tr -d '\r' < "$TMP/out" | sed "s/^const str RUNTIME_0 = /const str RUNTIME_$rname = /" > "$TMP/actual"
        if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
        else bad "embedded runtime ($rsrc)" "compiler/driver/runtime_$rout.envol is stale: regenerate it with envoc embed compiler/runtime/$rsrc.envol, renaming RUNTIME_0 to RUNTIME_$rname"; fi
    done

    say ''
    say 'compiler smoke tests'
    run "$ROOT" version
    if [ "$rc" -eq 0 ] && grep -q '^envoc ' "$TMP/out"; then pass; else bad 'envoc version' "exit $rc"; fi
    run "$ROOT" selftest
    if [ "$rc" -eq 0 ] && grep -q '^selftest: ok' "$TMP/out"; then pass; else bad 'envoc selftest' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    run "$ROOT"
    if [ "$rc" -eq 2 ] && grep -q '^usage: envoc' "$TMP/err"; then pass; else bad 'envoc no arguments' "exit $rc"; fi
    run "$ROOT" frobnicate
    if [ "$rc" -eq 2 ] && grep -q "^envoc: error: unknown command 'frobnicate'" "$TMP/err"; then pass; else bad 'envoc unknown command' "exit $rc"; fi

    # The front end and checker: the lexer, parser and checker goldens and the lexical,
    # syntax, type and ownership spec tests, in --core (Envo-Core) and in full mode.
    for suite in lexer:lex:.tokens:both parser:parse:.ast:both s1-parser:parse:.ast:s1 check:check:.check:both; do
      sdir=${suite%%:*}; rest=${suite#*:}; cmd=${rest%%:*}; rest=${rest#*:}; ext=${rest%%:*}; modes=${rest#*:}
      for mode in --core s1; do
        [ "$modes" = s1 ] && [ "$mode" = --core ] && continue
        if [ "$mode" = --core ]; then set -- --core; else set --; fi
        say "golden tests ($mode): tests/golden/$sdir"
        dir="$ROOT/tests/golden/$sdir"
        for f in "$dir"/*.envol; do
            base=$(basename "$f")
            name="$mode golden/$sdir/$base"
            run "$dir" "$@" "$cmd" "$base"
            if [ "$rc" -ne 0 ]; then bad "$name" "exit $rc: $(tr -d '\r' < "$TMP/err")"; continue; fi
            tr -d '\r' < "${f%.envol}$ext" > "$TMP/expected"
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
        say "spec tests ($mode): tests/spec/$sdir"
        dir="$ROOT/tests/spec/$sdir"
        for f in "$dir"/*.envol; do
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
            else bad "$mode spec/$sdir/$base" "expected exit 1 with '$want'; got exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
        done
      done
    done
    # EIR (M3.6): the same goldens and verifier errors as Stage 1.
    say 'golden tests: tests/golden/eir'
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
        # the binary form (M3.7): text -> binary -> text, and binary -> binary
        run "$dir" eir-check "$base" -o "$TMP/1.eirb"
        [ "$rc" -eq 0 ] && run "$dir" eir-check "$TMP/1.eirb"
        tr -d '\r' < "$TMP/out" > "$TMP/actual"
        [ "$rc" -eq 0 ] && run "$dir" eir-check "$TMP/1.eirb" -o "$TMP/2.eirb"
        if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual" && cmp -s "$TMP/1.eirb" "$TMP/2.eirb"; then pass
        else bad "golden/eir/$base (binary)" "exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
    done
    # -O2's EIR passes (M3.8)
    say 'golden tests: tests/golden/opt'
    dir="$ROOT/tests/golden/opt"
    for f in "$dir"/*.eir; do
        base=$(basename "$f")
        tr -d '\r' < "${f%.eir}.out" > "$TMP/expected"
        run "$dir" eir-check "$base" -O2
        tr -d '\r' < "$TMP/out" > "$TMP/actual"
        if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass
        else bad "golden/opt/$base" "exit $rc: $(tr -d '\r' < "$TMP/err")"; diff "$TMP/expected" "$TMP/actual" | head -n 10 || true; fi
    done
    say 'spec tests: tests/spec/eir'
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
    # The standard platform and the examples (PLAN D29): `envo test` builds and runs each
    # library test, adapter test and conformance suite (the suites against the reference
    # and the native adapters) at -O0 and -O2, and builds each example package. Keep in
    # step with build.ps1.
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
    # The examples: each runs, as a script and natively, and prints its output.txt
    # (run.args: what the script needs allowed)
    say 'examples: each one, as a script and natively, against its output.txt'
    for d in "$ROOT"/examples/*/; do
        [ -f "$d/output.txt" ] || continue
        extra=$(tr -d '\r' < "$d/run.args" 2>/dev/null || true)
        for mode in script native; do
            set +e
            if [ "$mode" = script ]; then
                # shellcheck disable=SC2086
                (cd "$d" && "$envo" run $extra .) > "$TMP/out" 2> "$TMP/err"
            else
                (cd "$d" && "$envo" run --native .) > "$TMP/out" 2> "$TMP/err"
            fi
            rc=$?
            set -e
            tr -d '\r' < "$TMP/out" > "$TMP/actual"
            if [ "$rc" -eq 0 ] && cmp -s "$TMP/actual" "$d/output.txt"; then pass
            else bad "example $(basename "$d") ($mode)" "exit $rc: $(head -c 300 "$TMP/err")"; diff "$d/output.txt" "$TMP/actual" | head -n 5 || true; fi
        done
    done
    # The script runtime (PLAN D35): every spec run program, and every multi-file one, runs
    # in the VM (`envo run -A`) with the output, exit code and panic it has natively.
    say 'script runtime: tests/spec/core-run, s1-run, s2-run and the multi-file programs in the VM'
    vmdir="$ROOT/build/run-vm"
    mkdir -p "$vmdir"
    for suite in core-run s1-run s2-run; do
        for f in "$ROOT"/tests/spec/$suite/*.envol; do
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
            grep -q '^// expect-error: ' "$d/main.envol" && continue
            set -- main.envol
            for f in "$d"/*.envol; do
                f=$(basename "$f")
                [ "$f" = main.envol ] || set -- "$@" "$f"
            done
            sed -n 's|^// expect: \(.*\)$|\1|p' "$d/main.envol" | tr -d '\r' > "$TMP/expected"
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
    cp "$ROOT"/tests/sandbox/*.envol "$boxdir"/
    for f in "$boxdir"/*.envol; do
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
        printf '#!/usr/bin/env envo\nuse std.env;\nList<str> all = env.Args();\nforeach (var a in all.AsSlice()) print(a);\n' > "$boxdir/args.envol"
        chmod +x "$boxdir/args.envol"
        set +e
        (cd "$boxdir" && PATH="$ROOT/build/envo:$PATH" ./args.envol one 'two words') > "$TMP/out" 2> "$TMP/err"
        rc=$?
        set -e
        printf 'one\ntwo words\n' > "$TMP/expected"
        if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/out"; then pass; else bad 'shebang script' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    fi
    # The TLS 1.3 client against openssl s_server (tests/tls/README.md), where openssl is
    # installed
    if command -v openssl > /dev/null 2>&1; then
        say 'tls: tests/tls/client.envol against openssl s_server'
        tdir="$ROOT/build/run-tls"
        rm -rf "$tdir"
        mkdir -p "$tdir"
        tls_ok=1
        (
            cd "$tdir"
            export MSYS_NO_PATHCONV=1
            openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout ca.key -out ca.pem -days 30 -subj "/CN=EnvoL Test CA" -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign" &&
            openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout other.key -out other.pem -days 30 -subj "/CN=Other CA" &&
            printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\nbasicConstraints=CA:FALSE\n' > leaf.ext &&
            openssl req -newkey rsa:2048 -nodes -keyout rsa.key -out rsa.csr -subj "/CN=localhost" &&
            openssl x509 -req -in rsa.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out rsa.pem -days 30 -sha256 -extfile leaf.ext &&
            openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout ec.key -out ec.csr -subj "/CN=localhost" &&
            openssl x509 -req -in ec.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out ec.pem -days 30 -sha256 -extfile leaf.ext
        ) > "$TMP/out" 2>&1 || tls_ok=0
        if [ "$tls_ok" -eq 0 ]; then bad 'tls certificates' "$(cat "$TMP/out")"; else
            EXE=$envoc2
            run "$tdir" build --lib "$ROOT" "$ROOT/tests/tls/client.envol" -o "$tdir/client$(host_suffix)"
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
    # AArch64 Linux (M10, PLAN D69): programs build as AArch64 ELF executables, with and
    # without the library; CI runs the run and library tests on an arm64 machine
    # (build.sh cross, cross-run)
    run "$ROOT" build "$ROOT/examples/00-hello/main.envol" --lib "$ROOT" -o "$TMP/hello-a64" --target aarch64-linux
    if [ "$rc" -eq 0 ] && [ "$(od -A n -t x1 -j 16 -N 4 "$TMP/hello-a64" | tr -d ' \n')" = "0300b700" ]; then pass; else bad 'aarch64-linux build' "exit $rc: $(cat "$TMP/err")"; fi
    # envo's own commands: new, run, test, check, explain, version (tests/envo/README.md)
    say 'envo commands: new, run, test, check, explain, version, prof, fuzz, dbg, packages'
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
    printf 'i32 x = ;\n' > "$erun/bad.envol"
    envo_do check bad.envol
    if [ "$rc" -eq 1 ] && grep -q -F 'bad.envol:1:9: error[E0101]' "$TMP/err" && grep -q -F '1 | i32 x = ;' "$TMP/err" && grep -q -F 'envo explain E0101' "$TMP/err"; then pass; else bad 'envo check' "exit $rc: $(cat "$TMP/err")"; fi
    envo_do explain E0004
    if [ "$rc" -eq 0 ] && grep -q -F 'E0004: unterminated string literal' "$TMP/out" && grep -q -F '[lex.str.1]' "$TMP/out"; then pass; else bad 'envo explain' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    envo_do explain E9999
    if [ "$rc" -eq 1 ]; then pass; else bad 'envo explain (unknown)' "exit $rc"; fi
    envo_do version
    if [ "$rc" -eq 0 ] && grep -q '^envo ' "$TMP/out"; then pass; else bad 'envo version' "exit $rc"; fi
    # envo prof: exact counts (tests/envo/prof); envo fuzz: finds a 4-byte magic input
    cp "$ROOT/tests/envo/prof/hot.envol" "$ROOT/tests/envo/fuzz/magic.envol" "$erun/"
    envo_do prof hot.envol
    if [ "$rc" -eq 0 ] && [ "$(tr -d '\r' < "$TMP/out")" = 'ok' ] && grep -q -E '^ +177 +[0-9]+ +[0-9.]+  Fib$' "$TMP/err" && grep -q -E '^ +10 +[0-9]+ +[0-9.]+  Square$' "$TMP/err"; then pass; else bad 'envo prof' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    envo_do fuzz magic.envol --runs 50000 --seed 1
    if [ "$rc" -eq 1 ] && grep -q '^crash: ' "$TMP/out" && grep -q 'panic: found the magic input' "$TMP/err" && [ -f "$erun/build/fuzz/magic/crash" ]; then pass; else bad 'envo fuzz' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    # envo dbg: a scripted session (tests/envo/dbg) gives the expected transcript
    cp "$ROOT/tests/envo/dbg/sum.envol" "$erun/"
    set +e
    (cd "$erun" && "$envo" dbg sum.envol) < "$ROOT/tests/envo/dbg/session.txt" > "$TMP/out" 2> "$TMP/err"
    rc=$?
    set -e
    tr -d '\r' < "$TMP/out" > "$TMP/actual"
    tr -d '\r' < "$ROOT/tests/envo/dbg/expected.txt" > "$TMP/expected"
    if [ "$rc" -eq 0 ] && cmp -s "$TMP/expected" "$TMP/actual"; then pass; else bad 'envo dbg' "exit $rc: $(diff "$TMP/expected" "$TMP/actual" | head -n 10) $(cat "$TMP/err")"; fi
    # packages (PLAN D66; tests/envo/pkg): a path dependency; a signed archive in a folder
    # registry, fetched into a lock; a changed archive and an untrusted key refused
    rm -rf "$erun/pk"
    cp -r "$ROOT/tests/envo/pkg" "$erun/pk"
    envo_do run pk/app
    if [ "$rc" -eq 0 ] && [ "$(tr -d '\r' < "$TMP/out")" = 'Hello, app!' ]; then pass; else bad 'packages: a path dependency' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    # a git dependency, by commit: pk/greet as a repository of its own (where git is installed)
    if command -v git >/dev/null 2>&1; then
        rm -rf "$erun/pk/greet-git" "$erun/pk/appg"
        cp -r "$erun/pk/greet" "$erun/pk/greet-git"
        git -C "$erun/pk/greet-git" init -q && git -C "$erun/pk/greet-git" add -A \
            && git -C "$erun/pk/greet-git" -c user.name=t -c user.email=t@t commit -q -m greet
        grev=$(git -C "$erun/pk/greet-git" rev-parse HEAD)
        gurl=$(cd "$erun/pk/greet-git" && (pwd -W 2>/dev/null || pwd))     # C:/... on Git Bash
        mkdir -p "$erun/pk/appg"
        printf '#eon 1\npackage {\n    name = "appg"\n}\ndependencies {\n    greet = { git = "%s", rev = "%s" }\n}\n' "$gurl" "$grev" > "$erun/pk/appg/envo.envon"
        printf 'use greet;\nprint(greet.Hello("appg").AsStr());\n' > "$erun/pk/appg/main.envol"
        envo_do run pk/appg
        if [ "$rc" -eq 0 ] && [ "$(tr -d '\r' < "$TMP/out")" = 'Hello, appg!' ] && [ -f "$erun/pk/appg/build/deps/greet-$grev/envo.envon" ]; then pass; else bad 'packages: a git dependency' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    fi
    envo_do key pk/publisher.key
    pub=$(sed -n 's/^public key //p' "$TMP/out" | tr -d '\r')
    envo_do key pk/other.key
    other=$(sed -n 's/^public key //p' "$TMP/out" | tr -d '\r')
    sed "s/KEY/$pub/" "$erun/pk/app2/envo.envon" > "$TMP/m" && cp "$TMP/m" "$erun/pk/app2/envo.envon"
    sed "s/KEY/$other/" "$erun/pk/app3/envo.envon" > "$TMP/m" && cp "$TMP/m" "$erun/pk/app3/envo.envon"
    envo_do publish pk/greet --registry pk/reg --key pk/publisher.key
    prc=$rc
    envo_do publish pk/greet --registry pk/reg
    if [ "$prc" -eq 0 ] && [ "$rc" -eq 1 ] && [ -f "$erun/pk/reg/greet/1.0.0.envopkg" ] && [ -f "$erun/pk/reg/greet/1.0.0.sig" ]; then pass; else bad 'packages: envo publish (once per version)' "exit $prc, then $rc: $(cat "$TMP/err")"; fi
    envo_do run pk/app2
    urc=$rc
    envo_do fetch pk/app2
    frc=$rc
    envo_do run pk/app2
    if [ "$urc" -eq 1 ] && [ "$frc" -eq 0 ] && [ -f "$erun/pk/app2/envo.lock.envon" ] && [ "$rc" -eq 0 ] && [ "$(tr -d '\r' < "$TMP/out")" = 'Hello, app2!' ]; then pass; else bad 'packages: envo fetch, the lock, a registry dependency' "exit $urc, $frc, $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    envo_do fetch pk/app3
    if [ "$rc" -eq 1 ] && grep -q 'no signature by a trusted key' "$TMP/err"; then pass; else bad 'packages: an untrusted signature' "exit $rc: $(cat "$TMP/err")"; fi
    printf ' ' >> "$erun/pk/reg/greet/1.0.0.envopkg"
    envo_do run pk/app2
    if [ "$rc" -eq 1 ] && grep -q 'the registry.s copy changed' "$TMP/err"; then pass; else bad 'packages: a changed archive' "exit $rc: $(cat "$TMP/err")"; fi
    # envo build --sbom: an SPDX 2.3 SBOM beside the program, the same for the same build
    SOURCE_DATE_EPOCH=1762905600 envo_do build --sbom pk/app
    sb="$erun/pk/app/build/app$(host_suffix).spdx.json"
    if [ "$rc" -eq 0 ] && [ -f "$sb" ] && grep -q '"spdxVersion": *"SPDX-2.3"' "$sb" && grep -q '"name": *"greet"' "$sb" && grep -q '2025-11-12T00:00:00Z' "$sb"; then pass; else bad 'envo build --sbom' "exit $rc: $(cat "$TMP/err")"; fi
    # releases (https://github.com/envoscale/EnvoScale/blob/main/guides/offline-install.md): envo archive gives the same bytes on every
    # OS (the digest is pinned in both scripts); envo sign and envo verify
    REL_TAR_SHA=b54a3aa9ab43038969bf16347b53b6940e813f9889ab3be0e0f29c6ef9b11ee1
    SOURCE_DATE_EPOCH=1762905600 envo_do archive pk/greet pk/greet.tar
    if [ "$rc" -eq 0 ] && [ "$(sha256 "$erun/pk/greet.tar")" = "$REL_TAR_SHA" ]; then pass; else bad 'envo archive (reproducible)' "exit $rc: $(sha256 "$erun/pk/greet.tar") $(cat "$TMP/err")"; fi
    envo_do sign pk/greet.tar --key pk/publisher.key
    src=$rc
    envo_do verify pk/greet.tar --key "$pub"
    vrc=$rc
    envo_do verify pk/greet.tar --key "$other"
    if [ "$src" -eq 0 ] && [ "$vrc" -eq 0 ] && [ "$rc" -eq 1 ]; then pass; else bad 'envo sign, envo verify' "exit $src, $vrc, $rc: $(cat "$TMP/err")"; fi
    # fuzz targets (tests/fuzz): each parser of untrusted input takes a few hundred fuzzed
    # inputs without a panic
    say 'fuzz targets: tests/fuzz, 300 runs each'
    frun="$ROOT/build/run-fuzz"
    rm -rf "$frun"
    mkdir -p "$frun"
    for t in "$ROOT"/tests/fuzz/*.envol; do
        n=$(basename "$t" .envol)
        cp -r "$ROOT/tests/fuzz/corpus/$n" "$frun/corpus-$n"
        set +e
        (cd "$frun" && "$envo" fuzz "$t" --runs 300 --seed 1 --corpus "corpus-$n" --max-len 1024) > "$TMP/out" 2> "$TMP/err"
        rc=$?
        set -e
        if [ "$rc" -eq 0 ] && grep -q '^no crash' "$TMP/out"; then pass; else bad "fuzz $n" "exit $rc: $(head -n 5 "$TMP/out") $(head -n 5 "$TMP/err")"; fi
    done
    # envo repl: cells piped in; each cell's output shows once, a bad cell shows its error
    set +e
    printf 'print("hello")\ni32 Twice(i32 x) {\n    return x * 2;\n}\nuse alloc.text;\nprint(text.Int(Twice(21) as i64).AsStr())\nu8 bad = nope;\n:quit\n' | (cd "$erun" && "$envo" repl) > "$TMP/out" 2> "$TMP/err"
    rc=$?
    set -e
    hellos=$(grep -o hello "$TMP/out" | wc -l | tr -d ' ')
    if [ "$rc" -eq 0 ] && [ "$hellos" -eq 1 ] && grep -q '> 42$' "$TMP/out" && grep -q -F 'error[E0203]' "$TMP/out"; then pass; else bad 'envo repl' "exit $rc: $(cat "$TMP/out" "$TMP/err")"; fi
    envo_do frobnicate
    if [ "$rc" -eq 2 ]; then pass; else bad 'envo (unknown command)' "exit $rc"; fi
    # envo fmt: each tests/golden/fmt/name.envol formats to name.expected, which formats to
    # itself; and the repository's own code is already in the canonical layout
    say 'envo fmt: tests/golden/fmt, and --check on the code'
    for f in "$ROOT"/tests/golden/fmt/*.envol; do
        expected="${f%.envol}.expected"
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
    (cd "$ROOT" && "$envo" fmt --check lib adapters tools tests/conformance compiler runtime examples) > "$TMP/out" 2> "$TMP/err"
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then pass; else bad 'envo fmt --check (run envo fmt on these files)' "$(cat "$TMP/out" "$TMP/err")"; fi
    # envo lsp: tests/lsp/session.jsonl, framed, piped in; the bodies it writes back must
    # be tests/lsp/expected.jsonl (tests/lsp/README.md)
    say 'envo lsp: tests/lsp/session.jsonl'
    lspdir="$ROOT/build/run-lsp"
    mkdir -p "$lspdir"
    # Git Bash on Windows: the URI needs the Windows form of the path (C:/...)
    if command -v cygpath > /dev/null 2>&1; then uri="file:///$(cygpath -m "$lspdir")/doc.envol"
    else uri="file://$lspdir/doc.envol"; fi
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
    say 'spec tests: tests/spec/lib'
    dir="$ROOT/tests/spec/lib"
    for f in "$dir"/*.envol; do
        base=$(basename "$f")
        line=$(grep -m1 '^// expect-error: ' "$f" | tr -d '\r' || true)
        code=$(printf '%s\n' "$line" | sed 's|^// expect-error: \(E[0-9]*\) @ .*|\1|')
        where=${line##* @ }
        case "$where" in
            *.envol:*) want="$where: error[$code]" ;;
            *) want="$base:$where: error[$code]" ;;
        esac
        libroot="$ROOT"
        if grep -q '^// lib: root' "$f"; then libroot=root; fi
        run "$dir" check --lib "$libroot" "$base"
        if [ "$rc" -eq 1 ] && grep -q -F "$want" "$TMP/err"; then pass
        else bad "spec/lib/$base" "expected exit 1 with '$want'; got exit $rc: $(tr -d '\r' < "$TMP/err")"; fi
    done
    # The compiler builds itself into the same bytes (the fixed point), and through an
    # object of itself, compiled and linked
    say 'fixed point: build/envoc builds itself into the same bytes'
    selfdir="$ROOT/build/run-envoc"
    mkdir -p "$selfdir"
    set -- $(compiler_files)
    for unit in "x86_64-linux:envoc" "x86_64-windows:envoc.exe"; do
        target=${unit%%:*}
        out=${unit#*:}
        run "$STAGE2" build -O2 "$@" -o "$selfdir/self-$out" --target "$target"
        if [ "$rc" -eq 0 ] && cmp -s "$selfdir/self-$out" "$BUILD2/$out"; then pass
        else bad "fixed point ($target)" "exit $rc, or build/envoc/$out builds itself into different bytes: $(head -c 300 "$TMP/err")"; fi
    done
    run "$STAGE2" compile -O2 "$@" -o "$selfdir/self.eo"
    [ "$rc" -eq 0 ] && run "$STAGE2" link -O2 "$selfdir/self.eo" -o "$selfdir/self-linked"
    if [ "$rc" -eq 0 ] && cmp -s "$selfdir/self-linked" "$BUILD2/envoc$(host_suffix)"; then pass
    else bad 'compile and link the compiler' "exit $rc, or the executable differs from build/envoc"; fi
    rundir="$ROOT/build/run-envoc"

    run "$ROOT" link "$selfdir/core-multi-program$(host_suffix).0.eo" -o "$selfdir/none"
    if [ "$rc" -eq 1 ] && grep -q 'no object defines @' "$TMP/err"; then pass; else bad 'link with a unit missing' "exit $rc: $(cat "$TMP/err")"; fi
    run "$ROOT" link "$selfdir/core-multi-program$(host_suffix).0.eo" "$selfdir/s1-multi-namespaces$(host_suffix).0.eo" -o "$selfdir/none"
    if [ "$rc" -eq 1 ] && grep -q 'compiled from different programs' "$TMP/err"; then pass; else bad 'link of two programs' "exit $rc: $(cat "$TMP/err")"; fi
    printf 'EIR\000\002\000' > "$selfdir/v2.eo"
    run "$ROOT" link "$selfdir/v2.eo" -o "$selfdir/none"
    if [ "$rc" -eq 1 ] && grep -q 'binary EIR version 2; this envoc reads version 1' "$TMP/err"; then pass; else bad 'link of an unknown version' "exit $rc: $(cat "$TMP/err")"; fi

    say ''
    say "$passed passed, $failed failed"
    [ "$failed" -eq 0 ] || exit 1
}

do_check() {
    problems=0
    problem() { printf 'check: %s\n' "$*" >&2; problems=$((problems + 1)); }

    for f in README.md LICENSE CONTRIBUTING.md build.sh build.ps1 spec/README.md spec/errors.md \
             NOTICE; do
        [ -f "$ROOT/$f" ] || problem "missing file: $f"
    done

    # The principles (project/principles.md in the docs): lib/** never imports adapters/**.
    hits=$(find "$ROOT/lib" -name '*.envol' -exec grep -n -E '^[[:space:]]*(use|using)[[:space:]]+adapters([^A-Za-z0-9_]|$)' /dev/null {} + 2>/dev/null || true)
    [ -z "$hits" ] || problem "lib imports an adapter: $hits"


    [ "$problems" -eq 0 ] || fail "$problems problem(s)"
    say "check: ok (no lib->adapters imports)"
}

# ------------------------------------------------------------------- compare
# compare <dir-a> <dir-b>: both builds (each a copy of build/) must be byte-identical.
do_compare() {
    [ "$#" -eq 2 ] || fail "usage: ./build.sh compare <dir-a> <dir-b>"
    differ=0
    files='envoc/envoc envoc/envoc.exe envo/envo envo/envo.exe'
    # after `dist`, the release archive's digest (https://github.com/envoscale/EnvoScale/blob/main/guides/offline-install.md)
    [ -f "$1/dist/SHA256SUMS" ] && files="$files dist/SHA256SUMS"
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

# ------------------------------------------------------------------- dist
# dist: the release archive (https://github.com/envoscale/EnvoScale/blob/main/guides/offline-install.md): build/dist/envoscale-<v>.tar
# with bin/ (envo and envoc for both OSes), lib/, adapters/, spec/, LICENSE and NOTICE, packed
# reproducibly by `envo archive`, and SHA256SUMS. Signing it is the release manager's step
# (`envo sign`), with the project's key.
# provenance <version> <sha256> <command>: an in-toto statement (SLSA provenance v1) of how
# the archive was built: the source commit, the command, the build time, and the digests of
# the compilers that built it. Unsigned; the release manager signs it with `envo sign`.
provenance() {
    commit=${GITHUB_SHA:-$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)}
    builder=local
    [ -n "${GITHUB_RUN_ID:-}" ] && builder="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
    printf '{\n'
    printf '  "_type": "https://in-toto.io/Statement/v1",\n'
    printf '  "subject": [{"name": "envoscale-%s.tar", "digest": {"sha256": "%s"}}],\n' "$1" "$2"
    printf '  "predicateType": "https://slsa.dev/provenance/v1",\n'
    printf '  "predicate": {\n'
    printf '    "buildDefinition": {\n'
    printf '      "buildType": "https://github.com/envoscale/EnvoScale/blob/main/guides/offline-install.md#provenance",\n'
    printf '      "externalParameters": {"command": "%s", "SOURCE_DATE_EPOCH": "0"},\n' "$3"
    printf '      "resolvedDependencies": [{"uri": "git+https://github.com/envoscale/EnvoLang", "digest": {"gitCommit": "%s"}}]\n' "$commit"
    printf '    },\n'
    printf '    "runDetails": {\n'
    printf '      "builder": {"id": "%s"},\n' "$builder"
    printf '      "byproducts": [\n'
    printf '        {"name": "seed %s", "digest": {"sha256": "%s"}},\n' "$SEED_TAG" "$(sha256 "$(seed)")"
    printf '        {"name": "envoc%s", "digest": {"sha256": "%s"}}\n' "$(host_suffix)" "$(sha256 "$BUILD2/envoc$(host_suffix)")"
    printf '      ]\n'
    printf '    }\n'
    printf '  }\n'
    printf '}\n'
}

do_dist() {
    do_build
    v=$(sed -n 's/^const str ENVO_VERSION = "\(.*\)";.*/\1/p' "$ROOT/tools/envo/main.envol" | tr -d '\r')
    dist="$ROOT/build/dist"
    rm -rf "$dist"
    mkdir -p "$dist/envoscale-$v/bin"
    cp "$ROOT/build/envo/envo" "$ROOT/build/envo/envo.exe" "$BUILD2/envoc" "$BUILD2/envoc.exe" "$dist/envoscale-$v/bin/"
    cp -r "$ROOT/lib" "$ROOT/adapters" "$ROOT/spec" "$dist/envoscale-$v/"
    cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$ROOT/README.md" "$dist/envoscale-$v/"
    (cd "$dist" && SOURCE_DATE_EPOCH=0 "$ROOT/build/envo/envo$(host_suffix)" archive "envoscale-$v" "envoscale-$v.tar") || fail "envo archive failed"
    (cd "$dist" && printf '%s  %s\n' "$(sha256 "envoscale-$v.tar")" "envoscale-$v.tar" > SHA256SUMS)
    provenance "$v" "$(sha256 "$dist/envoscale-$v.tar")" "build.sh dist" > "$dist/envoscale-$v.provenance.json"
    say "dist      build/dist/envoscale-$v.tar"
    say "          sha256 $(sha256 "$dist/envoscale-$v.tar")"
}

# ------------------------------------------------------------------- cross
# cross (M10, PLAN D69, D70): the run programs (tests/spec/core-run, s1-run, s2-run) and
# the library's tests (lib/**/tests) built for aarch64-linux and aarch64-macos at -O0 and
# -O2, each with its expected stdout, exit code and panic message, in build/cross/<target>.
# On Linux the library's tests use the Linux adapter (`// os: none` ones the reference
# adapters); on macOS only the `// os: none` ones are built until the macOS adapters exist.
# cross-run <dir> runs them on such a machine (CI's arm64 Linux and macOS runners) in a
# checkout, which needs no compiler: the library's tests in build/envo-test/run, as
# `envo test` runs them.
cross_target() {
    target=$1
    out="$ROOT/build/cross/$target"
    rm -rf "$out"
    mkdir -p "$out"
    n=0
    for suite in core-run s1-run s2-run; do
        for f in "$ROOT"/tests/spec/$suite/*.envol; do
            base="$suite-$(basename "$f" .envol)"
            sed -n 's|^// expect: \(.*\)$|\1|p' "$f" | tr -d '\r' > "$out/$base.expected"
            code=$(sed -n 's|^// expect-exit: \([0-9]*\).*|\1|p' "$f" | head -n 1)
            panic=$(sed -n 's|^// expect-panic: \(.*\)$|\1|p' "$f" | tr -d '\r' | head -n 1)
            [ -n "$code" ] || code=0
            [ -z "$panic" ] || code=101
            printf '%s\n' "$code" > "$out/$base.exit"
            printf '%s' "$panic" > "$out/$base.panic"
            for o in O0 O2; do
                (cd "$ROOT" && "$BUILD2/envoc$(host_suffix)" build "-$o" "$f" -o "$out/$base-$o" --target "$target") \
                    || fail "building $f for $target (-$o) failed"
            done
            n=$((n + 1))
        done
    done
    for f in "$ROOT"/lib/*/tests/*.envol "$ROOT"/lib/*/*/tests/*.envol "$ROOT"/lib/*/*/*/tests/*.envol; do
        [ -f "$f" ] || continue
        os=$(sed -n 's|^// os: \(.*\)$|\1|p' "$f" | tr -d '\r' | head -n 1)
        [ "$target" = aarch64-macos ] && [ "$os" != none ] && continue
        rel=${f#"$ROOT"/lib/}
        base="lib-$(printf '%s' "${rel%.envol}" | tr '/' '-')"
        sed -n -e 's|^// expect: \(.*\)$|\1|p' -e 's|^// expect:$||p' "$f" | tr -d '\r' > "$out/$base.expected"
        printf '0\n' > "$out/$base.exit"
        printf '' > "$out/$base.panic"
        for o in O0 O2; do
            if [ -n "$os" ]; then
                (cd "$ROOT" && "$BUILD2/envoc$(host_suffix)" build "-$o" --lib "$ROOT" --os "$os" "$f" -o "$out/$base-$o" --target "$target") \
                    || fail "building $f for $target (-$o) failed"
            else
                (cd "$ROOT" && "$BUILD2/envoc$(host_suffix)" build "-$o" --lib "$ROOT" "$f" -o "$out/$base-$o" --target "$target") \
                    || fail "building $f for $target (-$o) failed"
            fi
        done
        n=$((n + 1))
    done
    say "cross     $n programs, at -O0 and -O2, for $target in build/cross/$target"
}

do_cross() {
    do_build
    cross_target aarch64-linux
    cross_target aarch64-macos
}

do_cross_run() {
    [ "$#" -eq 1 ] || fail "usage: ./build.sh cross-run <dir>"
    dir=$(cd "$1" && pwd)
    t=$(mktemp -d)
    passed=0
    failed=0
    for p in "$dir"/*-O0 "$dir"/*-O2; do
        [ -f "$p" ] || continue
        name=${p##*/}
        base=${name%-O?}
        chmod +x "$p"
        rundir=$dir
        case "$base" in lib-*) rundir="$ROOT/build/envo-test/run"; mkdir -p "$rundir" ;; esac
        set +e
        (cd "$rundir" && "$p") > "$t/out" 2> "$t/err"
        rc=$?
        set -e
        want=$(cat "$dir/$base.exit")
        panic=$(cat "$dir/$base.panic")
        if ! cmp -s "$dir/$base.expected" "$t/out"; then
            say "FAIL $name: stdout differs"
            diff "$dir/$base.expected" "$t/out" | head -n 10 || true
            failed=$((failed + 1))
        elif [ "$rc" -ne "$want" ]; then
            say "FAIL $name: exit code $rc, expected $want: $(head -c 300 "$t/err")"
            failed=$((failed + 1))
        elif [ -n "$panic" ] && ! grep -q -F "panic: $panic" "$t/err"; then
            say "FAIL $name: stderr: $(head -c 300 "$t/err")"
            failed=$((failed + 1))
        else
            passed=$((passed + 1))
        fi
    done
    rm -rf "$t"
    say ''
    say "$passed passed, $failed failed"
    [ "$failed" -eq 0 ] || exit 1
}

case "${1:-help}" in
    build) do_build ;;
    test)  do_test ;;
    check) do_check ;;
    dist)  do_dist ;;
    cross) do_cross ;;
    cross-run) shift; do_cross_run "$@" ;;
    compare) shift; do_compare "$@" ;;
    clean) rm -rf "$ROOT/build"; say 'removed build/' ;;
    help|*)
        say 'usage: ./build.sh <build|test|check|dist|cross|cross-run|compare|clean>'
        say '  build      download the seed compiler, then build build/envoc and build/envo'
        say '  test       build, then run every test'
        say '  check      quick repository checks'
        say '  dist       build, then the release archive in build/dist'
        say '  cross      build, then the aarch64 tests in build/cross'
        say '  cross-run <dir>   run those on an aarch64 Linux or macOS machine'
        say '  compare <a> <b>   two builds (copies of build/) must be byte-identical'
        say '  clean      delete build/'
        [ "${1:-help}" = help ] || exit 2 ;;
esac
