# EnvoScale — Working Plan

This file is required by §0.1 of the founding brief ([`ENVOSCALE_PROMPT.md`](../ENVOSCALE_PROMPT.md)).
It records how the brief was understood, the questions still open, and the task
breakdown for the current milestone. It is rewritten at the start of each milestone.

- **Current milestone:** M4 (foundations). M0–M3 are done; their records are in §4.
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

## 5. M4 — Foundations

**DoD (brief §16):** `core`, `alloc`, `std`, `lib/ports`, OS adapters for Windows and
Linux, plus the `none`/in-memory reference adapters. Port conformance suite exists.
Read here as: the layers are Envo-S1 code that `envoc` compiles (D16); every port has a
reference adapter in `adapters/os/none` and native adapters for Windows and Linux, and
one conformance suite per port passes against all three on both hosts in CI. Library
resolution and the platform binding follow D21–D25.

| # | Increment | Tested by | State |
|---|---|---|---|
| [4.1](https://github.com/envoscale/EnvoScale/issues/81) | Library resolution: `--lib`, `use` loads modules by path (D21), `platform` binding and `--os` (D23), the lib→adapters rule in the compiler | `tests/spec/lib/` | done: `--lib`, `--os`, `platform`, E0214, E0215; `use a.b;` names `b` in types too |
| [4.2](https://github.com/envoscale/EnvoScale/issues/82) | `core`: integer formatting and parsing, `str` searching and splitting, math helpers, hashing | `lib/core/tests/` | done: `core.text`, `core.fmt`, `core.math`, `core.hash` (with `IKey`) |
| [4.3](https://github.com/envoscale/EnvoScale/issues/83) | `alloc`: `Map<K, V>`, `Set<T>`, `Box<T>`, text helpers | `lib/alloc/tests/` | done: `string` stays the builder; `alloc.text` builds on it |
| [4.4](https://github.com/envoscale/EnvoScale/issues/84) | `ports` and the reference adapters (`os.none`): in-memory file system, captured console, manual clock, seeded entropy, fixed environment | `tests/conformance/` against `os.none` | done: five ports, five suites |
| [4.5](https://github.com/envoscale/EnvoScale/issues/85) | Native adapters `os.windows` and `os.linux` (D25), Windows import table grown in both stages | `tests/conformance/` against each OS, in CI | done: KERNEL32 slots 12-18 and ADVAPI32's random generator in both stages; every suite passes natively |
| [4.6](https://github.com/envoscale/EnvoScale/issues/86) | `std`: `io`, `fs`, `path`, `time`, `env`, `random`, each with a simple door through `platform` and a full-control door taking the port | `lib/std/tests/` | done |
| [4.7](https://github.com/envoscale/EnvoScale/issues/87) | M4 complete: docs, examples, `STATUS.md` | the whole suite | |

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
