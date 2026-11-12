# `tests/envo` — the `envo` tool's own tests

> **Status:** M5. Run by `bootstrap.ps1 test` / `bootstrap.sh test` ("envo commands").

The scripts check each `envo` command end to end, in a scratch folder
(`build/run-envo`):

| Check | Passes when |
|---|---|
| `envo new demo` | it exits 0 and writes `demo/envo.envon` |
| `envo run demo` | it prints `Hello, demo!` and exits 0 |
| `envo test demo` | the package builds and its test passes at `-O0` and `-O2` (`3 passed, 0 failed`) |
| `envo check bad.envo` | it exits 1 with `bad.envo:1:9: error[E0101]`, the source line and a pointer to `envo explain` |
| `envo explain E0004` | it prints the registry entry and the text of `[lex.str.1]` |
| `envo explain E9999` | it exits 1 |
| `envo version` | it prints `envo …` |
| an unknown command | it exits 2 |
| `envo fmt --stdout` on `tests/golden/fmt/*.envo` | the output is `name.expected`, which formats to itself |
| `envo fmt --check` on `lib`, `adapters`, `tools`, `tests/conformance`, `compiler`, `bootstrap/stage1`, `examples` | nothing would change |

`envo test lib adapters tests/conformance examples` runs the library's tests, the
conformance suites and the examples (PLAN D29); its own behaviour is described in
[`tools/envo/README.md`](../../tools/envo/README.md).
