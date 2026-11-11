# Spec tests

One folder per chapter of [`docs/spec`](../../docs/spec/README.md), plus `hello/` for the
Hello World Gallery. Each test is a `.envo` file whose comments say what must happen:

```envo
// expect: Hello, World!          stdout line (repeat for more lines)
// expect-error: E0004 @ 2:9      compilation fails with this code at this position
```

| Folder | Chapter | Runs today |
|---|---|---|
| `01-lexical/` | 1. Lexical structure | Yes: `expect-error` tests |
| `core-syntax/` | Envo-Core grammar (`envo-core.md` §5.1) | Yes: `expect-error` tests (E01xx, E0905) |
| `core-types/` | Envo-Core names, types, constants (`envo-core.md` §5.2–5.3) | Yes: `expect-error` tests (E02xx, E03xx, E0905) |
| `core-run/` | Envo-Core semantics, run-time checks, built-ins | Yes: compiled with `envoc0 build` and run; `// expect:` stdout lines, `// expect-exit: N`, `// expect-panic: <reason>` |
| `core-multi/` | Programs of several files (`envo-core.md` §4, [item.mod.3]) | Yes: one folder per test; `main.envo` is the entry file and holds `// expect:` lines or `// expect-error: E#### @ <file>:L:C` |
| `s1-syntax/` | Envo-S1 grammar (`envo-s1.md`) | Yes: `expect-error` tests run with `envoc1 parse` (E0101, E0950) |
| `eir/` | EIR text and verifier (`eir.md` §3, §6) | Yes: `.eir` files with `; expect-error: E06xx @ L:C`, run with `envoc1 eir-check` |
| `hello/` | Hello World Gallery (brief §17) | Line-count limits only (`limits.txt`, checked by `bootstrap.* check`); execution as each milestone lands |

All Envo-Core `expect-error` tests run with `envoc0 check`, which lexes and parses first, so
each error is still reported by the stage that owns it. They also run under Stage 1
(`envoc1 --core`), which must report the same code at the same position (PLAN D14).

Files named `*.bin.envo` contain bytes a text editor would mangle (invalid UTF-8, raw
control characters); `.gitattributes` marks them binary.

Every rule in the spec lists the tests that cover it, and every test here exists because
a rule needs it. Once script mode exists (M6), every spec test runs in both AOT and script
mode and the results must match.
