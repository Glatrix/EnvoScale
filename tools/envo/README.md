# `tools/envo`

> **Status:** Experimental (M5): `new`, `build`, `run`, `check`, `test`, `fmt`, `lsp`,
> `explain`, `version`. The other commands in [`tools/README.md`](../README.md) come
> later.

The unified `envo` CLI. One binary that holds the compiler (PLAN D26): it is built from
the files in `files.txt` plus `compiler/files.txt` without `driver/main.envo`, by Stage 2
with the library (`envoc build --lib`). `bootstrap.ps1 build` / `bootstrap.sh build`
write it to `build/envo/envo(.exe)`. The compiler is called as a library through
`compiler/driver/build.envo` (`BuildProgram`, `CheckProgram`); a compile error is printed
in the shared format and ends `envo` with exit code 1.

## Commands

| Command | What it does |
|---|---|
| `envo new <name>` | Creates the package `<name>`: `envo.envon`, `main.envo`, `greet.envo`, `tests/greet.envo` |
| `envo build [dir \| file.envo...]` | Builds a package's program to `dir/build/<name>(.exe)`, or the program in the given files (`-O0`/`-O2`, `-o`, `--os none`, `--target`) |
| `envo run [dir \| file.envo...] [-- args]` | Builds, then runs the program with the arguments; exits with its exit code |
| `envo check [dir \| file.envo...]` | Checks names, types and ownership without building |
| `envo test [path...] [-O0] [-v]` | Builds and runs test programs and compares their output with their `// expect:` lines |
| `envo fmt [path...] [--check \| --stdout]` | Lays out `.envo` files in the canonical format (see `fmt.envo`); `--check` lists what would change and exits 1 |
| `envo lsp` | A language server for editors: diagnostics over JSON-RPC ([`tools/lsp`](../lsp/README.md)) |
| `envo explain <code>` | Prints a diagnostic code's entry from `docs/spec/errors.md` and the text of the rules it cites |
| `envo version`, `envo help` | |

Exit codes: 0 success, 1 errors (in the program or its tests), 2 a bad command line.

## Packages (D27)

A package is a folder with an `envo.envon` whose `package` block has a `name`. Its
sources are the `.envo` files in the folder and below it, outside `tests/` and `build/`
and outside folders that are packages themselves. `main.envo`, if there, holds the
program's top-level statements and is compiled first. Each `.envo` file under `tests/`
is a test program, built with the package's sources except `main.envo`.

Without a manifest, `envo build a.envo b.envo` works as `envoc build` does, with the
library resolved by module name (D21).

## Tests

`envo test <path>` finds, under each path:

- packages: the program must build, and each test program must pass;
- any `.envo` file under a `tests/` folder (outside packages): a test program, built on
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
