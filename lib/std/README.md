# `std`

> **Status:** Experimental (M4): `io`, `fs`, `path`, `time`, `env`, `random`. Written in
> Envo-S1. Tests: `lib/std/tests/`.

OS-level services built on ports, with no platform code
([`library.md`](../../docs/architecture/library.md)):

- `std.io`: `Print`, `Write`, `Error`, `ReadAll`.
- `std.fs`: `ReadText`, `WriteText`, `Exists`, `IsFile`, `IsDir`, `Delete`, `CreateDir`,
  `CreateDirAll`, `RemoveDir`.
- `std.path`: `Join`, `FileName`, `Stem`, `Extension`, `Parent`, `IsAbsolute` (text only).
- `std.time`: `NowNanos`, `MonoNanos`, `Now` (a UTC `Date`), `FromUnixNanos`,
  `FromUnixSeconds`, `Iso`, `Stopwatch`.
- `std.env`: `ArgCount`, `Arg`, `Args`.
- `std.random`: `Fill`, `U64`, `Below` (the system's generator) and `Rng` (seeded).

## Simple door

```envo
use std.fs;
var text = fs.ReadText("notes.txt").Unwrap();
```

The simple door uses the `platform` binding: the target's native adapters, or the
reference ones with `envoc --os none`.

## Full-control door

The same operations take the port explicitly (`…With`, `…To`, `…From`):
`fs.CreateDirAllWith(ref myFs, path)`, `io.PrintTo(ref console, text)`.

## Ports used

Console, FileSystem, Clock, Entropy, Environment. `thread`, `sync` and `async` wait
for the Threads and Executor ports (M6).
