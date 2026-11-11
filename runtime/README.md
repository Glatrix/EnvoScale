# `runtime/`

> **Status:** Not started. Startup and panics arrive with **M3**; the EIR VM, REPL and
> JIT tiering with **M6**.

Code that runs inside every Envo program or script, below the standard library:

| Part | Purpose | Milestone |
|---|---|---|
| Startup | Process entry, argument and environment capture, calling `main` / top-level statements | M3 |
| Panic | Panic messages, unwinding policy (abort by default), exit codes | M3 |
| ARC | Reference counting for `class` instances, atomic only when an instance crosses threads, `weak` references | M3 |
| EIR VM | The bytecode interpreter behind `envo run`, `envo repl` and `comptime` evaluation | M6 |
| JIT tiering | Promotes hot script functions to native code using the same backends as AOT | M6+ |

Script mode and compiled mode have **identical semantics** (brief §3.7). The runtime is
where that promise is kept: both modes share the same ARC, panic and startup code.

The runtime reaches the OS only through ports in [`lib/ports`](../lib/ports/README.md).
