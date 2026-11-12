# `adapters/os/none`

> **Status:** Experimental (M4). Tests: `adapters/os/none/tests/` and every conformance
> suite.

The reference adapters, which need no OS: a captured `Console`, a pass-through
`Terminal` (the process's own streams), an in-memory `FileSystem`, a manual `Clock`,
seeded `Entropy` (deterministic, for tests only), a fixed `Environment` and a scripted
`Process` whose programs echo their arguments. Every
port's conformance suite runs against these first. `platform.envo` binds them for
`envoc --os none`: a program then touches no files, sees a clock standing at
2026-01-01 00:00 UTC and gets the same random bytes on every run. Its output still goes
to the real console.
