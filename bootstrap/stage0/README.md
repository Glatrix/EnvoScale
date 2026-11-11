# Stage 0 — `envoc0`

> **Status:** In progress (M1). Platform shims, runtime helpers and the lexer
> (`envoc0 lex`) are written. Parser, checker and x86-64 code generation are next.
> See [`STATUS.md`](../../STATUS.md) for what is tested.

`envoc0` compiles **Envo-Core** ([`docs/spec/envo-core.md`](../../docs/spec/envo-core.md))
to x86-64 executables for Windows (PE) and Linux (ELF). It is written in `.eas`
([`docs/spec/eas.md`](../../docs/spec/eas.md)), a strict subset of NASM syntax, and has
no dependencies beyond the OS.

Goal: **correct, small and auditable, not fast.** Target: under ~15k lines of
heavily commented assembly, single- or two-pass, no optimizer.

## Build and test

From the repository root:

```powershell
.\bootstrap.ps1 build     # Windows
.\bootstrap.ps1 test
```

```sh
./bootstrap.sh build      # Linux
./bootstrap.sh test
```

## Layout

| File | Purpose |
|---|---|
| `envoc0-windows.eas` | Top-level unit for Windows; includes everything below |
| `envoc0-linux.eas` | Top-level unit for Linux |
| `platform/windows.eas` | PE header, kernel32 imports, shim routines, argv parsing, entry |
| `platform/linux.eas` | ELF header, syscall shim routines, entry |
| `src/main.eas` | Command dispatch |
| `src/mem.eas` | Arena allocator and memory helpers |
| `src/io.eas` | Buffered stdout/stderr, decimal output, file reading, exit |
| `src/diag.eas` | Diagnostics with line and column |
| `src/utf8.eas` | UTF-8 validation |
| `src/tokens.eas` | Token kinds and the kind table |
| `src/lexer.eas` | The lexer |

How it fits together, and why it is built this way:
[`docs/architecture/bootstrap.md`](../../docs/architecture/bootstrap.md).

## Usage (today)

```
envoc0 lex <file.envo>     print the token stream
envoc0 version             print the version
envoc0 help                print usage
```
