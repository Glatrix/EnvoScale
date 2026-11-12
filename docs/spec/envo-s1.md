# Envo-S1

> **Status:** Draft, accepted for M2 (2026-11-11). Implemented by Stage 1 (`envoc1`,
> milestone M2, increments 2.3–2.13 in [`docs/PLAN.md`](../PLAN.md) §5). Tests:
> `tests/spec/s1-*` (from M2.4).

Envo-S1 is the language `envoc1` accepts: **Envo-Core plus what a compiler needs to be
written comfortably**, and nothing more (PLAN decision D12). Stage 2 (`compiler/`) is
written in Envo-S1 until it compiles itself (M3); after that it may use all of Envo.

## 1. The subset properties

- **[s1.subset.1]** Every Envo-S1 program is a valid Envo program with the same meaning.
  S1 only ever removes features from full Envo.
- **[s1.subset.2]** Every Envo-Core program is a valid Envo-S1 program with the same
  meaning, and `envoc1` reports the same diagnostics for it as `envoc0` (same code, file,
  line and column), except that S1 accepts what Core rejects as "not part of Envo-Core".
- **[s1.subset.3]** `envoc1 --core` restricts the accepted language to Envo-Core and
  reports E0901–E0905 exactly as `envoc0` does. Differential tests (D14) run in this
  mode, and it checks that Stage 1's own source stays Core.
- **[s1.subset.4]** A construct of full Envo that S1 leaves out is **E0950** "not part of
  Envo-S1: X", reported at the construct.

## 2. Lexical structure

Chapter 1 applies, with Core's restrictions (`envo-core.md` §2) except that S1 accepts
the contextual keywords of RFCs 0003 and 0004 (`fn`, `mut`, `once`, `move`, `from`).
Interpolated strings, raw strings, directives, non-ASCII identifiers and float literals
remain out (E0901–E0905 become E0950 in S1 mode, with the same positions).

## 3. Types

Everything in Envo-Core (`envo-core.md` §3), plus:

| Type | Notes | Reference |
|---|---|---|
| generic types `S<T, U>` | structs, enums and interfaces with type parameters and `where` constraints; no const generics | [type.gen.1], [type.gen.2] |
| enums with payloads | `enum Expr { Int(i64 value), Add(*Expr left, *Expr right) }`; fieldless enums as in Core | [item.enum.1] |
| `T?` | `Option<T>` from the prelude; `null` is `None` | [type.opt.1] |
| `Result<T, E>` | from the prelude, with `Ok(v)` / `Err(e)` | chapter 2 §2.4 |
| `string` | owned UTF-8 text from the prelude; converts to `str` (a shared borrow) where a `str` is expected | §8 |
| `fn(…) -> R`, `mut fn`, `once fn` | closures and function values; not `extern "C" fn` | [RFC 0003](../rfcs/0003-function-types.md) |
| `mut T[]` | writable view | [RFC 0004](../rfcs/0004-lifetimes-and-views.md) [view.1] |

- **[s1.type.1]** S1 types are not all `Copy`: a type is `Copy` by [type.copy.1], and
  `string`, `List<T>`, function values and any type that implements `IDrop` or contains
  a non-`Copy` field are moved (chapter 5).
- **[s1.type.2]** Generics are monomorphized (D13): each set of type arguments compiles
  separately. A generic body may use only what its constraints provide, checked once at
  the definition ([type.gen.2]). Instantiation deeper than 64 nested levels is **E0350**
  "generic instantiation too deep".
- **[s1.type.3]** Not in S1: floats, `char`, `i128`/`u128`, tuples, classes and `weak`,
  dynamic interface values (`in IShape`, `Box<I>`), associated types and constants,
  const generics, `extern "C" fn`. Dynamic dispatch, where the compiler needs it, uses
  function values ([fn.pos.4]).

## 4. Items

Everything in Envo-Core (`envo-core.md` §4), plus:

- **[s1.item.1] Namespaces and `use`.** A file may start with `namespace a.b;`
  ([item.mod.2]) and import with `use a.b;`, `use a.b.{X, Y};` or `use a.b as c;`
  ([item.use.1]). Files without a namespace share the root namespace, as in Core. All
  files given to `envoc1` still form one program (one package).
- **[s1.item.2] Visibility.** `private` (the default) limits an item to its namespace;
  `public` and `internal` make it visible to the whole program ([item.vis.1]). Because a
  program is one package, nothing is exported, so lifetime origins are always inferred
  ([life.infer.4]).
- **[s1.item.3] Generic functions and types** with `where` constraints naming S1
  interfaces or function types ([fn.pos.2]).
- **[s1.item.4] Methods.** Inside a `struct` body, or in `impl T { … }` (the only place for
  an enum's methods), with
  the receivers of [item.method.1]: none (`in this`), `ref this`, `this`, or `static`.
  Called as `x.M(…)` and `T.M(…)`.
- **[s1.item.5] Interfaces.** `interface I<T> { … }` with method signatures and default
  bodies; `impl I for T { … }` and `struct T : I { … }` ([item.iface.1],
  [item.impl.1]). Interface methods are called through generic parameters only (static
  dispatch). An interface may be implemented for any named type, primitives included
  (`impl IHash for i64`). A generic `impl<T, U>` implements for `S<T, U>` with exactly its
  parameters, in order.
- **[s1.item.6] Parameter modes** `in` and `ref` ([own.mode.1]), and `from` clauses
  ([life.from.1], [life.from.4]). Not in S1: `out`, default and named arguments.
- **[s1.item.7]** Not in S1: classes, properties, attributes, `async`, `extern`,
  operator overloading, `#if`, `using` blocks.

## 5. Statements and expressions

Everything in Envo-Core (`envo-core.md` §5), plus:

- **[s1.expr.1] `match` as an expression**, with payload patterns: `Name(a, b)` binds
  payload fields, `Name(_, b)` ignores some, plus Core's constants, `|` alternatives and
  `_`, and `if` guards. A `match` must be exhaustive (E0308); arms with a guard do not
  count. Statement-form `match` is as in Core. A binding copies a `Copy` payload; any other
  payload is taken from a local the function owns or from a temporary, and is borrowed
  (`in`) from anything else, which then may not change or move in that arm.
- **[s1.expr.2] Conditional** `c ? a : b`.
- **[s1.expr.3] Option and Result.** `null`; `a ?? b` (the value of `a`, or `b` if it is
  `None`); and the postfix `?`, which returns early with `Err(e)` from a function
  returning `Result<_, E>` or with `None` from one returning `U?` ([expr.q.1]).
- **[s1.expr.4] Lambdas** with inferred captures and the `move` prefix
  ([RFC 0003](../rfcs/0003-function-types.md)).
- **[s1.expr.5] Slicing** `a[lo..hi]`, `a[lo..]`, `a[..hi]`, `a[..]`, `a[lo..=hi]` on
  arrays, slices and `str`, giving `T[]`, `mut T[]` or `str`
  ([RFC 0002](../rfcs/0002-slicing.md), [view.3]).
- **[s1.expr.6] Method calls** `x.M(args)` with automatic borrowing of `x` for `in this`
  and `ref this` receivers (`ref this` needs `x` to be a mutable place, E0315), and
  static calls `T.M(args)`.
- **[s1.expr.7] Generic calls and literals:** `Max<i64>(a, b)`, type arguments inferred
  from arguments where possible, and `new S<T> { … }`. In an expression, `<` starts type
  arguments only when it is joint with the name before it and the closing `>` is followed
  by `(` or `.`; otherwise it is a comparison. A closing `>>` is split ([lex.punct.2]).
  Inference matches each parameter type against its argument's type, arguments with a
  type of their own first; an untyped literal then takes the type already inferred, or
  `i32` ([core.expr.2]). The call's expected type is not used. A type argument left
  unknown is E0335; one that misses a bound is E0334.
- **[s1.expr.9] Static calls** `T.M(…)` and `S<A>.M(…)` name a static method; a method
  with a receiver is called on a value, and a static one on its type (E0343).
- **[s1.stmt.1] `foreach (var x in e)`** over arrays, slices, `str` (yielding `u8`) and
  integer ranges `lo..hi`. In a `foreach` over an array or slice that is not `Copy`, `x`
  is an `in` borrow of each element ([own.borrow.4]).
- **[s1.expr.8]** Not in S1: interpolated strings, `?.`, `is` patterns, tuples and
  destructuring, `new()` without a type, object initializers for classes, `await`,
  `yield`, `throw`/`try`/`catch` (not in Envo at all), and operators on non-primitive
  types.

## 5a. Syntax tree

`envoc1 parse` prints the tree in the format of `tests/golden/README.md`. Envo-Core
programs print exactly as under `envoc0`; the S1 additions add extra children and
bracketed markers, tested by `tests/golden/s1-parser/` and `tests/spec/s1-syntax/`.

## 6. Ownership

- **[s1.own.1]** Chapter 5 applies to S1 except classes (§5.6), threads (§5.7),
  allocators (§5.8) and `[NoAlloc]`: moves and use-after-move (E0501), moving out of a
  borrow (E0502), borrow conflicts (E0503), moving or dropping while borrowed (E0504),
  lifetime elision and inference (E0506–E0508, [RFC 0004](../rfcs/0004-lifetimes-and-views.md)).
- **[s1.own.2] Drops.** A type implements `IDrop` (§8) to run code when its value is
  dropped; locals drop in reverse declaration order at the end of their scope and fields
  after their struct's own `Drop` ([own.drop.1]). Values moved on some paths only are
  tracked with drop flags ([eir.model.2]).
- **[s1.own.3] Basic borrow checking.** `envoc1` checks borrows per local variable
  (a borrow of `a.b` counts as a borrow of `a`) and lets a borrow end at its last use
  ([own.borrow.2]). It may reject some programs that the full checker of Stage 2 accepts,
  for example disjoint borrows of two fields of one local; it never accepts a program
  that breaks chapter 5. Tests use only cases where both agree.

## 7. Built-in functions

The Envo-Core built-ins (`envo-core.md` §6), plus:

| Built-in | Meaning |
|---|---|
| `void free(*u8 p)` | release memory from `alloc`; only in `unsafe` (E0306). An implementation may keep never-freed arena semantics, so `free` may do nothing |
| `T[] slice_from<T>(*T ptr, usize len)` | unsafe view from raw parts ([expr.slice.5]) |
| `mut T[] slice_from_mut<T>(*T ptr, usize len)` | unsafe writable view ([view.6]) |

`alloc` returns memory aligned to 16 bytes, zeroed, as in Core.

## 8. The S1 prelude

Every S1 program is compiled with the prelude, which is S1 source shipped with `envoc1`
(`bootstrap/stage1/prelude/`) and imported implicitly ([item.use.1]). A program's own item
of the same name hides a prelude item, so every Envo-Core program keeps its meaning
([s1.subset.2]). `Copy` is an automatic interface built into the compiler: a bound
`where T : Copy` lets a generic body copy `T` values, and implementing it by hand is
E0336. The prelude contains only:

| Item | Members (minimum) |
|---|---|
| `enum Option<T> { None, Some(T value) }` | `IsSome`, `IsNone`, `Unwrap()` (panics on `None`), `UnwrapOr(T)` |
| `enum Result<T, E> { Ok(T value), Err(E error) }` | `IsOk`, `IsErr`, `Unwrap()`, `UnwrapErr()` |
| `struct List<T>` | `List<T>.New()`, `Len`, `Push(ref this, T)`, `Pop(ref this) -> T?`, `Get(i) -> in T`, `Set(ref this, i, T)`, `AsSlice() -> T[]`, `AsMutSlice(ref this) -> mut T[]`, `IDrop` |
| `struct string` | `string.From(str)`, `Len`, `Append(ref this, str)`, `AppendByte(ref this, u8)`, `AsStr() -> str`, `Equals(str)`, `IDrop` |
| `interface IDrop` | `void Drop(ref this)` |
| `interface IEquatable<T>` | `bool Equals(in T other)` |
| `interface IHash` | `u64 Hash()` |
| `interface IClone<T>` | `T Clone()` |

Hash maps and the rest of the standard library are written by the compiler in S1 on top
of these; they are not part of the language.

## 9. Command line

`envoc1` takes the same commands and arguments as `envoc0` (`envo-core.md` §7),
including several files as one program, plus:

| Command | Meaning |
|---|---|
| `envoc1 version` | print the version |
| `envoc1 eir <file.envo>...` | print the program's EIR text ([eir.text.1]) |
| `envoc1 eir-check <file.eir>` | parse and verify an EIR text file, and print it back |
| `--core` | before the command's files: accept only Envo-Core ([s1.subset.3]) |

## 10. Limits

`envoc1`'s limits are at least Stage 0's (`envo-core.md` §8), plus 64 levels of generic
instantiation (E0350). Larger limits are allowed.

## 11. Tests

| Folder | What |
|---|---|
| `tests/spec/core-*`, `tests/golden/lexer/` | run under `envoc1 --core`, must match `envoc0` (D14) |
| `tests/spec/s1-syntax/` | parser tests for the S1 additions (M2.4) |
| `tests/spec/s1-types/` | type tests: generics, interfaces, methods, closures, Option/Result (M2.8–M2.12) |
| `tests/spec/s1-run/` | compiled and run, with `// expect:` lines (M2.8–M2.12) |
| `tests/spec/s1-own/` | ownership errors E0501–E0508 (M2.10) |
| `tests/golden/eir/` | EIR text round-trips and verifier errors (M2.6) |
