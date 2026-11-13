# `adapters/`

The only place code may talk to an operating system, a driver, a browser or an editor.
Each adapter implements the [ports](../lib/ports/README.md) the library defines, for one
platform.

| Folder | What |
|---|---|
| [`os/windows`](os/windows) | Windows: files, processes, console, terminal, network, windows (Win32), the clipboard, Direct3D 12 |
| [`os/linux`](os/linux) | Linux, x86-64 and AArch64: the same ports over system calls, windows and the clipboard over X11 |
| [`os/wasm`](os/wasm) | The browser and Node.js, over the JavaScript host |
| [`os/none`](os/none) | The reference adapters: in memory, for the tests and as a fallback |
| [`interop/js`](interop/js) | The JavaScript host that runs Envol's WebAssembly |
| [`editors/vscode`](editors/vscode) | The VS Code extension, a client of `envo lsp` |

Rules:

- An adapter may use `lib/` and its own folder, never another adapter. `lib/` never uses
  `adapters/`.
- Operating system and driver interfaces are bound by hand: no vendor SDK headers and no
  binding generators.
- Every port has a reference adapter in `os/none` that passes the port's conformance suite
  in [`tests/conformance`](../tests/conformance).

Bringing EnvoScale to a new platform: [docs/porting/CHECKLIST.md](../docs/porting/CHECKLIST.md).
