# EnvoScale Status

Where every subsystem stands. Any change that moves a subsystem forward or back updates
this file (brief §0.4, §14.5). Tiers (brief §14.4): **Experimental** may change or vanish,
**Preview** needs an RFC for breaking changes, **Stable** follows SemVer and editions.
"—" means the subsystem doesn't exist yet.

_Last updated: 2026-11-11._ Work is tracked on the
[roadmap](https://github.com/orgs/envoscale/projects/3): one epic per milestone, increments
as sub-issues, owner decisions marked **Needs Decision**.

## Milestones

| # | Milestone | State |
|---|---|---|
| M0 | Charter and skeleton | **Done** |
| M1 | Stage 0 | **Done** |
| M2 | Stage 1 | **Done**: `envoc1`, written in Envo-Core, compiles Envo-Core and Envo-S1 |
| M3 | Self-hosting | **In progress**: Stage 2 compiles programs and itself, byte-identical to `envoc1`, also through objects and `envoc link` (3.1–3.7); `-O2` next (3.8); plan in `docs/PLAN.md` §5 |
| M4–M13 | | Not started |

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

## Subsystems

| Subsystem | Tier | Works | Missing | Next |
|---|---|---|---|---|
| **Language spec** (`docs/spec`) | Experimental | Chapter 1 normative, chapters 2–5 drafts; Envo-Core, Envo-S1, EIR v1, EAS, EON; error registry | Chapter 6 on (generics in depth, modules, async, comptime) | As M3 needs it |
| **RFCs** (`docs/rfcs`) | — | Template; RFCs 0001–0005 | — | As listed on the roadmap |
| **Seed** (`bootstrap/seed`) | — | — | Everything (Phase B, before 1.0) | After Stage 0's `.eas` subset is final |
| **Stage 0** (`bootstrap/stage0`) | Experimental | `envoc0` in 15k lines of assembly: `lex`, `parse`, `check`, `build`; PE/ELF output, cross-compiles; hello world is 8 KB | Fixes only (line budget used up) | — |
| **Stage 1** (`bootstrap/stage1`) | Experimental | `envoc1` in 17k lines of Envo-Core: front end, EIR v1 with verifier, x86-64 backend, PE/ELF, runtime in Envo. Compiles Envo-Core exactly like `envoc0`, and Envo-S1 (generics, interfaces, closures, ownership, enums, views, namespaces, prelude) | Speed (no optimizer, by design: D15) | Fixes found by Stage 2 |
| **Stage 2** (`compiler/`) | Experimental | `envoc` in Envo-S1, built by `envoc1`: `lex`, `parse`, `check`, `eir` and `build`, matching `envoc1` byte for byte on the tests and on both compilers; binary EIR, `.eo` objects and `envoc link` | Optimization, the fixed point in CI (M3.8–3.9) | `-O2` (M3.8) |
| **NASM adapter** (`adapters/bootstrap/nasm`) | Experimental | `assemble.ps1`, `assemble.sh` | — | — |
| **Build scripts** (`bootstrap.ps1`, `bootstrap.sh`) | Experimental | `check`, `build`, `test` on PowerShell and Git Bash | — | — |
| **CI** (`adapters/ci/github`) | Experimental | `check`, Windows and Linux test jobs (745/745 each), and `reproducible`, which requires byte-identical builds of all three compilers across hosts | — | — |
| **Tests** (`tests/`) | — | Lexer, parser and checker goldens; Core and S1 error, run and multi-file tests; EIR tests; CLI smoke tests; Hello World line limits | — | `-O2` run tests (M3.8) |
| **Runtime** (`runtime/`) | — | — | Everything | M3 (startup, panics, ARC), M6 (VM) |
| **Standard platform** (`lib/`) | — | — | Everything | M4 |
| **Adapters** (`adapters/os`, `window`, `gpu`, …) | — | — | Everything | M4 on |
| **Tools** (`tools/`) | — | — | Everything | M5 |
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
