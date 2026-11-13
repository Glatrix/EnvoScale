# `compiler/`

`envoc`, the Envo compiler: about 24,000 lines of Envo that compile Envo, including
themselves. The `envo` tool contains it; `envoc` on its own is what `build.sh` builds
first. How it is built and tested: [docs/architecture/stage2.md](../docs/architecture/stage2.md).

```
source (.envo)
  → syntax/    lexer and parser
  → sema/      names, types, generics, ownership and borrow checking
  → eir/       lowering to EIR, the typed SSA intermediate form (text and binary)
  → opt/       -O2's passes: inlining, folding, copy propagation, dead code
  → backend/   x86-64, AArch64 and WebAssembly code, register allocation, and the
               executable writers (PE, ELF, Mach-O, wasm)
```

| Folder | |
|---|---|
| [`driver/`](driver) | The `envoc` commands, and the runtime it puts into every program |
| [`runtime/`](runtime) | That runtime's sources |
| [`diag/`](diag) | Source files and error reports |
| [`syntax/`](syntax) | Lexer and parser |
| [`sema/`](sema) | The checker |
| [`eir/`](eir) | EIR: building, printing, reading, verifying, linking |
| [`opt/`](opt) | The optimizer |
| [`backend/`](backend) | Code generation for each target |
| [`util/`](util) | Maps, lists, text |

[`files.txt`](files.txt) lists the source files in build order; the first is the entry
file. The compiler is written in Envo-S1, the subset that the stage 1 compiler in
[EnvoScaleAsm](https://github.com/envoscale/EnvoScaleAsm) accepts, so that it can always be
rebuilt from assembly.
