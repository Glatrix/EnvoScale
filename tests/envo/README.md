# `tests/envo` — the `envo` tool's own tests

> **Status:** M5. Run by `build.ps1 test` / `build.sh test` ("envo commands").

The scripts check each `envo` command end to end, in a scratch folder
(`build/run-envo`):

| Check | Passes when |
|---|---|
| `envo new demo` | it exits 0 and writes `demo/envo.envon` |
| `envo run demo` | it prints `Hello, demo!` (in the script runtime) and exits 0 |
| `envo run --native demo` | the same, built and run as native code |
| `envo test demo` | the package builds and its test passes at `-O0`, `-O2` and in the script runtime (`4 passed, 0 failed`) |
| `envo check bad.envol` | it exits 1 with `bad.envol:1:9: error[E0101]`, the source line and a pointer to `envo explain` |
| `envo explain E0004` | it prints the registry entry and the text of `[lex.str.1]` |
| `envo explain E9999` | it exits 1 |
| `envo version` | it prints `envo …` |
| `envo repl`, cells piped in | each cell's output shows once (`hello`, then `42` from a function declared over three lines), and a cell that does not compile shows its error |
| `envo prof hot.envol` (`prof/hot.envol`) | the program prints `ok`, and the report on stderr counts 177 calls of `Fib` and 10 of `Square` |
| `envo fuzz magic.envol --runs 50000 --seed 1` (`fuzz/magic.envol`) | it finds the input starting `FUZ!` (checked a byte at a time), exits 1, saves it as `build/fuzz/magic/crash`, and the replay shows the panic |
| `envo dbg sum.envol` with `dbg/session.txt` on stdin | the transcript is `dbg/expected.txt`: stepping into and out of a call, a breakpoint, locals, the call stack, the source list |
| packages (`pkg/`) | `app` runs with a path dependency; `envo key`, `envo publish` (signed, once per version); `app2` needs `envo fetch`, then runs with the registry package; `app3` (another key) is refused; a changed archive is refused |
| an unknown command | it exits 2 |
| `envo fmt --stdout` on `tests/golden/fmt/*.envol` | the output is `name.expected`, which formats to itself |
| `envo fmt --check` on `lib`, `adapters`, `tools`, `tests/conformance`, `compiler`, `bootstrap/stage1`, `examples` | nothing would change |

`envo test lib adapters tests/conformance examples` runs the library's tests, the
conformance suites and the examples (PLAN D29); its own behaviour is described in
[`tools/envo/README.md`](../../tools/envo/README.md).
