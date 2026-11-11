# `lib/` — the standard platform

> **Status:** Not started. `core`, `alloc`, `std` and `ports` arrive with **M4**; domain
> modules follow the milestone table in [`docs/PLAN.md`](../docs/PLAN.md).

Pure, platform-free Envo code. Everything here reaches the outside world only through
**ports**: interfaces defined in [`ports/`](ports/README.md) and implemented in
[`adapters/`](../adapters/README.md).

## The one rule

**`lib/**` may import only `lib/**`.** Importing anything from `adapters/**` is a build
error, enforced by the compiler from M3 and by `bootstrap.* check` before then.

## Layers

| Folder | Depends on | Purpose |
|---|---|---|
| `core/` | nothing | Works on bare metal: primitives, `Option`/`Result`, interfaces, slices, `str`, formatting |
| `alloc/` | `core` | Allocators, `Box`, `List`, `string`, `Map`, `Set` |
| `ports/` | `core` | Every port interface |
| `std/` | `core`, `alloc`, `ports` | io, fs, path, process, env, time, thread, sync, async |
| `prelude/` | the above | Names every file sees without a `use` |
| `envo/*` | any of the above | Domain modules: text, crypto, net, http, gfx, ui, web, ai, … |

## Module folder layout

Every module folder contains:

- `README.md`: purpose, the **simple door**, the **full-control door**, ports used,
  and stability tier
- the source
- `tests/`
- an `examples/` snippet
