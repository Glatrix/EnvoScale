# Stage 1 architecture (`envoc1`)

`envoc1` is written in Envo-Core and built by `envoc0` (PLAN D11). Its front end mirrors
Stage 0 pass for pass so the two can be compared output for output (D14); its middle and
back end go through EIR v1 (D15). This page records the design of the parts that have no
Stage 0 counterpart. File-by-file contents are in
[`bootstrap/stage1/README.md`](../../bootstrap/stage1/README.md).

## Pipeline

```
sources ─ lex ─ parse ─ check ─ lower ─► EIR ─ verify ─ x86-64 backend ─ PE / ELF writer
                                          ▲
                      runtime (Envo-Core, compiled with every program)
```

## Code generation (M2.7)

**Lowering** turns the checked tree into EIR ([eir.model.1]–[eir.model.6]):

- Every local and parameter gets a `slot` in the entry block; reads and writes are `load`
  and `store`. No SSA construction is needed, and the result is still valid SSA.
- `str` and slices are the struct `{ ptr, u64 }`; structs and arrays live in slots and are
  copied with `copy`. Aggregate arguments are passed as a pointer to a copy the callee
  owns; aggregate results through a hidden first `%ret: ptr` parameter ([eir.model.3]).
- Run-time checks are EIR's checked instructions: `add.chk` and friends, `div`/`rem`,
  `shl`/`shr`, `bounds`, so overflow, division, shift and index checks panic exactly where
  Stage 0's do, with the same reasons.
- `match` lowers to `switch`; `&&` and `||` to branches; top-level statements become
  `@__main`, which returns the exit code.
- Statics and string literals become globals.

**The backend** keeps every SSA value in its own `rbp` slot (D15): each instruction loads
its operands into fixed registers, computes, and stores its result. Block parameters are
slots written by the branch that jumps there. There is no register allocator and no
optimizer; speed is Stage 2's job.

**Calling convention** (the "Envo convention" of [eir.ssa.5], for Stage 1 output): the
caller reserves `8 × n` bytes, stores argument *i* at `[rsp + 8i]`, keeps `rsp` 16-byte
aligned, and calls; the callee reads argument *i* at `[rbp + 16 + 8i]`; the result is in
`rax`; the caller releases the space.

## The runtime (M2.7; answers PLAN open question 8)

Stage 0 copies its own assembled runtime block into each program. `envoc1` cannot, so
**the Stage 1 runtime is written in Envo-Core** (`bootstrap/stage1/runtime/`) and compiled
into every program it builds, like any other source file:

- `runtime/common.envo`: the heap (a bump allocator over page-sized chunks), the
  built-ins (`print`, `write`, `read`, `open`, `close`, `alloc`, `exit`, `argc`, `arg`,
  `panic`), panic messages and exit codes, all with Stage 0's behaviour and messages.
- `runtime/linux.envo` and `runtime/windows.envo`: the OS layer, including Windows'
  UTF-16 conversion of paths and its command-line splitting.

The OS layer needs two operations Envo-Core cannot express, which the backend encodes as
**target intrinsics**, valid only in runtime code:

| Intrinsic | Target | Meaning |
|---|---|---|
| `intrinsic syscall(i64 n, i64 a, …)` → `i64` | Linux | `syscall` with up to six arguments |
| `intrinsic wincall(i64 k, i64 a, …)` → `i64` | Windows | call import *k* of the image's `KERNEL32.dll` table with the Microsoft x64 convention |

The portable EIR intrinsics of [eir.md](../spec/eir.md) §5.6 (`write`, `read`, …) lower to
calls into this runtime, so EIR itself stays target-independent and the script VM (M6) can
implement them directly.

The runtime's source is embedded in `envoc1` as string constants generated from
`runtime/*.envo` by `envoc1 embed`; `bootstrap.* test` fails if the generated file is out
of date, so the readable sources and what `envoc1` compiles cannot drift apart.

## Executable images

The same layout as Stage 0 (bootstrap.md, "Executable layout"): one read-write-execute
section at `0x400000`, headers written by Stage 1's own PE and ELF writers, and on Windows
an import table for `KERNEL32.dll`. Builds are deterministic, so `envoc1` builds of a
program are byte-identical on every host.

## Testing

Every `core-run` and `core-multi` program is built with `envoc1`, run, and must print the
same output and exit with the same code as under `envoc0` (M2.7's definition of done).
