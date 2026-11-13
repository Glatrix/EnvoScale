# `tools/envo`

> **Status:** Experimental (M5, M6): `new`, `build`, `run` (in the script runtime, or
> `--native`), `check`, `test`, `fmt`, `lsp`, `repl`, `explain`, `version`, and scripts
> run directly (`envo file.envol`). The other commands in
> [`tools/README.md`](../README.md) come later.

The unified `envo` CLI. One binary that holds the compiler (PLAN D26): it is built from
the files in `files.txt` plus `compiler/files.txt` without `driver/main.envol`, by Stage 2
with the library (`envoc build --lib`). `build.ps1 build` / `build.sh build`
write it to `build/envo/envo(.exe)`. The compiler is called as a library through
`compiler/driver/build.envol` (`BuildProgram`, `CheckProgram`); a compile error is printed
in the shared format and ends `envo` with exit code 1.

## Commands

| Command | What it does |
|---|---|
| `envo new <name>` | Creates the package `<name>`: `envo.envon`, `main.envol`, `greet.envol`, `tests/greet.envol` |
| `envo build [dir \| file.envol...]` | Builds a package's program to `dir/build/<name>(.exe)`, or the program in the given files (`-O0`/`-O2`, `-o`, `--os none`, `--target`) |
| `envo run [dir \| file.envol...] [--allow …] [--native] [-- args]` | Runs the program in the script runtime, sandboxed ([`script-runtime.md`](https://github.com/envoscale/EnvoScale/blob/main/architecture/script-runtime.md)); `--native` builds and runs native code; exits with the program's exit code |
| `envo [--allow …] file.envol [args]` | Runs a script directly, so `#!/usr/bin/env envo` works |
| `envo check [dir \| file.envol...]` | Checks names, types and ownership without building |
| `envo test [path...] [-O0] [-v]` | Builds and runs test programs and compares their output with their `// expect:` lines |
| `envo fmt [path...] [--check \| --stdout]` | Lays out `.envol` files in the canonical format (see `fmt.envol`); `--check` lists what would change and exits 1 |
| `envo repl [--allow …]` | An interactive session on the script runtime: cells of declarations and statements; each cell's new output shows; `:show`, `:reset`, `:quit` |
| `envo lsp` | A language server for editors: diagnostics over JSON-RPC ([`tools/lsp`](README.md#lsp)) |
| `envo explain <code>` | Prints a diagnostic code's entry from `spec/errors.md` and the text of the rules it cites |
| `envo version`, `envo help` | |

Exit codes: 0 success, 1 errors (in the program or its tests), 2 a bad command line.

## Packages (D27)

A package is a folder with an `envo.envon` whose `package` block has a `name`. Its
sources are the `.envol` files in the folder and below it, outside `tests/` and `build/`
and outside folders that are packages themselves. `main.envol`, if there, holds the
program's top-level statements and is compiled first. Each `.envol` file under `tests/`
is a test program, built with the package's sources except `main.envol`.

Without a manifest, `envo build a.envol b.envol` works as `envoc build` does, with the
library resolved by module name (D21).

## Tests

`envo test <path>` finds, under each path:

- packages: the program must build, and each test program must pass;
- any `.envol` file under a `tests/` folder (outside packages): a test program, built on
  its own with the library.

A test program runs in `build/envo-test/run` and must exit with 0 and print exactly its
`// expect: ` lines. `// os: none` builds it against the reference adapters; programs
under `tests/conformance/` run against both the reference and the native adapters.
Each is built at `-O0` and `-O2` (`-O0` alone with `-O0`). Builds run as child
`envo build` processes, so a program that does not compile fails its test without
stopping the run.

## The library

`envo` finds the folder that holds `lib/` and `adapters/` through `ENVO_HOME`, else by
looking above the `envo` executable, else above the working directory.

## Ports used

FileSystem, Environment and Process (through `std.fs`, `std.env`, `std.process`);
`envo.eon` for manifests.
