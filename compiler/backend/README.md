# `compiler/backend`

> **Status:** Container folder; see each backend.

Code generation backends. Each backend lowers optimized EIR to machine code or shader code for one target. Instruction encodings live in data files so the assembler (`compiler/asm`) can share them.
