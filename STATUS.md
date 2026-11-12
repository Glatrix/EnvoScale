# EnvoScale Status

Live status of every subsystem. Updated by every change that moves a subsystem forward
or back (brief §0.4, §14.5). Stability tiers are defined in brief §14.4:
**Experimental** (may change or vanish), **Preview** (breaking changes need an RFC),
**Stable** (SemVer + editions). "—" means the subsystem does not exist yet.

_Last updated: 2026-11-11._ Work is tracked on the
[EnvoScale Roadmap](https://github.com/orgs/envoscale/projects/3) project: one epic issue per
milestone, increments as sub-issues, and owner decisions marked **Needs Decision**.

## Milestones

| # | Milestone | State |
|---|---|---|
| M0 | Charter & skeleton | **Done** (see DoD record below) |
| M1 | Stage 0 | **Done** (see DoD record below) |
| M2 | Stage 1 | **Done** (see DoD record below): `envoc1`, written in Envo-Core and built by `envoc0`, compiles Envo-Core and Envo-S1 to Windows and Linux executables through EIR v1 |
| M3 | Self-hosting | **In progress**: increments 3.1–3.9 planned (`docs/PLAN.md` §5, decisions D16–D20); next the Stage 2 skeleton (M3.1) |
| M4–M13 | | Not started |

### M0 Definition of Done — record

| DoD item | Where | State |
|---|---|---|
| Repo layout from §6, README in every top-level folder | `tests/layout.txt` lists 138 folders; `bootstrap.* check` verifies each has a README | Done |
| `CHARTER.md`, `STATUS.md`, `PLAN.md` | root, `docs/PLAN.md` | Done |
| RFC template | `docs/rfcs/0000-template.md` | Done |
| `docs/spec/envo-core.md`, `eas.md`, `eon.md` | `docs/spec/` | Done (drafts; `eas.md` normative for the Stage 0 subset) |
| Language spec chapters 1–5 (first draft) | `docs/spec/01-…05-*.md` | Done (chapter 1 normative) |
| `examples/00-hello` | `examples/00-hello/` | Done |
| CI adapter running a check | `.github/workflows/ci.yml` → `bootstrap.sh check` | Done (passes on GitHub Actions) |

### M1 Definition of Done — record

| DoD item (brief §15) | Where | State |
|---|---|---|
| `envoc0` (assembly) compiles Envo-Core to working x86-64 executables on Windows and Linux | `bootstrap/stage0/`; `tests/spec/core-run/`, `core-multi/` run on both OSes in CI | Done |
| Spec tests for Envo-Core pass | 174 `expect-error` tests covering every error code Stage 0 reports, 33 run programs, 7 multi-file programs; 249/249 on Windows and Linux | Done |
| Built through the Phase A bootstrap adapter (§5.4) | `adapters/bootstrap/nasm/`; byte-identical builds across hosts and NASM versions (CI `reproducible`) | Done |
| `bootstrap.ps1` and `bootstrap.sh` work | both run `build`, `test`, `check` locally and in CI | Done |

### M2 Definition of Done — record

| DoD item (brief §15; PLAN §5) | Where | State |
|---|---|---|
| Envo-S1 specified | `docs/spec/envo-s1.md`, RFCs 0002–0005, EIR v1 (`docs/spec/eir.md`) | Done |
| `envoc1`, written in Envo-Core, builds with `envoc0` | `bootstrap/stage1/` (about 17k lines, listed in `files.txt`), built by both bootstrap scripts and CI; `envoc1 --core` checks its own source | Done |
| It compiles a larger subset: generics, interfaces, closures, a basic borrow checker, EIR | generics and interfaces (M2.8), closures (M2.9), ownership and borrow checking (M2.10), enums with payloads (M2.11), views, collections and namespaces (M2.12), all through EIR v1 to x86-64 (M2.6–M2.7); `docs/architecture/stage1.md` | Done |
| Every Envo-Core spec test passes under `envoc1` | `core-*` and golden suites, error for error with `envoc0` (D14), and every run program with the same output and exit code | Done |
| Every Envo-S1 spec test passes | `s1-syntax` (13), `s1-types` (77), `s1-own` (37), `s1-run` (10 programs), `s1-multi` (4); no E0951 left: every S1 construct compiles or is recorded as outside S1 (E0950) | Done |
| On Windows and Linux in CI, with a reproducible `envoc1` | 739/739 on both hosts; CI `reproducible` compares the Linux-host and Windows-host builds of `envoc0` and `envoc1` byte for byte | Done |

## Subsystems

| Subsystem | Tier | What works | What's missing | Next step |
|---|---|---|---|---|
| **Docs: language spec** (`docs/spec`) | Experimental | Ch. 1 normative with rule IDs linked to tests; ch. 2–5 drafts; Envo-Core, EAS, EON drafts; error registry | Ch. 6+ (generics, modules in depth, async, comptime). Envo-S1 and EIR v1 are specified (M2.1); EIR v1's text form and verifier are implemented (M2.6) | Envo-Core grammar (`envo-core.md` §5.1) is now normative and tested |
| **RFCs** (`docs/rfcs`) | — | Template; RFC 0001 (normative example audit) accepted | — | Further RFCs as listed on the roadmap (EIR v1, function types, lifetimes) |
| **Bootstrap: seed** (`bootstrap/seed`) | — | — | Everything (Phase B, required before 1.0) | After Stage 0 is complete, so the `.eas` subset is final |
| **Bootstrap: Stage 0** (`bootstrap/stage0`) | Experimental | 15.0k lines of `.eas`. `envoc0 lex`, `parse`, `check` and `build` (`check` and `build` take several files as one program): lexer, parser, type checker, x86-64 code generator with run-time checks (overflow, bounds, division, shifts), and PE/ELF writers. Compiled programs reuse envoc0's own runtime block (OS shim, argv, built-ins), so envoc0 cross-compiles; hello world is 8 KB. Builds are byte-identical across hosts and NASM 2.16/3.02. **249/249 tests pass on Windows and Linux** | Fixes only: the 15k-line budget is used up | Stage 1 (M2) |
| **Bootstrap: Stage 1** (`bootstrap/stage1`) | Experimental | In Envo-Core (17.3k lines), built by `envoc0` for Windows and Linux by both bootstrap scripts and CI: support library (buffers, vectors, hash map, files, diagnostics in `envoc0`'s format), `envoc1 version`, `help`, `selftest`, `lex`, `parse` (the whole Envo-S1 grammar) and `check` (Envo-Core names and types), `eir-check` (EIR v1 text reader, canonical printer and verifier), and `build`/`eir`: lowering to EIR, an x86-64 backend, PE/ELF writers and a runtime written in Envo-Core. Every Envo-Core test program built by `envoc1` gives the same output and exit code as under `envoc0`, on Windows and Linux; on Envo-Core the front end matches `envoc0` error for error, and `envoc1` checks its own source. Envo-S1 so far: generic functions and structs (monomorphized), methods and receivers, `in`/`ref` parameters, interfaces with default bodies and `where` bounds (static dispatch), function types, lambdas with captures and function values, moves and drops (`IDrop`, drop flags) and basic borrow checking, enums with payloads and `match` expressions with bindings and guards, `?:`; views and slicing, `foreach`, namespaces and `use`; the S1 prelude with Option, Result, `List<T>` and `string`; constructs outside Envo-S1 are E0950 | Speed (a stack-slot backend with no optimizer, by design: D15) | Stage 2 `envoc`, written in Envo-S1 (M3) |
| **Bootstrap adapter: NASM** (`adapters/bootstrap/nasm`) | Experimental | `assemble.ps1` / `assemble.sh` | — | Used by CI and local builds |
| **Build entry points** (`bootstrap.ps1`, `bootstrap.sh`) | Experimental | `check` (layout, lib→adapters imports, gallery line limits), `build` and `test` all work on Windows PowerShell and Git Bash. Verified that `check` catches a planted forbidden import and that `test` catches a wrong token and a wrong error column | — | — |
| **CI adapter** (`adapters/ci/github`) | Experimental | Runs on [envoscale/EnvoScale](https://github.com/envoscale/EnvoScale/actions). All four jobs pass: `check`, `stage0-windows` and `stage0-linux` (739/739 each, including every run and multi-file program compiled by both `envoc0` and `envoc1`, Stage 1's differential lexer, parser and checker tests, Envo-S1 syntax, type, ownership and run tests, EIR tests and the Stage 1 self-check), and `reproducible`, which fails unless the Linux-host and Windows-host builds of `envoc0` and `envoc1` are byte-identical. Every jump in Stage 0 states its size (`docs/spec/eas.md`), so NASM 2.16 (CI) and 3.02 (local) produce the same bytes. Linux installs NASM through `install-nasm.sh`, which falls back to `archive.ubuntu.com` when the runner's mirror fails | CI builds with one NASM version per host (3.01 on Ubuntu 26.04); NASM 2.16, 3.01 and 3.02 give identical bytes since the adapter keeps `near` jumps rel32. The mirror fallback has not been exercised yet | Stage 1 jobs (M2) |
| **Tests** (`tests/`) | — | 13 lexer, 8 parser and 8 checker golden tests; 41 lexical, 43 syntax and 90 type `expect-error` spec tests; 33 compiled-and-run programs; 7 multi-file programs (1 run, 6 errors); Envo-S1: 13 syntax, 77 type and 37 ownership `expect-error` tests, 10 compiled-and-run programs and 4 multi-file tests; 6 CLI smoke tests (incl. cross-compilation); Hello World Gallery files with line limits | Stage 1 tests (M2) | M2 |
| **Compiler: Stage 2** (`compiler/`) | — | — | Everything | M3 |
| **Runtime** (`runtime/`) | — | — | Everything | M3 (startup/panic/ARC), M6 (VM) |
| **Standard platform** (`lib/`) | — | — | Everything | M4 |
| **Adapters** (`adapters/os`, `window`, `gpu`, …) | — | — | Everything | M4 onward |
| **Tools** (`tools/`) | — | — | Everything | M5 |
| **Templates** (`templates/`) | — | — | Everything | M5 / M9 |

## Known limitations


- **Linux is only exercised in CI.** The development machine runs Windows (WSL is broken
  there); the Linux binary is cross-assembled locally and run by the `stage0-linux` job.
- **Stage 0 source files are limited to 16 MiB**, reported as an error.
- **Envo-Core has no way to make a non-empty slice.** `T[]` exists, but slicing
  ([RFC 0002](docs/rfcs/0002-slicing.md)) is in full Envo and Envo-S1 only, so Core code
  (including Stage 1's source) uses a pointer and a length instead.
- **The legal documents have not had legal review.** `LICENSE` applies the PolyForm
  Noncommercial License 1.0.0 (full text in `LICENSES/`) and reserves commercial use for
  signed agreements. The commercial agreement and order form templates
  (`docs/legal/`), `CLA.md` and `TRADEMARKS.md` are original drafts, and the licensor is
  still named by GitHub handle rather than a legal person or company. A lawyer should
  review them, and the licensor be named, before the first commercial license is sold
  ([#35](https://github.com/envoscale/EnvoScale/issues/35)).
