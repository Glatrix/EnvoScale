# 2. Types

> **Status:** Draft. Becomes normative as Stage 0 (Core types, M1), Stage 1 (generics,
> interfaces, M2) and Stage 2 (everything, M3) implement it.
> Tests: none yet (M1 adds Core type tests under `tests/spec/02-types/`).

Envo is statically typed with local type inference. Every value has exactly one type
known at compile time. There is no garbage collector, no implicit boxing, and no
runtime type information unless a type opts in with `[Reflect]`.

## 2.1 Primitive types

**[type.prim.1]** The primitive types are:

| Type | Size | Values |
|---|---|---|
| `bool` | 1 byte | `false` (0) or `true` (1) |
| `i8` `i16` `i32` `i64` `i128` | 1, 2, 4, 8, 16 bytes | two's complement signed integers |
| `u8` `u16` `u32` `u64` `u128` | 1, 2, 4, 8, 16 bytes | unsigned integers |
| `isize` `usize` | pointer size | signed / unsigned pointer-sized integers |
| `f16` `f32` `f64` | 2, 4, 8 bytes | IEEE 754 binary16/32/64 |
| `char` | 4 bytes | a Unicode scalar value (0–D7FF, E000–10FFFF) |
| `str` | 2 words | a borrowed, immutable, valid UTF-8 byte sequence |
| `void` | 0 bytes | the single value `()`; the type of statements and of functions that return nothing |
| `never` | 0 bytes | no values; the type of `return`, `break`, `panic(…)` and functions that never return |

**[type.prim.2] Familiar aliases.** For readers coming from C#, these predeclared aliases
are exactly the same types:

| Alias | Type | | Alias | Type |
|---|---|---|---|---|
| `byte` | `u8` | | `long` | `i64` |
| `int` | `i32` | | `ulong` | `u64` |
| `uint` | `u32` | | `float` | `f32` |
| | | | `double` | `f64` |

`decimal` (128-bit decimal floating point) and `string` (owned, growable UTF-8 text) are
library types from the prelude, not primitives.

## 2.2 Integer semantics

**[type.int.1]** Integer arithmetic that overflows **panics**, in every build mode and
in both AOT and script mode. Envo has no "overflow is fine in release" mode, so a program
behaves the same however it is built.

**[type.int.2]** Wrapping arithmetic is explicit: `a +% b`, `a -% b`, `a *% b` and their
compound forms wrap modulo 2ⁿ. Saturating and checked arithmetic are methods
(`a.SaturatingAdd(b)`, `a.CheckedAdd(b)` → `T?`).

**[type.int.3]** Division or remainder by zero panics. `MIN / -1` panics.

**[type.int.4]** Shifting by an amount ≥ the bit width panics. `<<` on signed values is
an arithmetic shift of the bit pattern; `>>` is arithmetic for signed and logical for
unsigned types.

## 2.3 Literals and inference

**[type.lit.1]** An integer literal without a suffix is **untyped**: it takes the type
the context requires, and is an error if its value does not fit. If the context imposes
no type, it is `i32` (`int`), and an error if it does not fit `i32`.

**[type.lit.2]** A float literal without a suffix is untyped and defaults to `f64`.

**[type.lit.3]** A character literal has type `char`. As the only implicit conversion
involving literals, a character literal whose value is ≤ U+007F may be used where a
`u8` is expected (`u8 c = 'a';`).

**[type.lit.4]** A string literal has type `str` (borrowed for the whole program). It
converts implicitly to `string` where a `string` is expected; that conversion does not
allocate (the string points at static data until it is first mutated).

**[type.conv.1]** There are **no other implicit numeric conversions**. Convert with
`as` (chapter 3): `x as i64`. Lossy `as` conversions (narrowing, float→int) are defined:
integers truncate the bit pattern; float→int rounds toward zero and saturates, with NaN
becoming 0.

*Rationale:* implicit widening is convenient, but it interacts badly with inference
and overload resolution. Explicit `as` plus untyped literals covers nearly every case
beginners hit, with error messages that suggest the cast.

## 2.4 Compound types

| Syntax | Name | Meaning |
|---|---|---|
| `T[N]` | fixed array | `N` values of `T` stored inline; `N` is a constant expression |
| `T[]` | slice | sugar for `Span<T>`: a borrowed view of contiguous `T`s (pointer + length) |
| `(A, B)` / `(A a, B b)` | tuple | anonymous product type, optionally with element names |
| `T?` | optional | sugar for `Option<T>`; `null` is `Option<T>.None` |
| `*T` | raw pointer | address of a `T`; dereferencing requires `unsafe` |
| `Result<T, E>` | result | `Ok(T)` or `Err(E)`; the standard error type |

**[type.array.1]** Indexing an array or slice checks the bounds and panics when out of
range. The optimizer removes checks it can prove redundant (brief §4.3).

**[type.opt.1]** `T?` requires no space between `T` and `?` (see the token flags in
§1.5). `string? name` is an optional string; `string ? a : b` is a conditional.

**[type.opt.2]** `T?` has the same size as `T` whenever `T` has an unused bit pattern
(references, class handles, non-zero integers, enums with spare tags).

## 2.5 User-defined types

Declared with items (chapter 4):

| Kind | Allocation | Copies? | Notes |
|---|---|---|---|
| `struct` | inline (stack or containing value) | moved; `Copy` if every field is `Copy` | value type |
| `enum` | inline | moved; `Copy` if every payload is `Copy` | algebraic: variants may carry payloads |
| `class` | heap, reference counted | the *handle* is copied and the count incremented | shared ownership; `weak` breaks cycles |
| `interface` | — | — | a trait: a set of methods a type can implement |

**[type.copy.1]** A type is `Copy` when copying its bytes is a complete copy: all
primitives (a `str` is a shared borrow, so copying it is fine), raw pointers, slices, fixed arrays and tuples of `Copy` types, and structs and enums whose fields are
all `Copy` (inferred automatically; opt out with `[NoCopy]`). Assigning or passing a
`Copy` value copies it; any other value is **moved** (chapter 5).

**[type.class.1]** Assigning a class value copies the handle and increments the
reference count. This is the one implicit cost in the language, and it is the documented
meaning of `class`. Escape analysis may remove it.

## 2.6 Generics

**[type.gen.1]** Functions, structs, enums, classes and interfaces may take type
parameters: `List<T>`, `T Largest<T>(…) where T : IComparable<T>`. Generics are
**monomorphized**: each instantiation is compiled separately, with no runtime cost.

**[type.gen.2]** Constraints are written with `where T : I1, I2`. A generic body may
only use operations that its constraints provide; this is checked once at the
definition, not at each instantiation.

**[type.gen.3]** Const generics take compile-time values: `struct Matrix<T, const usize R, const usize C>`.

## 2.7 Interfaces (traits)

**[type.iface.1]** An interface declares methods (optionally with default bodies),
associated types and associated constants. Types implement interfaces explicitly
(`impl IArea for Shape { … }` or `struct Shape : IArea { … }`).

**[type.iface.2]** **Auto-interfaces** are implemented by the compiler when a type's
structure allows it: `Copy`, `Sendable` (safe to move to another thread) and `Shareable`
(safe to borrow from several threads at once). They have no `I` prefix because they are
markers, not behaviour.

**[type.iface.3]** Operators are interfaces: `a + b` calls `IAdd<Rhs>.Add`, `a < b` calls
`IComparable<T>.CompareTo`, and so on (chapter 3, §3.4).

**[type.iface.4]** Interface values (`dyn`-style dynamic dispatch) are written
`in IShape` / `Box<IShape>` and use a vtable. They are opt-in: a generic parameter is
always static dispatch.

## 2.8 Layout

**[type.layout.1]** The default layout of structs, enums and tuples is unspecified:
the compiler may reorder fields to reduce padding. It is still deterministic for a given
compiler version and target.

**[type.layout.2]** `[Layout(C)]` gives C layout (declaration order, natural alignment);
`[Layout(Packed)]` removes padding; `[Align(N)]` raises alignment; explicit field offsets
and bitfields are available for `[Layout(C)]` structs.

## 2.9 Type inference

**[type.infer.1]** `var x = e;` gives `x` the type of `e`. Inference is local to a
function body: parameter types, return types (except for `=>` lambdas) and field types
are always written.

## 2.10 Envo-Core

**Core:** Envo-Core has the integer types, `bool`, `str`, `void`, fixed arrays,
slices, raw pointers, structs and fieldless enums. It has no floats, `char` (character
literals are ASCII and used as `u8`), tuples, optionals, classes, interfaces or
generics. See [`envo-core.md`](envo-core.md).
