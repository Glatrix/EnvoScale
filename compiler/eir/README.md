# `compiler/eir`

> **Status:** EIR v1 in memory, the text reader and printer, the verifier, lowering
> (M3.6), the binary form and linking (M3.7).

EIR, the Envo IR: SSA-based, typed and versioned, with text (`.eir`) and binary (`.eirb`)
forms and a verifier. Spec: `docs/spec/eir.md`.

- `ir.envo`: the module, as flat lists addressed by index.
- `read.envo`, `print.envo`, `verify.envo`: the text form and the verifier.
- `binary.envo`: the binary form, also used for objects (`.eo`).
- `link.envo`: fills an object's declarations from the other objects of the program.
- `lower*.envo`: lowering from the checked syntax tree, a port of Stage 1's `lower/`.
