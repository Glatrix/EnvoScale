# Stage 1 — `envoc1`

> **Status:** Specified (M2.1); implementation starts with M2.2. The plan, increments and
> decisions D11–D15 are in [`docs/PLAN.md`](../../docs/PLAN.md). It accepts
> [Envo-S1](../../docs/spec/envo-s1.md) and compiles through [EIR v1](../../docs/spec/eir.md).

A fuller compiler written in Envo-Core and built by `envoc0`. It adds generics, interfaces, closures, a basic borrow checker and EIR, which is enough to compile the real compiler in `compiler/`. It stays buildable forever as part of the diverse double-compiling trust check.

How it will be built (decision D11): `bootstrap/stage1/` is a multi-file Envo-Core
program, compiled by `envoc0 build` with the files in the order listed in `files.txt`
(`main.envo`, the entry file, first). Every Envo-Core test runs under both `envoc0` and
`envoc1` and must give the same result (D14).
