# `compiler/opt`

> **Status:** `-O2`'s EIR passes (M3.8). Tests: `tests/golden/opt/` and every run
> program at `-O0` and `-O2`.

The EIR passes `-O2` runs between lowering and code generation (PLAN D20). Each one
rewrites functions in place or rebuilds them at the end of the module's lists. The
verifier runs after them, and every pass is deterministic.

`envoc eir-check <file.eir> -O2` runs them on EIR text and prints the result; the goldens
in `tests/golden/opt/` use it.

## `inline.envo`: inlining

A call to a single-block function of at most 16 instructions that ends in `ret` is
replaced by a copy of that function's instructions. The callee's parameters become the
arguments, and the call's result becomes the returned value. The callee's slots move to
the caller's entry block (EIR allows slots only there), and the copy starts by zeroing
them, as a call would. One level only, in function order: a callee inlined into a caller
that comes later is already its own inlined version.

Most of these calls are accessors (`NodeAt`, `SymAt`, `Len`) and a call costs more than
their body.

## `mem2reg.envo`: locals become values

Lowering keeps every local in a slot and reads and writes it with `load` and `store`. A
scalar slot whose address is used only by loads and stores of its own type (and `zero`
and `slot.end`) becomes SSA values instead: each block where the local is live on entry
gets a parameter, a load becomes the local's current value, a store or `zero` sets it,
and every branch passes the current value along. The local starts as 0, as a slot does.
The pass runs before inlining and again after it (inlined copies bring their own slots);
simplification then removes the parameters that receive one value on every edge.

## `simplify.envo`: folding, copy propagation, dead code, CFG

Per function, repeated until nothing changes (at most 8 rounds):

- **Constant folding.** It mirrors the backend's arithmetic, so a folded value is the
  one the code would have computed. Checked operations fold only when they can't panic:
  no overflow, no division by zero, a shift amount in range. Floats are left alone.
- **Branches.** `condbr` and `switch` on a known value become `br`, and `select` on a
  known condition becomes the chosen operand.
- **Copy propagation.** A block parameter that receives the same value on every edge
  (or itself, around a loop) becomes that value. This is trivial-phi removal.

Then the function is rebuilt: unreachable blocks go, pure instructions with unused
results go (with whatever only they used), a block whose only predecessor ends in `br`
to it is merged into that predecessor, and values are renumbered.

## What the backend adds at -O2

See `compiler/backend/x86_64/README.md`: constants, slot addresses and global addresses
are recomputed where they're used; other values get callee-saved registers by linear
scan; small copies and zeroing are unrolled.
