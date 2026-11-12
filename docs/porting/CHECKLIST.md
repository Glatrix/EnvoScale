# Porting Checklist

> **Status:** Outline. The port conformance suites this checklist relies on arrive with
> M4; the steps for Stage 0 work today.

Bringing EnvoScale to a new operating system or CPU should need only three things
(charter §2.3): **an OS adapter set**, **an executable-format writer** if the format is
new, and **a calling-convention description** if the ABI is new. Nothing in `lib/` or the
compiler core changes.

## 0. Decide what you are porting

| You have | You need |
|---|---|
| A new OS on a supported CPU (e.g. FreeBSD on x86-64) | steps 1, 2, 4, 5 |
| A supported OS on a new CPU | steps 3, 4 (plus a backend in `compiler/backend/`) |
| Bare metal | steps 2 (flat binary), 4 with `adapters/os/none` |

## 1. Stage 0 (so the bootstrap runs natively)

- [ ] Add `bootstrap/stage0/platform/<os>.eas` implementing the eight `sys_*` routines and
      the executable header (see [`architecture/bootstrap.md`](../architecture/bootstrap.md)).
- [ ] Add `bootstrap/stage0/envoc0-<os>.eas` that includes it and `src/*`.
- [ ] Teach `bootstrap.sh` / `bootstrap.ps1` the new target.
- [ ] `tests/golden/lexer` and `tests/spec` pass with the new binary.

## 2. Executable format (only if new)

- [ ] Writer in `compiler/link/<format>/`.
- [ ] Golden tests for headers; a hello world that runs.

## 3. Calling convention (only if new)

- [ ] ABI description in `compiler/backend/<arch>/abi/<name>.envon`: argument registers,
      stack alignment, callee-saved registers, struct passing, varargs, red zone.
- [ ] `extern "<abi>"` tests against hand-written assembly.

## 4. OS adapter set

For each port, implement `adapters/os/<os>/<port>` and pass its conformance suite with
`envo port check`:

- [ ] `Console`
- [ ] `FileSystem`
- [ ] `Clock`
- [ ] `Entropy`
- [ ] `Threads`
- [ ] `Executor` (async I/O)
- [ ] `NetStack`
- [ ] optional: `Window`, `GpuDevice`, `AudioDevice`, `Clipboard`, `FontSource`, `Input`

Until a port is implemented, its reference adapter (`adapters/os/none`, `gpu/software`,
`audio/null`) is used, so programs still run.

## 5. Make it official

- [ ] Target triple added to the target list and `#if target.os == "<os>"`.
- [ ] CI adapter job for the platform.
- [ ] Row in `STATUS.md` with a tier.
