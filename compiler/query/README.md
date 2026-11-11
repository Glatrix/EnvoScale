# `compiler/query`

> **Status:** Not started. Planned for **M3**.

The incremental, memoized query engine (in the spirit of rustc/Roslyn). Every compiler stage is a query; results are cached and invalidated precisely. Powers fast rebuilds and the LSP.
