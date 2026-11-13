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
      the executable header (see https://github.com/envoscale/EnvoScaleAsm).
- [ ] Add `bootstrap/stage0/envoc0-<os>.eas` that includes it and `src/*`.
- [ ] Teach `build.sh` / `build.ps1` the new target.
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

## Worked example: AArch64 Linux and macOS (M10, PLAN D69, D70)

- **No Stage 0 port.** Programs for the new CPU are cross-compiled on x86-64
  (`--target aarch64-linux`, `--target aarch64-macos`); `build.sh cross` builds the
  run tests and the library's tests, and `build.sh cross-run` runs them on the target
  (CI's arm64 Linux and macOS runners), with no compiler there.
- **Backend:** `compiler/backend/aarch64/`: the encoder, the code generator (it follows
  the x86-64 one instruction for instruction, so the same tests apply), and the ELF and
  Mach-O writers.
- **Runtime OS layer:** `compiler/runtime/<os>_aarch64.envol`, embedded in `envoc`.
- **Adapters:** where only the system calls differ, a module gets a file per architecture
  (`adapters/os/linux/sys/sys.<arch>.envol`); the loader takes `<name>.<arch>.envol` before
  `<name>.envol`.
