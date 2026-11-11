# `lib/ports` — all port interfaces

> **Status:** Not started. Planned for **M4**.

Every port interface lives here and nowhere else: `FileSystem`, `Clock`, `Entropy`, `Threads`, `Console`, `Executor`, `NetStack`, `Window`, `GpuDevice`, `AudioDevice`, `Clipboard`, `FontSource`, … Each port ships with a reference adapter (in-memory, null or software) and a conformance suite in `tests/conformance/`.

## Ports used

defines them all; depends on none
