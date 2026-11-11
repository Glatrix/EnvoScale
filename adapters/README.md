# `adapters/` — the only place platform code may live

> **Status:** CI adapter (`ci/github`) and the Phase A bootstrap adapter
> (`bootstrap/nasm`) exist. Everything else starts with **M4**.

An **adapter** implements a port from [`lib/ports`](../lib/ports/README.md) for one
specific platform, or connects EnvoScale to an outside system (CI, interop, remote APIs).

## Rules

- `adapters/<kind>/<name>/` may import `lib/**` and its own folder only. Never another adapter.
- `lib/**` never imports anything from here.
- OS and hardware interfaces are reached with **hand-written bindings**. No vendor SDK
  headers, no binding generators.
- Every port has a **reference adapter** (in-memory, null or software) that passes the
  port's conformance suite and serves as the universal fallback.
- Adapters are selected by target triple and build profile, or explicitly by the user.

## Kinds

| Folder | Port(s) | Examples |
|---|---|---|
| `os/` | FileSystem, Console, Clock, Threads, Entropy, Executor, NetStack | windows, linux, macos, wasm, none |
| `window/` | Window | win32, wayland, x11, cocoa, web |
| `gpu/` | GpuDevice | vulkan, d3d12, metal, webgpu, software |
| `audio/` | AudioDevice | wasapi, alsa, pulse, coreaudio, webaudio, null |
| `input/`, `clipboard/`, `fonts-system/` | Input, Clipboard, FontSource | per platform |
| `interop/` | — | c-abi, js |
| `ai-remote/` | — | HTTP adapters to external model APIs (optional) |
| `ci/` | — | github |
| `bootstrap/` | — | nasm (active), fasm (optional) — Phase A only |

Adding a new platform? Start with [`docs/porting/CHECKLIST.md`](../docs/porting/CHECKLIST.md).
