# Architecture notes

> **Status:** Living documents.

One document per subsystem describing how it is built and why:

- [`bootstrap.md`](bootstrap.md): Stage 0 and the bootstrap chain.
- [`stage1.md`](stage1.md): Stage 1 (`envoc1`).
- [`stage2.md`](stage2.md): Stage 2 (`envoc`), the self-hosting compiler.
- [`ports-and-adapters.md`](ports-and-adapters.md): the shape of the platform.
- [`library.md`](library.md): the standard platform as built in M4 (layers, module
  resolution, the `platform` binding, adapters, conformance).
- [`tooling.md`](tooling.md): the `envo` tool, packages and the Process port (M5).
