# EnvoScale Status

Live status of every subsystem. Updated by every change that moves a subsystem forward
or back (brief §0.4, §14.5). Stability tiers are defined in brief §14.4:
**Experimental** (may change or vanish), **Preview** (breaking changes need an RFC),
**Stable** (SemVer + editions). "—" means the subsystem does not exist yet.

_Last updated: 2026-11-11._

## Milestones

| # | Milestone | State |
|---|---|---|
| M0 | Charter & skeleton | **Done** (see DoD record below) |
| M1 | Stage 0 | **In progress**: platform shims, runtime helpers and lexer done; 58/58 tests pass on Windows (Linux runs in CI only). Parser next |
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
| CI adapter running a check | `.github/workflows/ci.yml` → `bootstrap.sh check` | Done (not yet run on GitHub: the repository has not been pushed) |

## Subsystems

| Subsystem | Tier | What works | What's missing | Next step |
|---|---|---|---|---|
| **Docs: language spec** (`docs/spec`) | Experimental | Ch. 1 normative with rule IDs linked to tests; ch. 2–5 drafts; Envo-Core, EAS, EON drafts; error registry | Ch. 6+ (generics, modules in depth, async, comptime); EIR (M2) | Resolve RFC 0001; ch. 3 rules become tests as the parser lands |
| **RFCs** (`docs/rfcs`) | — | Template; RFC 0001 (normative example audit) proposed | Owner decision on RFC 0001 C1/C2 | Review RFC 0001 |
| **Bootstrap: seed** (`bootstrap/seed`) | — | — | Everything (Phase B, required before 1.0) | After Stage 0 is complete, so the `.eas` subset is final |
| **Bootstrap: Stage 0** (`bootstrap/stage0`) | Experimental | Assembles with NASM 3.02 into `envoc0.exe` (16,384 bytes) and `envoc0` (8,360 bytes), byte-identical on rebuild. PE and ELF headers; Windows (kernel32) and Linux (syscall) shims with argv parsing; arena; buffered I/O; diagnostics with line/column; UTF-8 validation; the lexer; `envoc0 lex`, `version`, `help`. **Windows: all 58 tests pass** (PowerShell and Git Bash runners). Linux ELF headers checked structurally; not yet run | Parser, checker, x86-64 code generation, PE/ELF writers for output programs, builtins | First CI run to execute the Linux binary; then the parser (PLAN.md §5, 1.5) |
| **Bootstrap: Stage 1** (`bootstrap/stage1`) | — | — | Everything | M2 |
| **Bootstrap adapter: NASM** (`adapters/bootstrap/nasm`) | Experimental | `assemble.ps1` / `assemble.sh` | — | Used by CI and local builds |
| **Build entry points** (`bootstrap.ps1`, `bootstrap.sh`) | Experimental | `check` (layout, lib→adapters imports, gallery line limits), `build` and `test` all work on Windows PowerShell and Git Bash. Verified that `check` catches a planted forbidden import and that `test` catches a wrong token and a wrong error column | `bootstrap.sh` not yet run on Linux | First CI run |
| **CI adapter** (`adapters/ci/github`) | Experimental | Workflow: `check`; Stage 0 build+test on Linux and Windows | Has never run (no remote yet); no cross-host byte-identity check | Push to GitHub; then compare the envoc0 SHA-256 printed by both jobs automatically |
| **Tests** (`tests/`) | — | 13 lexer golden tests, 41 lexical `expect-error` spec tests, 4 CLI smoke tests, Hello World Gallery files with line limits | Everything that needs a parser or code generator | Parser golden tests (M1.5) |
| **Compiler: Stage 2** (`compiler/`) | — | — | Everything | M3 |
| **Runtime** (`runtime/`) | — | — | Everything | M3 (startup/panic/ARC), M6 (VM) |
| **Standard platform** (`lib/`) | — | — | Everything | M4 |
| **Adapters** (`adapters/os`, `window`, `gpu`, …) | — | — | Everything | M4 onward |
| **Tools** (`tools/`) | — | — | Everything | M5 |
| **Templates** (`templates/`) | — | — | Everything | M5 / M9 |

## Known limitations

- **The Linux binary has never been run.** The development machine runs Windows; the
  Linux ELF is cross-assembled locally and its headers are checked, but only the
  `stage0-linux` CI job (not yet run) executes it. Treat `platform/linux.eas` as
  untested until that job passes.
- **Linux path is only exercised in CI.** The development machine runs Windows; the
  Linux ELF is cross-assembled locally but only run by the `stage0-linux` CI job.
- **Windows paths must be in the active code page.** Stage 0 uses `CreateFileA` and
  `GetCommandLineA`. (TODO(M1): decide whether UTF-8 paths are needed before Stage 1;
  `docs/PLAN.md` open question 5.)
- **Stage 0 source files are limited to 16 MiB**, reported as an error.
- **The license is a placeholder choice** (MIT) pending owner confirmation
  (`docs/PLAN.md` open question 2).
