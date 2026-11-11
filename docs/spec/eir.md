# EIR — Envo Intermediate Representation

> **Status:** Not started. The first version is designed and implemented with Stage 1
> (milestone M2), through an RFC.

EIR is the compiler's middle layer: every front end lowers to it, every optimization
pass reads and writes it, every backend consumes it, and the script runtime and
`comptime` evaluator interpret it.

## Requirements fixed by the brief

- **SSA form**, typed, with explicit control flow (basic blocks and terminators).
- **Versioned**: textual (`.eir`) and binary forms both carry a version; old versions
  have a migration path (brief §14.1).
- **Textual and binary forms** that round-trip exactly.
- A **verifier** that every pass's output must pass in debug builds.
- **One semantics** for AOT, the script VM and `comptime`, so the conformance suite can
  require identical results in both execution modes.
- Inspectable with `envo build --emit eir|eir-opt` and `envo eir`.

## To be decided in the M2 RFC

- Memory model in EIR (explicit loads/stores vs. value semantics for aggregates).
- How ownership facts (moves, drops, borrows) are represented after borrow checking.
- Exceptions-free panic edges and unwinding policy.
- The binary encoding and its magic header.
