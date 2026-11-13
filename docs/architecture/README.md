# Architecture notes

> **Status:** Living documents.

One document per subsystem describing how it is built and why:

- [`stage2.md`](stage2.md): the compiler (`envoc`). How it is built up from assembly is
  in [EnvoScaleAsm](https://github.com/envoscale/EnvoScaleAsm).
- [`ports-and-adapters.md`](ports-and-adapters.md): the shape of the platform.
- [`library.md`](library.md): the standard platform as built in M4 (layers, module
  resolution, the `platform` binding, adapters, conformance).
- [`tooling.md`](tooling.md): the `envo` tool, packages and the Process port (M5).
- [`script-runtime.md`](script-runtime.md): `envo run`, the EIR interpreter and permissions (M6).
- [`network.md`](network.md): the Net port, HTTP and TLS (M7).
- [`graphics.md`](graphics.md): the Terminal and Window ports, drawing, fonts and UI (M8).
