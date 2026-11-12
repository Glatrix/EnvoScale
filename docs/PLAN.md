# EnvoScale — Working Plan

This file is required by §0.1 of the founding brief ([`ENVOSCALE_PROMPT.md`](../ENVOSCALE_PROMPT.md)).
It records how the brief was understood, the questions still open, and the task
breakdown for the current milestone. It is rewritten at the start of each milestone.

- **Current milestone:** M9 (web). M0–M8 are done; their records are in §4.
- **Live status:** [`STATUS.md`](../STATUS.md) is authoritative for what works today.

---

## 1. Understanding

EnvoScale is one language (**Envo**), one toolchain (`envo`/`envoc`) and one standard
platform (`envo.*`) that must eventually cover everything from inline assembly to
3-line websites. It has four constraints that shape every decision:

1. **Zero third-party dependencies.** Only what the OS or hardware provides, reached
   through hand-written adapters. Specs and test vectors are data, not dependencies.
2. **Ports and adapters.** `lib/**` is pure and platform-free and defines *ports*;
   `adapters/**` implements them. The dependency arrow points one way and the build
   will enforce it.
3. **A trusted bootstrap.** The compiler starts as auditable assembly (Stage 0), climbs
   through Envo-Core (Stage 1) to full Envo (Stage 2), and must reach a byte-identical
   fixed point. A hex seed (Phase B) eventually removes the need for any outside assembler.
4. **Two doors everywhere.** Every API has a short beginner entrance built *on top of*
   a full-control entrance — never a separate code path.

The brief is a decades-long plan. This repository's job right now is to give every
part of that plan a clear home, and to make the first rung of the bootstrap ladder
real and tested. Breadth is done with documents; depth is done with working code.

## 2. Decisions made while reading the brief

These are interpretation choices, not deviations. Each is written down where it lives.

| # | Decision | Where |
|---|---|---|
| D1 | `.eas` is defined as a **strict subset of NASM syntax** assembled in flat-binary mode. Stage 0 writes its own PE/ELF headers as data, so the Phase A adapter (NASM `-f bin`) and the future seed produce the same bytes from the same file, with no linker. | `docs/spec/eas.md` |
| D2 | Stage 0 executables use one RWX section/segment at a fixed base (`0x400000`), `TimeDateStamp = 0`, no relocations. Smallest auditable layout; deterministic. | `docs/architecture/bootstrap.md` |
| D3 | Stage 0's internal calling convention is the System V x86-64 register order on both OSes. The Windows shim converts to Win64 at the kernel32 boundary. | `docs/architecture/bootstrap.md` |
| D4 | Envo-Core uses `str` (borrowed UTF-8 view) rather than `string` (owned), so every Core program stays a valid full-Envo program. | `docs/spec/envo-core.md` |
| D5 | The Stage 0 lexer implements the **full Envo lexical grammar** where it is cheap (all keywords and operators are reserved), and rejects only constructs Core excludes (interpolation, raw strings, directives, non-ASCII identifiers) with dedicated `E09xx` errors. | `docs/spec/01-lexical.md` |
| D6 | Whitespace before `?` is significant (Swift's rule), and newlines can end statements. Tokens therefore carry "space before" / "newline before" flags from day one. This is what lets the normative examples (`T?`, `x?`, `a ? b : c`, newline-separated builder blocks) parse without ambiguity. | `docs/spec/01-lexical.md`, `docs/spec/03-expressions.md` |
| D7 | `await` covers every async call in its operand (Swift's model), so `await http.Get(url)?.Text()` from §3.3 means what it looks like. There is no `?.` token; `x?.y` is `(x?).y`. | `docs/spec/03-expressions.md` |
| D8 | Until the `envo` CLI exists (M5), the CI adapter calls `bootstrap.ps1` / `bootstrap.sh`. These are the only build entry points that exist, and they use OS tools only. When `envo` exists, CI switches to `envo` commands. | `adapters/ci/github/README.md` |
| D9 | Diagnostics use stable codes from day one. Ranges: `E0001–E0099` lexical, `E01xx` syntax, `E02xx` names, `E03xx` types, `E05xx` ownership, `E09xx` "not part of Envo-Core". | `docs/spec/errors.md` |
| D10 | Folder READMEs for subsystems that don't exist yet say so plainly ("Not started — M7") instead of holding stub code. | every `README.md` |
| D11 | Stage 1 is a multi-file Envo-Core program in `bootstrap/stage1/`, built by `envoc0 build` with the file order fixed in `bootstrap/stage1/files.txt` (`main.envo` first). Stage 0's line budget is spent, so Stage 0 gets bug fixes only; anything Stage 1's source would like from the language is done in Core as written. | `bootstrap/stage1/README.md` |
| D12 | The language `envoc1` accepts is **Envo-S1**: Envo-Core plus what the Stage 2 compiler needs to be written comfortably (generics, interfaces, closures, methods, owned strings, `T?`, `Result` and `?`, namespaces, slicing) and nothing more. It is a strict subset of full Envo, defined in `docs/spec/envo-s1.md`, so every S1 program is an Envo program. | `docs/spec/envo-s1.md` |
| D13 | Stage 1 compiles generics by monomorphization and interfaces by static dispatch through generic bounds, plus `dyn` objects with vtables only if the Stage 2 design needs them. Simplest correct choice; Stage 2 may add other strategies. | `docs/spec/envo-s1.md` |
| D14 | Stage 1 is tested **differentially**: every Envo-Core test runs under both `envoc0` and `envoc1` and must give the same result, and `envoc1 lex` must print the same token dumps as `envoc0 lex`. Two independent implementations of Core catch each other's bugs. | `bootstrap.*`, `tests/` |
| D15 | Stage 1's backend is deliberately simple: EIR → x86-64 with every SSA value in a stack slot, no optimizer, the same one-section executable layout as Stage 0. Speed comes in Stage 2. | `docs/architecture/bootstrap.md` |
| D16 | Stage 2 (`envoc`) is written in **Envo-S1** in `compiler/`, one file per pass in the existing folders, built by `envoc1` from `compiler/files.txt`, until the fixed point (D18); after it, `envoc` may use any Envo it compiles. | `compiler/README.md` |
| D17 | Stage 2 keeps EIR v1 (now with its binary form, [eir.bin]) and implements Envo-S1's semantics first, so every Stage 1 test is a Stage 2 test and the two compilers are compared like Stage 0 and Stage 1 were (D14). Full Envo grows from there in later milestones. | `docs/architecture/stage2.md` |
| D18 | The **fixed point**: `envoc1` builds `envoc` (stage2a); stage2a builds `envoc` (stage2b); stage2b builds `envoc` (stage2c). stage2b and stage2c must be byte-identical, and identical between the Windows and Linux hosts. CI checks it on every push. | `docs/architecture/stage2.md` |
| D19 | Linking in M3 is **whole-program over EIR objects**: a source file compiles to a binary EIR object (`.eo`); `envoc link` merges objects with the runtime, generates code and writes PE or ELF directly. Foreign objects (COFF/ELF, `.lib`/`.a`) arrive with `extern "C"` in M4. | `docs/architecture/stage2.md` |
| D20 | `-O0` keeps Stage 1's stack-slot code generation (fast and simple); `-O2` adds SSA optimizations (constant folding, copy propagation, dead-code elimination, CFG simplification, inlining of small functions) and linear-scan register allocation. Both are deterministic, and every run test runs at both levels and must agree. | `docs/architecture/stage2.md` |
| D21 | **Library modules** resolve by path until package manifests exist (M5): namespace `a.b` is the file `<lib>/a/b/b.envo` (`std.fs` is `lib/std/fs/fs.envo`), loaded when a file `use`s it, transitively. `envoc --lib <dir>` names the folder that holds `lib/` and `adapters/`. The runtime cannot list folders, and one file per module keeps the rule exact. | `docs/architecture/library.md` |
| D22 | **Ports are interfaces** used through generic bounds (static dispatch, D13): Envo-S1 has no dynamic interface values. An adapter is a struct that implements the port and owns its state. The full-control door takes the port as a parameter (`fs.ReadTextWith(ref myFs, path)`). | `docs/architecture/library.md` |
| D23 | The simple door reaches the target's adapters through one namespace, **`platform`**, which the build binds: `adapters/os/<os>/platform.envo` for the target's OS, or `adapters/os/none` with `--os none`. `lib/` names `platform` but never an adapter namespace (`os.*`); the compiler enforces it (E0213). | `docs/architecture/library.md` |
| D24 | M4's ports are the ones the runtime can serve today: `Console`, `FileSystem`, `Clock`, `Entropy` and `Environment`. `Threads`, `Executor`, `NetStack` and the device ports come with the milestones that need them (M6, M7, M8); `std.thread`, `sync` and `async` wait for them. | `docs/PLAN.md` §5 |
| D25 | Native adapters call the OS directly through the target intrinsics (`__syscall`, `__wincall`). The Windows import table grows in both Stage 1 and Stage 2, so their executables stay byte-identical (D17), and gains a second DLL for the system's random generator. | `docs/architecture/library.md` |
| D26 | **`envo` contains the compiler.** The brief puts every tool in one `envo` binary, so `envo` is built from `compiler/` (minus its entry file) plus `tools/`, and calls the compiler as a library (`envoc.build`). `envoc` stays, as the compiler on its own and the stage the fixed point checks. | `tools/envo/README.md` |
| D27 | **Packages replace the one-file rule** (D21) where a manifest exists: a package is a folder with `envo.envon`; its root module is its `.envo` files outside `tests/`, and a library module is every `.envo` file in its folder. Listing a folder needs `FileSystem.List`, a new port operation. Without a manifest, D21 still applies. | `docs/architecture/tooling.md` |
| D28 | **Running programs** goes through a new port, `Process`: start a program with arguments, wait for it, get its exit code, with its output sent to a file when asked. `envo run`, `envo test` and the language server use it. Windows gets its functions in both stages' import tables (D25). | `docs/architecture/tooling.md` |
| D29 | **The bootstrap scripts stay** for building and testing Stages 0–2: they must work without `envo`. CI calls `envo test` for what `envo` can run (the library, the conformance suites, the examples) in place of the scripts' library block (D8, read for a self-hosting toolchain). | `adapters/ci/github/README.md` |
| D30 | The **language server** is basic in M5: diagnostics only (`textDocument/publishDiagnostics` on open, change and save), computed by running `envo check` on the document as a child process. Hover, completion and go-to-definition need the query-based compiler (brief §8) and come later. | `tools/lsp/README.md` |
| D31 | **The script runtime is an EIR interpreter** in `runtime/vm/`, compiled into `envo`. It runs the module the compiler makes for the host target, with the runtime in it, on host memory: pointers are host addresses, slots and globals are host allocations. Layouts, wrapping, checks and panics are the AOT program's, so the two modes agree by construction. A tiered JIT reusing the backends comes later. | `runtime/vm/README.md` |
| D32 | The VM **forwards the two target intrinsics** (`syscall`, `wincall`) to the host, through a `match` over the import slots for `wincall`. It starts a program by setting its arguments (`__rt_set_args`) and calling `__main`, so the script sees its own arguments, not `envo`'s. A function value is a tagged function index, not a code address. | `runtime/vm/README.md` |
| D33 | **`envo run` runs in the VM**, sandboxed; `envo run --native` builds and runs native code as M5's `run` did; `envo build` is AOT. `envo <file.envo> [args]` is `envo run`, so `#!/usr/bin/env envo` works. | `tools/envo/README.md` |
| D34 | **Permissions** follow the brief's Deno-like model (§2.5): a script has its console and nothing else until `--allow` grants `read[:path]`, `write[:path]`, `fs[:path]` (both), `env`, `run`, `net` (for M7) or `all`. The VM checks them where it forwards system calls; a denied call fails as the OS would with "access denied", so library code sees `IoError.Denied`, and `envo` prints one note per denied capability. | `docs/architecture/script-runtime.md` |
| D35 | **Both modes in the tests**: the bootstrap scripts run every spec run test (`core-run`, `s1-run`, `s2-run`, the multi-file programs) through `envo run --allow all` as well as natively, requiring the same output and exit code; `envo test` runs each library test in the VM too. Error tests share the front end, so they agree by construction. | `tests/README.md` |
| D36 | **`envo repl`** keeps a session of cells: declarations accumulate, and each statement cell runs the session's program again in the VM, showing only the output that is new. A resident VM state needs incremental compilation (the query-based compiler) and comes later. | `tools/envo/README.md` |
| D37 | **`envo.crypto` is written in Envo-S1**, one module per family (`sha2`, `mac`, `chacha`, `aes`, `curve25519`, `random`) under `lib/envo/crypto/`, with `envo.crypto` as the simple door. Constant time by construction: no branch, loop bound or memory index depends on a secret; tags compare in constant time. The whole module stays Experimental until an independent audit (brief §7.2), as its README and `SECURITY.md` say. | `lib/envo/crypto/README.md` |
| D38 | **Test vectors** come from the standards (RFC 8439, 7748, 8032, 4231, 5869; FIPS 180-4 and 197; the GCM specification), copied into the library's tests, with their sources listed in `tests/vectors/README.md`. An algorithm exists only once its vectors pass. | `tests/vectors/README.md` |
| D39 | **The CSPRNG** is ChaCha20 keyed from the `Entropy` port (32 bytes), rekeyed from its own output after each request (fast key erasure), so the system's generator is read once per generator, not per call. | `lib/envo/crypto/README.md` |
| D40 | **A `Net` port** for TCP (connect, listen, accept, read, write, close) and name lookup. Windows: `ws2_32.dll` joins the import table in both stages (D25); Linux: system calls, and a DNS client in Envo reading `/etc/hosts` and `/etc/resolv.conf`. The script runtime gates it with `--allow net`. | `docs/architecture/network.md` |
| D41 | **TLS 1.3 client** (RFC 8446) with X25519 and `TLS_CHACHA20_POLY1305_SHA256` / `TLS_AES_128_GCM_SHA256`; certificates are verified (X.509 chain to the system's roots, names, validity; RSA and ECDSA P-256 signatures) before any application data. A connection that cannot be verified fails; there is no "insecure" switch in M7. | `docs/architecture/network.md` |
| D42 | **HTTP/1.1** client and server in `envo.http` over the Net port (and TLS for `https`), sharing request and response types. The brief's `serve(8080) { get("/") => … }` door needs trailing blocks, which Envo-S1 lacks; M7 gives the same server as calls (`Router`, `Get`, `Serve`) and the door follows when the language has it. | `lib/envo/http/README.md` |
| D43 | **A Terminal port** (`ITerminal`): write text, the window's size, raw mode on and off, and input as key events. Windows: the console API (a second KERNEL32 import descriptor, D25), with VT input so keys arrive as on Linux; Linux: `ioctl` (`TCGETS`, `TCSETS`, `TIOCGWINSZ`) and VT sequences. `envo.term` builds a cell buffer with a diffing renderer on it; `envo.cli` (arguments, help, tables, progress) needs only the console. | `lib/envo/term/README.md` |
| D44 | **`envo.gfx` is a software rasterizer first**: an RGBA canvas with shapes, anti-aliased edges, alpha blending and images, tested by hashing pixels (golden images). The GPU adapters (D46) draw the same commands faster. | `lib/envo/gfx/README.md` |
| D45 | **A Window port** (`IWindow`): open a window, poll events (keys, mouse, resize, close), present an RGBA framebuffer. The Win32 adapter uses `USER32.dll` and `GDI32.dll` from the import table (both stages, added with D43) and `__wincall12`; the window procedure is `DefWindowProcW`, events are read from the message queue, so no callback into Envo code is needed; `os.none` gives an off-screen window for tests. Linux windows (X11/Wayland) come after M8, as the brief's DoD names Win32 only. | `docs/architecture/graphics.md` |
| D46 | **`envo.gpu`** is a port (frames of colored triangles, drawn off-screen and read back) with a software adapter in `envo.gpu`, and a Direct3D 12 adapter in `os.windows`. The D3D12 adapter loads the system's libraries at run time through `__wincallp` (a call through a function pointer, in both stages) and compiles its HLSL with the system's `D3DCompile`. Every adapter agrees with the software adapter to within 1 per channel. Vulkan, for Linux GPUs, follows Linux windows after M8, as it needs SPIR-V and the brief's DoD names Win32 windows only. | `docs/architecture/graphics.md` |
| D47 | **`envo.ui`** is a retained component tree (`Column`, `Row`, `Text`, `Button`, …) with one layout pass, drawn by a desktop renderer (`envo.gfx` into a window) or a terminal renderer (`envo.term` cells). Lumen tokens (`docs/lumen/`) are its default theme. | `lib/envo/ui/README.md` |
| D48 | **A WebAssembly backend in Stage 2** (`--target wasm32-web`): memory keeps the front end's layout (8-byte pointers, addresses below 4 GiB), so EIR is unchanged. Every value is a canonical `i64` local, so the x86-64 backend's checks and panics carry over. Each function is a loop around a `br_table` on its block number; slots live on a shadow stack in memory; function pointers index the module's table. Stage 1 does not need it. | `compiler/backend/wasm/README.md` |
| D49 | **One host import**, `envo.host(k, a, b, c, d)`, reached through a `__hostcall` runtime intrinsic (both stages). The runtime's OS layer (`compiler/runtime/wasm.envo`) and the `os.wasm` adapters call it. `adapters/interop/js/envo.js` implements it in Node.js and browsers, with no framework. Every spec run program and library test runs under Node.js in the bootstrap scripts. | `adapters/interop/js/README.md` |
| D50 | **`envo.web`** on `envo.http`: a router with path parameters, static files with types and confined paths, an HTML builder that escapes by default, and page rendering on the server (SSR) and to files (SSG) from the same code. | `lib/envo/web/README.md` |
| D51 | **Markdown** (`envo.markdown`: CommonMark's blocks and inlines, with GitHub's tables) and **Lumen templates** for pages (Landing and Docs), with the CSS generated from Lumen's tokens. | `lib/envo/web/README.md` |
| D52 | **The website is an Envo program** (`website/`, its plan in `website/PLAN.md`) that builds the pages and `docs/` into static files with the Landing and Docs templates, served locally by `envo.web`. Publishing it (#61) is the owner's call. The sandbox runs `envoc` itself, built for `wasm32-web`, in the browser. | `website/README.md` |

## 3. Open questions

Items marked **RFC** conflict with the brief as written and are tracked in an RFC
(§0.7). The others are choices the project owner should confirm.

1. ~~**RFC 0001**~~ **Accepted 2026-11-11** (C1 `Copy` bound, C2 `Trimmed()`). Original question: **RFC 0001 — normative example audit.** Some §3.3 examples can't type-check under
   the brief's own rules: `Largest<T>` moves a non-`Copy` `T` out of a borrowed span
   ("no hidden copies"), and `ReadConfig` returns `text.Trim()` — a borrow of a local
   — as an owned `string`. See [`docs/rfcs/0001-normative-example-audit.md`](rfcs/0001-normative-example-audit.md).
2. ~~**License.**~~ **Decided 2026-11-11 by the owner:** free for individuals and
   noncommercial use (PolyForm Noncommercial 1.0.0), commercial licenses for companies,
   contributions under a CLA. See `LICENSING.md`. On 2026-11-11 the owner asked for
   something more official; PolyForm Noncommercial was kept, because it is a standard,
   lawyer-drafted, SPDX-listed license and the better-known alternatives (BSL, FSL,
   Elastic) all let companies use the software without paying. The package around it was
   made formal instead: full license text in `LICENSES/`, SPDX expression, commercial
   agreement and order form templates in `docs/legal/`, and `TRADEMARKS.md`. The text
   below is the original question.
   `LICENSE` was MIT with "The EnvoScale contributors" as a placeholder
   choice. The owner should confirm or replace it before the first public release.
3. ~~**Explicit lifetime syntax.**~~ **Decided 2026-11-11 by [RFC 0004](rfcs/0004-lifetimes-and-views.md):**
   borrow origins (`from a, b`), inferred for functions a library does not export, and `mut T[]` for
   writable views. Original question: the brief says explicit lifetimes "exist but are
   rarely needed" without giving a spelling. Rust's `'a` collides with char literals
   in a C#-style lexer. Deferred to an RFC ([#31](https://github.com/envoscale/EnvoScale/issues/31));
   the draft spec reports elision failures as an error with no explicit escape hatch yet.
4. ~~**Function types.**~~ **Decided 2026-11-11 by [RFC 0003](rfcs/0003-function-types.md):**
   `fn(A) -> R`, with closure kinds `fn` / `mut fn` / `once fn`, generic in parameter
   position and a code + environment value elsewhere; `extern "C" fn` for C. Original
   question: no syntax is given for function pointer / closure types.
5. ~~**Unicode paths on Windows.**~~ **Decided 2026-11-11: UTF-8 everywhere.** Stage 0 now uses the `…W` APIs and converts with kernel32's UTF-8 routines. Original question: Stage 0 uses the `…A` kernel32 entry points, so paths
   must be in the active code page. Fixing it means UTF-16 conversion in assembly;
   deferred unless it blocks someone (tracked in `STATUS.md`).
6. **Edition name.** The brief uses `edition = "2027"` while the current year is 2026.
   Kept as written; the first stable edition will be named when it ships.
7. ~~**Slices in Envo-Core.**~~ **Decided 2026-11-11 by [RFC 0002](rfcs/0002-slicing.md):**
   `a[lo..hi]` in full Envo and Envo-S1; Core keeps no slicing (Stage 0's budget), so
   Stage 1's source uses a pointer and a length.
8. ~~**How Stage 1 programs get their runtime.**~~ **Decided 2026-11-11 (M2.7):** the
   Stage 1 runtime is written in Envo-Core and compiled into every program `envoc1`
   builds, on top of two target intrinsics the backend encodes (`syscall` on Linux,
   `wincall` for `KERNEL32.dll` imports on Windows). See
   [`architecture/stage1.md`](architecture/stage1.md). Original question: Stage 0 copies
   its own assembled runtime block into each output program; `envoc1` cannot do that.

## 4. Done milestones

- **M0 — Charter and skeleton.** Repository layout, charter, status, specs (drafts), RFC
  template, error registry, Hello World Gallery, CI. DoD record in `STATUS.md`.
- **M1 — Stage 0.** `envoc0`, 15.0k lines of `.eas`, compiles Envo-Core programs of one
  or more files to Windows and Linux executables, byte-identical across hosts and NASM
  versions. 249/249 tests on both OSes. Increments 1.1–1.9 were: spec, platform shims,
  runtime helpers, lexer, parser, checker, code generation and writers, built-ins, and
  the full spec suite with multi-file programs. DoD record in `STATUS.md`.
- **M2 — Stage 1.** `envoc1`, about 17k lines of Envo-Core built by `envoc0`, compiles
  Envo-Core and Envo-S1 to Windows and Linux executables through EIR v1. Increments
  2.1–2.13 were: specs and RFCs 0002–0005, skeleton, lexer, parser, Core checker, EIR,
  lowering and backend, generics and interfaces, closures, ownership, enums with
  payloads, views and collections and namespaces, and the S1 suite complete. 739/739
  tests on both OSes. DoD record in `STATUS.md`; design in
  [`architecture/stage1.md`](architecture/stage1.md).

- **M3 — Self-hosting.** `envoc`, written in Envo-S1 in `compiler/`, built by `envoc1`.
  Increments 3.1–3.10 were: skeleton, lexer, parser, checker, ownership (each matching
  `envoc1` on every test and on both compilers' sources), lowering and the `-O0`
  backend (byte-identical to `envoc1`), binary EIR objects and `envoc link`, `-O2`
  (inlining, folding, dead code, block merging, linear-scan registers), the fixed point
  in CI on both hosts, and ownership beyond Stage 1. Followed by a security and
  performance sweep. Design in [`architecture/stage2.md`](architecture/stage2.md);
  follow-ups #79, #80.

- **M4 — Foundations.** `lib/core`, `alloc`, `ports` and `std` in Envo-S1, compiled by
  `envoc --lib` (module resolution D21, the `platform` binding D23); reference adapters
  (`os.none`) and native ones for Windows and Linux; one conformance suite per port,
  passing against all three on both hosts. Increments 4.1–4.7; design in
  [`architecture/library.md`](architecture/library.md).

- **M5 — Daily tooling.** The `envo` binary, holding the compiler as a library (D26):
  `new`, `build`, `run`, `check`, `test`, `fmt`, `lsp`, `explain`; packages (D27); the
  Process port and directory listing (D28); diagnostics with a source line and `help:`;
  `envo.eon` and `envo.json`; CI testing the library through `envo test` (D29).
  Increments 5.1–5.8; design in [`architecture/tooling.md`](architecture/tooling.md).

- **M6 — Script runtime.** `envo run` compiles in memory and interprets the EIR on host
  memory (D31, D32), sandboxed with `--allow` permissions (D34); scripts and shebang
  lines (D33); `envo repl` (D36); every spec run test and library test in both modes
  (D35). Increments 6.1–6.7; design in
  [`architecture/script-runtime.md`](architecture/script-runtime.md).

- **M7 — Crypto and network.** `envo.crypto` in Envo-S1, constant time where secrets
  are involved (D37), every vector passing (D38), a CSPRNG (D39); RSA, ECDSA and X.509
  verification; the Net and Trust ports with Winsock, Linux syscalls and an own DNS
  client (D40); `envo.http` (D42); a verifying TLS 1.3 client (D41). Increments
  7.1–7.8; design in [`architecture/network.md`](architecture/network.md).

- **M8 — Graphics and UI.** The Terminal port and `envo.term` (D43), `envo.cli`,
  `envo.gfx` in exact integer arithmetic (D44), `envo.font`, the Window port with a
  Win32 adapter needing no callbacks (D45), the GPU port with software and Direct3D 12
  adapters reached through `__wincallp` (D46), Lumen version 1 and `envo.ui` with
  desktop and terminal renderers (D47). Increments 8.1–8.9; design in
  [`architecture/graphics.md`](architecture/graphics.md).

## 5. M9 — Web

**DoD (brief §16):** WASM backend, JS interop adapter, `envo.web` server/router, SSG +
SSR, Lumen templates (Landing and Docs at minimum). The EnvoScale docs site is built
with EnvoScale.

| # | Increment | Tested by | State |
|---|---|---|---|
| [9.1](https://github.com/envoscale/EnvoScale/issues/120) | The WebAssembly backend (D48) | spec run programs under Node.js, -O0 and -O2 || done |
| [9.2](https://github.com/envoscale/EnvoScale/issues/121) | The host (`envo.js`) and the `os.wasm` adapters (D49) | library tests and conformance suites under Node.js || done |
| [9.3](https://github.com/envoscale/EnvoScale/issues/122) | `envo.web`: router, static files, HTML building (D50) | `lib/envo/web/tests/` || done |
| [9.4](https://github.com/envoscale/EnvoScale/issues/123) | `envo.markdown` and Lumen templates (D51) | `lib/envo/markdown/tests/`, golden pages || done |
| [9.5](https://github.com/envoscale/EnvoScale/issues/124) | SSG and SSR from the same pages (D50) | golden sites || done |
| [9.6](https://github.com/envoscale/EnvoScale/issues/126) | The website and docs site built with Envo (D52) | `website/`, CI builds it || done |
| [9.7](https://github.com/envoscale/EnvoScale/issues/125) | The sandbox: `envoc` in the browser (D52) | `envoc` built for `wasm32-web` compiles and runs a program under Node.js || done |
| [9.8](https://github.com/envoscale/EnvoScale/issues/127) | Docs and status; M9 complete | CI | |

## 6. Risks

- **Envo-S1 is a small language for a library.** No floats, no dynamic interface
  values, no classes; lambdas own no resources. Mitigation: M4's layers use what S1 has
  (static dispatch, D22), and each module's README says what changes when `envoc`
  accepts more of Envo. APIs are designed for full Envo and implemented in S1 now.
- **The heap never frees** (Stage 1's runtime). Library code allocates freely; fine at
  test scale, and the allocator port arrives with `alloc`'s allocator interface.
- **OS behaviour differs.** Conformance suites define the behaviour each port promises,
  and run against every adapter on both hosts in CI. A difference is an adapter bug or a
  suite that promised too much.
- **Untestable Linux path locally.** Development happens on Windows; Linux binaries
  only run in CI. Unchanged from M1.
- **Spec drift.** Chapters 1–5 are drafts; the library is written against Envo-S1,
  which is normative where `envoc` implements it.
