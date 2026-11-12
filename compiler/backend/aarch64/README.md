# `compiler/backend/aarch64`

> **Status:** Experimental (M10, PLAN D69). Linux programs without the standard platform's
> Linux adapter (`--target aarch64-linux`); tested on an arm64 machine in CI.

The AArch64 backend, for Linux:

- `asm.envo`: the encoder. One 32-bit word per instruction, labels and fixups, the
  self-relocation stub (PLAN D68), and linking (64 KiB pages).
- `gen.envo`: EIR to machine code. It follows the x86-64 backend at -O0 instruction for
  instruction: each value in a frame slot below x29, operands in x9-x11, arguments on the
  stack, results in x0, system calls through `svc #0` (number in x8, arguments in x0-x5).
- `image.envo`: the ELF executable: position-independent (ET_DYN), code read and execute,
  data read and write.

The runtime's OS layer for it is `compiler/runtime/linux_aarch64.envo` (embedded as
`compiler/driver/runtime_a64.envo`). `bootstrap.sh cross` builds the run tests for it and
`bootstrap.sh cross-run` runs them on an AArch64 machine.

Still to come: the Linux adapter's system calls for AArch64 (so `--lib` works with the
Linux platform), registers at -O2, and macOS (Mach-O).
