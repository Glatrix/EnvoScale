# Benchmarks

> **Status:** Started (M6): `vm/`, programs that time the script runtime against native
> code. Run by hand for now; tracking over time and a regression threshold in CI come
> later.

## `vm/`

Each program prints its result as a test does (`// expect:`), so it doubles as a check.

```bash
envo run -A tests/bench/vm/sieve.envol          # the script runtime
envo run --native tests/bench/vm/sieve.envol    # native code (-O0)
```

| Program | What it exercises | Native `-O0` | Script runtime |
|---|---|---|---|
| `fib.envol` | calls (Fibonacci of 27) | 0.02 s | 0.76 s |
| `sieve.envol` | loops and memory (primes below 2 000 000) | 0.08 s | 6.95 s |
| `text.envol` | library code (100 000 lines split, a map) | 0.20 s | 15.2 s |
| the compiler building `calls.envol` | 30 000 lines of Envo-S1 | 0.12 s | 3.3 s |

Measured on the development machine (Windows, M6.6), wall time including the
compile step. The script runtime is an interpreter over EIR: 35 to 100 times slower
than native code, and about a third faster than its first version (4.9 s for the
compiler run). A JIT that reuses the native backends is the next step (brief §3.7).
