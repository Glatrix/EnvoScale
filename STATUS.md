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
| M1 | Stage 0 | **In progress**: platform shims, runtime helpers, lexer and parser done; 109/109 tests pass on Windows and Linux. Type checker next |
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
| **Docs: language spec** (`docs/spec`) | Experimental | Ch. 1 normative with rule IDs linked to tests; ch. 2–5 drafts; Envo-Core, EAS, EON drafts; error registry | Ch. 6+ (generics, modules in depth, async, comptime); EIR (M2) | Resolve RFC 0001; Envo-Core grammar (`envo-core.md` §5.1) is now normative and tested |
| **RFCs** (`docs/rfcs`) | — | Template; RFC 0001 (normative example audit) proposed | Owner decision on RFC 0001 C1/C2 | Review RFC 0001 |
| **Bootstrap: seed** (`bootstrap/seed`) | — | — | Everything (Phase B, required before 1.0) | After Stage 0 is complete, so the `.eas` subset is final |
| **Bootstrap: Stage 0** (`bootstrap/stage0`) | Experimental | Assembles with NASM 3.02 into `envoc0.exe` (24,576 bytes) and `envoc0` (16,016 bytes), byte-identical on rebuild. PE and ELF headers; Windows (kernel32) and Linux (syscall) shims with argv parsing; arena; buffered I/O; diagnostics with line/column; UTF-8 validation; the lexer; the Envo-Core parser with E01xx/E0905 diagnostics and a 256-level depth limit; `envoc0 lex`, `parse`, `version`, `help`. **All 109 tests pass on Windows** (PowerShell and Git Bash runners, locally and in CI) **and on Linux** (CI) | Type checker, x86-64 code generation, PE/ELF writers for output programs, builtins | Type checker (PLAN.md §5, 1.6) |
| **Bootstrap: Stage 1** (`bootstrap/stage1`) | — | — | Everything | M2 |
| **Bootstrap adapter: NASM** (`adapters/bootstrap/nasm`) | Experimental | `assemble.ps1` / `assemble.sh` | — | Used by CI and local builds |
| **Build entry points** (`bootstrap.ps1`, `bootstrap.sh`) | Experimental | `check` (layout, lib→adapters imports, gallery line limits), `build` and `test` all work on Windows PowerShell and Git Bash. Verified that `check` catches a planted forbidden import and that `test` catches a wrong token and a wrong error column | — | — |
| **CI adapter** (`adapters/ci/github`) | Experimental | Runs on [envoscale/EnvoScale](https://github.com/envoscale/EnvoScale/actions). All three jobs pass: `check`, `stage0-windows` and `stage0-linux` (109/109 each). Both hosts produce envoc0 binaries byte-identical to the local build, even with different NASM versions (2.16.01 in Linux CI, 3.02 locally). Linux installs NASM through `install-nasm.sh`, which falls back to `archive.ubuntu.com` when the runner's mirror fails | The mirror fallback has not been exercised yet (the default mirror worked on the passing run); the hash comparison is read by eye, not automated | Automate the cross-host hash comparison (issue: "CI: check envoc0 is byte-identical across Windows and Linux hosts") |
| **Tests** (`tests/`) | — | 13 lexer and 8 parser golden tests, 41 lexical and 43 syntax `expect-error` spec tests, 4 CLI smoke tests, Hello World Gallery files with line limits | Everything that needs a type checker or code generator | Type-checking spec tests (M1.6) |
| **Compiler: Stage 2** (`compiler/`) | — | — | Everything | M3 |
| **Runtime** (`runtime/`) | — | — | Everything | M3 (startup/panic/ARC), M6 (VM) |
| **Standard platform** (`lib/`) | — | — | Everything | M4 |
| **Adapters** (`adapters/os`, `window`, `gpu`, …) | — | — | Everything | M4 onward |
| **Tools** (`tools/`) | — | — | Everything | M5 |
| **Templates** (`templates/`) | — | — | Everything | M5 / M9 |

## Known limitations

- **Linux is only exercised in CI.** The development machine runs Windows (WSL is broken
  there); the Linux binary is cross-assembled locally and run by the `stage0-linux` job.
- **Windows paths must be in the active code page.** Stage 0 uses `CreateFileA` and
  `GetCommandLineA`. (TODO(M1): decide whether UTF-8 paths are needed before Stage 1;
  `docs/PLAN.md` open question 5.)
- **Stage 0 source files are limited to 16 MiB**, reported as an error.
- **The license and CLA have not had legal review.** `LICENSE` applies the PolyForm
  Noncommercial License 1.0.0 by reference to its official text and adds commercial
  terms; `CLA.md` is an original draft. Both should be reviewed by a lawyer before
  commercial licenses are sold.
