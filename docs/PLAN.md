# EnvoScale — Working Plan

This file is required by §0.1 of the founding brief ([`ENVOSCALE_PROMPT.md`](../ENVOSCALE_PROMPT.md)).
It records how the brief was understood, the questions still open, and the task
breakdown for the current milestone. It is rewritten at the start of each milestone.

- **Current milestone:** M2 (Stage 1). M0 and M1 are done; their records are in §4.
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

## 5. M2 — Stage 1

**DoD (brief §15):** `envoc1`, written in Envo-Core, builds with `envoc0` and compiles a
larger subset (generics, interfaces, closures, basic borrow checker, EIR). Its spec tests
pass. Read here as: Envo-S1 (D12) is specified, `envoc1` compiles every Envo-Core and
Envo-S1 spec test correctly on Windows and Linux in CI, and its build is reproducible.

The milestone is cut into increments that each end tested. Each one is an issue under
the M2 epic on the roadmap project.

| # | Increment | Tested by | State |
|---|---|---|---|
| [2.1](https://github.com/envoscale/EnvoScale/issues/46) | Specs and RFCs: `envo-s1.md`; RFCs for slices (#45), function types (#30), lifetimes (#31), EIR v1 (#29) | review | done: [`envo-s1.md`](spec/envo-s1.md), RFCs [0002](rfcs/0002-slicing.md)–[0005](rfcs/0005-eir-v1.md) |
| [2.2](https://github.com/envoscale/EnvoScale/issues/47) | Stage 1 skeleton: build with `envoc0`, support library (arena, buffers, strings, hash map, files, diagnostics), `envoc1 version`; scripts and CI build it | smoke tests | done: support library, `envoc1 version` / `selftest`, built for both OSes by the scripts and CI |
| [2.3](https://github.com/envoscale/EnvoScale/issues/48) | Lexer for the full lexical grammar | lexer goldens and `01-lexical` must match `envoc0` (D14) | done: all 13 goldens and 41 lexical tests match in `--core` and S1 modes; all 275 test inputs lex identically |
| [2.4](https://github.com/envoscale/EnvoScale/issues/49) | Parser for Envo-S1 | `core-syntax` (same codes and positions as `envoc0`), new S1 syntax tests | done: the Core grammar matches `envoc0` on every parser golden, `core-syntax` test and test input; the S1 grammar has 4 hand-checked goldens and 13 error tests |
| [2.5](https://github.com/envoscale/EnvoScale/issues/50) | Names and types for Envo-Core | `core-types` (same codes and positions) | done: every `check` golden, `core-types` and `core-multi` test and test input gives the same output as `envoc0`; `envoc1` checks its own source |
| [2.6](https://github.com/envoscale/EnvoScale/issues/51) | EIR v1: data structures, text form (print and parse, round-trip), verifier | `tests/golden/eir/` | done: `envoc1 eir-check`; 3 round-trip goldens and 13 verifier/syntax tests (`tests/spec/eir/`). The binary form ([eir.bin.*]) moves to Stage 2, where it is first needed |
| [2.7](https://github.com/envoscale/EnvoScale/issues/52) | Lowering Core to EIR; x86-64 backend; PE/ELF writer; runtime | `core-run`, `core-multi` under `envoc1` | done: every `core-run` and `core-multi` program built by `envoc1` gives the same output and exit code as under `envoc0`, on both OSes ([`architecture/stage1.md`](architecture/stage1.md)) |
| [2.8](https://github.com/envoscale/EnvoScale/issues/53) | Generics and interfaces | S1 type and run tests | done: generic functions and structs (monomorphized), methods and receivers, `in`/`ref` parameters, interfaces with default bodies and bounds; 31 type and 4 run tests ([`architecture/stage1.md`](architecture/stage1.md)) |
| [2.9](https://github.com/envoscale/EnvoScale/issues/54) | Closures and function types | S1 type and run tests | done: function types and kinds, lambdas with inferred types and captures (borrowed for function-typed parameters, copied otherwise), named functions as values, calls through function values; 10 type tests and a run test |
| [2.10](https://github.com/envoscale/EnvoScale/issues/55) | Ownership: moves, borrows, lifetime elision, basic borrow checker (E05xx) | S1 ownership tests | done: `Copy` and the prelude's `IDrop`, the move checker (E0501, E0502), drops with drop flags, call borrows (E0503, E0504), escaping closures and `from` clauses (E0507, E0508); 28 ownership tests and a drop-order run test |
| [2.11](https://github.com/envoscale/EnvoScale/issues/66) | Enums with payloads, `match` expressions with payload patterns and guards, `Option` and `Result`, `?:`, `??` and `?` | S1 type and run tests | done: tagged enums (generic, recursive through pointers, with drops), unqualified variants, `match` with payload bindings and guards, `match` expressions, `Option`/`Result` in the prelude with `T?`, `null`, `??` and `?`, the conditional; 20 type tests and 2 run tests |
| [2.12](https://github.com/envoscale/EnvoScale/issues/67) | The rest of Envo-S1: `foreach`, slicing, namespaces and `use`, the prelude (`string`, `List<T>`, `IDrop`) | S1 type and run tests | done: views and slicing with run-time checks, `foreach`, `List<T>` and `string` in the prelude, namespaces, `use` and visibility; run tests for views and collections, 4 multi-file tests (`tests/spec/s1-multi/`), 16 error tests |
| [2.13](https://github.com/envoscale/EnvoScale/issues/56) | Envo-S1 spec suite green on Windows and Linux in CI; reproducible `envoc1`; no E0951 left | CI | next |

## 6. Risks

- **Stage 1 volume.** A compiler in Envo-Core, which has no generics or methods, is
  verbose. Expect 30–50k lines. Mitigation: a small support library written once, one
  file per pass, and tests per increment so size never hides bugs.
- **Stage 0 bugs found by a large program.** `envoc0` has only compiled tests so far.
  A miscompilation in Stage 1 looks like a Stage 1 bug. Mitigation: differential tests
  (D14) and a minimal reproduction added to `core-run` for every Stage 0 bug found.
  Fixes must fit Stage 0's budget; a fix that cannot gets an RFC.
- **Debugging without locations.** Programs built by `envoc0` panic with a reason but
  no source location. Mitigation: small functions, unit-style tests per module, and
  `envoc1` itself reporting its phase on internal errors.
- **Speed.** `envoc0` output has no optimizer and a bump allocator that never frees.
  Fine at Stage 1's scale; measured from 2.4 on and recorded in `STATUS.md`.
- **Untestable Linux path locally.** Development happens on Windows; Linux binaries
  only run in CI. Unchanged from M1.
- **Spec drift.** Chapters 1–5 are drafts; Envo-S1 makes parts of chapters 2–5
  normative as `envoc1` implements them.
