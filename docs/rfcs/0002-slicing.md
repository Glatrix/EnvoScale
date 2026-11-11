# RFC 0002: Slicing

- **Status:** Accepted (2026-11-11). Under the owner's standing instruction to decide open
  design questions by the brief's core principles; this RFC adds no new concept, only the
  C# range-index syntax the brief's "C#-style syntax" already implies.
- **Author(s):** founding engineer
- **Affects:** language (chapters 2 and 3, Envo-S1); not Envo-Core
- **Tracking:** [#45](https://github.com/envoscale/EnvoScale/issues/45), milestone M2

## Summary

Add **slicing**: `a[lo..hi]` makes a `T[]` view of part of an array or slice, and a
`str` view of part of a `str`. Either bound may be left out (`a[lo..]`, `a[..hi]`,
`a[..]`), `..=` makes the upper bound inclusive, and the bounds are checked. A slice
borrows what it views. For code that builds a view from raw parts, an `unsafe`
built-in `slice_from(ptr, len)` mirrors `str_from`. Slicing is part of full Envo and of
Envo-S1; Envo-Core stays as it is.

## Motivation

Chapter 2 defines `T[]` as a borrowed view of contiguous values, and Envo-Core has the
type with indexing, `.Len` and `.Ptr`. But no rule says how to *make* one. The only
slice a Core program can create is the zero value, which is empty
(`tests/spec/core-run/panic_slice_bounds.envo`). Without a way to make views:

- functions cannot take "part of a buffer" without passing a pointer and a length by
  hand, which needs `unsafe` and defeats bounds checking;
- `str` cannot be split without `str_from`, which is also `unsafe`;
- the Stage 2 compiler, written in Envo-S1, would be full of pointer-and-length pairs.

## Guide-level explanation (the simple door)

Square brackets with a range take part of an array, a slice or a string:

```envo
int[6] nums = [1, 2, 3, 4, 5, 6];
int[] middle = nums[1..4];     // 2, 3, 4      (the end is excluded)
int[] head   = nums[..2];      // 1, 2
int[] tail   = nums[4..];      // 5, 6
int[] all    = nums[..];       // the whole array
int[] two    = nums[1..=2];    // 2, 3         (..= includes the end)

str name = "Ada Lovelace";
str first = name[..3];         // "Ada"
```

A slice is a view, not a copy: it points into `nums`, so `nums` cannot be moved or
changed while `middle` is in use. Asking for more than is there stops the program
with `panic: index out of bounds`, the same as indexing past the end.

String slices count **bytes**. Cutting a string in the middle of a character stops the
program with `panic: str slice is not on a character boundary`.

## Reference-level explanation (the full-control door)

### Grammar

No new tokens. Inside index brackets, a range is allowed where an expression is:

```
IndexSuffix  = "[" ( Expr | RangeIndex ) "]"
RangeIndex   = [ Expr ] ( ".." | "..=" ) [ Expr ]
```

`..=` needs an upper bound (`a[1..=]` is E0101). Range expressions elsewhere keep the
meaning chapter 3 gives them; this RFC only defines them as an index.

### Rules

- **[expr.slice.1]** `a[lo..hi]` needs `a` to be an array `T[N]`, a slice `T[]` or a
  `str`, and gives `T[]` for arrays and slices and `str` for `str`. `lo` and `hi` may
  have any integer type, like an index ([core.expr.6]); an unsuffixed literal bound is
  `usize`. A missing `lo` is 0; a missing `hi` is the length. `a[lo..=hi]` means
  `a[lo..hi + 1]`, where `hi + 1` cannot overflow because it is computed in `u64`
  after the bound check below. Slicing anything else is **E0328**.
- **[expr.slice.2]** Bounds are checked at run time, in this order: each bound is
  converted to `u64` (a negative bound is out of bounds), then `lo <= hi` and
  `hi <= length` must both hold. Otherwise the program panics with
  `index out of bounds` ([type.array.1]). Bounds that are constants and visibly out of
  range for an array are a compile-time error (**E0304**, as for constant indexes).
- **[expr.slice.3]** For `str`, `lo` and `hi` are byte offsets, and each must be 0,
  the length, or the offset of a byte that is not a UTF-8 continuation byte
  (`10xxxxxx`). Otherwise the program panics with
  `str slice is not on a character boundary`. So every `str` stays valid UTF-8.
- **[expr.slice.4]** The result points into `a`'s storage; it is a **shared borrow** of
  `a` (chapter 5), so `a` may not be moved, dropped or mutated while the result is
  live ([own.borrow.1]–[own.borrow.3]). Slicing an array that is not a place (a call
  result, for example) is **E0329**, because the view would outlive its storage.
  Elements are read through the view. Writing needs an exclusive view, `mut T[]`,
  defined by [RFC 0004](0004-lifetimes-and-views.md) ([view.1]–[view.6]).
- **[expr.slice.5]** `T[] slice_from<T>(*T ptr, usize len)` is a built-in that makes a
  view of `len` values at `ptr`. It needs `unsafe` (E0306): the caller vouches that the
  memory holds `len` valid `T`s and stays alive while the view is used. It is the
  `T[]` counterpart of `str_from`. Full Envo also exposes it as
  `Span<T>.FromRaw(ptr, len)` in `envo.mem`.

### Envo-Core and Stage 0

Envo-Core does not get slicing: Stage 0's line budget is spent (PLAN D11), and Core
code can use a pointer and a length. [core.subset.1] still holds, because Core only
gets smaller than full Envo. `envo-core.md` §3 says so next to `T[]`.

### Tests

When `envoc1` implements Envo-S1 (M2.7–M2.11): run tests for every bound form on arrays,
slices and `str`, including empty slices (`a[2..2]`, `a[len..]`); panic tests for
`lo > hi`, `hi > len`, a negative bound and a non-boundary `str` cut; error tests for
E0328, E0329 and the constant-bound E0304; and a borrow test for [expr.slice.4] once the
borrow checker exists (M2.10).

## Drawbacks

- Byte offsets for `str` are easy to misuse with non-ASCII text. The panic on a
  non-boundary cut keeps it safe; character-based helpers belong in `envo.text`.
- One more trap reason in the runtime.

## Alternatives

- **A slicing method** (`a.Slice(lo, hi)`). Works without syntax, but every C# user
  expects `a[1..3]`, and ranges are already in chapter 3's precedence table.
- **Only `slice_from`.** Needs `unsafe` for an everyday operation.
- **Slicing in Envo-Core too.** Would need parser, checker and code-generator work in
  Stage 0, over its budget; Stage 1 does not need it, because it is written in Core.
- **Do nothing.** `T[]` would stay a type with no useful values.

## Prior art

C# 8 ranges and indices (`span[1..3]`, `^1` for "from the end"); Rust's slicing
(`&a[1..3]`) with its char-boundary panic for `str`; Go's `a[lo:hi]`. The `^1`
from-the-end index is left out; it can come later without breaking anything.

## Unresolved questions

- ~~Writing through a view~~: decided by [RFC 0004](0004-lifetimes-and-views.md),
  `mut T[]`.
- A from-the-end index (`a[^1]`, `a[..^1]`): later RFC if wanted.

## Migration / edition impact

None. This only adds meaning to syntax that was not valid before.
