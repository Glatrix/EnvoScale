# `compiler/backend/x86_64`

> **Status:** `-O0` (M3.6) and `-O2` (M3.8).

The x86-64 backend, ported from Stage 1 (`bootstrap/stage1/x64/`). A frame of a page or
more is reserved one page at a time, touching each (a stack probe), so a large frame
never jumps past the stack's guard page; all three stages do this. `envoc build -map
<file>` writes each function's address, for profilers and debugging.

- `asm.envol`: the instruction encoder, with code and data buffers, labels and fixups.
- `gen.envol`: code generation. At `-O0` every SSA value has its own stack slot and
  `envoc build` writes the same bytes as `envoc1 build`.
- `regalloc.envol`: `-O2` register allocation.
- `image.envol`: PE (Windows) and ELF (Linux) executables, and the Windows import table.

## -O2

- **Rematerialization.** Values defined by `const`, `slot` and `addr` get no storage.
  Each use recomputes them with one `mov`/`lea`.
- **In place.** Add, sub, the bitwise operations, loads, field addresses, pointer adds
  and integer conversions compute straight into the result's register, with the other
  operand from its register or as an immediate; loads and stores address a value's
  register or the frame directly. A 32-bit add or subtract runs on the low half, so the
  carry or overflow flag is its check and the result needs no re-normalizing; `and`,
  `or` and `xor` of normal values are normal and are not re-extended. Immediates that fit
  in a byte use the short form.
- **Compare and branch.** A compare used only by the `condbr` after it becomes `cmp` and
  one `jcc`; a branch to the block emitted next falls through, the false side as well as
  the true one (the blocks' order is `compiler/opt/layout.envol`'s).
- **Parallel moves.** Branch arguments, call arguments and incoming parameters are moved
  as one parallel copy: a move goes once nothing still to be read lives in its
  destination, a value already in place is not moved, and a cycle goes through r11.
- **Addressing.** A field or element address used only by the load or store right after
  it is not computed: the access addresses `[base + offset]` or `[base + index * size]`
  itself, and an element address that is kept is one `lea`. Memory operands use no
  displacement or an 8-bit one where it fits, so most loads and stores are 3 or 4 bytes.
- **Arguments in registers.** Calls pass their first five arguments in rdi, rsi, r8, r9
  and r10 (the caller-saved registers, which a call overwrites anyway) and the rest on
  the stack; a parameter keeps the register it arrives in when its interval allows. The
  `-O0` convention, all arguments on the stack, stays Stage 1's.
- **Select.** `select` is a `test` and a `cmov`, without a branch.
- **Stores of constants.** A constant that fits 32 bits is stored as an immediate.
- **Spills.** A value just stored to its stack slot is read from the register it came
  from, when no code or label lies between.
- **Division by a constant.** Unsigned `/` and `%` by a constant are a shift and a mask
  for a power of two, else a multiply by the divisor's reciprocal and a shift when a
  64-bit reciprocal is exact for every dividend (as for 10), or a few more steps when
  not (Granlund and Montgomery), instead of `div`. Lowering writes an unsigned `x % c` as
  `x - (x / c) * c`, so `x % c` and `x / c` side by side share one quotient.
- **Jump tables.** A `switch` of at least 4 cases whose keys are dense jumps through a
  table indexed by the key; a sparse one stays a chain of compares.
- **Registers.** Linear scan over one interval per value (definition to last use,
  widened to every block where liveness says the value is live). rbx, r12-r15 and rbp
  are callee-saved and go to any value (a function pushes the ones it uses); rsi,
  rdi and r8-r10 go only to values that live across no call or system call (liveness at
  each call says which do, so a value whose interval only spans a call it is dead at, or
  that a call takes as an argument, may have one; and whose interval holds no copy or
  fill that uses rsi and rdi), and need no saving. A call or system call moves its
  register arguments all at once, so an argument may sit in another's register. After
  the scan, a value left in memory that lives across calls on one arm of a branch only (a
  list or string growing, an error path) takes a caller-saved register that is free over
  its whole interval, when storing it to its slot before each of those calls and loading
  it after costs less than memory; while such a call sets up its arguments, it reads the
  value from the slot. A value that gets no register keeps its stack slot. When registers run out, the value that would cost least in memory (its
  uses, weighted by 8 for each loop around them; loops are found from the branches back
  to a block on the path that reaches them, not from the layout order) is the one that
  stays there. rax, rcx,
  rdx and r11 are the code generator's scratch. Hints keep copies
  away: a block parameter takes a register one of its incoming values has, a value passed
  to a parameter takes the parameter's, and the result of an add, sub, mul, `and`, `or` or
  `xor` takes its first operand's when that operand dies there, if each is free. A
  value may also share a register with one that is dead all through the value's interval
  (block liveness says no path from there reaches a use), which removes the copy of a
  loop counter that is returned after the loop; the register then stays reserved until
  both are done. A branch edge whose arguments already sit in its parameters' places is
  taken by the `jcc` itself.
- **Small copies and zeroing.** `copy` and `zero` of a constant size up to 256 bytes,
  and the zeroing of a frame's slots, become 8/4/2/1-byte moves through rax, with the
  addresses in their own registers, instead of `rep movsb`/`rep stosb` (so they leave rsi
  and rdi alone). A call of the prelude's `string.CopyBytes` with a small constant length
  becomes such a copy.
- **Compact frames.** Only values that got no register (and are not recomputed) have a
  stack slot, so frames are small and most offsets fit a byte.
- **No frame pointer.** The frame is addressed from rsp, so rbp is one more callee-saved
  register. Offsets are worked out from where rbp would be (the return address - 8) and
  moved to rsp's view, also while a call's stack arguments are reserved. The values'
  spill slots sit next to rsp and the slots above them. A function that keeps nothing in
  its frame and calls nothing does not move rsp at all (the panic stubs align it
  themselves). `-O0` keeps rbp frames.
- **Slots that need no zeroing.** A slot every path writes in full before reading it (or
  passing its address on) is not zeroed on entry (`frame.envol`). Stores, loads, copies
  and zeroing through the slot and field addresses inside it are followed byte by byte
  for slots of up to 64 bytes; a call whose aggregate result comes back through the slot
  (lowering marks it with `Imm` 1) writes all of it.
