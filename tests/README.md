# Tests

`./build.sh test` runs all of them.

| Folder | What |
|---|---|
| [`spec/`](spec/README.md) | The language: programs that must print something, or fail with a given error |
| [`golden/`](golden/README.md) | Compiler output (tokens, syntax trees, types, IR, formatting) against expected files |
| [`conformance/`](conformance/README.md) | Each port's suite, run against every adapter |
| [`envo/`](envo/README.md) | The `envo` tool's commands, end to end |
| [`lsp/`](lsp/README.md) | A scripted language-server session |
| [`sandbox/`](sandbox/README.md) | Script permissions (`--allow`) |
| [`tls/`](tls/README.md) | The TLS 1.3 client against `openssl s_server`, where OpenSSL is installed |
| [`fuzz/`](fuzz/README.md) | Fuzzing corpora for every parser of untrusted input |
| [`bench/`](bench/README.md) | Benchmarks for the script runtime |

## Annotations

```envo
// expect: Hello, World!          one line of expected output (repeat for more lines)
// expect-exit: 3                 the exit code
// expect-panic: index out of range
// expect-error: E0004 @ 3:9      must fail to compile with this code, at line 3, column 9
```

Columns count Unicode characters from 1, as the compiler's messages do. Every program in
`spec/` runs both compiled and in the script runtime (`envo run`), and both must agree.
