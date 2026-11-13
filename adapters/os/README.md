# OS adapters

> **Status:** `none`, `windows` and `linux` implement M4's ports: Console, FileSystem,
> Clock, Entropy and Environment. See
> [`EnvoScale/architecture/library.md`](https://github.com/envoscale/EnvoScale/blob/main/architecture/library.md).

One folder per operating system. Each holds the adapters (`<os>.envol`, namespace
`os.<os>`) and the `platform` binding (`platform.envol`) that `envoc --lib` loads for the
target, or for `--os none`. Threads, executors and networking come with M6 and M7.
