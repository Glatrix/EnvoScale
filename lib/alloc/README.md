# `alloc`

> **Status:** Not started. Planned for **M4**.

Heap-backed types on top of `core`: allocator interface, `Box<T>`, `List<T>`, `string`, `Map<K, V>`, `Set<T>`, arenas.

## Simple door

```envo
var names = new List<string>();
```

## Full-control door

Every collection accepts an explicit allocator: `new List<int>(alloc: arena)`. The context allocator is used when none is given.

## Ports used

none (allocators are values, not ports)
