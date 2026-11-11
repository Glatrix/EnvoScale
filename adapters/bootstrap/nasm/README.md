# `adapters/bootstrap/nasm` — Phase A assembler adapter

> **Status:** Active (Phase A). Temporary by design; replaced by the hex seed in Phase B.

Assembles Stage 0 (`bootstrap/stage0/*.eas`) with [NASM](https://www.nasm.us/) while the
hex seed is being written (brief §5.4). It is **outside the core** and never needed to
*use* EnvoScale: only to build `envoc0` from source.

## Installing NASM

Any NASM 2.14 or newer works. NASM is not committed to this repository.

| OS | Command |
|---|---|
| Windows | `winget install NASM.NASM` (or the installer from nasm.us) |
| Debian/Ubuntu | `sudo apt-get install nasm` |
| Fedora | `sudo dnf install nasm` |
| macOS | `brew install nasm` |

The scripts find NASM in this order:

1. the `NASM` environment variable (full path to the executable)
2. `nasm` on `PATH`
3. Windows only: `%ProgramFiles%\NASM\nasm.exe` and `%LOCALAPPDATA%\bin\NASM\nasm.exe`

## Interface

The adapter is one script per host shell. Both take the same three arguments and do
nothing except run NASM in flat-binary mode:

```
assemble.ps1 <input.eas> <output-file> <include-dir>
assemble.sh  <input.eas> <output-file> <include-dir>
```

`bootstrap.ps1` / `bootstrap.sh` call these and nothing else knows NASM exists. A Phase B
seed adapter will offer the same interface, and CI will compare the two outputs byte for byte.

## Why flat binary

Stage 0 writes its own PE and ELF headers as data in `.eas`, so the assembler never has
to understand object files or linking. That keeps the `.eas` subset small enough for the
seed to implement, and means NASM, the seed and `envo asm` can be held to identical bytes.
