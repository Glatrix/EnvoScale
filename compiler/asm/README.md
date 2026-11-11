# `compiler/asm`

> **Status:** Not started. Planned for **M3**.

The table-driven Envo assembler. Reads `.eas` (`docs/spec/eas.md`) and `asm { }` blocks; instruction encodings are data files per architecture. Once it exists it must assemble `bootstrap/stage0/*.eas` byte-identically to NASM and the seed.
