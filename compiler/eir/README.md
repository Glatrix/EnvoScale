# `compiler/eir`

> **Status:** EIR v1 in memory, the text reader and printer, the verifier, lowering
> (M3.6), the binary form and linking (M3.7).

EIR, the EnvoL IR: SSA-based, typed and versioned, with text (`.eir`) and binary (`.eirb`)
forms and a verifier. Spec: `spec/eir.md`.

- `ir.envol`: the module, as flat lists addressed by index.
- `read.envol`, `print.envol`, `verify.envol`: the text form and the verifier.
- `binary.envol`: the binary form, also used for objects (`.eo`).
- `link.envol`: fills an object's declarations from the other objects of the program.
- `lower*.envol`: lowering from the checked syntax tree, a port of Stage 1's `lower/`.
