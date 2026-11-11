# 5. Ownership and Borrowing

> **Status:** Draft. Stage 1 implements a basic borrow checker (M2); Stage 2 the full
> flow-sensitive one (M3). Envo-Core has no borrow checking. Tests: none yet (M2).

Envo has Rust's memory model with fewer things to write: every value has one owner,
borrows are checked at compile time, and lifetimes are inferred.

## 5.1 Ownership and moves

**[own.move.1]** Every value has exactly one owner: a variable, a field, an element, or
a temporary. When the owner goes out of scope the value is **dropped**.

**[own.move.2]** Assigning, passing by value, or returning a non-`Copy` value **moves**
it. Using a variable after it has been moved is an error (E0501) unless it has been
assigned again. `Copy` values (§2.5) are copied instead.

**[own.move.3]** Moving out of a borrow is an error (E0502): you cannot take ownership
of something you only borrowed. The fix is to borrow, clone explicitly (`.Clone()`), or
swap (`mem.Replace`). There are no hidden copies of non-`Copy` values.

**[own.drop.1]** Locals drop in reverse declaration order; struct fields drop in
declaration order after the struct's own `Drop` method, if any. A type gets custom drop
behaviour by implementing `IDrop`.

## 5.2 Parameter modes

| Syntax | Meaning | Rust equivalent |
|---|---|---|
| `T x` | takes ownership (move), or copies a `Copy` type | `x: T` |
| `in T x` | shared, read-only borrow | `x: &T` |
| `ref T x` | exclusive, mutable borrow | `x: &mut T` |
| `out T x` | output borrow; the callee must initialize it before returning | `&mut MaybeUninit<T>` (safe) |
| `class` value | shared ownership (ARC) | `Rc` / `Arc` |
| `weak T` | non-owning reference to a class instance | `Weak` |
| `*T` | raw pointer, `unsafe` only | `*mut T` |

**[own.mode.1]** At the call site, `in` arguments are borrowed implicitly; `ref` and
`out` must be written (`Swap(ref a, ref b)`, `TryParse(s, out var n)`), so mutation is
visible where it happens.

**[own.mode.2]** An `out` parameter may not be read before it is assigned, and must be
assigned on every path that returns normally (E0505).

## 5.3 Borrow rules

**[own.borrow.1]** At any point, a value may have **either** any number of shared
borrows **or** exactly one exclusive borrow, never both. Violations are E0503.

**[own.borrow.2]** Borrows are checked **flow-sensitively** (non-lexical): a borrow
lasts from its creation to its last use, not to the end of its scope.

**[own.borrow.3]** A value may not be moved or dropped while borrowed (E0504).

**[own.borrow.4]** Local variables may hold borrows: `var best = items[0];` where
`items` is `in Span<T>` and `T` is not `Copy` binds `best` as an `in T` borrow rather
than attempting a move. (`var` infers the binding mode; an explicit type `T best`
requests ownership and is an error if that would move out of a borrow.)

## 5.4 Lifetimes

**[own.life.1]** Every borrow has a lifetime the compiler infers. In function signatures
lifetimes are **elided**:

0. If a function returns a borrow and has no borrowed parameters, the result borrows
   static data ([life.infer.1]).
1. If a function returns a borrow and has exactly one borrowed parameter (counting
   `this`), the result borrows from that parameter.
2. If it has a borrowed `this`, the result borrows from `this`.
3. Otherwise, a function that is not exported from a library has its result's origins
   inferred from its body ([life.infer.2]); an exported one needs a `from` clause (E0506).

**[own.life.2]** A struct or enum with borrowed fields (for example a `str` or `T[]`
field) implicitly takes a lifetime parameter, inferred at each use.

**[own.life.3]** Explicit lifetimes name where a borrow comes from:
`str Longest(in str a, in str b) from a, b`, and `ref` parameters can say what may be
stored into them (`ref List<str> names from name`). See
[RFC 0004](../rfcs/0004-lifetimes-and-views.md), [life.origin.1]–[life.infer.4].

**[own.view.1]** `T[]` is a shared, read-only view; `mut T[]` is an exclusive view that can
be written through ([RFC 0004](../rfcs/0004-lifetimes-and-views.md), [view.1]–[view.6]).

## 5.5 Error messages

Ownership errors are where most learning happens, so they follow a fixed shape: name the
problem in plain words, show where the value was borrowed or moved and where it was
used, and suggest a fix.

```text
error[E0501]: `names` was used after it was moved
  --> app.envo:7:11
   |
 5 |     var team = new Team(names);
   |                         ----- `names` was moved into `Team` here
 6 |
 7 |     print(names.Count);
   |           ^^^^^ used here after the move
   |
help: if `Team` only needs to read the list, borrow it: `Team(in List<string> names)`
help: or give `Team` its own copy: `new Team(names.Clone())`
```

## 5.6 Classes and shared mutation

**[own.class.1]** Class instances are shared by reference counting. Assigning a handle
increments the count (atomically only when the instance can cross threads, which the
compiler infers), and dropping it decrements the count. The instance is dropped when the
count reaches zero.

**[own.class.2]** Fields of a class can be mutated through any handle. To keep this
memory-safe, the compiler proves exclusive access where it can, and otherwise inserts a
dynamic **exclusivity check**: overlapping mutable access to the same instance at
runtime panics (Swift's model). Escape analysis removes most checks.

**[own.class.3]** `weak T` holds a non-owning reference; reading it yields `T?`, which is
`null` after the instance is dropped. Reference cycles must be broken with `weak`; the
compiler warns about obvious strong cycles in field types.

## 5.7 Threads

**[own.thread.1]** `Sendable` (may be moved to another thread) and `Shareable` (may be
borrowed by several threads at once) are auto-interfaces, inferred from a type's fields.
Spawning a thread or task requires the captured values to be `Sendable`; sharing a
borrow requires `Shareable`. Together these rule out data races at compile time.

**[own.thread.2]** A class whose fields are mutated is not `Shareable` unless it is
marked `[Synchronized]` (which wraps member access in a lock) or its mutable fields are
atomics.

## 5.8 Allocators

**[own.alloc.1]** At the simple door, collections use the **context allocator**. At the
full-control door every allocating type accepts an explicit allocator:
`new List<int>(alloc: arena)`.

**[own.alloc.2]** `[NoAlloc]` on a function is checked by the compiler: it may not
allocate, directly or through anything it calls (E0510).

## 5.9 `unsafe`

**[own.unsafe.1]** Inside `unsafe { … }` the programmer may dereference raw pointers,
take raw addresses with `&`, call `unsafe` functions, write inline `asm`, and use
unchecked intrinsics. Borrow rules still apply to safe references; the compiler simply
stops checking what raw pointers point to. `envo audit unsafe` lists every block.

## 5.10 Envo-Core

**Core:** Envo-Core has no borrow checker, no classes and no drops. All Core types are
`Copy`. Raw pointers are dereferenced inside `unsafe` blocks, as in full Envo, so Core
code stays valid Envo; full Envo may still reject a Core program that breaks borrow
rules Stage 0 does not check. Stage 1's own source is written to pass both.
