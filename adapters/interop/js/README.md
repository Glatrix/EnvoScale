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
  A library test can opt out with `// wasm: skip (why)`. It also runs the browser host
  on a stand-in canvas ([`window-page.envo`](window-page.envo)) and, where Node can turn
  JSPI on, a program whose endless loop yields to the page
  ([`window-loop.envo`](window-loop.envo), [`window-loop.js`](window-loop.js)).

## The browser host (M14.8)

`EnvoWeb.run(bytes, { canvas })` makes the canvas the program's window (PLAN D72):
`Open` sizes it, keys (as `KEY_*` codes and typed characters), the pointer (in the
canvas's pixels, however large the page shows it) and the wheel become the port's events,
and `Present` draws frames with `putImageData`. `onTitle(text)` hears `SetTitle`.

A windowed program polls in a loop that does not end on its own. Under JSPI (PLAN D77)
`run` wraps the import in `WebAssembly.Suspending` and starts the program through
`WebAssembly.promising`, so a poll that finds no event waits for the next animation frame.
`EnvoWeb.canYield()` says whether the browser can; a page should not start a windowed
program where it cannot. Text needs a font the program can load: a page gives one through
`memoryFs`.
