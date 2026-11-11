# Stage 1 — `envoc1`

> **Status:** Support library (M2.2), lexer (M2.3) and parser (M2.4) done; names and types
> are next (M2.5). The
> plan, increments and decisions D11–D15 are in [`docs/PLAN.md`](../../docs/PLAN.md). It
> accepts [Envo-S1](../../docs/spec/envo-s1.md) and compiles through
> [EIR v1](../../docs/spec/eir.md).

A fuller compiler written in Envo-Core and built by `envoc0`. It adds generics, interfaces, closures, a basic borrow checker and EIR, which is enough to compile the real compiler in `compiler/`. It stays buildable forever as part of the diverse double-compiling trust check.

## How it is built

`bootstrap/stage1/` is a multi-file Envo-Core program (D11). `envoc0 build` compiles the
files in the order listed in [`files.txt`](files.txt), `main.envo` (the entry file)
first. `bootstrap.ps1 build` and `bootstrap.sh build` do this after assembling Stage 0,
for both operating systems:

```
build/stage1/envoc1.exe    Windows
build/stage1/envoc1        Linux
```

CI checks that the builds made on Linux and on Windows are byte-identical, as for
Stage 0.

## Layout

| File | Contents |
|---|---|
| `main.envo` | entry file: command-line dispatch |
| `driver.envo` | commands: loading sources, `lex` |
| `syntax/tokens.envo` | token kinds and spellings, generated from Stage 0's `tokens.eas` |
| `syntax/lexer.envo` | the lexer, step for step like Stage 0's, plus the `lex` dump |
| `syntax/nodes.envo` | syntax tree node kinds, dump table and token classes (Stage 0's `nodes.eas`) |
| `syntax/parser.envo` | the parser, routine for routine like Stage 0's, plus the `parse` dump |
| `syntax/parser_s1.envo` | the Envo-S1 grammar, reached where Stage 0 reports E0905 |
| `support/mem.envo` | raw memory: copy, zero, compare, loads and stores |
| `support/text.envo` | `str` helpers: equality, prefixes, sub-strings, FNV-1a hashing, number parsing |
| `support/buf.envo` | `Buf`, a growable byte buffer with number formatting |
| `support/vec.envo` | `Vec`, a growable array of fixed-size elements |
| `support/map.envo` | `Map`, a `str` → `u64` hash map |
| `support/io.envo` | process state (`Ctx`), buffered output, files, host detection |
| `support/diag.envo` | source files, positions and diagnostics in `envoc0`'s format |
| `support/selftest.envo` | `envoc1 selftest`: unit tests for the support files |

## Conventions

- **No generics in Core**, so containers (`Vec`, `Map`) store raw bytes or `u64`s and
  callers cast element pointers inside `unsafe`.
- **One static.** All process state lives in a `Ctx` on the heap, reached through
  `TheCtx()`; nothing else uses a static.
- **Memory is never freed.** `alloc` is an arena (`envo-core.md` §6), and so are the
  containers built on it. A compiler run is short, so this is the simplest correct
  choice.
- **Same messages as `envoc0`.** Diagnostics, exit codes and positions match Stage 0, so
  every Envo-Core test can run under both compilers (D14).

## Commands

`envoc1 version`, `help`, `selftest`, `lex` and `parse` (the whole Envo-S1 grammar) work
today. `check`, `build`, `eir` and `eir-check` arrive with increments 2.5–2.7 (Envo-S1 §9).
