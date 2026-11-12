# `adapters/ci/github` — GitHub Actions adapter

> **Status:** Active. Runs `check` on every push and pull request, the build and tests
> on Windows and Linux, and `reproducible`, which requires the two hosts' builds to be
> byte-identical (`./bootstrap.sh compare`). The `fixed-point` jobs run
> `bootstrap fixedpoint` on both hosts (Stage 2 built by itself twice at `-O2` must
> not change) and compare the results across hosts.

GitHub only reads workflows from `.github/workflows/`, so this adapter is that folder
plus this README. Switching CI providers means deleting `.github/` and adding a sibling
adapter here; nothing else in the repository knows which CI is in use.

## Contract

The workflow contains **no build logic**. Each step is one call to a repository entry point:

| Today (before M5) | After M5 |
|---|---|
| `bootstrap.ps1 check` / `bootstrap.sh check` | `envo check` |
| `bootstrap.ps1 test` / `bootstrap.sh test` | `envo test` |
| `bootstrap.ps1 fixedpoint` / `bootstrap.sh fixedpoint` | `envo selfhost` |

Calling the bootstrap scripts instead of `envo` is a temporary sequencing necessity
(decision D8 in [`docs/PLAN.md`](../../../docs/PLAN.md)): `envo` does not exist yet.

The one provider-specific step is installing NASM for the Phase A bootstrap
(see [`adapters/bootstrap/nasm`](../../bootstrap/nasm/README.md)). It disappears when
the hex seed can build Stage 0 (Phase B). On Linux it goes through
`install-nasm.sh`, which falls back from the runner's default apt mirror (whose
hostname has repeatedly failed to resolve) to `archive.ubuntu.com`.

## Files

- [`/.github/workflows/ci.yml`](../../../.github/workflows/ci.yml)
- [`install-nasm.sh`](install-nasm.sh): NASM for the Linux job
