# RFC 0004: Explicit lifetimes (`from`) and writable views (`mut T[]`)

- **Status:** Accepted (2026-11-11). Under the owner's standing instruction to decide open
  design questions by the brief's core principles: "lifetimes are inferred" and explicit
  ones "exist but are rarely needed" (brief §3.4), with no syntax that collides with C#
  readers' expectations.
- **Author(s):** founding engineer
- **Affects:** language (chapters 2, 4 and 5, Envo-S1, RFC 0002); not Envo-Core
- **Tracking:** [#31](https://github.com/envoscale/EnvoScale/issues/31), milestone M2

## Summary

Explicit lifetimes are written by naming **where a borrow comes from**, not with
lifetime variables: `str Longest(in str a, in str b) from a, b` says the result borrows
from `a` and `b`. A `ref` parameter can say the same about what is stored into it. For
functions that other packages cannot call, the compiler works this out from the body, so
`from` is only ever required on a library's exported signatures that elision cannot
cover. Slices come in two
kinds: `T[]`, a shared read-only view, and `mut T[]`, an exclusive view that can be
written through.

## Motivation

Chapter 5 elides lifetimes in signatures and reports E0506 when elision fails, with "no
explicit escape hatch yet" ([own.life.3]). Rust's `'a` reads oddly next to C#'s
`'a'` character literals, and lifetime variables are the part of Rust that beginners
find hardest. Three things are needed:

1. a way to write a signature that elision cannot express (`Longest` above);
2. a rule that keeps every Envo-Core program valid Envol ([core.subset.1]), even though
   Core has no lifetimes and functions like `str Pick(str a, str b)` are valid Core;
3. a way to write through a slice, which RFC 0002 deferred here ([expr.slice.4]).

## Guide-level explanation (the simple door)

Most of the time you never write a lifetime. When a function returns something it
borrowed and the compiler cannot tell from where, say it with `from`:

```envo
public str Longest(in str a, in str b) from a, b {   // in a library
    return a.Length >= b.Length ? a : b;
}
```

Read it as "the result comes from `a` and `b`": both must stay alive while you use the
result. Inside your own program you do not even need that; the compiler reads the body.
`from` is only required on functions a library exports, because their signature is a
promise to other packages.

A slice is a view into an array. A plain `int[]` view can only be read. To change the
elements, ask for a `mut int[]`:

```envo
void Fill(mut int[] xs, int v) {
    for (usize i = 0; i < xs.Len; i++) xs[i] = v;
}

int[8] buf;
Fill(buf[2..6], 7);      // buf[2] to buf[5] become 7
```

While a `mut` view exists, nothing else can use those elements, so two pieces of code
can never write the same element at the same time.

## Reference-level explanation (the full-control door)

### Borrow origins

- **[life.origin.1]** A **borrow origin** names where a borrow comes from: a parameter
  of the current function, or `this`. Every borrow (`in`/`ref` parameters, `str`, `T[]`,
  `mut T[]`, closures and structs with borrowed captures or fields) has a set of origins;
  a borrow is valid only while all of its origins are.
- **[life.origin.2]** A struct or enum with borrowed fields has **one** implicit origin
  parameter shared by all of them ([own.life.2]); each use of the type supplies it. A
  struct that needs fields borrowed from different places is not expressible in this
  version (see Unresolved questions).

### `from` on results

```
FunctionDecl = … "(" Params ")" [ FromClause ] [ WhereClause ] Body
FromClause   = "from" Origin { "," Origin }
Origin       = Identifier | "this"
```

- **[life.from.1]** `from p1, …, pn` declares that the borrows in the result may come
  only from those parameters (or `this`). A caller keeps the listed arguments borrowed
  while the result is live, as for elision rule 1 ([own.life.1]).
- **[life.from.2]** Each listed name must be a parameter that holds a borrow (an `in` or
  `ref` parameter, or a by-value parameter of a type that holds borrows such as `str`)
  or `this` in a method; otherwise **E0508**.
- **[life.from.3]** The body is checked against the clause: returning a borrow whose
  origins are not all listed is **E0507**, which names the origin and suggests adding it.

### `from` on `ref` and `out` parameters

```
Param = [ "in" | "ref" | "out" ] Type Identifier [ "from" Origin { "," Origin } ] [ "=" Expr ]
```

- **[life.from.4]** On a `ref` or `out` parameter, `from` declares that after the call the
  parameter's borrows may also come from the listed parameters:
  `void Push(ref List<str> names from name, str name)` may store `name` in `names`, so
  the caller's list stays tied to the caller's string. Storing a borrow into a `ref` or
  `out` parameter without such a clause is E0507. `from` on an `in` or by-value parameter
  is E0508.

### Inference and elision

- **[life.infer.1]** Elision ([own.life.1]) gains a first rule: a function that returns a
  borrow but has **no** borrowed parameters returns a borrow of static data (string
  literals, `str_from` of memory that is never freed).
- **[life.infer.2]** For a function that is not **exported** (callable from another
  package: `public` and reachable from a library's public API) and has no `from` clause, when
  elision rules 2 and 3 do not apply, the compiler **infers** the clause from the body:
  the result's origins are the origins of every value that can reach a `return`. A group
  of mutually recursive functions is solved together by fixed-point iteration, starting
  from "no origins". The same applies to borrows stored into `ref`/`out` parameters.
- **[life.infer.3]** An exported function whose result origins elision cannot determine
  needs a `from` clause (E0506, whose help text now shows the `from` clause to add).
  Exported signatures never depend on their bodies, so changing a body cannot break
  another package.
- **[life.infer.4]** An Envo-Core program is a single executable package, so none of its
  functions are exported (its `public` has no effect, `envo-core.md` §4). Every Core
  function falls under elision or [life.infer.2], and every Core program stays valid Envol
  ([core.subset.1]).

### Writable views: `mut T[]`

- **[view.1]** `T[]` is a **shared view** (`Span<T>`): reading only, `Copy`, any number
  may exist at once. `mut T[]` is an **exclusive view** (`SpanMut<T>`): elements may be
  read and assigned (`xs[i] = v`), it is not `Copy`, and while it is live its elements
  are exclusively borrowed ([own.borrow.1]). There is no `mut str`: a `str` stays valid
  UTF-8.
- **[view.2]** `mut` is a contextual keyword in type position directly before `fn`
  ([fn.syn.1]) or before a slice type `T[]`. Before any other type it is **E0333**.
- **[view.3]** Slicing (`a[lo..hi]`, RFC 0002) produces a `mut T[]` when its target type
  is `mut T[]` (a parameter, a variable with a written type, a field), and a `T[]`
  otherwise. Producing a `mut T[]` needs `a` to be a place that can be mutated: a local,
  a field of one, a `ref` parameter, or a `mut T[]` view; it exclusively borrows the
  sliced elements of `a` (otherwise E0315 "cannot assign to this").
- **[view.4]** Passing a `mut T[]` variable to a `mut T[]` parameter **reborrows** it for
  the call instead of moving it, so the caller can use its view again afterwards.
- **[view.5]** A `mut T[]` converts to `T[]` (a shared reborrow) wherever a `T[]` is
  expected. Assigning through a `T[]` is E0315.
- **[view.6]** `unsafe` built-in `mut T[] slice_from_mut<T>(*T ptr, usize len)` is the
  writable counterpart of `slice_from` ([expr.slice.5]).

### Errors

| Code | Message |
|---|---|
| E0507 | this returns (or stores) a borrow of `x`, but the signature does not say `from x` |
| E0508 | `from` can only name a borrowed parameter or `this` |
| E0333 | `mut` only applies to `fn` types and slices |

### Tests

With M2.10: borrow tests for [life.from.1]–[life.from.4], inference across a recursive
pair ([life.infer.2]), the exported-signature rule ([life.infer.3]), a Core-style
`str Pick(str a, str b)` that must still compile ([life.infer.4]); run tests for
`mut T[]` writes, reborrowing ([view.4]) and `mut` slicing of arrays, fields and views;
error tests for E0333, E0507, E0508, and E0503 for two overlapping `mut` views.

## Drawbacks

- Origins cannot say "these two parameters share a lifetime that is shorter than either",
  which Rust's `'a` can. Such signatures are rare, and listing both origins is safe; it
  only keeps both arguments borrowed a little longer.
- Inferring origins for functions that are not exported means a body change can change
  their signature. Errors then point at the calling code, so they say which body caused the
  inferred origin.

## Alternatives

- **Rust's `'a`.** Fully general, but it is the hardest part of Rust to learn, and it
  reads like an unclosed character literal to C# readers. The lexer could tell them
  apart, so this stays available for a later RFC if origins prove too weak.
- **Lifetime parameters with a keyword** (`<life a>`). Same power as `'a` with a friendlier
  spelling, but still asks users to invent names for something they already have a name
  for: the parameter.
- **No explicit lifetimes, only inference.** Breaks the principle that exported
  signatures are checkable on their own.
- **Writability from the parameter mode** (`ref int[] xs`). `ref` already means "may
  replace the view itself", and a writable view must not be `Copy`, so it needs its own
  type.

## Prior art

Swift's lifetime dependencies (`@lifetime(borrow x)`, formerly `dependsOn(x)`), which
name the parameter a result depends on; Hylo's projections; Rust's lifetime elision and
`&[T]` / `&mut [T]`; C#'s `ReadOnlySpan<T>` / `Span<T>` and `scoped`.

## Unresolved questions

- Structs whose borrowed fields come from different origins ([life.origin.2]): needs
  named origin parameters, possibly `struct Pair<from a, from b>`.
- `mut` views of struct fields across a whole array (`xs[..].X`).

## Migration / edition impact

None. `from` and `mut` are contextual keywords in positions that were not valid before.
RFC 0002's [expr.slice.4] now points here for writes, and [own.life.3] is settled.
