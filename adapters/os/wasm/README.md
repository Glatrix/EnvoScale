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
| Terminal | not a terminal | the same |
| Window | none | the canvas the page gives `run` (M14.8): its keys and pointer, frames drawn on it; under JSPI (PLAN D77) a poll with no event waits for the next frame |
| Clipboard | within the run | within the page, and written to the system's where the browser allows |
| Gpu | the software adapter (WebGPU comes later) | the same |
