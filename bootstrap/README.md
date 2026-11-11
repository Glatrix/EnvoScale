# Bootstrap: from assembly to self-hosting

> **Status:** Stage 0 in progress (M1). Stage S (seed), Stage 1 and Stage 2 not started.

EnvoScale's compiler is built up a ladder of stages, each small enough to audit and
each built by the one below it. The point is trust: anyone can rebuild the whole
toolchain from source they can read, without trusting a binary we hand them.

```
Stage S  (seed)      Tiny hex-coded assembler, verifiable by eye           bootstrap/seed/
   ↓ assembles
Stage 0  (assembly)  envoc0: compiles Envo-Core → x86-64 machine code      bootstrap/stage0/
   ↓ compiles
Stage 1  (Envo-Core) envoc1: a fuller compiler written in Envo-Core        bootstrap/stage1/
   ↓ compiles
Stage 2  (Envo)      envoc: the real compiler, written in full Envo        compiler/
   ↓ compiles itself
Stage 3              envoc built by Stage 2 == Stage 2's rebuild (fixed point)
```

## Building

One command per OS, run from the repository root:

| OS | Command |
|---|---|
| Windows | `.\bootstrap.ps1 build` |
| Linux, macOS (with a POSIX shell) | `./bootstrap.sh build` |

Both scripts use only tools the OS ships with, plus the Phase A assembler described below.
Other commands: `test` (run Stage 0 tests), `check` (repository layout and gallery
checks), `clean`, `help`.

Output goes to `build/stage0/`:

| File | What |
|---|---|
| `envoc0.exe` | Stage 0 for x86-64 Windows (PE) |
| `envoc0` | Stage 0 for x86-64 Linux (ELF) |

Both binaries are produced on every host, because Stage 0 writes its own executable
headers and is assembled as a flat binary. Only the native one is *run* by `test`.

## Phases (brief §5.4)

- **Phase A — now.** Stage 0 is assembled by NASM through the optional adapter in
  [`adapters/bootstrap/nasm/`](../adapters/bootstrap/nasm/README.md). NASM is the only
  outside tool in the chain, and only for this step.
- **Phase B — required before 1.0.** The hex seed in [`seed/`](seed/README.md) assembles
  Stage 0 by itself. CI checks that seed-built and NASM-built `envoc0` are byte-identical.
- **Closing the loop.** Once Stage 2 exists, `envo asm` also assembles
  `stage0/*.eas`, and CI checks that result is byte-identical too.

Stage 0's source language, `.eas`, is a strict subset of NASM syntax precisely so that
all three assemblers can be held to the same bytes. See [`docs/spec/eas.md`](../docs/spec/eas.md).

## Trust

Stages 0 and 1 stay buildable and tested forever. Building Stage 2 two independent ways
(through Stage 1, and through itself) and comparing results is a diverse double-compiling
defence against "trusting trust" attacks.

More detail: [`docs/architecture/bootstrap.md`](../docs/architecture/bootstrap.md).
