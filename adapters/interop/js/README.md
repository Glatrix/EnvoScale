# `adapters/interop/js`

> **Status:** Experimental (M9.2).

The JavaScript side of WebAssembly programs (PLAN D49), written by EnvoScale with no
framework:

- [`envo.js`](envo.js) runs a module built by `envoc build --target wasm32-web`:
  `node envo.js program.wasm [arguments…]` in Node.js, or
  `await EnvoWeb.run(bytes, { args, stdout, stderr, env })` in a page. It provides the
  program's one import, `envo.host(k, a, b, c, d)`. The functions `k` are listed in
  `compiler/runtime/wasm.envo` and `adapters/os/wasm/wasm.envo`.
- [`test-wasm.js`](test-wasm.js) runs the spec run programs and the library tests as
  WebAssembly under Node.js. The bootstrap scripts run it where Node.js is installed.
  A library test can opt out with `// wasm: skip (why)`.
