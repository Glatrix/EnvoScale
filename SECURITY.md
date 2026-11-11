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
