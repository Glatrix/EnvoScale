# Principles

The rules every part of EnvoScale follows. Changing one takes an accepted
[RFC](rfcs/README.md).

## No third-party code

The compiler, the standard library and every `envo.*` module are written here, with no
outside libraries, packages or code generators.

What is allowed is what the operating system or the hardware itself offers: system calls,
`kernel32.dll`, `libSystem` on macOS, GPU driver APIs (Direct3D 12, Vulkan, Metal,
WebGPU) and browser APIs. Those are reached only from `adapters/`, through bindings
written by hand.

Published standards are not dependencies: implementing TLS 1.3, PNG or UTF-8 from the
spec is encouraged, and official test vectors may be committed as data, with their source
named.

## A simple door and a full-control door

Every API has a short way in, with sensible defaults, and a way to control every detail.
The simple door is built on top of the full one, never beside it, so beginners and experts
use the same code.

## Ports and adapters

Code in `lib/` never touches an operating system. It defines **ports**, small interfaces
for a capability (files, clock, entropy, window, GPU, network, console), and code in
`adapters/` implements them for one platform each.

- `lib/` never imports `adapters/`; `./build.sh check` enforces it.
- Every port has a reference adapter (in memory, or in software) used by the tests and as
  a fallback.
- Bringing EnvoScale to a new OS means writing its adapters, and an executable format
  and calling convention if they are new: [porting/CHECKLIST.md](porting/CHECKLIST.md).

## Any CPU, OS, GPU and editor

x86-64, AArch64 and WebAssembly today; Windows, Linux, macOS and the browser; Direct3D 12
and a software renderer; any editor through `envo lsp`. Each new one is an adapter, not a
rewrite.

## Safe by default

Memory safety, no data races and no null by default. `unsafe` unlocks raw pointers,
inline assembly and unchecked operations, and is easy to find. Scripts run sandboxed:
`envo run app.envo --allow net,fs:./data`.

## Learn from everyone, copy from no one

Other languages and systems are studied freely (Rust, C#, Zig, Go, Swift, LLVM, Deno and
many more); code is never copied from them.
