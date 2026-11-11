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

## Generics, methods and interfaces (M2.8)

`check/generic.envo` adds Envo-S1's generics to the checker, and lowering compiles each
instantiation separately (monomorphization, PLAN D13).

**Environments.** A generic item has a list of type arguments, its *environment*: the
owner's parameters first (the struct, `impl` or interface a method belongs to), then the
item's own. Each type parameter is a symbol holding its index in that list, and a type
parameter type (`TYK_PARAM`) points at it, so substitution is positional and needs no
names. An interface's methods have one extra entry at index 0, `This`, the implementing
type; the interface's own parameters follow.

**Types.** A generic instance (`Box<i64>`, `IComparable<T>`) is interned like derived
types: same struct and same arguments, same type index, so type equality stays an
integer comparison. A generic struct's fields are resolved once, with its parameters in
scope; an instance's field types and layout are the field types with its arguments
substituted. Layouts that still mention parameters only serve to find cycles (E0303).

**Checking.** A generic body is checked once, at its definition ([type.gen.2]): a value of
parameter type `T` supports only assignment, passing, returning, and the methods of its
`where` bounds. At a call, explicit type arguments fill the environment; the rest are
inferred by matching parameter types against argument types, typed arguments first and
untyped literals last (so `Max(x, 1)` with `x: i64` is `Max<i64>`, and `Max(1, 2)` is
`Max<i32>`). Then every bound is checked against the substituted arguments: a concrete
type meets a bound through an `impl` (or a struct's `: I` list); a type parameter only
through the bounds of the function being checked. The call records its callee and
environment.

**Methods** live in a table keyed by owner and name: a struct's or enum's symbol, or the
type itself for primitives (`impl IHash for i64`). A struct body's methods, `impl T`
methods and an interface implementation's methods all go there, as do default bodies an
implementation inherits. Receivers follow [item.method.1]: no receiver is `in this`;
`in this` and `ref this` pass a pointer; `this` passes a copy. `in` and `ref` parameters
are also passed by address ([own.mode.1]); in the body they are places reached through
that pointer, and an `in` place is read-only (E0315).

**Interfaces** are bounds only ([s1.type.3]): an interface method called on a value of
parameter type is resolved when the body is instantiated, to the implementation's method
for the concrete type, or to the interface's default body instantiated with `This` set to
that type. An implementation must provide every method without a default body with the
interface's signature (E0337, E0339) and nothing else (E0340).

**Instantiation.** After checking, `CollectInstances` walks the recorded calls from the
top-level statements and the non-generic functions outward, substituting each call's
environment with that of the body containing it, and makes one instance per distinct
(function, type arguments). Every method, generic or not, is compiled through an
instance, so only methods that are called are compiled. Instantiation more than 64
levels deep is E0350. Lowering then compiles every instance with its environment, so
each node's type is substituted as it is lowered.

**Names.** An instance's EIR name is the function's name (with its owner for a method)
followed by each type argument: `@Max.i64`, `@Box.Get.i64`, `@i64.Compare`. Type
arguments are written self-delimiting (`0.` pointer, `1.` slice, `2.N.` array, and a
generic instance's argument count before its arguments: `Box.1.i64`), so different
instances never share a name.

**Not yet (E0951).** Envo-S1 constructs `envoc1` does not compile yet are reported as
E0951 rather than mis-compiled: generic enums and enums with payloads, `T?`, function
types, `mut` views, namespaces and `use`, generic interface methods, and an `impl` whose
type parameters are not exactly its type's (`impl<T> I for Box<Box<T>>`). Each goes away
with the increment that implements it; M2.13 removes the code.

## Executable images

The same layout as Stage 0 (bootstrap.md, "Executable layout"): one read-write-execute
section at `0x400000`, headers written by Stage 1's own PE and ELF writers, and on Windows
an import table for `KERNEL32.dll`. Builds are deterministic, so `envoc1` builds of a
program are byte-identical on every host.

## Testing

Every `core-run` and `core-multi` program is built with `envoc1`, run, and must print the
same output and exit with the same code as under `envoc0` (M2.7's definition of done).
Envo-S1 has no Stage 0 to compare with: `tests/spec/s1-run/` programs carry their expected
output, and `tests/spec/s1-types/` one expected error each (M2.8 onward).
