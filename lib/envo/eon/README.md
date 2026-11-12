# `envo.eon`

> **Status:** Not started. Planned for **M5**. Tier when it lands: Experimental.

EON (Envo Object Notation) reader and writer, `[Derive(Eon)]`, and a compact binary form. Spec: `docs/spec/eon.md`.

## Simple door

```envo
var cfg = eon.Load<Config>("app.envon")?;
```

## Full-control door

Streaming reader/writer, a lossless document model for tools that must preserve comments.

## Ports used

FileSystem (only via the convenience loaders)
