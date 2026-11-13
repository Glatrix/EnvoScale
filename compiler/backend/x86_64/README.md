# `compiler/backend/x86_64`

> **Status:** `-O0` (M3.6) and `-O2` (M3.8).

The x86-64 backend, ported from Stage 1 (`bootstrap/stage1/x64/`). A frame of a page or
more is reserved one page at a time, touching each (a stack probe), so a large frame
never jumps past the stack's guard page; all three stages do this. `envoc build -map
<file>` writes each function's address, for profilers and debugging.

- `asm.envo`: the instruction encoder, with code and data buffers, labels and fixups.
- `gen.envo`: code generation. At `-O0` every SSA value has its own stack slot and
  `envoc build` writes the same bytes as `envoc1 build`.
- `regalloc.envo`: `-O2` register allocation.
- `image.envo`: PE (Windows) and ELF (Linux) executables, and the Windows import table.

## -O2

- **Rematerialization.** Values defined by `const`, `slot` and `addr` get no storage.
  Each use recomputes them with one `mov`/`lea`.
- **In place.** Add, sub, the bitwise operations, loads, field addresses, pointer adds
  and integer conversions compute straight into the result's register, with the other
  operand from its register or as an immediate; loads and stores address a value's
  register or the frame directly.
- **Compare and branch.** A compare used only by the `condbr` after it becomes `cmp` and
  one `jcc`; a branch to the block emitted next falls through, and branch arguments move
  directly unless a parameter's place holds an argument still to be read.
- **Registers.** Linear scan over one interval per value (definition to last use,
  widened to every block where liveness says the value is live). rbx and r12-r15 are
  callee-saved and go to any value (a function pushes the ones it uses after rbp); rsi,
  rdi and r8-r10 go only to values whose interval holds no call or system call (and rsi
  and rdi no copy or fill), and need no saving. A value that gets no register keeps its
  stack slot. rax, rcx, rdx and r11 are the code generator's scratch.
- **Small copies and zeroing.** `copy` and `zero` of a constant size up to 128 bytes,
  and the zeroing of a frame's slots, become 8/4/2/1-byte moves instead of
  `rep movsb`/`rep stosb`.
