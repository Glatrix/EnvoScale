# `compiler/runtime`

The code the compiler puts into every program it builds: startup, the built-ins, the
heap, panics, and the layer over each OS. The compiler holds these files as string
constants in `compiler/driver/runtime*.envol`, made with `envoc embed`; `build.sh test`
fails if those are out of date.

- [`common.envol`](common.envol): the built-ins, the heap and panics, for every target.
- [`linux.envol`](linux.envol), [`windows.envol`](windows.envol): the OS layer for x86-64
  Linux and Windows. These four make `driver/runtime.envol`:
  `envoc embed compiler/runtime/common.envol compiler/runtime/linux.envol compiler/runtime/windows.envol compiler/runtime/prelude.envol`.
- [`prelude.envol`](prelude.envol): the prelude every Envo-S1 program sees.
- [`wasm.envol`](wasm.envol): the OS layer for `wasm32-web` (PLAN D48, D49), over the
  host's functions; `driver/runtime_wasm.envol`, with the constant renamed `RUNTIME_WASM`.
