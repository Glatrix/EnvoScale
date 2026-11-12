# `tools/prof`

> **Status:** M13. The profiler is `envo prof` (`tools/envo/prof.envo`), in the `envo` binary.

`envo prof [dir | file.envo] [--top N] [--runtime] [-- args]` runs the program in the
script runtime and counts, for every function, its calls and the EIR instructions run
in it (PLAN D63). The report goes to stderr after the program's output:

```
envo prof: 10557 instructions in 19 functions
      calls  instructions       %  function
        177          2297    21.8  Fib
          1           184     1.7  __main
         10            70     0.7  Square
```

The counts are exact and the same on every machine, so profiles can be compared across
changes and checked in tests (`tests/envo/prof`). Runtime functions (`__rt_`, `__os_`)
are hidden unless `--runtime` is given. A sampling profiler for native code (time on
the CPU, threads) comes with the debug information emitters.
