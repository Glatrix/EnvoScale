# `compiler/opt`

> **Status:** `-O2`'s EIR passes (M3.8). Tests: `tests/golden/opt/` and every run
> program at `-O0` and `-O2`.

The EIR passes `-O2` runs between lowering and code generation (PLAN D20). Each one
rewrites functions in place or rebuilds them at the end of the module's lists. The
verifier runs after them, and every pass is deterministic.

`envoc eir-check <file.eir> -O2` runs them on EIR text and prints the result; the goldens
in `tests/golden/opt/` use it.

The order: locals become values; every function is simplified once (and its common
subexpressions merged), so a callee is measured at its real size; small functions are
inlined; locals become values again; then per function simplification, jump threading,
common subexpressions, loop-invariant loads, checks that cannot fail, and block layout.

## `inline.envol`: inlining

A call to a single-block function of at most 16 instructions that ends in `ret` is
replaced by a copy of that function's instructions. The callee's parameters become the
arguments, and the call's result becomes the returned value. A call to a function of more
blocks and at most 16 instructions in all splits the caller's block: the callee's entry
block ends the first part, its other blocks follow, and each `ret` becomes a branch to a
new block that holds the rest of the caller's block and takes the call's result as its
parameter. The callee's slots move to the caller's entry block (EIR allows slots only
there), and the copy starts by zeroing them, as a call would. One level only, in function
order: a callee inlined into a caller that comes later is already its own inlined version.
Recursive callees stay calls. Constants and field addresses are not counted (they become
immediates and addressing modes), and blocks that panic are counted apart, up to 8
instructions, so a bounds check does not keep a small accessor from being inlined.
`panic("text")` lowers to a call of `__rt_panic_lit` with the text's address and length,
so a panic path needs no slots.

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

## `checks.envol`: overflow checks that cannot fail

Below the true edge of `x < y`, `x + 1` cannot overflow, and below the true edge of
`x > y` (or `x != 0` for an unsigned `x`), `x - 1` cannot; the checked add or subtract
becomes a plain one. The edge's block must have the compare's branch as its only way in,
so everything it dominates runs only when the compare held. A counting loop then runs
without a check per step.

## `cse.envol`: common subexpressions, loads and decided branches

Blocks are visited so a block's dominators come first. An instruction that computes what
one in a dominating position already computed (the same operation on the same values) is
replaced by it; a checked one becomes plain arithmetic, since the same check already
passed. A load is replaced by an earlier load of the same address, or by the value an
earlier store wrote there, when nothing that may write memory runs between them: a block
starts a new memory version unless its only predecessor ends where it starts, and every
store, copy, zero, call or intrinsic starts another. A field read from a local that a
`copy` filled whole, with nothing written since, reads the copy's source instead, so the
local often goes. A branch whose condition a dominating branch already decided (the same
compare, or its opposite, for integers) becomes a plain branch. Field and element
addresses get value numbers, so loads through them match, but stay in place: the backend
folds each into the one load or store after it.

## `layout.envol`: block order

The order the backend emits blocks in. A block is followed, where it can be, by the block
it branches to (the true side of a condition first), so the branch falls through; a
loop's body then follows its test. Blocks that only lead to a panic or `unreachable` go
last. The entry block stays first.

## `simplify.envol`: folding, copy propagation, dead code, CFG

Per function, repeated until nothing changes (at most 8 rounds):

- **Constant folding.** It mirrors the backend's arithmetic, so a folded value is the
  one the code would have computed. Checked operations fold only when they can't panic:
  no overflow, no division by zero, a shift amount in range. Floats are left alone.
- **Branches.** `condbr` and `switch` on a known value become `br`, a `condbr` with one
  side that is only `unreachable` becomes a `br` to the other, and `select` on a known
  condition becomes the chosen operand.
- **Copy propagation.** A block parameter that receives the same value on every edge
  (or itself, around a loop) becomes that value. This is trivial-phi removal.

Then the function is rebuilt: unreachable blocks go, pure instructions with unused
results go (with whatever only they used), a block whose only predecessor ends in `br`
to it is merged into that predecessor, and values are renumbered. A local that is only
ever written (stored, copied or zeroed into) goes with its writes.

## What the backend adds at -O2

See `compiler/backend/x86_64/README.md`: constants, slot addresses and global addresses
are recomputed where they're used; other values get callee-saved registers by linear
scan; small copies and zeroing are unrolled.
