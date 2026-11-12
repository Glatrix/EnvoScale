# `adapters/os/wasm`

> **Status:** Experimental (M9.2). Tests: the conformance suites under Node.js.

The `os.wasm` adapters for WebAssembly programs (PLAN D49), bound by `platform` for
`--target wasm32-web`. They reach the host (`adapters/interop/js/envo.js`) through
`__hostcall(k, …)`.

| Port | In Node.js | In a browser |
|---|---|---|
| Console | the process's streams | callbacks the page gives |
| FileSystem | the machine's files (`fs`) | none: reads fail with NotFound |
| Clock, Entropy | `Date.now`, `process.hrtime`, `crypto.getRandomValues` | `Date.now`, `performance.now`, `crypto.getRandomValues` |
| Environment | the arguments, `process.env`, `process.cwd()` | the arguments and variables the page gives |
| Process, Net | Denied: not from WebAssembly (the browser's fetch and WebSocket come later) | the same |
| Terminal, Window | not a terminal; no window (a page draws through the DOM) | the same |
| Gpu | the software adapter (WebGPU comes later) | the same |
