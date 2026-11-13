# Architecture: Ports and Adapters

> **Status:** Design. Ports and the first adapters are implemented in M4.

## The shape

```
            ┌───────────────────────── lib/ (pure, platform-free) ─────────────────────────┐
            │  core ← alloc ← std ← envo.*                                                 │
            │                  ↑                                                           │
            │            lib/ports  (interfaces: FileSystem, Clock, Window, GpuDevice, …)  │
            └──────────────────▲───────────────────────────────────────────────────────────┘
                               │ implements (adapters depend on lib, never the reverse)
   ┌───────────────┬───────────┴───────┬──────────────────┬──────────────────────┐
 adapters/os/linux  adapters/os/windows  adapters/gpu/vulkan  adapters/os/none (reference)
```

- A **port** is a small interface in `lib/ports` describing one capability.
- An **adapter** implements a port for one platform, in `adapters/<kind>/<name>`.
- `lib/**` never imports `adapters/**`. The compiler enforces it from M3 (a violation is a
  compile error); until then `bootstrap.* check` greps for it.

## Capabilities

Ports are **values passed around as capabilities**, not global singletons:

- A program receives its ports through a typed **context** at startup. `std.fs` functions
  use the context's `FileSystem`; a test can pass an in-memory one instead.
- Script mode starts with **no** capabilities. `envo run app.envol --allow net,fs:./data`
  grants a `NetStack` and a `FileSystem` restricted to `./data`. Restriction is itself an
  adapter wrapping another adapter.
- Libraries that need a capability say so in their signature, so `envo audit` can show
  what a dependency can touch.

## Reference adapters

Every port ships with a reference adapter that needs no OS: in-memory file system, manual
clock, deterministic entropy (tests only), captured console, single-threaded executor,
software GPU. They serve three purposes:

1. the port's **conformance suite** is developed against them first;
2. most of `lib/`'s tests run against them, fast and deterministic;
3. they are the fallback on a new platform until native adapters exist.

## Selecting adapters

The build picks adapters from the **target triple** and **profile** (e.g.
`x86_64-windows` → `os/windows`, `window/win32`, `gpu/d3d12` with `gpu/software` as
fallback). A program can override any choice explicitly at the full-control door.

## Conformance

`tests/conformance/<port>/` holds one suite per port. `envo port check <adapter>` runs it.
An adapter is complete when its suite passes; that is the definition used by
[`docs/porting/CHECKLIST.md`](../porting/CHECKLIST.md).

## Stage 0

Stage 0 follows the same idea at the smallest possible scale: its whole OS interface is
eight `sys_*` routines in one platform file per OS ([`bootstrap.md`](https://github.com/envoscale/EnvoScaleAsm/blob/main/docs/bootstrap.md)).
