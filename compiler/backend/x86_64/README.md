# `compiler/backend/x86_64`

> **Status:** `-O0` (M3.6) and `-O2` (M3.8).

The x86-64 backend, ported from Stage 1 (`bootstrap/stage1/x64/`):

- `asm.envo`: the instruction encoder, with code and data buffers, labels and fixups.
- `gen.envo`: code generation. At `-O0` every SSA value has its own stack slot and
  `envoc build` writes the same bytes as `envoc1 build`.
- `regalloc.envo`: `-O2` register allocation.
- `image.envo`: PE (Windows) and ELF (Linux) executables, and the Windows import table.

## -O2

- **Rematerialization.** Values defined by `const`, `slot` and `addr` get no storage.
  Each use recomputes them with one `mov`/`lea`.
- **Registers.** Linear scan over one interval per value (definition to last use,
  widened to every block where liveness says the value is live) into rbx and r12–r15.
  These are callee-saved, so they survive calls and system calls, and instructions use
  other registers as scratch. A function pushes the ones it uses after rbp. A value
  that gets no register keeps its stack slot.
- **Small copies and zeroing.** `copy` and `zero` of a constant size up to 128 bytes,
  and the zeroing of a frame's slots, become 8/4/2/1-byte moves instead of
  `rep movsb`/`rep stosb`.
