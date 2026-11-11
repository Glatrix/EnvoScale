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
| M2 | Stage 1 | **Next**: RFCs (EIR v1, function types, lifetimes), then `envoc1` in Envo-Core |
| M3–M13 | | Not started |

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

## Subsystems

| Subsystem | Tier | What works | What's missing | Next step |
|---|---|---|---|---|
| **Docs: language spec** (`docs/spec`) | Experimental | Ch. 1 normative with rule IDs linked to tests; ch. 2–5 drafts; Envo-Core, EAS, EON drafts; error registry | Ch. 6+ (generics, modules in depth, async, comptime); EIR (M2) | Envo-Core grammar (`envo-core.md` §5.1) is now normative and tested |
| **RFCs** (`docs/rfcs`) | — | Template; RFC 0001 (normative example audit) accepted | — | Further RFCs as listed on the roadmap (EIR v1, function types, lifetimes) |
| **Bootstrap: seed** (`bootstrap/seed`) | — | — | Everything (Phase B, required before 1.0) | After Stage 0 is complete, so the `.eas` subset is final |
| **Bootstrap: Stage 0** (`bootstrap/stage0`) | Experimental | 15.0k lines of `.eas`. `envoc0 lex`, `parse`, `check` and `build` (`check` and `build` take several files as one program): lexer, parser, type checker, x86-64 code generator with run-time checks (overflow, bounds, division, shifts), and PE/ELF writers. Compiled programs reuse envoc0's own runtime block (OS shim, argv, built-ins), so envoc0 cross-compiles; hello world is 8 KB. Builds are byte-identical across hosts and NASM 2.16/3.02. **249/249 tests pass on Windows and Linux** | Fixes only: the 15k-line budget is used up | Stage 1 (M2) |
| **Bootstrap: Stage 1** (`bootstrap/stage1`) | — | — | Everything | M2 |
| **Bootstrap adapter: NASM** (`adapters/bootstrap/nasm`) | Experimental | `assemble.ps1` / `assemble.sh` | — | Used by CI and local builds |
| **Build entry points** (`bootstrap.ps1`, `bootstrap.sh`) | Experimental | `check` (layout, lib→adapters imports, gallery line limits), `build` and `test` all work on Windows PowerShell and Git Bash. Verified that `check` catches a planted forbidden import and that `test` catches a wrong token and a wrong error column | — | — |
| **CI adapter** (`adapters/ci/github`) | Experimental | Runs on [envoscale/EnvoScale](https://github.com/envoscale/EnvoScale/actions). All four jobs pass: `check`, `stage0-windows` and `stage0-linux` (249/249 each), and `reproducible`, which fails unless the Linux-host and Windows-host builds are byte-identical. Every jump in Stage 0 states its size (`docs/spec/eas.md`), so NASM 2.16 (CI) and 3.02 (local) produce the same bytes. Linux installs NASM through `install-nasm.sh`, which falls back to `archive.ubuntu.com` when the runner's mirror fails | CI builds with one NASM version per host; local NASM 3.02 was compared by hand (identical). The mirror fallback has not been exercised yet | Stage 1 jobs (M2) |
| **Tests** (`tests/`) | — | 13 lexer, 8 parser and 8 checker golden tests; 41 lexical, 43 syntax and 90 type `expect-error` spec tests; 33 compiled-and-run programs; 7 multi-file programs (1 run, 6 errors); 6 CLI smoke tests (incl. cross-compilation); Hello World Gallery files with line limits | Stage 1 tests (M2) | M2 |
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
