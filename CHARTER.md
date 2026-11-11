# EnvoScale Charter

These principles are binding on every file in this repository. They are copied
verbatim from §2 of the founding brief. Changing them requires an RFC
(see [`docs/rfcs/`](docs/rfcs/README.md)) that is accepted before the change lands.

---

## Non-Negotiable Principles

### 2.1 Zero third-party dependencies
- The core, compiler, standard library, and all `envo.*` modules use **no external libraries, packages, or code generators**.
- **What is allowed:** interfaces the *operating system or hardware itself* provides (syscalls, `kernel32.dll`/`ntdll.dll`, `libSystem` on macOS where syscalls are unstable, GPU driver APIs such as Vulkan/Metal/D3D12/WebGPU, browser APIs). These are reached **only through adapters** (§2.3), with hand-written bindings. No vendor SDK headers or binding generators.
- **Specs and data are not dependencies.** Implementing a published standard (TLS 1.3, PNG, glTF, UTF-8, SPIR-V, an RFC test vector set) is encouraged. Test vectors from NIST, the RFCs, Wycheproof-style suites, etc. may be committed as data files with attribution.
- **Infrastructure is reached through thin adapters only.** For example, CI workflow files may run on GitHub Actions, but they only call `envo` commands; switching CI providers means replacing one small adapter folder.

### 2.2 Progressive disclosure: simple door, full-control door
Every API offers two entrances:
- **The simple door:** sensible defaults, templates, a short hello world.
- **The full-control door:** every default can be overridden, and every abstraction can be bypassed for the layer beneath it.

Rule: the simple door is built **on top of** the full-control door, never as a separate code path. Beginners and experts use the same system.

Skill levels the design must serve:

| Level | User | Example |
|---|---|---|
| 0 | Never coded before | `print("Hello, World!")` as a script |
| 1 | Builds apps from templates | A website in 3 lines with Lumen templates |
| 2 | Typed application developer | Modules, structs, generics, ownership defaults |
| 3 | Systems programmer | `unsafe`, allocators, memory layout, FFI |
| 4 | Toolchain / platform hacker | Inline asm, custom adapters, new backends |

### 2.3 Ports and adapters (hexagonal architecture)
- **Core** code is pure and platform-free. It defines **ports**: small interfaces describing a capability (`FileSystem`, `Clock`, `Entropy`, `Threads`, `Window`, `GpuDevice`, `NetStack`, `AudioDevice`, `Console`, …).
- **Adapters** implement ports for one specific platform (`adapters/os/windows`, `adapters/gpu/vulkan`, …).
- **The dependency direction is one-way:** adapters depend on core; core *never* imports an adapter. This is enforced by the build system: a violation is a compile error.
- **Every port ships with a reference adapter:** an in-memory/null/software version used for tests and as a universal fallback (for example, a software rasterizer for `GpuDevice`, or an in-memory file system for `FileSystem`).
- **Adapters are selected** by target triple and build profile, or explicitly by the user.
- **Porting EnvoScale to a brand-new OS** should require only: (1) an OS adapter set, (2) an object-file/executable format writer if new, and (3) a calling-convention description if new. Document this in `docs/porting/CHECKLIST.md` with a **port conformance test suite** that proves an adapter is complete.

### 2.4 Everything-agnostic
- **CPU:** x86-64, AArch64, RISC-V 64, WebAssembly, and later others.
- **OS:** Windows, Linux, macOS, Web (WASM), bare metal, and later others.
- **GPU API:** Vulkan, D3D12, Metal, WebGPU, and software.
- **Editor:** a standard LSP server, so any editor works.
- **Cloud and CI:** adapters only.

### 2.5 Safe by default, unsafe on request
- Memory safety, thread safety (no data races), and null safety are on by default.
- `unsafe` unlocks raw pointers, inline asm, and unchecked operations. It is lexically scoped and easy to audit (`envo audit unsafe` lists every use).
- Scripts run **sandboxed with capability permissions** by default (`envo run app.envo --allow net,fs:./data`), similar to Deno's model.

### 2.6 Study list (inspiration only, never copied code)
Rust (ownership, traits, editions, error messages), C#/Roslyn (syntax, properties, LINQ, async, source generators), Zig (comptime, cross-compilation, explicit allocators), Go (tooling simplicity, fast compiles), Swift/SwiftUI (declarative UI, ARC), Jai/Odin (data-oriented design), LLVM/Cranelift/QBE/TCC (backends, IR, register allocation), stage0/live-bootstrap/GNU Mes (bootstrapping from a hex seed), Plan 9 and SerenityOS (whole-system coherence), Flutter/Skia/Dear ImGui/Slint (rendering and UI), Bevy/Godot (ECS, engines), PyTorch/tinygrad/llama.cpp (tensors, autograd, inference), BoringSSL/libsodium/Monocypher (crypto API design and constant-time discipline), Deno/Bun (all-in-one tooling, permissions).
