# OS adapters

> **Status:** `none`, `windows` and `linux` implement M4's ports: Console, FileSystem,
> Clock, Entropy and Environment. See
> [`docs/architecture/library.md`](../../docs/architecture/library.md).

One folder per operating system. Each holds the adapters (`<os>.envo`, namespace
`os.<os>`) and the `platform` binding (`platform.envo`) that `envoc --lib` loads for the
target, or for `--os none`. Threads, executors and networking come with M6 and M7.
