# `compiler/runtime`

Runtime sources that only Stage 2 compiles into programs. Stage 1's runtime
(`bootstrap/stage1/runtime/`) serves the x86-64 targets of both stages.

- [`wasm.envo`](wasm.envo): the OS layer for `wasm32-web` (PLAN D48, D49), over the
  host's functions. It is embedded in `envoc` as `compiler/driver/runtime_wasm.envo`,
  generated with `envoc1 embed compiler/runtime/wasm.envo` and the constant renamed
  `RUNTIME_WASM`. The bootstrap scripts check that it is current.
