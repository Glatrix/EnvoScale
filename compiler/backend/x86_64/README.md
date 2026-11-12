# `compiler/backend/x86_64`

> **Status:** `-O0` done (M3.6). `-O2` comes in M3.8.

The x86-64 backend, ported from Stage 1 (`bootstrap/stage1/x64/`):

- `asm.envo`: the instruction encoder, with code and data buffers, labels and fixups.
- `gen.envo`: `-O0` code generation. Every SSA value has its own stack slot.
- `image.envo`: PE (Windows) and ELF (Linux) executables, and the Windows import table.

`envoc build` writes the same bytes as `envoc1 build`. Register allocation (linear scan,
D20) and the SSA optimizations arrive with `-O2`.
