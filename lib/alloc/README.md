# `alloc`

> **Status:** Experimental (M4). Written in Envo-S1. Tests: `lib/alloc/tests/`.

Heap-backed types on top of `core` ([`library.md`](https://github.com/envoscale/EnvoScale/blob/main/architecture/library.md)):

- `alloc.map`: `Map<K, V>`, a hash table (open addressing, linear probing) for keys that
  implement `core.hash.IKey`: `Set`, `Get`/`GetOr` (copies), `View` (for values that are
  not `Copy`), `Has`, `Remove`, `Clear`, `Keys`, `Values`.
- `alloc.set`: `Set<T>` on top of `Map`.
- `alloc.box`: `Box<T>`, one owned value on the heap, for recursive types.
- `alloc.text`: `Int`, `Uint`, `Hex`, `Split`, `Lines`, `Join`, `Replace`, `Repeat`,
  `Lower`, `Upper`, `PadLeft`, `PadRight`.

`List<T>` and `string` are still the Envo-S1 prelude's.

## Simple door

```envo
use alloc.map.{Map};
var ages = Map<string, u64>.New();
ages.Set(string.From("ada"), 36);
```

## Full-control door

An allocator interface, so a collection can use an arena, comes when `envoc` compiles
the rest of chapter 5 (the context allocator of [own.alloc.1]).

## Ports used

none (allocators are values, not ports)
