# `compiler/sema`

> **Status:** The checker is in (M3.4): names, types, generics, interfaces, closures, enums,
> views and namespaces, with the same results as `envoc1 check`. The move and borrow
> checks come in M3.5.

Semantic analysis: name resolution, type inference and checking, interface (trait)
resolution, borrow and lifetime checking, and comptime evaluation. See
[`docs/architecture/stage2.md`](../../docs/architecture/stage2.md).
