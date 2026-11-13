# `compiler/driver`

> **Status:** Started in M3.1. `main.envol` is the entry file; `build.envol` holds the
> compiler as a library (`BuildProgram`, `CheckProgram`), which `envo` calls too
> ([`tooling.md`](https://github.com/envoscale/EnvoScale/blob/main/architecture/tooling.md)); `library.envol` resolves library
> modules (`--lib`).

The `envoc` entry point: command-line options, target selection, build profiles, and
running the query engine across threads.
