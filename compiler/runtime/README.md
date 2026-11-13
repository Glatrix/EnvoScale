# `compiler/runtime`

The code the compiler puts into every program it builds: startup, the built-ins, the
heap, panics, and the layer over each OS. The compiler holds these files as string
constants in `compiler/driver/runtime*.envo`, made with `envoc embed`; `build.sh test`
fails if those are out of date.

- [`common.envo`](common.envo): the built-ins, the heap and panics, for every target.
- [`linux.envo`](linux.envo), [`windows.envo`](windows.envo): the OS layer for x86-64
  Linux and Windows. These four make `driver/runtime.envo`:
  `envoc embed compiler/runtime/common.envo compiler/runtime/linux.envo compiler/runtime/windows.envo compiler/runtime/prelude.envo`.
- [`prelude.envo`](prelude.envo): the prelude every Envo-S1 program sees.
- [`wasm.envo`](wasm.envo): the OS layer for `wasm32-web` (PLAN D48, D49), over the
  host's functions; `driver/runtime_wasm.envo`, with the constant renamed `RUNTIME_WASM`.
