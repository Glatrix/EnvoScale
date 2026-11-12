# EnvoScale Status

Where every subsystem stands. Any change that moves a subsystem forward or back updates
this file (brief §0.4, §14.5). Tiers (brief §14.4): **Experimental** may change or vanish,
**Preview** needs an RFC for breaking changes, **Stable** follows SemVer and editions.
"—" means the subsystem doesn't exist yet.

_Last updated: 2026-11-12._ Work is tracked on the
[roadmap](https://github.com/orgs/envoscale/projects/3): one epic per milestone, increments
as sub-issues, owner decisions marked **Needs Decision**.

## Milestones

| # | Milestone | State |
|---|---|---|
| M0 | Charter and skeleton | **Done** |
| M1 | Stage 0 | **Done** |
| M2 | Stage 1 | **Done**: `envoc1`, written in Envo-Core, compiles Envo-Core and Envo-S1 |
| M3 | Self-hosting | **Done**: `envoc`, written in Envo-S1, compiles itself at `-O2` to a fixed point, checked in CI on both hosts; objects and linking; ownership beyond Stage 1 (3.1–3.10, `docs/PLAN.md` §5) |
| M4 | Foundations | **Done**: `core`, `alloc`, `ports`, `std` in Envo-S1 through `envoc --lib`; reference, Windows and Linux adapters; conformance suites passing on both hosts (4.1–4.7) |
| M5 | Daily tooling | **Done**: the `envo` binary (the compiler as a library) with `new`, `build`, `run`, `check`, `test`, `fmt`, `lsp`, `explain`; packages; rich diagnostics; `FileSystem.List` and the `Process` port; `envo.eon`, `envo.json` (5.1–5.8) |
| M6 | Script runtime | **Done**: `envo run` interprets the program's EIR, sandboxed with `--allow` permissions; scripts and `#!/usr/bin/env envo`; `envo repl`; every spec run test and library test passes in both modes (6.1–6.7) |
| M7 | Crypto and network | **Done** (Experimental, not audited): `envo.crypto` (SHA-2, HMAC/HKDF, ChaCha20-Poly1305, AES-GCM, X25519, Ed25519, a CSPRNG; RSA, ECDSA and X.509 verification), the Net and Trust ports, `envo.http` (HTTP/1.1 client and server), `envo.tls` (a verifying TLS 1.3 client) (7.1–7.8) |
| M8 | Graphics and UI | **Done** (Experimental): `envo.term` and the Terminal port, `envo.cli`, `envo.gfx`, `envo.font`, the Window port (Win32), `envo.lumen` and `envo.ui` (desktop and terminal renderers), `envo.gpu` (software and Direct3D 12) (8.1–8.9) |
| M9 | Web | **Done** (Experimental): the WebAssembly backend, the JS host and `os.wasm`, `envo.markdown`, `envo.web` with Lumen's Landing and Docs templates, the website and its in-browser sandbox, built by Envo programs (9.1–9.8) |
| M10 | AArch64 and macOS | **Blocked** on test machines: no AArch64 or macOS hardware here, and GitHub's arm64 and macOS runners cost money for a private repository (an owner decision) |
| M11–M13 | | Not started |

### M0 Definition of Done

| Item | Where | State |
|---|---|---|
| Repo layout, a README in every top-level folder | `tests/layout.txt` (138 folders), checked by `bootstrap.* check` | Done |
| `CHARTER.md`, `STATUS.md`, `PLAN.md` | root, `docs/PLAN.md` | Done |
| RFC template | `docs/rfcs/0000-template.md` | Done |
| `envo-core.md`, `eas.md`, `eon.md` | `docs/spec/` | Done (drafts; `eas.md` normative for Stage 0) |
| Spec chapters 1–5, first draft | `docs/spec/` | Done (chapter 1 normative) |
| `examples/00-hello` | `examples/00-hello/` | Done |
| CI running a check | `.github/workflows/ci.yml` | Done |

### M1 Definition of Done

| Item (brief §15) | Where | State |
|---|---|---|
| `envoc0` compiles Envo-Core to x86-64 on Windows and Linux | `bootstrap/stage0/`; run tests on both OSes in CI | Done |
| Envo-Core spec tests pass | 174 error tests, 33 run programs, 7 multi-file programs | Done |
| Built through the Phase A bootstrap adapter | `adapters/bootstrap/nasm/`; byte-identical across hosts and NASM versions | Done |
| `bootstrap.ps1` and `bootstrap.sh` work | `build`, `test`, `check`, locally and in CI | Done |

### M2 Definition of Done

| Item (brief §15, PLAN §5) | Where | State |
|---|---|---|
| Envo-S1 specified | `docs/spec/envo-s1.md`, RFCs 0002–0005, `docs/spec/eir.md` | Done |
| `envoc1`, in Envo-Core, builds with `envoc0` | `bootstrap/stage1/` (about 17k lines); checks its own source | Done |
| Generics, interfaces, closures, borrow checking, EIR | `docs/architecture/stage1.md` | Done |
| Every Envo-Core spec test passes under `envoc1` | same errors and same program output as `envoc0` | Done |
| Every Envo-S1 spec test passes | `s1-syntax`, `s1-types`, `s1-own`, `s1-run`, `s1-multi` | Done |
| Windows and Linux in CI, reproducible | 739/739 on both; Linux and Windows builds byte-identical | Done |

### M5 Definition of Done

| Item (brief §16, PLAN §5) | Where | State |
|---|---|---|
| `envo` CLI with `new`, `build`, `run`, `test`, `fmt` | `tools/envo/` (plus `check`, `lsp`, `explain`, `version`); one binary holding the compiler (D26) | Done |
| Packages | `envo.envon` with a `package` block (D27); `envo new` makes one | Done |
| Diagnostics with error codes | the shared one-line format, plus a source line, caret and `help:` from `envo`; `envo explain` reads the registry | Done |
| Basic LSP | `envo lsp`: diagnostics over JSON-RPC (D30); `tests/lsp` | Done |
| Running programs | `ports.IProcess` with reference, Windows and Linux adapters; `FileSystem.List`, `Environment.Var`, `CurrentDir` | Done |
| CI uses `envo test` | the bootstrap scripts build `envo` and run `envo test lib adapters tests/conformance examples` (D29); green on both hosts | Done |

### M6 Definition of Done

| Item (brief §16, PLAN §5) | Where | State |
|---|---|---|
| EIR VM | `runtime/vm`: an interpreter over the compiler's EIR for the host target, runtime included (D31, D32); the compiler itself runs in it and builds byte-identical executables | Done |
| REPL | `envo repl` (D36) | Done |
| Shebang | `envo file.envo`, `#!/usr/bin/env envo` (D33); a shebang script runs on Linux in CI | Done |
| Sandbox permissions | `--allow read, write, fs (:path), env, run, net, all` (D34); `tests/sandbox` | Done |
| Every spec test in both modes | every spec run and multi-file program, and every library test, in the VM too (D35); green on both hosts | Done |

### M7 Definition of Done

| Item (brief §16, PLAN §5) | Where | State |
|---|---|---|
| Hashes, AEADs | `envo.crypto`: SHA-256/384/512, HMAC, HKDF; ChaCha20-Poly1305, AES-128/256-GCM | Done |
| X25519, Ed25519 | `envo.crypto.curve25519` | Done |
| CSPRNG | `envo.crypto.random`: ChaCha20 keyed from the Entropy port, fast key erasure | Done |
| TLS 1.3 client | `envo.tls`: X25519, both SHA-256 suites, chain, name, CertificateVerify and Finished verified; `tests/tls` against `openssl s_server` | Done |
| TCP/DNS | `ports.INet` with reference, Windows (Winsock) and Linux (syscalls, own DNS client) adapters; `tests/conformance/net` | Done |
| HTTP/1.1 client and server | `envo.http`, `https://` through `envo.tls` | Done |
| All crypto test vectors pass | every vector in `tests/vectors/README.md`, natively and (where fast enough) in the script runtime | Done |
| Marked Experimental | READMEs, `SECURITY.md` (not audited) | Done |

### M8 Definition of Done

| Item (brief §16, PLAN §5) | Where | State |
|---|---|---|
| `envo.gpu` with software and Vulkan/D3D12 adapters | `ports.IGpu`; `envo.gpu.Software`; Direct3D 12 in `os.windows`; `tests/conformance/gpu` (every adapter within 1 of software) | Done (Vulkan follows Linux windows, after M8: D46) |
| `envo.gfx` | software rasterizer with anti-aliased shapes and blending; golden hashes | Done |
| `envo.font` | TrueType parsing and anti-aliased rendering; system fonts; robustness tests | Done |
| Win32 window adapter | `ports.IWindow`; `os.windows.Window`; `tests/conformance/window` | Done |
| `envo.ui` with desktop and terminal renderers | `envo.ui`: one layout for pixels and cells, focus and input | Done |
| Lumen tokens | `docs/lumen/`, `lib/envo/lumen/tokens.eon`, `envo.lumen` (WCAG 2.2 AA pairs) | Done |
| `envo.cli` / `envo.term` | `envo.cli`; `ports.ITerminal` and `envo.term` | Done |

### M9 Definition of Done

| Item (brief §16, PLAN §5) | Where | State |
|---|---|---|
| WASM backend | `compiler/backend/wasm`: every spec run program and library test under Node.js; `envoc` itself built as WebAssembly rebuilds itself to the same bytes | Done |
| JS interop adapter | `adapters/interop/js/envo.js` (Node.js and browsers), `adapters/os/wasm` | Done |
| `envo.web` server/router | `envo.web`: routes with parameters, static files, `Serve` | Done |
| SSG + SSR | one code path: `App.Handle` per request, `Build` to files | Done |
| Lumen templates (Landing, Docs) | `envo.web.templates`, CSS from Lumen's tokens | Done |
| The docs site built with EnvoScale | `website/site.envo` builds the site (with the sandbox) in CI; publishing is #61 | Done |

## Subsystems

| Subsystem | Tier | Works | Missing | Next |
|---|---|---|---|---|
| **Language spec** (`docs/spec`) | Experimental | Chapter 1 normative, chapters 2–5 drafts; Envo-Core, Envo-S1, EIR v1, EAS, EON; error registry | Chapter 6 on (generics in depth, modules, async, comptime) | As M3 needs it |
| **RFCs** (`docs/rfcs`) | — | Template; RFCs 0001–0005 | — | As listed on the roadmap |
| **Seed** (`bootstrap/seed`) | — | — | Everything (Phase B, before 1.0) | After Stage 0's `.eas` subset is final |
| **Stage 0** (`bootstrap/stage0`) | Experimental | `envoc0` in 15k lines of assembly: `lex`, `parse`, `check`, `build`; PE/ELF output, cross-compiles; hello world is 8 KB | Fixes only (line budget used up) | — |
| **Stage 1** (`bootstrap/stage1`) | Experimental | `envoc1` in 17k lines of Envo-Core: front end, EIR v1 with verifier, x86-64 backend, PE/ELF, runtime in Envo. Compiles Envo-Core exactly like `envoc0`, and Envo-S1 (generics, interfaces, closures, ownership, enums, views, namespaces, prelude) | Speed (no optimizer, by design: D15) | Fixes found by Stage 2 |
| **Stage 2** (`compiler/`) | Experimental | `envoc` in Envo-S1, built by `envoc1`: `lex`, `parse`, `check`, `eir` and `build`, matching `envoc1` byte for byte on the tests and on both compilers; binary EIR, `.eo` objects and `envoc link`; `-O2`; the fixed point (D18) in CI; `--lib` for the standard platform; the driver as a library for `envo`; a WebAssembly backend (`--target wasm32-web`, D48) | `once fn` inference, non-lexical borrows ([#79](https://github.com/envoscale/EnvoScale/issues/79)) | M9: the compiler in the browser |
| **NASM adapter** (`adapters/bootstrap/nasm`) | Experimental | `assemble.ps1`, `assemble.sh` | — | — |
| **Build scripts** (`bootstrap.ps1`, `bootstrap.sh`) | Experimental | `check`, `build`, `test`, `fixedpoint` on PowerShell and Git Bash; build `envo` after Stage 2 and test through it | — | — |
| **CI** (`adapters/ci/github`) | Experimental | `check`, Windows and Linux test jobs (745/745 each), and `reproducible`, which requires byte-identical builds of all three compilers across hosts | — | — |
| **Tests** (`tests/`) | — | Lexer, parser and checker goldens; Core and S1 error, run and multi-file tests; EIR tests; CLI smoke tests; Hello World line limits | — | New `s1-own` tests for M3.10 |
| **Runtime** (`runtime/`) | Experimental | Startup, panics and the OS layer (`bootstrap/stage1/runtime/`, in every program); the EIR VM (`runtime/vm`) with permissions | ARC, a JIT, floats in the VM | M7 on |
| **Standard platform** (`lib/`) | Experimental | `core`, `alloc`, `ports`, `std` (io, fs, path, time, env, random, process), `envo.eon`, `envo.json`, `envo.crypto`, `envo.http`, `envo.tls`, `envo.cli`, `envo.term`, `envo.gfx`, `envo.font`, `envo.lumen`, `envo.ui`, `envo.gpu`, `envo.markdown`, `envo.web`, in Envo-S1 through `envoc --lib` | Other domain modules (`envo.*`), threads and async, floats | M8 on |
| **Adapters** (`adapters/os`, `window`, `gpu`, …) | Experimental (`os`) | `os/none` (reference), `os/windows`, `os/linux`: Console, FileSystem, Clock, Entropy, Environment, Process, Net, Trust, Terminal, Window (Win32; Linux after M8), Gpu (Direct3D 12; software elsewhere); every conformance suite passes on both hosts | Vulkan, audio, threads, Linux windows | M8 on |
| **Tools** (`tools/`) | Experimental | `envo`: `new`, `build`, `run` (script runtime or `--native`), `check`, `test`, `fmt`, `lsp`, `repl`, `explain`, `version`; scripts | `doc`, `lint`, `pkg`, `dbg`, `prof`, `fuzz` | later milestones |
| **Templates** (`templates/`) | — | — | Everything | M5, M9 |

## Known limitations

- **Linux runs only in CI.** WSL is broken on the dev machine, so Linux binaries are built
  locally but run by the `stage0-linux` job.
- **Source files are limited to 16 MiB** in Stages 0 and 1.
- **Envo-Core can't make a non-empty slice.** Slicing ([RFC 0002](docs/rfcs/0002-slicing.md))
  is Envo-S1 and up, so Core code, including Stage 1, uses a pointer and a length.
- **The legal documents haven't been reviewed by a lawyer.** `LICENSE` uses the PolyForm
  Noncommercial License 1.0.0. The commercial templates in `docs/legal/`, `CLA.md` and
  `TRADEMARKS.md` are drafts, and the licensor is still a GitHub handle. Both need fixing
  before the first commercial license is sold
  ([#35](https://github.com/envoscale/EnvoScale/issues/35)).
