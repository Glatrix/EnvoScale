# `compiler/` — Stage 2 `envoc`

> **Status:** Being built in **M3** (self-hosting), increment by increment
> ([`docs/PLAN.md`](../docs/PLAN.md) §5): written in Envo-S1, built by `envoc1` from
> [`files.txt`](files.txt) (PLAN D16). Today: the driver (`envoc version`, `help`,
> `selftest`), the support library and diagnostics. Design:
> [`docs/architecture/stage2.md`](../docs/architecture/stage2.md).

The real Envo compiler, written in idiomatic full Envo. Once it compiles itself to a
byte-identical fixed point, **all compiler development happens here** (brief §5.5).

## Pipeline

```
source (.envo)
  → syntax/   Lexer → Parser → AST (lossless CST kept for tooling/formatter)
  → sema/     Name resolution → Type inference & checking → Interface resolution
              → Borrow & lifetime checking → Comptime evaluation
  → eir/      Lowering → EIR (SSA, typed, versioned, textual + binary forms)
  → opt/      Pass manager
  → backend/  Instruction selection → register allocation → scheduling → emission
  → asm/      Envo assembler (machine code)
  → link/     ELF | PE/COFF | Mach-O | WASM | flat binary
  + debuginfo/ DWARF | CodeView/PDB
```

- **Query-based and incremental** (`query/`): every stage is a memoized query.
- **Parallel by default:** parse, check and codegen per module across threads.
- **Deterministic:** the same inputs produce byte-identical output on every host.

## Folders

| Folder | Purpose |
|---|---|
| `driver/` | `envoc` entry point and build orchestration |
| `query/` | Incremental query engine |
| `diag/` | Diagnostics and error codes |
| `syntax/` | Lexer, parser, CST/AST |
| `sema/` | Resolve, types, interfaces, borrow check, comptime |
| `eir/` | IR definition, builder, verifier, text/binary formats |
| `opt/` | Pass manager and one folder per pass |
| `backend/{x86_64,aarch64,riscv64,wasm,spirv,wgsl,msl}/` | Code generation |
| `asm/` | Table-driven assembler |
| `link/{elf,pe,macho,wasm}/` | Linker and object/executable writers |
| `debuginfo/{dwarf,codeview}/` | Debug information |
