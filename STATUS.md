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
| M1 | Stage 0 | **In progress**: platform shims, runtime helpers, the whole Stage 0 pipeline works: `envoc0 build` compiles Envo-Core to Windows and Linux executables; 233/233 tests pass. Remaining: a broader test suite (M1.9) |
| M2–M13 | | Not started |

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

## Subsystems

| Subsystem | Tier | What works | What's missing | Next step |
|---|---|---|---|---|
| **Docs: language spec** (`docs/spec`) | Experimental | Ch. 1 normative with rule IDs linked to tests; ch. 2–5 drafts; Envo-Core, EAS, EON drafts; error registry | Ch. 6+ (generics, modules in depth, async, comptime); EIR (M2) | Envo-Core grammar (`envo-core.md` §5.1) is now normative and tested |
| **RFCs** (`docs/rfcs`) | — | Template; RFC 0001 (normative example audit) accepted | — | Further RFCs as listed on the roadmap (EIR v1, function types, lifetimes) |
| **Bootstrap: seed** (`bootstrap/seed`) | — | — | Everything (Phase B, required before 1.0) | After Stage 0 is complete, so the `.eas` subset is final |
| **Bootstrap: Stage 0** (`bootstrap/stage0`) | Experimental | 14.7k lines of `.eas`. `envoc0 lex`, `parse`, `check` and `build`: lexer, parser, type checker, x86-64 code generator with run-time checks (overflow, bounds, division, shifts), and PE/ELF writers. Compiled programs reuse envoc0's own runtime block (OS shim, argv, built-ins), so envoc0 cross-compiles; hello world is 8 KB. Builds are byte-identical across hosts and NASM 2.16/3.02. **233/233 tests pass on Windows** (both runners); Linux runs in CI | Multi-file builds (`envoc0 build a.envo b.envo`); a test for every Envo-Core rule | M1.9, then Stage 1 (M2) |
| **Bootstrap: Stage 1** (`bootstrap/stage1`) | — | — | Everything | M2 |
| **Bootstrap adapter: NASM** (`adapters/bootstrap/nasm`) | Experimental | `assemble.ps1` / `assemble.sh` | — | Used by CI and local builds |
| **Build entry points** (`bootstrap.ps1`, `bootstrap.sh`) | Experimental | `check` (layout, lib→adapters imports, gallery line limits), `build` and `test` all work on Windows PowerShell and Git Bash. Verified that `check` catches a planted forbidden import and that `test` catches a wrong token and a wrong error column | — | — |
| **CI adapter** (`adapters/ci/github`) | Experimental | Runs on [envoscale/EnvoScale](https://github.com/envoscale/EnvoScale/actions). All four jobs pass: `check`, `stage0-windows` and `stage0-linux` (208/208 each), and `reproducible`, which fails unless the Linux-host and Windows-host builds are byte-identical. Every jump in Stage 0 states its size (`docs/spec/eas.md`), so NASM 2.16 (CI) and 3.02 (local) produce the same bytes. Linux installs NASM through `install-nasm.sh`, which falls back to `archive.ubuntu.com` when the runner's mirror fails | CI builds with one NASM version per host; local NASM 3.02 was compared by hand (identical). The mirror fallback has not been exercised yet | Code generation (M1.7) |
| **Tests** (`tests/`) | — | 13 lexer, 8 parser and 8 checker golden tests; 41 lexical, 43 syntax and 90 type `expect-error` spec tests; 24 compiled-and-run programs; 6 CLI smoke tests (incl. cross-compilation); Hello World Gallery files with line limits | A run test for every Envo-Core rule | M1.9 |
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
- **The license and CLA have not had legal review.** `LICENSE` applies the PolyForm
  Noncommercial License 1.0.0 by reference to its official text and adds commercial
  terms; `CLA.md` is an original draft. Both should be reviewed by a lawyer before
  commercial licenses are sold.
