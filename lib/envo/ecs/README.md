# `envo.ecs`

> **Status:** Experimental (M11.2). Tests: `lib/envo/ecs/tests/`.

Entities and components (PLAN D54), the core `envo.render3d` and games share.
- **Entities** are an index plus a generation, so a handle to a despawned entity never
  reaches the entity that reuses its index.
- **Components** of each type live in a sparse set, `Store<T>`. The values are dense in one
  list, so a system runs through them in order. Adding, removing and finding one is O(1).

Envo-S1 has no runtime types, so a program declares a store per component type and
writes its systems as functions over the stores they use.

## Simple door

```envo
use envo.ecs;

ecs.World w = ecs.World.New();
ecs.Store<Position> positions = ecs.Store<Position>.New();
ecs.Entity e = w.Spawn();
positions.Set(e, new Position { X = 0.0, Y = 0.0 });
```

## Full-control door

- `World`: `Spawn`, `Despawn`, `IsAlive`, `Count`.
- `Store<T>`: `Set`, `Has`, `Get`, `Find` (the dense position), `Remove` (the last value
  fills the gap), `Values`, `ValuesMut`, `Entities` (the owner of each value), `Len`.

## Not yet

Archetype tables, queries over several stores at once, and a scheduler running systems
on several threads (with threads).

## Ports used

None.
