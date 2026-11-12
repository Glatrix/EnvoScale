# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Use GitHub's private
vulnerability reporting ("Report a vulnerability" on the repository's Security tab).

Include what you found, how to reproduce it, and the commit or version affected.
You should get an acknowledgement within 7 days. We will agree a disclosure date with
you; the default is 90 days after the report or when a fix ships, whichever is sooner.

## Supported versions

EnvoScale has not had a release. Until 1.0, only the `main` branch is supported, and
every subsystem is **Experimental** unless [`STATUS.md`](STATUS.md) says otherwise.

From 1.0, commercial licensees get long-term-support releases and advance notice of
security fixes, as their license agreement specifies (see [`LICENSING.md`](LICENSING.md)).
The public response process above applies to everyone.

## Cryptography audit status

`envo.crypto` does not exist yet (milestone M7). When it lands it stays
**Experimental** until an independent audit is completed and published here. Until
then, do not use it to protect anything that matters.

| Module | Audit | Notes |
|---|---|---|
| `envo.crypto` | none | not implemented yet |

## Supply chain

- The repository has **zero third-party dependencies**; adding one is a charter violation.
- The compiler is bootstrapped from assembly (`bootstrap/`). Before 1.0 the chain will
  start from an auditable hex seed, and CI will check that every stage reproduces
  byte-identical binaries (see [`bootstrap/README.md`](bootstrap/README.md)).
- Until then, Stage 0 is assembled by NASM through an optional adapter
  (`adapters/bootstrap/nasm/`). This is the one outside tool in the trust chain, and it
  is temporary by design.
- CI runs with read-only repository permissions, pins every GitHub action to a commit
  SHA, and does not leave the job's token in the checkout. NASM itself comes from the
  runner's package manager (apt, Chocolatey) unpinned. The `reproducible` and
  `fixed-point` jobs compare both hosts' builds byte for byte, so a NASM difference
  between them would show.

## Known hardening gaps

These are known and tracked. Programs the compilers produce today are for development,
not for running untrusted input.

- **Executable layout** (PLAN D2). Executables have one read-write-execute
  section at a fixed base address, with no relocations: no W^X, no ASLR. The layout
  was chosen to keep Stage 0 auditable; separate code and data sections and relocatable
  images are tracked in [#80](https://github.com/envoscale/EnvoScale/issues/80).
- **Write errors in programs.** The Envo-Core `write` built-in returns nothing, so a
  program cannot see a failed write (a full disk, a closed pipe). The compilers check
  their own output by reading it back. A `write` that reports errors belongs to the
  standard library's I/O (M4).
- **Stack overflow** ends a program with the operating system's crash (an access
  violation or SIGSEGV at the guard page), not a panic message. Every frame larger than a
  page is probed, so an overflow always hits the guard page and never skips it.

