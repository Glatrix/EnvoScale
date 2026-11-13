# `compiler/sema`

> **Status:** The whole checker is in (M3.4, M3.5): names, types, generics, interfaces,
> closures, enums, views, namespaces, and the move and borrow checks, with the same results
> as `envoc1 check`.

Semantic analysis: name resolution, type inference and checking, interface (trait)
resolution, borrow and lifetime checking, and comptime evaluation. See
[`EnvoScale/architecture/stage2.md`](https://github.com/envoscale/EnvoScale/blob/main/architecture/stage2.md).
