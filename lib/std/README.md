# `std`

> **Status:** Not started. Planned for **M4**.

OS-level services built on ports: `io`, `fs`, `path`, `process`, `env`, `time`, `thread`, `sync`, `async`. No platform code: everything goes through `lib/ports`.

## Simple door

```envo
var text = fs.ReadText("notes.txt")?;
```

## Full-control door

Pass a specific `FileSystem` capability: `fs.With(myFs).ReadText(path)`.

## Ports used

FileSystem, Clock, Threads, Console, Executor, Entropy
