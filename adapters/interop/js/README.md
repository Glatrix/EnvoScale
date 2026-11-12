# `adapters/interop/js`

> **Status:** Experimental (M9.2).

The JavaScript side of WebAssembly programs (PLAN D49), written by EnvoScale with no
framework:

- [`envo.js`](envo.js) runs a module built by `envoc build --target wasm32-web`:
  `node envo.js program.wasm [arguments…]` in Node.js, or
  `await EnvoWeb.run(bytes, { args, stdout, stderr, env })` in a page. It provides the
  program's one import, `envo.host(k, a, b, c, d)`. The functions `k` are listed in
  `compiler/runtime/wasm.envo` and `adapters/os/wasm/wasm.envo`. `EnvoWeb.memoryFs(map)`
  is a file system in memory for a page or a test: paths to bytes, which the program's
  writes land in.
- [`sandbox.js`](sandbox.js) is the website's sandbox page. `envoc.wasm`, the compiler
  built for WebAssembly, compiles the program in the page through `memoryFs`, and the
  program runs in the page.
- [`test-wasm.js`](test-wasm.js) runs the spec run programs and the library tests as
  WebAssembly under Node.js. It also builds `envoc.wasm` and has it rebuild itself to the
  same bytes (the fixed point in WebAssembly), then compiles and runs a program in memory
  as the sandbox does. The bootstrap scripts run it where Node.js is installed.
  A library test can opt out with `// wasm: skip (why)`.
