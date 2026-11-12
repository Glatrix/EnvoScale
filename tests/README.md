# `tests/`

| Folder | What | Runner today |
|---|---|---|
| [`spec/`](spec/README.md) | One folder per spec chapter; `.envo` files with `// expect:` / `// expect-error:` | `bootstrap.* test` (lexical chapter) |
| [`golden/`](golden/README.md) | Inputs with expected outputs (token dumps, later AST/EIR/asm/diagnostics) | `bootstrap.* test` (lexer) |
| [`conformance/`](conformance/README.md) | Port/adapter conformance suites | `envo test tests/conformance` |
| [`envo/`](envo/README.md) | The `envo` tool's commands, end to end | `bootstrap.* test` |
| [`lsp/`](lsp/README.md) | A scripted language-server session | `bootstrap.* test` |
| [`sandbox/`](sandbox/README.md) | Script permissions (`--allow`) | `bootstrap.* test` |
| [`tls/`](tls/README.md) | The TLS 1.3 client against `openssl s_server` | `bootstrap.* test` |
| [`bootstrap/`](bootstrap/README.md) | Stage equivalence and fixed-point checks | M2/M3 |
| [`diff/`](diff/README.md) | `-O0` vs `-O3`, AOT vs script, GPU adapter vs software | M3+ |
| [`fuzz/`](fuzz/README.md) | Fuzz corpora | M13 |
| [`bench/`](bench/README.md) | Tracked benchmarks | M5 |
| [`vectors/`](vectors/README.md) | Official test vectors with attribution | M7 |

## Annotations

```envo
// expect: Hello, World!          one line of expected stdout (repeat for more lines)
// expect-error: E0004            the program must fail to compile with this code
// expect-error: E0004 @ 3:9      ...reported at line 3, column 9
```

Columns count Unicode scalar values from 1, as in compiler diagnostics.
Every spec run program runs natively and in the script runtime (`envo run`), and both must
agree (PLAN D35).
