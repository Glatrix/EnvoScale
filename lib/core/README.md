# `core`

> **Status:** Not started. Planned for **M4**.

Works on bare metal with no OS and no allocator: primitive types, `Option`/`Result`, core interfaces (`Copy`, `IEquatable`, …), slices, `str`, formatting.

## Simple door

```envo
print($"{1 + 2}")   // formatting lives in core; printing goes through a port
```

## Full-control door

Every core type is usable with no allocator and no OS. `[NoAlloc]` code can only call into `core`.

## Ports used

none
