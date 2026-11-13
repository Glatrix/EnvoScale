# `compiler/opt`

> **Status:** `-O2`'s EIR passes (M3.8). Tests: `tests/golden/opt/` and every run
> program at `-O0` and `-O2`.

The EIR passes `-O2` runs between lowering and code generation (PLAN D20). Each one
rewrites functions in place or rebuilds them at the end of the module's lists. The
verifier runs after them, and every pass is deterministic.

`envoc eir-check <file.eir> -O2` runs them on EIR text and prints the result; the goldens
in `tests/golden/opt/` use it.

## `inline.envol`: inlining

A call to a single-block function of at most 16 instructions that ends in `ret` is
replaced by a copy of that function's instructions. The callee's parameters become the
arguments, and the call's result becomes the returned value. A call to a function of more
blocks and at most 12 instructions in all splits the caller's block: the callee's entry
block ends the first part, its other blocks follow, and each `ret` becomes a branch to a
new block that holds the rest of the caller's block and takes the call's result as its
parameter. The callee's slots move to the caller's entry block (EIR allows slots only
there), and the copy starts by zeroing them, as a call would. One level only, in function
order: a callee inlined into a caller that comes later is already its own inlined version.
Recursive callees stay calls.

Most of these calls are accessors (`NodeAt`, `SymAt`, `Len`) and a call costs more than
their body.

## `thread.envol`: jump threading

`a && b`, `a || b` and `!` in a condition lower to a block whose only instruction branches
on its parameter. An edge into it whose argument is known where it leaves (a constant, or
the condition of the branch it leaves on) goes straight to the side that argument picks,
and an unconditional branch into it gets a copy of its branch, so the compare before it
fuses with the branch in the backend. It runs after simplification, which then runs again
on the functions it changed. A block whose parameters are used past its branch is left
alone.

## `mem2reg.envol`: locals become values

Lowering keeps every local in a slot and reads and writes it with `load` and `store`. A
scalar slot whose address is used only by loads and stores of its own type (and `zero`
and `slot.end`) becomes SSA values instead: each block where the local is live on entry
gets a parameter, a load becomes the local's current value, a store or `zero` sets it,
and every branch passes the current value along. The local starts as 0, as a slot does.
The pass runs before inlining and again after it (inlined copies bring their own slots);
simplification then removes the parameters that receive one value on every edge.

## `licm.envol`: loop-invariant loads

In a loop that writes no memory (no store, copy, zero, call or intrinsic), a load from a
field of a parameter that points to valid memory for the whole call reads the same value
every time round. Lowering records those parameters in `EFunc.Deref`: `in` and `ref`
parameters, `this`, aggregates passed by pointer, and the hidden result pointer. The load
moves, with the field addresses it needs, to the end of the loop's preheader (the one
block outside the loop that branches unconditionally into its header). A loop over a
`str` parameter then keeps its pointer and length in registers. EIR read from text or
object files has no `Deref` bits, so it hoists nothing there.

## `simplify.envol`: folding, copy propagation, dead code, CFG

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
