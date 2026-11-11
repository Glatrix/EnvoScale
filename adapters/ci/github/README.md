# `adapters/ci/github` — GitHub Actions adapter

> **Status:** Active. Runs `check` on every push and pull request, and the Stage 0
> build and tests on Windows and Linux.

GitHub only reads workflows from `.github/workflows/`, so this adapter is that folder
plus this README. Switching CI providers means deleting `.github/` and adding a sibling
adapter here; nothing else in the repository knows which CI is in use.

## Contract

The workflow contains **no build logic**. Each step is one call to a repository entry point:

| Today (before M5) | After M5 |
|---|---|
| `bootstrap.ps1 check` / `bootstrap.sh check` | `envo check` |
| `bootstrap.ps1 test` / `bootstrap.sh test` | `envo test` |

Calling the bootstrap scripts instead of `envo` is a temporary sequencing necessity
(decision D8 in [`docs/PLAN.md`](../../../docs/PLAN.md)): `envo` does not exist yet.

The one provider-specific step is installing NASM for the Phase A bootstrap
(see [`adapters/bootstrap/nasm`](../../bootstrap/nasm/README.md)). It disappears when
the hex seed can build Stage 0 (Phase B).

## Files

- [`/.github/workflows/ci.yml`](../../../.github/workflows/ci.yml)
