# EnvoScale — Master Build Prompt

> **How to use this file:** Give this whole document to an AI coding agent (or a team) as the founding brief for the `EnvoScale` GitHub repository. It is the source of truth for vision, rules, architecture, and order of work. Anything not covered here is decided through the RFC process in §15, never by improvising.

---

## 0. Your Role and Operating Rules

You are the founding engineer and architect of **EnvoScale** ("Environment Scale"). You are building the first stage of a project meant to grow for decades. Act like it:

1. **Read this whole document before writing any code.** Then write `docs/PLAN.md`: your understanding, open questions, and a concrete task breakdown for the current milestone (§16).
2. **Work milestone by milestone, in order.** Do not scaffold 40 empty modules and call it done. A small amount of working, tested code is worth more than a large amount of stubbed code.
3. **Never fake completion.** No placeholder functions that return fake success. Unfinished work has a `TODO(#issue-or-milestone): reason` and an entry in `STATUS.md`.
4. **Keep `STATUS.md` current.** It lists every subsystem with a stability tier (§14.4), what works, what's missing, and the next step.
5. **Everything is tested.** A feature without tests does not exist (§14.2).
6. **Write it down.** Design decisions go in `docs/architecture/` or an RFC (§15). Code comments explain *why*, not *what*.
7. **When this document is ambiguous or impossible as written, stop and write an RFC** describing the conflict and your proposed resolution, instead of quietly deviating.
8. **Learn from everyone, copy from no one.** You may study any codebase, paper, or spec in the world (see §2.6). You must write original implementations. Never paste code from another project, and respect all licenses.

---

## 1. Vision

EnvoScale is a **modern, all-in-one, everything-agnostic computing environment**: one language, one toolchain, and one standard platform covering systems programming, scripting, desktop apps, websites, terminals, 2D/3D graphics, AI, cryptography, networking, and more.

It must be:

- **Easy for beginners.** "Hello World" for *any* domain fits in 1–3 lines.
- **Unlimited for experts.** Every layer can be opened up, down to inline assembly, custom allocators, memory layout, and custom backends.
- **Self-sufficient.** No third-party packages. Whatever EnvoScale needs, it builds.
- **Self-hosting.** The compiler starts life in assembly, is rewritten in its own language, and compiles itself.
- **Future-proof.** Any new OS, CPU, GPU API, or platform can be supported by writing an adapter, without touching the core.

This first repository is the foundation. It does not need to contain everything on day one, but its **structure must already have a clear place for everything** described here.

### 1.1 Naming

| Thing | Name | Notes |
|---|---|---|
| Project / repo | **EnvoScale** | The whole environment |
| Language | **Envo** | Source files: `.envo` |
| Compiler binary | `envoc` | Usually invoked through `envo build` |
| Unified CLI | `envo` | build, run, test, fmt, doc, pkg, repl… |
| Intermediate representation | **EIR** (Envo IR) | Textual form: `.eir` |
| Envo assembly | `.eas` | Intel-style syntax; used by bootstrap and `asm` blocks |
| Data/config format | **EON** (Envo Object Notation) | `.eon`; a strict literal subset of Envo syntax |
| Design language | **Lumen** | The Mac-like visual system (§9) |
| Standard modules | `envo.*` | e.g. `envo.gfx`, `envo.crypto` |

Codenames may be revised by RFC; module paths must stay stable once marked stable.

---

## 2. Non-Negotiable Principles

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

---

## 3. The Envo Language

### 3.1 Design summary
**"Rust's semantics with C#'s syntax and approachability."**

- C#-style, type-first syntax: braces, `var`, `class`/`struct`/`enum`/`interface`, properties, `=>` expression bodies, `$"..."` interpolation, `namespace`, `using`/`use`, attributes `[...]`, `async`/`await`, top-level statements.
- Rust-style semantics: ownership and borrowing, no garbage collector, algebraic enums with payloads, exhaustive `match`, `Result`/`Option` instead of exceptions and null, traits (as `interface`), monomorphized generics, zero-cost abstractions, and a strong compile-time evaluator.
- **Simpler than Rust:** lifetimes are inferred in nearly all code. Explicit lifetimes exist but are rarely needed. Classes give beginners shared, reference-counted objects without fighting the borrow checker.

### 3.2 Hello world (all valid Envo)
```envo
print("Hello, World!")
```
That is a complete program in both script mode and compiled mode. Top-level statements are allowed in the entry file. A prelude (`envo.prelude`) is implicitly imported.

### 3.3 Core syntax tour (normative examples; the spec must make these work)
```envo
namespace Shapes;

use envo.math;

// Value type: stack-allocated, owned, moved by default (Copy if all fields are Copy)
public struct Point {
    public f32 X;
    public f32 Y;
    public f32 Length => math.sqrt(X * X + Y * Y);   // computed property
}

// Algebraic enum with payloads
public enum Shape {
    Circle(Point center, f32 radius),
    Rect(Point min, Point max),
}

// Interface = trait. Implemented explicitly or by extension.
public interface IArea {
    f32 Area();
}

impl IArea for Shape {
    f32 Area() => match this {
        Circle(_, r)    => math.PI * r * r,
        Rect(a, b)      => (b.X - a.X) * (b.Y - a.Y),
    };
}

// Generics with constraints, monomorphized
public T Largest<T>(in Span<T> items) where T : IComparable<T> {
    var best = items[0];
    foreach (var it in items) if (it > best) best = it;
    return best;
}

// Errors are values; `?` propagates
public Result<string, IoError> ReadConfig(in string path) {
    var text = fs.ReadText(path)?;
    return Ok(text.Trim());
}

// Nullable sugar: T? == Option<T>
string? FindUser(int id) => id == 1 ? "ada" : null;

// Class = heap-allocated, automatically reference-counted, `weak` breaks cycles
public class Node {
    public string Name { get; set; }
    public List<Node> Children { get; } = new();
    public weak Node? Parent;
}

// async/await on a pluggable executor
async Result<string, NetError> Fetch(string url) => await http.Get(url)?.Text();

// Pipelines (LINQ-like, zero allocation when possible)
var total = orders.Where(o => o.Paid).Select(o => o.Amount).Sum();
```

### 3.4 Ownership model (the simplified version)
| Syntax | Meaning | Rust equivalent |
|---|---|---|
| `T x` (param) | Takes ownership (move), or copy for Copy types | `x: T` |
| `in T x` | Shared, read-only borrow | `x: &T` |
| `ref T x` | Exclusive, mutable borrow | `x: &mut T` |
| `out T x` | Must-initialize output borrow | `&mut MaybeUninit<T>` (safe) |
| `class` | Shared ownership (ARC; atomic only when it crosses threads, determined by inference) | `Rc`/`Arc` |
| `weak T` | Non-owning reference to a class instance | `Weak` |
| `*T` | Raw pointer, `unsafe` only | `*mut T` |

- The borrow checker uses non-lexical, flow-sensitive analysis. Error messages must explain the problem in plain words, show where it happens, and suggest a fix.
- `Sendable` / `Shareable` auto-interfaces are inferred and give data-race freedom.
- **Allocators are explicit at the full-control door, implicit at the simple door:** collections use the context allocator by default and accept a custom allocator (`new List<int>(alloc: arena)`). `[NoAlloc]` on a function is verified by the compiler.

### 3.5 Compile-time power
- `const` functions and `comptime { }` blocks run at compile time on the same EIR interpreter that powers script mode.
- **Attribute-driven generators** (like C# source generators, hygienic, written in Envo): `[Derive(Eq, Hash, Debug, Eon, Json)]`.
- Reflection is compile-time by default, with opt-in runtime type info (`[Reflect]`).
- Conditional compilation: `#if target.os == "windows"` (typed expressions, not string macros).

### 3.6 Systems-level control
- **Inline assembly:** `asm x86_64 { ... }` with typed operand bindings, clobber lists, and per-architecture blocks.
- **Intrinsics:** `simd.f32x8`, CPU feature queries, and `[TargetFeature("avx2")]` with automatic runtime multiversioning (`[Multiversion("avx512", "avx2", "base")]`).
- **Layout:** `[Layout(C)]`, `[Layout(Packed)]`, `[Align(64)]`, explicit field offsets, bitfields.
- **ABI control:** `extern "C"`, `extern "sysv64"`, `extern "win64"`, naked functions, `[Export("name")]`, custom sections, a linker script equivalent in EON.
- **No hidden costs:** no hidden allocations, no hidden copies of non-Copy types, no exceptions, no runtime type checks unless asked for.
- **Optimization hints:** `[Inline]`, `[NoInline]`, `[Cold]`, `[Hot]`, `likely()`/`unlikely()`, `assume()`, `[Pure]`.

### 3.7 Two execution modes, one language
| | **Compiled (AOT)** | **Script runtime** |
|---|---|---|
| Command | `envo build` | `envo run file.envo`, `envo repl`, shebang `#!/usr/bin/env envo` |
| Output | Native executables/libraries, WASM | Executes immediately |
| Engine | Full optimizer + native backend | EIR bytecode VM, with a tiered JIT that reuses the same backends |
| Semantics | **Identical.** Script mode is not a dialect. | **Identical.** |

A conformance suite runs every spec test in both modes and requires identical output.

### 3.8 Language evolution
- **Editions** (e.g., `edition = "2027"` in the manifest) allow breaking syntax changes without breaking old code. Editions interoperate within one build.
- The language spec lives in `docs/spec/` as numbered chapters, and each normative rule links to tests that verify it.

---

## 4. Toolchain Architecture

### 4.1 Compiler pipeline
```
source (.envo)
  → Lexer → Parser → AST (lossless CST kept for tooling/formatter)
  → Name resolution → Type inference & checking → Trait resolution
  → Borrow & lifetime checking → Comptime evaluation
  → Lowering → EIR (SSA, typed, versioned, textual + binary forms)
  → Optimizer (pass manager, see 4.3)
  → Backend: instruction selection → register allocation → scheduling → emission
  → Envo assembler (machine code) → Envo linker
  → ELF | PE/COFF | Mach-O | WASM | flat binary
  + debug info: DWARF | CodeView/PDB
```
- **Query-based, incremental compilation** (like rustc/Roslyn): every stage is a cached, memoized query, which powers fast rebuilds and the LSP.
- **Parallel by default:** parse, check, and codegen per module across threads.
- **Deterministic and reproducible:** the same inputs give byte-identical outputs on every host.

### 4.2 Backends
| Tier | Targets |
|---|---|
| Tier 1 (initial) | x86-64 (Windows PE, Linux ELF) |
| Tier 1 (next) | AArch64 (macOS Mach-O, Linux ELF), WASM32 |
| Tier 2 | RISC-V 64, bare metal (flat/ELF) |
| Shader targets | SPIR-V (Vulkan), WGSL (WebGPU), MSL text (Metal), DXIL (D3D12, later) |

Shaders are **written in Envo** (a restricted, GPU-safe subset marked `[Shader]`) and compiled by the same compiler. There is no separate shading language.

### 4.3 Optimization (the "all assembly optimizations" requirement)
Levels: `-O0` (fast compile, debuggable), `-O1`, `-O2` (default release), `-O3` (aggressive), `-Os`/`-Oz` (size). Each pass can be toggled individually (`--pass`, `--no-pass`), and results can be inspected with `envo build --emit ast|eir|eir-opt|asm|obj`.

Required passes over time: constant folding/propagation (SCCP), dead code elimination, global value numbering, CSE, LICM, inlining with cost model, scalar replacement of aggregates, mem2reg, loop unrolling, loop vectorization and SLP vectorization, strength reduction, induction variable simplification, tail-call optimization, bounds-check elimination, devirtualization, escape analysis (stack-promote ARC objects), jump threading, branch layout, peephole optimization, **linear-scan register allocation for debug builds and graph-coloring/PBQP for release**, instruction scheduling per micro-architecture model, `-march`/`-mtune` CPU models, LTO, PGO (`envo build --profile-generate` / `--profile-use`), and binary size passes (identical code folding, section GC).

Every optimization must have: an RFC or design note, unit tests on EIR snippets, and differential tests that compare `-O0` vs `-On` results.

### 4.4 Envo assembler and linker
- The assembler (`envo asm`) understands `.eas` and is also used for `asm { }` blocks. It is table-driven: instruction encodings live in data files per architecture.
- The linker supports static linking, dynamic libraries, symbol visibility, section GC, ICF, and import libraries for Windows system DLLs, written without system linker tools.

---

## 5. Bootstrap: From Assembly to Self-Hosting

This is a **required** part of the project and an important trust guarantee.

### 5.1 The ladder
```
Stage S  (seed)      Tiny hex-coded assembler, verifiable by eye
   ↓ assembles
Stage 0  (assembly)  envoc0: compiles "Envo-Core" subset → x86-64 machine code. Written in .eas.
   ↓ compiles
Stage 1  (Envo-Core) envoc1: a fuller compiler written in Envo-Core
   ↓ compiles
Stage 2  (Envo)      envoc:  the real compiler, written in full Envo
   ↓ compiles itself
Stage 3              envoc built by Stage 2  →  must be byte-identical to Stage 2's rebuild (fixed point)
```

### 5.2 Stage S — the seed
- `bootstrap/seed/` contains a minimal assembler written as **commented hexadecimal machine code** (`seed.hex`), small enough to audit (target: under 4 KB of output).
- Hex is converted into a binary using **only OS-provided tools**: PowerShell on Windows (`bootstrap/seed/hex2bin.ps1`), POSIX `sh` + `printf`/`od` on Linux (`hex2bin.sh`).
- The seed supports only what Stage 0's source needs: labels, a fixed subset of x86-64 instructions, data directives, and writing a PE or ELF file.
- It may be built as a short chain (hex0 → hex1 with labels → asm0) in the style of stage0/live-bootstrap, if that keeps each step small and auditable.

### 5.3 Stage 0 — the assembly compiler (`bootstrap/stage0/`)
- Written in `.eas` (Intel-style syntax, NASM-like so it is readable).
- **Targets:** x86-64 Windows (PE) and x86-64 Linux (ELF). All OS interaction goes through a tiny platform shim (`platform/windows.eas` via kernel32 imports; `platform/linux.eas` via syscalls) with roughly 8 functions: `open`, `read`, `write`, `close`, `alloc`, `free`, `exit`, `args`.
- Compiles **Envo-Core**, a deliberately small subset defined in `docs/spec/envo-core.md`: integer types, `bool`, raw pointers, fixed arrays, slices, structs, simple tagged enums, functions, `if`/`while`/`for`/`return`/`break`/simple `match`, modules as flat files, string literals, and an arena allocator. No generics, traits, borrow checking, or closures.
- **Goal: correct, small, and auditable, not fast.** Single-pass or two-pass, no optimizer. It writes machine code and the executable header directly (no separate assembler needed). Target: under ~15k lines of assembly, heavily commented.

### 5.4 Pragmatic path to the seed
Building the hex seed is slow, careful work. To avoid blocking progress:
1. **Phase A:** Stage 0 may first be assembled with a mainstream assembler through an **optional bootstrap adapter** (`adapters/bootstrap/nasm/` or `fasm/`). This adapter is outside the core and never required to *use* EnvoScale.
2. **Phase B (required before 1.0):** The seed ladder can build Stage 0 on its own. CI checks that **seed-built and adapter-built Stage 0 binaries are byte-identical.**
3. Once Stage 2 exists, `envo asm` can also assemble `bootstrap/stage0/*.eas`, which closes the loop. CI checks that this result is byte-identical too.

### 5.5 Stages 1–3
- **Stage 1** (`bootstrap/stage1/`): written in Envo-Core. It adds generics, interfaces, closures, the borrow checker, and EIR, so it can compile the real compiler.
- **Stage 2** (`compiler/`): the real compiler, in idiomatic full Envo, with the full optimizer and all backends. **From this point on, all compiler development happens here.**
- **Stage 3 fixed-point check:** Stage 2 compiles itself → binary A; A compiles itself → binary B; **A == B byte-for-byte.** This runs in CI on every change to `compiler/`.
- **Trust:** keep Stage 0 and Stage 1 permanently buildable and tested (diverse double-compiling defends against "trusting trust" attacks). Document the full chain in `bootstrap/README.md`, with a single command for each OS: `./bootstrap.sh` / `.\bootstrap.ps1`.

---

## 6. Repository Layout

```
EnvoScale/
├── README.md                 # What, why, 60-second quick start, hello-world gallery
├── CHARTER.md                # The principles in §2, verbatim and binding
├── STATUS.md                 # Live status of every subsystem + stability tier
├── CONTRIBUTING.md  SECURITY.md  CODE_OF_CONDUCT.md  LICENSE
├── envo.eon                  # Root workspace manifest
├── bootstrap.sh / bootstrap.ps1
│
├── bootstrap/
│   ├── seed/                 # hex seed + hex2bin scripts (OS tools only)
│   ├── stage0/               # .eas compiler for Envo-Core
│   │   ├── src/              # lexer.eas, parser.eas, codegen.eas, pe.eas, elf.eas …
│   │   └── platform/         # windows.eas, linux.eas
│   └── stage1/               # compiler written in Envo-Core
│
├── compiler/                 # Stage 2 envoc (in Envo)
│   ├── driver/  query/  diag/
│   ├── syntax/               # lexer, parser, CST/AST
│   ├── sema/                 # resolve, types, traits, borrowck, comptime
│   ├── eir/                  # IR definition, builder, verifier, text/binary formats
│   ├── opt/                  # pass manager + one folder per pass
│   ├── backend/{x86_64,aarch64,riscv64,wasm,spirv,wgsl,msl}/
│   ├── asm/                  # table-driven assembler
│   ├── link/{elf,pe,macho,wasm}/
│   └── debuginfo/{dwarf,codeview}/
│
├── runtime/                  # program startup, panic, ARC, EIR VM, JIT tiering
│
├── lib/                      # The standard platform (pure core code, ports only)
│   ├── core/                 # no OS, no allocator: primitives, Option/Result, traits, slices, fmt
│   ├── alloc/                # allocators, Box, Vec/List, String, Map, Set
│   ├── ports/                # ALL port interfaces live here
│   ├── std/                  # io, fs, path, process, env, time, thread, sync, async
│   ├── prelude/
│   └── envo/                 # domain modules (see §7)
│       ├── text/  eon/  json/  collections/  math/  simd/  random/  time/
│       ├── crypto/  net/  http/  compress/  image/  font/  audio/  db/
│       ├── cli/  term/  gfx/  gpu/  ui/  lumen/  web/  render3d/  ai/
│       └── test/  bench/  log/  reflect/
│
├── adapters/                 # The ONLY place platform-specific code may live
│   ├── os/{windows,linux,macos,wasm,none}/
│   ├── window/{win32,wayland,x11,cocoa,web}/
│   ├── gpu/{vulkan,d3d12,metal,webgpu,software}/
│   ├── audio/{wasapi,alsa,pulse,coreaudio,webaudio,null}/
│   ├── input/  clipboard/  fonts-system/
│   ├── interop/{c-abi,js}/
│   ├── ai-remote/            # HTTP adapters to external model APIs (optional)
│   ├── ci/github/            # CI adapter: thin workflow files that only call `envo`
│   └── bootstrap/{nasm,fasm}/  # optional, Phase A only (§5.4)
│
├── tools/                    # All in Envo
│   ├── envo/                 # unified CLI
│   ├── lsp/  fmt/  lint/  doc/  dbg/  prof/  fuzz/  pkg/
│
├── templates/
│   ├── projects/             # `envo new <template>`: console, app, site, game, ai, lib, cli
│   └── lumen/                # site/app templates: Landing, Docs, Blog, Dashboard, Portfolio, Store
│
├── examples/                 # 00-hello, 01-cli, 02-window, 03-site, 04-3d, 05-ai …
├── tests/
│   ├── spec/                 # one folder per spec chapter; `// expect:` annotations
│   ├── conformance/          # ports/adapters conformance suites
│   ├── bootstrap/            # stage equivalence + fixed-point checks
│   ├── golden/  diff/  fuzz/  bench/
│   └── vectors/              # official test vectors (crypto, formats), with attribution
└── docs/
    ├── PLAN.md
    ├── spec/                 # language spec (numbered chapters) + envo-core.md + eir.md + eas.md + eon.md
    ├── architecture/         # one doc per subsystem
    ├── rfcs/                 # 0000-template.md, numbered RFCs
    ├── porting/CHECKLIST.md
    ├── guides/               # beginner → expert learning path
    └── lumen/                # design language spec (§9)
```

**Enforced rules:**
- `lib/**` may import only `lib/**`. Importing `adapters/**` from `lib/**` is a build error.
- `adapters/<kind>/<name>/` may import `lib/**` and its own folder only.
- Each module folder contains: `README.md` (purpose, simple door, full-control door), source, `tests/`, and an `examples/` snippet.

---

## 7. Standard Platform Modules

Each module below needs: a **simple door** (hello world ≤ 3 lines), a **full-control door**, ports it depends on, and a stability tier. Start with the ones scheduled for the current milestone (§16).

### 7.1 Foundations
- **`core` / `alloc` / `std`:** layered like Rust's (`core` works on bare metal; `alloc` adds heap; `std` adds OS through ports).
- **`envo.text`:** UTF-8 everywhere, Unicode segmentation/normalization/case mapping (tables generated from Unicode data files by an Envo tool), formatting, a regex engine (linear-time by default, backtracking opt-in).
- **`envo.eon` / `envo.json`:** serialization through `[Derive(Eon, Json)]`. Also a compact binary format.
- **`envo.collections`:** Vec/List, Deque, Map (SwissTable-style), BTreeMap, Set, intrusive lists, arenas, slot maps.
- **`envo.math` / `envo.simd`:** scalar math, vectors/matrices/quaternions, big integers, SIMD types with portable fallbacks.
- **`envo.async`:** the executor is a port. Adapters use IOCP (Windows), io_uring/epoll (Linux), kqueue (macOS), and the browser event loop (web).
- **`envo.compress`:** DEFLATE/zlib/gzip, LZ4-style, and a Zstandard-compatible codec.
- **`envo.image` / `envo.font` / `envo.audio`:** PNG, JPEG, QOI, WebP decode (and encode where reasonable); TrueType/OpenType parsing, rasterization, and text shaping (basic shaping first, full complex-script shaping later); WAV/FLAC/Opus-class codecs over time.
- **`envo.db`:** an embedded transactional storage engine (B-tree + WAL), with a query layer later.
- **`envo.test` / `envo.bench` / `envo.log`:** built into the CLI (`envo test`, `envo bench`).

### 7.2 Cryptography — `envo.crypto`
- **Hashes:** SHA-2, SHA-3/SHAKE, BLAKE2, BLAKE3. **MAC/KDF:** HMAC, HKDF, PBKDF2, Argon2id, scrypt.
- **Symmetric/AEAD:** AES (with AES-NI/ARMv8 crypto acceleration and a constant-time software fallback), AES-GCM, ChaCha20-Poly1305, XChaCha20-Poly1305.
- **Asymmetric:** X25519, Ed25519, ECDSA/ECDH P-256/P-384, RSA (for interoperability), plus **post-quantum** ML-KEM and ML-DSA.
- **CSPRNG** seeded from the `Entropy` port.
- **Protocols:** TLS 1.3 (client and server), X.509 parsing/validation, and later Noise and SSH.
- **Rules:**
  - Implement only standardized, published algorithms. Never invent custom crypto.
  - Constant-time code paths, enforced by a lint and tested with timing-variance tests.
  - Every algorithm is tested against official test vectors in `tests/vectors/`.
  - Secrets are zeroed on drop (`Secret<T>`).
  - The whole module stays **Experimental** (§14.4) until an independent audit. Say so in its README and in `SECURITY.md`.
- **Simple door:** `print(crypto.sha256("hello").Hex())`, `var box = crypto.SealedBox.Encrypt(key, data)`.

### 7.3 Networking — `envo.net` / `envo.http`
TCP/UDP/DNS, HTTP/1.1, HTTP/2, HTTP/3 + QUIC, WebSocket, and TLS through `envo.crypto`. Client and server share the same types.
```envo
use envo.http;
serve(8080) { get("/") => "Hello, World!" }
```

### 7.4 Terminal / CLI engine — `envo.cli` + `envo.term`
- **`envo.cli`:** declarative argument parsing from attributes (subcommands, help, completion scripts, colors, validation), prompts, progress bars, spinners, and tables.
- **`envo.term`:** a VT/ANSI engine with a Windows console adapter, raw mode, input events, and a cell-buffer renderer with diffing.
- **TUI:** the same component model as `envo.ui` rendered into terminal cells (see §8.3). One UI codebase can target desktop, web, *and* terminal.
- **Future:** an Envo-based shell and a GPU-accelerated terminal emulator built on `envo.gfx`.
```envo
[Command("greet")] void Greet(string name = "World") => print($"Hello, {name}!")
```

### 7.5 AI — `envo.ai`
- **Tensors:** n-dimensional, strided, with dtypes f32/f16/bf16/int8/int4. Kernels for CPU (SIMD, multithreaded) and GPU (compute shaders written in Envo through the `GpuDevice` port).
- **Autograd**, layers, optimizers (SGD, Adam/AdamW), losses, data loaders.
- **Model building blocks:** MLP, CNN, attention/transformer blocks, RoPE, KV cache, sampling.
- **Tokenizers:** BPE/Unigram, written from scratch.
- **Model formats:** readers for widely used open weight formats (safetensors-style, GGUF-style) implemented from their public specs, plus a native `.envomodel` format. Quantization (int8/int4, k-quant style).
- **Inference serving** through `envo.http`. Embeddings and a vector index (HNSW) for retrieval.
- **Remote model APIs** through `adapters/ai-remote/` only, never in core.
```envo
use envo.ai;
print(ai.Load("models/tiny.gguf").Ask("Say hello"))
```

---

## 8. Graphics — `envo.gpu`, `envo.gfx`, `envo.render3d`

### 8.1 `envo.gpu` (the low layer)
A modern explicit GPU abstraction (devices, queues, buffers, textures, pipelines, bind groups, command encoders, sync), modeled on what Vulkan, Metal, D3D12, and WebGPU have in common. Adapters live in `adapters/gpu/*`. **The `software` adapter is mandatory** and must be able to run every test (headless CI, new OSes, and fallback).

### 8.2 `envo.gfx` (2D, web and desktop)
Paths, Béziers, fills/strokes, gradients, high-quality anti-aliasing, clipping, blending, images, text rendering (via `envo.font`), blur/vibrancy effects, and a retained compositor with layer caching. One API; GPU-accelerated when available, software otherwise. On the web it renders through WebGPU, falling back to Canvas2D through the `js` interop adapter.
```envo
use envo.gfx;
window("Hello") { canvas(c => c.Text("Hello, World!", 24, 40)) }
```

### 8.3 `envo.ui` (the component model)
- Declarative, reactive components (state, bindings, effects), similar in spirit to SwiftUI/Flutter. Layout engine: stack, grid, flex, constraints. Accessibility tree, input, focus, animation, i18n.
- **Renderers are adapters of the component model:** desktop (GPU via `envo.gfx`), web (DOM through WASM + the `js` adapter, or canvas), and terminal (`envo.term`).
- Native look-and-feel is handled by themes; the default theme is **Lumen** (§9).

### 8.4 `envo.render3d` (3D tooling)
- An ECS-based scene (a data-oriented entity/component/system core in `envo.ecs` shared with games).
- A physically based renderer: PBR materials, image-based lighting, shadows, a clustered or forward+ pipeline, post-processing (tonemapping, bloom, TAA).
- glTF 2.0 import (own parser), meshes, skinning, animation, and cameras.
- Later: physics (`envo.physics`), audio spatialization, a scene editor built with `envo.ui`, and ray tracing where the hardware supports it.
```envo
use envo.render3d;
scene { cube().Spin(); light.Sun(); }
```

---

## 9. Lumen — the Design Language and Web Stack

### 9.1 Goal
Make **a modern, Mac-like (clean, calm, translucent, softly animated) website or app in very few lines** through templates, *or* give full pixel-level control. Same system for web and desktop (the Electron-like experience, but native, small, and fast).

### 9.2 Lumen design tokens (`docs/lumen/` is the spec)
- **Color:** semantic roles (background, surface, elevated, label, secondary label, accent, separator, success/warning/danger), with automatic light/dark and high-contrast modes and a wide-gamut option.
- **Typography:** a type scale (largeTitle → caption) built on system UI fonts through an adapter. The project may design its own typeface later; it never bundles third-party fonts.
- **Space and shape:** a 4-pt spacing scale, corner radii, continuous ("squircle") corners.
- **Materials:** translucent/vibrant surfaces (backdrop blur), elevation, and shadows.
- **Motion:** spring-based animation curves, and respect for reduced-motion settings.
- **Accessibility:** WCAG 2.2 AA contrast by default, full keyboard navigation, screen reader semantics.

Tokens are written in EON and exposed as typed Envo constants. Themes are token overrides.

### 9.3 Three levels of control
```envo
// Level 1 — template (a full, responsive, beautiful landing page)
use envo.web;
site("Acme") { page("/") => Landing(title: "Hello, World!", subtitle: "Built with Envo") }
```
```envo
// Level 2 — compose Lumen components
page("/") => Stack {
    NavBar(brand: "Acme", links: ["Docs", "Pricing"])
    Hero(title: "Ship faster", action: Button("Get started", href: "/start"))
    Grid(cols: 3) { foreach (var f in features) Card(f.Title, f.Body) }
}
```
```envo
// Level 3 — full control: custom styles, custom components, or raw gfx canvas
component PriceTag(decimal amount) => Text($"${amount}")
    .Style(s => s.Font(Lumen.Type.Title).Color(0x0A84FF).Padding(12).Radius(10).Blur(20));
```

### 9.4 Web delivery
- Envo compiles to **WASM**. The compiler also generates the small JS loader/glue (written by EnvoScale, not a framework) through `adapters/interop/js`.
- **Rendering strategies:** static site generation, server-side rendering with hydration, and client-only. The user chooses per page.
- `envo.web` includes the HTTP server, router, forms, sessions, auth helpers (using `envo.crypto`), and asset pipelines (images, fonts, CSS generated from Lumen tokens), all in Envo.
- **Desktop apps** use the same `envo.ui` + Lumen code, rendered natively through `envo.gfx` (no embedded browser). The result is a single small executable.

### 9.5 Templates (`templates/lumen/`)
Landing, Docs (dogfooded for EnvoScale's own documentation site), Blog, Dashboard, Portfolio, Store, Settings app, and Chat app. Every template is fully overridable component by component.

---

## 10. Tooling — the `envo` CLI

| Command | Purpose |
|---|---|
| `envo new <template> <name>` | Create a project from `templates/projects` |
| `envo run [file]` | Run a script or project (sandboxed, `--allow ...`) |
| `envo build` | Compile (`--target`, `--release`, `-O`, `--emit`) |
| `envo test` / `envo bench` | Tests and benchmarks |
| `envo fmt` / `envo lint` | One canonical format, no configuration needed; lints with auto-fixes |
| `envo doc` | API docs generated as a Lumen site |
| `envo repl` | Interactive shell on the script runtime |
| `envo pkg add/publish/audit` | Package manager (§11) |
| `envo dbg` / `envo prof` | Native debugger (also speaks the Debug Adapter Protocol) and sampling profiler |
| `envo fuzz` | Coverage-guided fuzzer |
| `envo asm` / `envo eir` | Low-level tools |
| `envo audit unsafe` | Lists every `unsafe` block and FFI boundary |
| `envo port check <adapter>` | Runs the port conformance suite against an adapter |
| `envo lsp` | Language server (own JSON-RPC implementation) |

**Error messages** are a feature: they name the problem in plain language, show source snippets with labels, suggest a fix, and include a stable error code with `envo explain E0042`.

---

## 11. Packages and Manifests

```eon
// envo.eon
package {
    name    = "hello"
    version = "0.1.0"
    edition = "2027"
}
dependencies {
    // only other Envo packages; no foreign package ecosystems in core
}
targets { default = ["native", "wasm"] }
```
- Content-addressed, reproducible builds with a lockfile (`envo.lock.eon`).
- Packages are signed with `envo.crypto` (Ed25519, with ML-DSA added as post-quantum support matures).
- Registries are accessed through an adapter, so a self-hosted registry is a first-class option.
- **The standard platform needs no packages at all.** The package manager exists for user code.

---

## 12. Interop With Existing Infrastructure

Interop is always an **adapter**, never part of the core:
- **C ABI** (`adapters/interop/c-abi`): call C libraries and export Envo functions to C. Bindings are written in Envo or generated by an Envo tool that reads C headers itself (no libclang).
- **JS** (`adapters/interop/js`): browser and JS runtime interop for WASM.
- **Later:** Python, .NET, JVM, and Objective-C/Swift bridges.
- **Data/protocols:** speaking HTTP, SQL wire protocols, or cloud APIs is done by modules or adapters implementing the public protocol, not by linking vendor SDKs.

---

## 13. Security Model
- Memory and thread safety by default; `unsafe` is auditable (§2.5).
- **Capability-based I/O:** ports are passed around as capabilities. Script mode grants none by default.
- Supply chain: zero dependencies, a reproducible bootstrap from a hex seed, signed packages, and fixed-point compiler checks.
- `SECURITY.md` defines vulnerability reporting, supported versions, and the crypto audit status.
- The fuzzer runs continuously on the parser, the EIR verifier, every file format decoder, the TLS stack, and the HTTP parser.

---

## 14. Engineering Standards

### 14.1 Code
- One canonical style (`envo fmt`). Names: `PascalCase` for types/methods/properties, `camelCase` for locals/parameters, `snake_case` for module paths, `SCREAMING_CASE` only for true constants.
- Small modules with a clear purpose. No global mutable state. Dependencies (ports, allocators, loggers) are passed explicitly or through a typed context.
- Every file format and wire protocol has a version/magic header and a migration path.

### 14.2 Testing
- **Spec tests** (`tests/spec/`) are `.envo` files with `// expect: <output>` or `// expect-error: E0042` annotations, run in both AOT and script modes.
- **Unit tests** live next to code. **Golden tests** cover diagnostics, EIR, and assembly output. **Differential tests** compare `-O0` vs `-O3`, AOT vs script, and each GPU adapter vs the software reference (image diffs within tolerance).
- **Bootstrap tests:** stage equivalence and the fixed-point check (§5.5).
- **Conformance suites** for each port. **Fuzzing** (§13). **Benchmarks** tracked over time, so regressions fail CI past a threshold.

### 14.3 Performance targets (initial goals, revisited by RFC)
- A static hello world on x86-64 Linux is under 16 KB. Windows is under 32 KB.
- Stage 2 debug builds compile at least 250k lines/second/core. Incremental rebuild of one changed function happens in under 200 ms.
- Script-mode startup is under 20 ms for hello world.
- Release-mode code is within 10–20% of C compiled by mainstream optimizing compilers on a published benchmark suite, closing that gap over time.

### 14.4 Stability tiers
- **Experimental:** may change or vanish; behind `--unstable` or `[Unstable]`.
- **Preview:** API mostly settled; breaking changes require an RFC.
- **Stable:** follows SemVer and the edition policy; deprecation needs at least one edition of warnings.

### 14.5 Versioning and commits
- SemVer for the toolchain and every package. Editions for the language.
- Conventional commits (`feat(compiler/opt): add LICM pass`). One logical change per commit. Every PR updates `STATUS.md` when it changes a subsystem's state.

### 14.6 Documentation
- Each public item has a doc comment with a runnable example. Doc examples are tested.
- `docs/guides/` provides a learning path: *Your first line* → *Your first app* → *Your first website* → *Understanding ownership* → *Going low-level* → *Writing an adapter* → *Contributing to the compiler*.

---

## 15. RFC Process
- Any change to the language, EIR, a stable API, the port interfaces, or this charter needs an RFC in `docs/rfcs/NNNN-title.md`, following `0000-template.md`: Summary, Motivation, Guide-level explanation (the simple door), Reference-level explanation (the full-control door), Drawbacks, Alternatives, Prior art, Unresolved questions, Migration/edition impact.
- An RFC is accepted after review, and its implementation links back to it.

---

## 16. Milestones (Strict Order)

Each milestone has a **Definition of Done (DoD)**. Do not start the next one until the DoD is met and recorded in `STATUS.md`.

| # | Milestone | Definition of Done |
|---|---|---|
| **M0** | **Charter & skeleton** | Repo layout from §6 exists, with a README in every top-level folder explaining its purpose. `CHARTER.md`, `STATUS.md`, `PLAN.md`, the RFC template, `docs/spec/envo-core.md`, `eas.md`, `eon.md`, and the first draft of language spec chapters 1–5 (lexical structure, types, expressions, items, ownership). `examples/00-hello`. CI adapter that runs a placeholder check. |
| **M1** | **Stage 0** | `envoc0` (assembly) compiles Envo-Core to working x86-64 executables on **Windows and Linux**. Spec tests for Envo-Core pass. Built through the Phase A bootstrap adapter (§5.4). `bootstrap.ps1` and `bootstrap.sh` work. |
| **M2** | **Stage 1** | `envoc1`, written in Envo-Core, builds with `envoc0` and compiles a larger subset (generics, interfaces, closures, basic borrow checker, EIR). Its spec tests pass. |
| **M3** | **Self-hosting** | Stage 2 `envoc` in full Envo, with an x86-64 backend, `-O0`/`-O2`, and PE+ELF linking. **Fixed-point check passes in CI.** |
| **M4** | **Foundations** | `core`, `alloc`, `std`, `lib/ports`, OS adapters for Windows and Linux, plus the `none`/in-memory reference adapters. Port conformance suite exists. |
| **M5** | **Daily tooling** | `envo` CLI with `new`, `build`, `run`, `test`, `fmt`; diagnostics with error codes; basic LSP. |
| **M6** | **Script runtime** | EIR VM, REPL, shebang, sandbox permissions. Every spec test passes in both modes. |
| **M7** | **Crypto & network** | Hashes, AEADs, X25519/Ed25519, CSPRNG, TLS 1.3 client, TCP/DNS, HTTP/1.1 client and server. All crypto test vectors pass. Marked Experimental. |
| **M8** | **Graphics & UI (desktop + terminal)** | `envo.gpu` with software + Vulkan/D3D12 adapters, `envo.gfx`, `envo.font`, Win32 window adapter, `envo.ui` with desktop and terminal renderers, Lumen tokens, `envo.cli`/`envo.term`. |
| **M9** | **Web** | WASM backend, JS interop adapter, `envo.web` server/router, SSG + SSR, Lumen templates (Landing and Docs at minimum). The EnvoScale docs site is built with EnvoScale. |
| **M10** | **AArch64 + macOS** | AArch64 backend, Mach-O linker, macOS OS/window/Metal adapters. |
| **M11** | **3D** | ECS, PBR renderer, glTF import, `scene { }` simple door. |
| **M12** | **AI** | Tensors, CPU + GPU kernels, autograd, tokenizer, model loading, local inference. |
| **M13** | **Ecosystem** | Package manager and registry adapter, debugger, profiler, fuzzer, seed ladder (Phase B) complete and byte-identical in CI. |
| **Beyond** | | RISC-V, HTTP/2/3 + QUIC, post-quantum crypto, physics, scene editor, shell, terminal emulator, database query layer, more interop bridges, possibly a research OS built on the same adapters. |

**For the first working session:** complete **M0** fully, then start **M1** by writing the Envo-Core spec, the Stage 0 lexer, and the platform shims, with tests. Report progress in `STATUS.md`.

---

## 17. Hello World Gallery (must stay true forever)

These go in the README and in `tests/spec/hello/`. CI fails if any of them stops working or grows past its line count.

| Domain | Program |
|---|---|
| Console | `print("Hello, World!")` |
| CLI tool | `[Command] void Greet(string name = "World") => print($"Hello, {name}!")` |
| Window | `use envo.ui;` / `window("Hello") { Text("Hello, World!") }` |
| Website | `use envo.web;` / `site("Hello") { page("/") => Landing(title: "Hello, World!") }` |
| HTTP API | `use envo.http;` / `serve(8080) { get("/") => "Hello, World!" }` |
| Terminal UI | `use envo.term;` / `tui { Text("Hello, World!").Bold() }` |
| 3D | `use envo.render3d;` / `scene { cube().Spin(); light.Sun(); }` |
| 2D | `use envo.gfx;` / `window("Hi") { canvas(c => c.Circle(100, 100, 50, Lumen.Accent)) }` |
| Crypto | `print(crypto.sha256("Hello, World!").Hex())` |
| AI | `use envo.ai;` / `print(ai.Load("tiny.gguf").Ask("Say hello"))` |
| Systems | `[NoAlloc] extern "C" int main() { unsafe { asm x86_64 { /* … */ } } return 0; }` |

(`/` separates lines.)

---

## 18. Final Checklist Before Every Merge
- [ ] No third-party code or packages were introduced.
- [ ] No `lib/**` → `adapters/**` imports.
- [ ] Simple door and full-control door both exist for any new public API.
- [ ] Tests added and passing in AOT and script modes. Fixed-point check passes if `compiler/` changed.
- [ ] Docs, examples, and `STATUS.md` updated. An RFC is linked if required.
- [ ] Hello World Gallery still passes, with no growth in line counts.
- [ ] Output is deterministic and reproducible.

---

*EnvoScale: one environment, every platform, every skill level, built from the first byte up.*
