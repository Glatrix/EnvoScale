# `lib/ports` — all port interfaces

> **Status:** Experimental (M4): `IConsole`, `IFileSystem`, `IClock`, `IEntropy`,
> `IEnvironment` and `IoError`, in `ports.envo`.

Every port interface lives here and nowhere else. Each one has a reference adapter in
`adapters/os/none`, native adapters for Windows and Linux, and a conformance suite in
`tests/conformance/<port>/` that every adapter must pass
([`library.md`](../../docs/architecture/library.md)).

Ports are interfaces used through generic bounds (PLAN D22), because Envo-S1 has no
dynamic interface values. Their methods take `ref this`, so an adapter can keep state.

Later ports come with the milestones that need them (D24): `Threads` and `Executor`
(M6), `NetStack` (M7), `Window`, `GpuDevice`, `AudioDevice`, `Clipboard` and
`FontSource` (M8).

## Ports used

defines them all; depends on none
