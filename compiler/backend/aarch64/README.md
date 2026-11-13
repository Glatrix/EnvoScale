# `compiler/backend/aarch64`

> **Status:** Experimental (M10, PLAN D69, D70). Linux (`--target aarch64-linux`), with the
> standard platform; macOS (`--target aarch64-macos`), with the reference adapters only so
> far. Tested on CI's arm64 Linux and macOS runners.

The AArch64 backend, for Linux and macOS:

- `asm.envol`: the encoder. One 32-bit word per instruction, labels and fixups, the
  self-relocation stub (PLAN D68), and linking (64 KiB pages).
- `gen.envol`: EIR to machine code. It follows the x86-64 backend at -O0 instruction for
  instruction: each value in a frame slot below x29, operands in x9-x11, arguments on the
  stack, results in x0, system calls through `svc #0` (number in x8, arguments in x0-x5).
- `image.envol`: the ELF executable: position-independent (ET_DYN), code read and execute,
  data read and write.
- `macho.envol`: the Mach-O executable for macOS: started by dyld (`LC_MAIN`), the same
  layout and self-relocation, and an ad-hoc code signature (SHA-256 of each 4 KiB page).
- `regalloc.envol`: at -O2, the x86-64 backend's linear scan (PLAN D20) over x19-x28;
  constants, frame addresses and labels are recomputed where used.

The runtime's OS layers are `compiler/runtime/linux_aarch64.envol` and
`compiler/runtime/macos_aarch64.envol` (embedded as `compiler/driver/runtime_a64.envol` and
`runtime_macos.envol`). On Linux the standard platform's adapter takes its system calls
from `adapters/os/linux/sys/sys.aarch64.envol`. `build.sh cross` builds the run tests
and the library's tests for both, and `build.sh cross-run` runs them on an AArch64
machine.

Still to come: the macOS adapters (files, processes, network, terminal, window, Metal),
and libSystem imports in place of raw system calls on macOS.
