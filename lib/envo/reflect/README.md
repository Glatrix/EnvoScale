# `envo.reflect`

> **Status:** Not started. Planned for **M5**. Tier when it lands: Experimental.

Compile-time reflection by default; runtime type info only for `[Reflect]` types.

## Simple door

```envo
foreach (var f in reflect.Fields<User>()) print(f.Name);
```

## Full-control door

Runtime type info, attribute queries, generators.

## Ports used

none
