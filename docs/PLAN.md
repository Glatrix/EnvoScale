# EnvoScale — Working Plan

This file is required by §0.1 of the founding brief ([`ENVOSCALE_PROMPT.md`](../ENVOSCALE_PROMPT.md)).
It records how the brief was understood, the questions still open, and the task
breakdown for the current milestone. It is rewritten at the start of each milestone.

- **Current milestone:** M0 (charter and skeleton) → done this session; M1 (Stage 0) started.
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

## 3. Open questions

Items marked **RFC** conflict with the brief as written and are tracked in an RFC
(§0.7). The others are choices the project owner should confirm.

1. ~~**RFC 0001**~~ **Accepted 2026-11-11** (C1 `Copy` bound, C2 `Trimmed()`). Original question: **RFC 0001 — normative example audit.** Some §3.3 examples can't type-check under
   the brief's own rules: `Largest<T>` moves a non-`Copy` `T` out of a borrowed span
   ("no hidden copies"), and `ReadConfig` returns `text.Trim()` — a borrow of a local
   — as an owned `string`. See [`docs/rfcs/0001-normative-example-audit.md`](rfcs/0001-normative-example-audit.md).
2. ~~**License.**~~ **Decided 2026-11-11 by the owner:** free for individuals and
   noncommercial use (PolyForm Noncommercial 1.0.0), commercial licenses for companies,
   contributions under a CLA. See `LICENSING.md`. The text below is the original question.
   `LICENSE` was MIT with "The EnvoScale contributors" as a placeholder
   choice. The owner should confirm or replace it before the first public release.
3. **Explicit lifetime syntax.** The brief says explicit lifetimes "exist but are
   rarely needed" without giving a spelling. Rust's `'a` collides with char literals
   in a C#-style lexer. Deferred to an RFC; the draft spec reports elision failures
   as an error with no explicit escape hatch yet.
4. **Function types.** No syntax is given for function pointer / closure types.
   Deferred to an RFC alongside generics (needed by M2).
5. ~~**Unicode paths on Windows.**~~ **Decided 2026-11-11: UTF-8 everywhere.** Stage 0 now uses the `…W` APIs and converts with kernel32's UTF-8 routines. Original question: Stage 0 uses the `…A` kernel32 entry points, so paths
   must be in the active code page. Fixing it means UTF-16 conversion in assembly;
   deferred unless it blocks someone (tracked in `STATUS.md`).
6. **Edition name.** The brief uses `edition = "2027"` while the current year is 2026.
   Kept as written; the first stable edition will be named when it ships.

## 4. M0 — Charter and skeleton (done this session)

| Task | Output |
|---|---|
| Repository layout from §6, with a README in every folder | all folders |
| Charter, status, contributing, security, code of conduct, license | root files |
| RFC template + RFC 0001 | `docs/rfcs/` |
| Envo-Core, EAS and EON specs | `docs/spec/envo-core.md`, `eas.md`, `eon.md` |
| Language spec chapters 1–5 (draft) | `docs/spec/01-…05-*.md` |
| Error code registry | `docs/spec/errors.md` |
| `examples/00-hello` | `examples/00-hello/` |
| Hello World Gallery files + line-count check | `tests/spec/hello/`, `bootstrap.* check` |
| CI adapter running the check | `.github/workflows/ci.yml`, `adapters/ci/github/` |
| Porting checklist outline | `docs/porting/CHECKLIST.md` |

**DoD:** every item above exists, `bootstrap.ps1 check` and `bootstrap.sh check` pass,
and `STATUS.md` records M0 as done.

## 5. M1 — Stage 0 (started this session)

The milestone is large, so it is cut into increments that each end tested.

| # | Increment | Tested by | State |
|---|---|---|---|
| 1.1 | Envo-Core spec (lexical, types, statements, builtins) | review | done (draft) |
| 1.2 | Platform shims: PE/ELF headers, 8 shim functions, argv | builds; smoke tests | done (Windows and Linux) |
| 1.3 | Runtime helpers: arena, buffered I/O, diagnostics, UTF-8 check | via 1.4 tests | done |
| 1.4 | Lexer + `envoc0 lex` token dump | `tests/golden/lexer/`, `tests/spec/01-lexical/` | done |
| 1.5 | Parser → AST for Envo-Core | `tests/golden/parser/`, `tests/spec/core-syntax/` | done (109/109 on Windows and Linux) |
| 1.6 | Type checker for Envo-Core | `tests/golden/check/`, `tests/spec/core-types/` | done (208/208 on Windows) |
| 1.7 | x86-64 code generation + PE/ELF writers for *output* programs | `// expect:` spec tests, hello world | next |
| 1.8 | Builtins (`print`, file I/O, `alloc`, args) for output programs | spec tests | |
| 1.9 | Full Envo-Core spec test suite green on Windows and Linux in CI | CI | |

Nothing is marked done until its tests pass. The Linux half of each increment counts as
done only once the `stage0-linux` CI job passes.

## 6. Risks

- **Assembly volume.** Stage 0 targets < 15k lines. After the checker (M1.6) it is
  10.8k lines, about 600 of them generated tables, leaving roughly 4k for code
  generation, the PE/ELF writers and built-ins. Keeping the code generator a simple
  stack machine that reuses the checker's types and layouts is how that budget is met;
  if it is exceeded, the overrun gets an RFC rather than silent growth.
- **Untestable Linux path locally.** Development happens on Windows; the Linux ELF is
  cross-assembled here and only *run* in CI. The two platform files share no code
  paths besides the shim interface, so a Linux-only bug stays in `platform/linux.eas`.
- **Spec drift.** Chapters 1–5 are drafts. The lexical chapter is normative now
  because Stage 0 implements it; the others become normative as stages implement them.
