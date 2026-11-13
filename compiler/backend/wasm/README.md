# `compiler/backend/wasm`

> **Status:** Experimental (M9.1). Tests: `adapters/interop/js/test-wasm.js` (every spec run
> program at -O0 and -O2, and the library tests, under Node.js).

The WebAssembly backend (PLAN D48): `envoc build --target wasm32-web` writes a wasm32
module.

- **Memory** keeps the front end's layout (pointers are 8 bytes in memory, addresses below
  4 GiB), so EIR is the same as for x86-64. The data starts at 1024, with a 1 MiB shadow
  stack above it for stack slots; the heap grows the memory at the end.
- **Values:** every SSA value is an `i64` local, kept canonical (sign- or zero-extended)
  as the x86-64 backend keeps it, so the same checks give the same panics.
- **Control flow:** a function's blocks become one loop around a `br_table` on a block
  number. Any control flow maps to it directly, and branch arguments are a parallel copy
  through the operand stack.
- **Calls:** direct calls are `call`; function pointers are indices into the module's
  table, called with `call_indirect`.
- **The host:** the program reaches it through one import, `envo.host(k, a, b, c, d)` (D49),
  which the runtime's OS layer (`compiler/runtime/wasm.envol`) and the `os.wasm` adapters
  call through `__hostcall`. The host is `adapters/interop/js/envo.js`.
- **Names:** a `name` section carries every function's name, for the host's stack traces.

Floats are not supported yet, as in the x86-64 backend.
