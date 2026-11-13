# `lib/`

The standard library, in Envol. Nothing here touches an operating system: it reaches the
outside world only through **ports**, interfaces defined in [`ports/`](ports/README.md)
and implemented in [`adapters/`](../adapters/README.md). Using an adapter from `lib/` is a
compile error (E0215); the one meeting point is the `platform` binding, which the build
picks for the target. More: [docs/architecture/library.md](../docs/architecture/library.md).

| Folder | Needs | |
|---|---|---|
| [`core/`](core) | nothing | Works anywhere, even without an OS: `Option`, `Result`, slices, `str`, text and number formatting |
| [`alloc/`](alloc) | `core` | `List`, `string`, `Map` and the allocators |
| [`ports/`](ports) | `core` | Every port interface |
| [`std/`](std) | the above | Files, paths, processes, environment, time, randomness, the clipboard |
| [`envo/`](envo) | any of the above | Crypto, TLS, HTTP, JSON, EON, command lines, the GPU port's software device, AI |

Each module folder has a README (what it is for, the simple way in, the full-control way
in, and the ports it uses), its source and a `tests/` folder that `envo test` runs.
