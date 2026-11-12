# Tooling: `envo`, packages and the Process port (M5)

> **Status:** M5, in progress. Decisions D26–D30 in [`PLAN.md`](../PLAN.md).

## One binary (D26)

`envo` is built from `tools/envo/` plus `compiler/` without `driver/main.envo`, by Stage 2
with the library (`envoc build --lib <root>`), so it can use `std`, `envo.eon` and the
ports. The compiler's driver functions are in `compiler/driver/build.envo`:

| Function | Used by |
|---|---|
| `BuildProgram(paths, output, target, opt, lib, os, map)` | `envoc build`, `envo build`, `envo run` |
| `CheckProgram(paths, lib, os, target)` | `envo check` |
| `CompileProgram(...)` | `envoc build --core`, `compile`, `eir` |

They are top-level functions, not a namespace, because the embedded runtime and the
library loader they use are. A compile error prints `path:line:col: error[E####]: …`
and ends the process with exit code 1. `envo test` therefore builds each test in a child
`envo build`, so one failure does not end the run.

`envoc` stays: it is the compiler alone, the stage the fixed point checks (D18), and
what the bootstrap scripts test.

## Packages (D27)

A package is a folder with an `envo.envon` holding a `package` block:

```eon
#eon 1
package {
    name    = "demo"
    version = "0.1.0"
    edition = "2027"
}
dependencies {
}
```

- Sources: every `.envo` file in the folder and below it, outside `tests/` and
  `build/` and outside nested packages. `main.envo` comes first and holds the
  program's top-level statements.
- Tests: every `.envo` file under `tests/`, each a program built with the sources
  except `main.envo`.
- Output: `build/<name>` (`.exe` on Windows) inside the package.

Listing a folder uses `FileSystem.List` (entries in byte order, so builds do not depend
on the order the system returns). `dependencies` is read but must be empty until the
package manager (M12); library modules are still found by name under the library root
(D21). The root `envo.envon` is a `workspace`, not a package: `envo test` looks inside
it.

## Running programs (D28)

`ports.IProcess.Run(program, args, workDir, outPath, errPath)` starts a program, waits
for it, and gives its exit code (128 + n for a Linux program ended by signal n). Its
output goes to files when asked: `envo test` captures each test's output that way.

| Adapter | How |
|---|---|
| `os.none` | Scripted: programs known by name echo their arguments; for tests of code that runs programs |
| `os.windows` | `CreateProcessW` with a command line quoted for `CommandLineToArgvW`, inheritable standard handles, `WaitForSingleObject`, `GetExitCodeProcess` |
| `os.linux` | `fork`, `dup2`, `chdir`, `execve` (with the parent's environment from `/proc/self/environ`), `wait4`; PATH lookup as a shell does |

The Windows import table grew to 28 KERNEL32 slots in both Stage 1 and Stage 2, and
`__wincall` takes 10 arguments (`__wincall12` takes 12) ([`library.md`](library.md)). The conformance suite
(`tests/conformance/process`) runs itself as the child, so it needs no other program.

`IEnvironment` gained `Var` (environment variables) and `CurrentDir`, which `envo` uses
to find the library (`ENVO_HOME`) and to give test programs absolute paths.

## The language server (D30)

`envo lsp` speaks the Language Server Protocol's base protocol on standard input and
output, with `envo.json` for the messages. On `didOpen`, `didChange` and `didSave` it
writes the document's text to `build/envo-lsp/<server>/` beside it (a folder of its
own, so two servers on one folder do not collide; removed when it exits), runs `envo check` on that
copy (with the rest of the package, found by walking up to an `envo.envon` with a
`package` block) as a child process, and publishes the first error with its code and
`help:` line, its column converted to UTF-16 units. Running the check in a child keeps
the server alive when the compiler stops at an error. `tests/lsp` replays a session.

## Tests in CI (D29)

The bootstrap scripts build `envo` after Stage 2 and call
`envo test lib adapters tests/conformance examples` in place of their own library loop,
then check `envo`'s commands end to end ([`tests/envo`](../../tests/envo/README.md)).
They still build and test Stages 0–2 without `envo`.
