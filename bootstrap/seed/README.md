# Stage S — the hex seed

> **Status:** Not started. Required before 1.0 (Phase B, milestone **M13**).

A minimal assembler written as commented hexadecimal machine code (`seed.hex`, target < 4 KB of output), turned into a binary with OS-provided tools only (`hex2bin.ps1` with PowerShell, `hex2bin.sh` with POSIX `sh` + `printf`/`od`). It assembles exactly the `.eas` subset that Stage 0 uses (see `docs/spec/eas.md`), so Stage 0 can be built without NASM. It may be a short chain (hex0 → hex1 with labels → asm0) if that keeps each step auditable. CI will check that the seed-built and NASM-built `envoc0` are byte-identical.
