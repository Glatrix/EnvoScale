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
| M1 | Stage 0 | **In progress**: platform shims, runtime helpers, lexer, parser and type checker done; 208/208 tests pass on Windows (Linux in CI). Code generation next |
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
| **Bootstrap: Stage 0** (`bootstrap/stage0`) | Experimental | Assembles with NASM 3.02 into `envoc0.exe` (40,960 bytes) and `envoc0` (32,504 bytes), byte-identical on rebuild. PE and ELF headers; Windows (kernel32, UTF-8 paths and arguments via the wide APIs) and Linux (syscall) shims with argv parsing; arena; buffered I/O; diagnostics with line/column; UTF-8 validation; the lexer; the Envo-Core parser with E01xx/E0905 diagnostics and a 256-level depth limit; the type checker (scopes, struct layout, enums, constant evaluation, literal typing, places, `unsafe`, termination and `match` exhaustiveness) with E02xx/E03xx diagnostics; `envoc0 lex`, `parse`, `check`, `version`, `help`. **All 208 tests pass on Windows** (PowerShell and Git Bash runners, locally and in CI) **and on Linux** (CI) | x86-64 code generation, PE/ELF writers for output programs, builtins | Code generation (PLAN.md §5, 1.7) |
| **Bootstrap: Stage 1** (`bootstrap/stage1`) | — | — | Everything | M2 |
| **Bootstrap adapter: NASM** (`adapters/bootstrap/nasm`) | Experimental | `assemble.ps1` / `assemble.sh` | — | Used by CI and local builds |
| **Build entry points** (`bootstrap.ps1`, `bootstrap.sh`) | Experimental | `check` (layout, lib→adapters imports, gallery line limits), `build` and `test` all work on Windows PowerShell and Git Bash. Verified that `check` catches a planted forbidden import and that `test` catches a wrong token and a wrong error column | — | — |
| **CI adapter** (`adapters/ci/github`) | Experimental | Runs on [envoscale/EnvoScale](https://github.com/envoscale/EnvoScale/actions). All three jobs pass: `check`, `stage0-windows` and `stage0-linux` (208/208 each). The two CI hosts (NASM 2.16.x) produce byte-identical envoc0 binaries. Linux installs NASM through `install-nasm.sh`, which falls back to `archive.ubuntu.com` when the runner's mirror fails | **NASM 3.02 (local) and 2.16 (CI) now produce different bytes** for the M1.6 code (issue #20); the mirror fallback has not been exercised yet; the hash comparison is read by eye, not automated | Automate the cross-host hash comparison (issue: "CI: check envoc0 is byte-identical across Windows and Linux hosts") |
| **Tests** (`tests/`) | — | 13 lexer, 8 parser and 8 checker golden tests; 41 lexical, 43 syntax and 90 type `expect-error` spec tests; 5 CLI smoke tests; Hello World Gallery files with line limits | `// expect:` tests that run compiled programs | Code generation tests (M1.7) |
| **Compiler: Stage 2** (`compiler/`) | — | — | Everything | M3 |
| **Runtime** (`runtime/`) | — | — | Everything | M3 (startup/panic/ARC), M6 (VM) |
| **Standard platform** (`lib/`) | — | — | Everything | M4 |
| **Adapters** (`adapters/os`, `window`, `gpu`, …) | — | — | Everything | M4 onward |
| **Tools** (`tools/`) | — | — | Everything | M5 |
| **Templates** (`templates/`) | — | — | Everything | M5 / M9 |

## Known limitations

- **Different NASM versions assemble Stage 0 differently since M1.6.** NASM 2.16 (CI)
  and 3.02 (local) disagree on some instruction encoding added by the checker; each
  version is self-consistent and every build passes all tests. Tracked in issue #20;
  the fix is an encoding rule in `docs/spec/eas.md` that every assembler, including
  the future seed, must follow.

- **Linux is only exercised in CI.** The development machine runs Windows (WSL is broken
  there); the Linux binary is cross-assembled locally and run by the `stage0-linux` job.
- **Stage 0 source files are limited to 16 MiB**, reported as an error.
- **The license and CLA have not had legal review.** `LICENSE` applies the PolyForm
  Noncommercial License 1.0.0 by reference to its official text and adds commercial
  terms; `CLA.md` is an original draft. Both should be reviewed by a lawyer before
  commercial licenses are sold.
