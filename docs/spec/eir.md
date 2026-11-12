# EIR — Envo Intermediate Representation, version 1

> **Status:** Specified by [RFC 0005](../rfcs/0005-eir-v1.md) (accepted 2026-11-11).
> Stage 1 implements the in-memory form, the text form and the verifier
> (`envoc1 eir-check`, M2.6) and lowering and the x86-64 backend (M2.7). Stage 2 adds
> the binary form and objects (§7, M3.7). Tests: `tests/golden/eir/` (round trips) and
> `tests/spec/eir/` (verifier and syntax errors).

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

## 1. Model

**[eir.model.1]** An EIR **module** is one compilation's whole program after type
checking, monomorphization, borrow checking and drop elaboration. It contains, in this
order: a header, named struct types, globals, and functions.

**[eir.model.2] Post-ownership.** EIR has no moves, borrows or lifetimes. The front end
has already checked them and turned them into ordinary operations: a move is a copy whose
source is never used again, a borrow is a pointer, and every drop is an explicit `call`
to the type's drop function, guarded by a drop flag (an ordinary `bool` slot) where a
value is dropped only on some paths. `slot.end` marks where a slot's storage is dead, for
stack-slot sharing.

**[eir.model.3] Scalars in SSA, aggregates in memory.** SSA values have scalar types
only. Structs and arrays live in memory: in stack slots, globals or the heap. They are
read and written through pointers (`load`, `store`, `copy`, `zero`, `fieldaddr`,
`elemaddr`). Passing or returning an aggregate is lowered by the front end to passing a
pointer: an aggregate argument is a pointer to a copy the callee owns, and an aggregate
result is written through a hidden first parameter `%ret: ptr`.

**[eir.model.4] Panics abort.** A panic prints `panic: <reason>` to standard error and
ends the process with exit code 101, without unwinding and without running drops. Panics
come from the `panic` terminator and from **checked instructions** (those marked "may
panic" in §5), which panic instead of producing a result when their check fails. There
are no exceptions and no unwind edges in v1.

**[eir.model.5] Defined behaviour.** Every instruction is defined for every input except
memory access through a pointer that does not point to live, suitably sized memory, which
only `unsafe` code can produce. Wrapping, checked and conversion instructions say exactly
what happens, so the compiler, the VM and `comptime` agree on every safe program.

**[eir.model.6] Target.** The header names the target, which fixes pointer size and the
size and alignment of every type (§2). Sizes and field offsets in a module are computed
from it. The script VM and `comptime` use the host's target.

## 2. Types

| Type | Meaning | Size, align (x86-64) |
|---|---|---|
| `bool` | `false` or `true` | 1, 1 |
| `i8` `i16` `i32` `i64` | signed integers, two's complement | 1, 2, 4, 8 |
| `u8` `u16` `u32` `u64` | unsigned integers | 1, 2, 4, 8 |
| `f32` `f64` | IEEE 754 binary32 / binary64 | 4, 8 |
| `ptr` | an address; pointers are untyped | 8, 8 |
| `$Name` | a named struct type declared in the module | from its fields |
| `[N x T]` | an array of `N` values of `T` | `N × size(T)`, align(T) |
| `void` | no value; only as a function result | — |

**[eir.type.1]** `isize` and `usize` are lowered to `i64`/`u64` on 64-bit targets.
Enums are lowered to their representation integer type; `char` to `u32`. Envo `str` and
slices are the struct `{ ptr, u64 }`, function values ([fn.abi.2]) `{ ptr, ptr }`.

**[eir.type.2]** Scalar types are `bool`, the integer types, `f32`, `f64` and `ptr`. Only
they can be SSA values, parameters and results. `$Name` and `[N x T]` appear only as the
type of slots, globals, `load`/`store` of scalars inside them (through `fieldaddr`
/`elemaddr`), and size computations.

**[eir.type.3]** A struct declaration lists field types:
`type $Point = { i64, i64 }`. Fields are laid out in order at their natural alignment,
and the struct is padded to its alignment; the front end has already reordered fields if
Envo's layout rules ([type.layout.1]) allow it. `type $T = packed { … }` removes padding.

## 3. Text form

```
Module     = Header { TypeDecl } { Global } { Function }
Header     = "eir" Version "target" String NL
TypeDecl   = "type" StructName "=" [ "packed" ] "{" [ Type { "," Type } ] "}" NL
Global     = "global" GlobalName ":" Type [ "readonly" ] "=" Init NL
Init       = "zero" | "bytes" String | "{" Init { "," Init } "}" | Integer | GlobalName
Function   = ( "func" | "extern" ) GlobalName "(" [ Param { "," Param } ] ")" "->" Type
             [ Attr ] ( "{" NL { Block } "}" | NL )
Param      = ValueName ":" Type
Attr       = "abi" String
Block      = BlockName [ "(" Param { "," Param } ")" ] ":" NL { Inst NL } Term NL
Inst       = [ ValueName "=" ] Opcode Operands
Operand    = ValueName | Integer | Float | GlobalName | Type
```

- **[eir.text.1]** Names: `@name` for functions and globals (Envo's mangled path, e.g.
  `@shapes.Area`), `%name` for SSA values and parameters, `^name` for blocks, `$Name` for
  struct types. The printer numbers values and blocks in order (`%0`, `%1`, `^bb0`, …),
  so printing is deterministic and golden tests are stable.
- **[eir.text.2]** One instruction per line; `;` starts a comment to the end of the line.
  Integers are decimal or `0x` hex; floats are written as the hex of their bit pattern
  (`0f3ff0000000000000`) so they round-trip exactly; strings use the escapes of
  chapter 1 (`\n`, `\"`, `\\`, `\xHH`).
- **[eir.text.3]** The first line is always `eir 1 target "<target>"`, for example
  `eir 1 target "x86_64-linux"`.
- **[eir.text.4]** A function's entry block has no parameter list of its own: its
  parameters are the function's. The reader accepts any value and block names and the
  printer renumbers them ([eir.text.1]), so printing a parsed module gives its canonical
  form, and printing that again gives the same text. Errors are E0601–E0614
  (`errors.md`).

Example: `int Add(int a, int b) => a + b;` with a checked add.

```
eir 1 target "x86_64-linux"

func @Add(%0: i32, %1: i32) -> i32 {
^bb0:
  %2 = add.chk i32 %0, %1
  ret %2
}
```

## 4. Functions, blocks and SSA

- **[eir.ssa.1]** A function definition is a list of basic blocks; the first is the
  entry block. Each block ends with exactly one terminator and contains no other.
- **[eir.ssa.2]** Blocks take **parameters** instead of φ-nodes: a branch passes one
  argument per parameter of its target, and the parameter takes that value. The entry
  block's parameters are the function's parameters.
- **[eir.ssa.3]** Every value is defined once and every use is dominated by its
  definition. A block parameter is defined at the start of its block.
- **[eir.ssa.4]** `slot` instructions appear only in the entry block, before any other
  instruction, so the frame size is known up front.
- **[eir.ssa.5]** `extern` declares a function defined outside the module (the runtime,
  or a foreign function with `abi "C"`). Without an `abi` attribute a function uses the
  Envo calling convention, which the backend chooses.

## 5. Instructions

`T` is a scalar type; `I` an integer type; `%p` a `ptr`. "May panic" instructions panic
with the reason shown when their check fails ([eir.model.4]).

### 5.1 Constants and data

| Instruction | Result | Notes |
|---|---|---|
| `const T k` | `T` | integer, `bool` (`0`/`1`) or float bit pattern |
| `addr @g` | `ptr` | address of a global or function |
| `slot $T` / `slot I` / `slot [N x T]` | `ptr` | a stack slot, zero-initialized, aligned for the type |
| `slot.end %p` | — | the slot's storage is dead from here on |

### 5.2 Integer arithmetic

| Instruction | Result | Notes |
|---|---|---|
| `add.wrap I a, b` · `sub.wrap` · `mul.wrap` | `I` | wrap modulo 2^bits |
| `add.chk I a, b` · `sub.chk` · `mul.chk` | `I` | may panic: `integer overflow` |
| `neg.chk I a` | `I` | may panic: `integer overflow` (signed `MIN`, or unsigned non-zero) |
| `div I a, b` · `rem I a, b` | `I` | signedness from `I`; may panic: `division by zero`, and `integer overflow` for signed `MIN / -1` |
| `and I a, b` · `or` · `xor` · `not I a` | `I` | bitwise; `I` may also be `bool` |
| `shl I a, n` · `shr I a, n` | `I` | `shr` is arithmetic for signed `I`, logical for unsigned; `n` has type `I` and may panic: `shift amount out of range` unless `0 ≤ n < bits` |
| `cmp.eq T a, b` · `cmp.ne` · `cmp.lt` · `cmp.le` · `cmp.gt` · `cmp.ge` | `bool` | integers by signedness, `bool`, `ptr` (unsigned) and floats (IEEE, false on NaN except `ne`) |
| `select T c, a, b` | `T` | `a` if `c` is true, else `b` |

### 5.3 Floats

`fadd` `fsub` `fmul` `fdiv` `fneg` on `f32`/`f64`, IEEE 754 round-to-nearest-even; no
instruction may panic, and the bit pattern of every NaN result is the target's default
quiet NaN, so results are identical everywhere.

### 5.4 Conversions

| Instruction | Notes |
|---|---|
| `trunc I1 -> I2 a` | keep the low bits |
| `zext I1 -> I2 a` · `sext I1 -> I2 a` | widen with zeros / the sign bit |
| `itof I -> F a` · `ftoi F -> I a` | `ftoi` rounds toward zero and saturates; NaN becomes 0 ([type.conv.1]) |
| `fext f32 -> f64 a` · `ftrunc f64 -> f32 a` | IEEE conversion |
| `ptoi ptr -> u64 a` · `itop u64 -> ptr a` | address ↔ integer |
| `bitcast T1 -> T2 a` | same size, reinterpret the bits |

### 5.5 Memory

| Instruction | Result | Notes |
|---|---|---|
| `load T %p` | `T` | read a scalar |
| `store T v, %p` | — | write a scalar |
| `fieldaddr $S %p, k` | `ptr` | address of field `k` (a constant) of the struct at `%p` |
| `elemaddr T %p, i` | `ptr` | `%p + i × size(T)`, `i` an integer; no bounds check |
| `ptradd %p, n` | `ptr` | `%p + n` bytes, `n` an `i64` |
| `copy %dst, %src, n` | — | copy `n` bytes (a constant or `u64` value); the regions may not overlap |
| `zero %p, n` | — | set `n` bytes to zero |
| `bounds I i, len` | — | may panic: `index out of bounds` unless `0 ≤ i < len` (as unsigned after a signed `i` is checked `≥ 0`) |
| `bounds.range lo, hi, len` | — | `u64` operands; may panic: `index out of bounds` unless `lo ≤ hi ≤ len` (slicing, [expr.slice.2]) |
| `bounds.utf8 %p, len, at` | — | may panic: `str slice is not on a character boundary` ([expr.slice.3]) |

### 5.6 Calls and intrinsics

| Instruction | Notes |
|---|---|
| `call @f(args)` | direct call; result type from `@f`'s declaration |
| `call.ind T (args) %fp` | indirect call through a code pointer, result type `T`, with the callee's convention given by its declaration in `abi` form when not Envo (`call.ind abi "C" …`) |
| `intrinsic name(args)` | an operation of the runtime that every backend and the VM implement, listed below |

v1 intrinsics, mirroring the Envo-Core built-ins (`envo-core.md` §6) and the Stage 0
platform shim: `write(i32 fd, ptr, u64 len)`, `read(i32 fd, ptr, u64 n) -> i64`,
`open(ptr path, u64 len, i32 mode) -> i32`, `close(i32)`, `alloc(u64 n) -> ptr`,
`exit(i32)`, `argc() -> u64`, `arg(u64 i, ptr out)` (writes a `str`), and
`panic.msg(ptr, u64 len)` (prints `panic: ` and the message, then exits 101).

Two **target intrinsics** exist only in the runtime's OS layer and only for their
target (docs/architecture/stage1.md): `syscall(i64 n, i64 a1, …, i64 a6) -> i64` on Linux
and `wincall(i64 k, i64 a1, …, i64 a8) -> i64` on Windows, which calls import *k* of the
image's `KERNEL32.dll` table.

### 5.7 Terminators

| Terminator | Notes |
|---|---|
| `br ^b(args)` | jump |
| `condbr c, ^t(args), ^f(args)` | `c` is a `bool` |
| `switch I v, [k1: ^b1(args), …], ^default(args)` | the `k` are distinct constants of `I` |
| `ret` / `ret v` | `v`'s type is the function's result type |
| `panic "reason"` | panic with one of the reasons below ([eir.model.4]) |
| `unreachable` | may panic: `unreachable code reached`; the optimizer may assume it is never executed only after proving it |

**[eir.panic.1]** Panic reasons are a closed list, numbered for the binary form:
0 `integer overflow`, 1 `index out of bounds`, 2 `division by zero`, 3 `out of memory`,
4 `shift amount out of range`, 5 `unreachable code reached`,
6 `str slice is not on a character boundary`. User panics use `intrinsic panic.msg`.

## 6. Verifier

The verifier rejects a module unless all of these hold; each failure names the function,
block and instruction.

- **[eir.verify.1]** Names are unique per kind; every name used is defined; struct types
  are not recursive except through `ptr`.
- **[eir.verify.2]** Every block ends in exactly one terminator; every branch target
  exists and receives one argument of the right type per parameter.
- **[eir.verify.3]** Every operand has the type its instruction requires, and every
  result is used at its type ([eir.type.2]); constants fit their type.
- **[eir.verify.4]** Every use is dominated by its definition ([eir.ssa.3]).
- **[eir.verify.5]** `slot`s are only at the start of the entry block ([eir.ssa.4]).
- **[eir.verify.6]** Calls match their callee's parameter and result types; `ret` matches
  the function's result type.
- **[eir.verify.7]** `fieldaddr` indexes exist; `switch` keys are distinct; panic reasons
  are in the list ([eir.panic.1]).

Every pass's output is verified in debug builds of the compiler, and the M2.6 golden
tests include one invalid module per rule.

## 7. Binary form

**[eir.bin.1]** A binary module (`.eirb`) is: the magic bytes `45 49 52 00` (`EIR\0`), the
format version as a `u16` little-endian (`1`), then sections in this order, each a
section id byte followed by its byte length as an unsigned LEB128: 1 strings, 2 target,
3 types, 4 globals, 5 functions. Numbers inside sections are unsigned LEB128, except
integer constants, `switch` keys and immediates, which are signed LEB128 of their 64 bits.
Names and string data are indexes into the string section.

**[eir.bin.2]** The sections:

- **strings**: a count, then each string as its byte length and bytes. String 0 is empty.
- **target**: the target's string.
- **types**: the types after the primitives, in id order (primitives have fixed ids,
  `void` = 1 to `ptr` = 13). A struct is `14`, its name, flags (1 packed, 2 defined) and
  its field type ids; an array is `15`, its element type id and length.
- **globals**: a count, then each global's name, type id, a read-only byte and its
  initializer: a kind byte (1 zero, 2 bytes, 3 list, 4 integer, 5 address) followed by
  the string, the element count and elements, the integer or the name.
- **functions**: a count, then each function's name, flags (1 `extern`), ABI string,
  result type, parameter count, and the types of all its values, parameters first. A
  definition adds its blocks: each block's first parameter (as a value number), parameter
  count and instructions. An instruction is its opcode, its result (value number + 1, or
  0), its type operands (two type ids, 0 if unused), its immediate, a string (intrinsic,
  ABI) and its operands, each a kind byte (1 value, 2 integer, 3 global name, 4 branch
  target with its arguments, 5 `switch` key) and its payload.

Values and blocks are numbered from the function's first, so the encoding of a module
does not depend on where its functions sit in memory. Decoding gives back the same types,
globals and functions, and printing the result gives the same text. The opcode numbering
is part of the version: adding an opcode at the end is a minor change, and changing an
existing one needs a new version and a migration in `envo eir upgrade`.

**[eir.bin.3]** `envoc eir-check` reads either form and prints text, or writes the binary
form with `-o`. Both round trips are exact; the tests check them on the EIR goldens and
on every run program.

**[eir.bin.4] Objects.** An EIR object (`.eo`, PLAN D19) is a binary module of a whole
program in which only one unit's functions (one file's, or the runtime's) have bodies;
the others are `extern` declarations with the Envo convention. `envoc link` fills each
declaration with the body another object of the same program defines and generates code
from the result.

## 8. Versioning

**[eir.ver.1]** Version 1 is this document. A reader rejects a module whose version it
does not know, naming both versions. A later version adds an upgrade step from the
previous one, so any older module can be migrated forward one version at a time.
